/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：视�?VOD) API
 * 说明：所有视频接口统一�?JgApp 插件 (pluginApi �?api.php/jgappapi.index/*)
 */

import { pluginApi } from './index'
import type { Movie, BannerMovie, MovieDetail, VodSource, VodEpisode, Category, TypeRecommendSection, CategoryFilter } from '../types'

export type { Movie, BannerMovie, MovieDetail, VodSource, VodEpisode, TypeRecommendSection, CategoryFilter }

const mapVodToMovie = (v: any): Movie => ({
  id: String(v.vod_id || v.id || ''),
  title: v.vod_name || v.title || '',
  poster_path: v.vod_pic || v.poster || v.pic || '',
  vote_average: Number(v.vod_score || v.score || 0),
  release_date: String(v.vod_year || v.year || ''),
  overview: v.vod_remarks || v.overview || v.blurb || ''
})

export interface HomeData {
  banners: BannerMovie[]
  hotMovies: Movie[]
  typeRecommendList: TypeRecommendSection[]
  categories: Category[]
  hotSearchList: string[]
}

/**
 * 获取首页完整数据
 * 插件接口: api.php/jgappapi.index/init
 * 修正：根据真�?API 返回结构调整
 *   - type_list 每个条目内嵌 recommend_list�?0条），直接使�? *   - 全局 recommend_list 为空，hotMovies 从分类推荐合并取�?N �? *   - 过滤 "全部" (type_id=0)
 */
export const getHomeData = async (): Promise<HomeData | null> => {
  try {
    const res: any = await pluginApi.get('init')

    // Banners
    const banners: BannerMovie[] = (res.banner_list || []).map((v: any) => ({
      id: String(v.vod_id || v.slide_id || v.id || ''),
      title: v.vod_name || v.slide_name || v.title || '',
      poster_path: v.vod_pic || v.slide_pic || v.poster || v.img || '',
      backdrop_path: v.vod_pic_slide || v.vod_pic || v.slide_pic || '',
      vote_average: Number(v.vod_score || 0),
      release_date: String(v.vod_year || ''),
      overview: v.vod_remarks || v.slide_remarks || '',
      link: v.vod_link || v.slide_url || v.url || ''
    }))

    // type_list: 每个分类内嵌 recommend_list�?0条影片）
    const rawTypeList: any[] = res.type_list || []

    // 分类推荐区块：过�?全部"和空推荐
    const typeRecommendList: TypeRecommendSection[] = rawTypeList
      .filter((t: any) => {
        const tid = String(t.type_id || '')
        const tname = t.type_name || ''
        const recCount = (t.recommend_list || []).length
        return tid !== '0' && tname !== '全部' && recCount > 0
      })
      .map((section: any) => ({
        type_id: String(section.type_id || ''),
        type_name: section.type_name || '',
        list: (section.recommend_list || section.list || []).map(mapVodToMovie)
      }))
      .filter(s => s.list.length > 0)

    // 分类元数据：同样过滤"全部"
    const categories: Category[] = rawTypeList
      .filter((v: any) => {
        const tid = String(v.type_id || '')
        const tname = v.type_name || ''
        const recCount = (v.recommend_list || []).length
        return tid !== '0' && tname !== '全部' && recCount > 0
      })
      .map((v: any) => ({
        type_id: String(v.type_id || ''),
        type_name: v.type_name || '',
        type_pid: String(v.type_pid || '0'),
        type_sort: Number(v.type_sort || 0),
        type_logo: v.type_logo || '',
        type_en: v.type_en || ''
      }))

    // 热播精选：全局 recommend_list 为空，从各分类推荐合并去重取�?N �?    const globalRecommend: Movie[] = (res.recommend_list || []).map(mapVodToMovie)
    let hotMovies: Movie[]
    if (globalRecommend.length > 0) {
      hotMovies = globalRecommend
    } else {
      // 从各分类推荐合并去重
      const seen = new Set<string>()
      hotMovies = []
      for (const section of typeRecommendList) {
        for (const m of section.list) {
          if (!seen.has(m.id) && hotMovies.length < 12) {
            seen.add(m.id)
            hotMovies.push(m)
          }
        }
      }
    }

    return {
      banners,
      hotMovies,
      typeRecommendList,
      categories,
      hotSearchList: res.hot_search_list || []
    }
  } catch (error) {
    console.error('获取首页数据失败:', error)
    return null
  }
}

/**
 * 获取热门视频列表（分页，用于发现页等场景�? * 插件接口: api.php/jgappapi.index/typeFilterVodList?sort=周榜
 */
export const getHotMovies = async (page: number = 1): Promise<Movie[]> => {
  try {
    const res: any = await pluginApi.get('typeFilterVodList', {
      params: { sort: '周榜', page, limit: 20 }
    })
    const list = res.recommend_list || res.vod_list || res.list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('获取热门视频失败:', error)
    return []
  }
}

/**
 * 获取Banner轮播图数�? */
export const getBannerMovies = async (): Promise<BannerMovie[]> => {
  try {
    const homeData = await getHomeData()
    return homeData?.banners || []
  } catch (error) {
    console.error('获取Banner失败:', error)
    return []
  }
}

/**
 * 按分类获取视频列表（支持筛选和分页�? * 插件接口: api.php/jgappapi.index/typeFilterVodList
 */
export const getCategoryMovies = async (
  categoryId: string,
  page: number = 1,
  filter: CategoryFilter = {}
): Promise<Movie[]> => {
  try {
    const by = filter.by || 'time'
    let sortParam = '最�?
    if (by === 'hits' || by === 'hits_week') sortParam = '周榜'
    else if (by === 'hits_day') sortParam = '日榜'
    else if (by === 'hits_month') sortParam = '月榜'
    else if (by === 'score') sortParam = '最�?
    else sortParam = '最�?

    const params: Record<string, string | number> = {
      type_id: Number(categoryId),
      page,
      limit: 20,
      sort: sortParam
    }
    if (filter.class) params.class = filter.class
    if (filter.area) params.area = filter.area
    if (filter.year) params.year = filter.year
    if (filter.lang) params.lang = filter.lang

    const res: any = await pluginApi.get('typeFilterVodList', { params })
    const list = res.recommend_list || res.vod_list || res.list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('获取分类视频失败:', error)
    return []
  }
}

/**
 * 获取全部分类列表
 */
export const getCategories = async (): Promise<Category[]> => {
  try {
    const homeData = await getHomeData()
    return homeData?.categories || []
  } catch (error) {
    console.error('获取分类列表失败:', error)
    return []
  }
}

/**
 * 按名称搜索视�? * 插件接口: api.php/jgappapi.index/searchList
 */
export const searchMovies = async (keyword: string): Promise<Movie[]> => {
  try {
    const res: any = await pluginApi.get('searchList', {
      params: { keywords: keyword, page: 1 }
    })
    const list = res.search_list || res.recommend_list || res.vod_list || res.list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('搜索视频失败:', error)
    return []
  }
}

/**
 * 高级搜索
 */
export const searchMoviesAdvanced = async (keyword: string, page: number = 1, _limit: number = 20): Promise<{ list: Movie[], total: number }> => {
  try {
    const res: any = await pluginApi.get('searchList', {
      params: { keywords: keyword, page }
    })
    const list = (res.search_list || res.recommend_list || res.vod_list || res.list || []).map(mapVodToMovie)
    return { list, total: list.length }
  } catch (error) {
    console.error('高级搜索失败:', error)
    return { list: [], total: 0 }
  }
}

/**
 * 获取视频详情（含解析后的播放列表�? * 插件接口: api.php/jgappapi.index/vodDetail
 */
export const getMovieDetail = async (id: string): Promise<MovieDetail | null> => {
  try {
    const res: any = await pluginApi.get('vodDetail', {
      params: { vod_id: Number(id) }
    })

    const info = res.vod || {}
    if (!info.vod_id) {
      console.error('视频详情加载失败: 视频不存�?)
      return null
    }

    const vodPlayList = res.vod_play_list || info.vod_play_list || []

    let playList: VodSource[] = []
    if (vodPlayList && Array.isArray(vodPlayList)) {
      playList = vodPlayList.map((src: any) => ({
        name: src.player_info?.show || src.show || src.from || '',
        urls: (src.urls || []).map((ep: any) => ({
          name: ep.name,
          url: ep.url
        }))
      }))
    }

    return {
      id: String(info.vod_id || id),
      title: info.vod_name || '',
      poster_path: info.vod_pic || '',
      backdrop_path: info.vod_pic_slide || info.vod_pic || '',
      vote_average: Number(info.vod_score || 0),
      release_date: String(info.vod_year || ''),
      overview: info.vod_blurb || info.vod_remarks || '',
      vod_play_list: playList
    }
  } catch (error) {
    console.error('获取视频详情失败:', error)
    return null
  }
}