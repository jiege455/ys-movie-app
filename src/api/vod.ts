/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：视频(VOD) API
 * 说明：所有视频接口统一走 JgApp 插件 (pluginApi → api.php/jgappapi.index/*)
 *       插件内部通过 think\Db 直接查询 CMS 数据库，无需开启 CMS 接口开关
 *       无需额外上传 php 文件到宝塔
 */

import { pluginApi } from './index'
import type { Movie, BannerMovie, MovieDetail, VodSource, VodEpisode, Category, TypeRecommendSection, CategoryFilter } from '../types'

export type { Movie, BannerMovie, MovieDetail, VodSource, VodEpisode, TypeRecommendSection, CategoryFilter }

const mapVodToMovie = (v: any): Movie => ({
  id: String(v.vod_id),
  title: v.vod_name,
  poster_path: v.vod_pic || '',
  vote_average: Number(v.vod_score || 0),
  release_date: String(v.vod_year || ''),
  overview: v.vod_remarks || ''
})

export interface HomeData {
  banners: BannerMovie[]
  hotMovies: Movie[]
  typeRecommendList: TypeRecommendSection[]
  categories: Category[]
  hotSearchList: string[]
}

/**
 * 获取首页完整数据（一次请求返回轮播图+推荐+分类+热搜词）
 * 插件接口: api.php/jgappapi.index/init
 */
export const getHomeData = async (): Promise<HomeData | null> => {
  try {
    const res: any = await pluginApi.get('init')

    const banners: BannerMovie[] = (res.banner_list || []).map((v: any) => ({
      id: String(v.vod_id),
      title: v.vod_name,
      poster_path: v.vod_pic || '',
      backdrop_path: v.vod_pic_slide || v.vod_pic || '',
      vote_average: Number(v.vod_score || 0),
      release_date: String(v.vod_year || ''),
      overview: v.vod_remarks || '',
      link: v.vod_link || ''
    }))

    const hotMovies: Movie[] = (res.recommend_list || []).map(mapVodToMovie)

    const typeRecommendList: TypeRecommendSection[] = (res.type_recommend_list || []).map(
      (section: any) => ({
        type_id: String(section.type_id || ''),
        type_name: section.type_name || '',
        list: (section.list || []).map(mapVodToMovie)
      })
    )

    const categories: Category[] = (res.type_list || []).map((v: any) => ({
      type_id: String(v.type_id || ''),
      type_name: v.type_name || '',
      type_pid: String(v.type_pid || '0'),
      type_sort: Number(v.type_sort || 0),
      type_logo: v.type_logo || '',
      type_en: v.type_en || ''
    }))

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
 * 获取热门视频列表（分页，用于发现页等场景）
 * 插件接口: api.php/jgappapi.index/typeFilterVodList?sort=周榜
 */
export const getHotMovies = async (page: number = 1): Promise<Movie[]> => {
  try {
    const res: any = await pluginApi.get('typeFilterVodList', {
      params: { sort: '周榜', page, pagesize: 20 }
    })
    const list = res.recommend_list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('获取热门视频失败:', error)
    return []
  }
}

/**
 * 获取Banner轮播图数据
 * 插件接口: init 已包含，单独调时复用 getHomeData
 */
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
 * 按分类获取视频列表（支持筛选和分页）
 * 插件接口: api.php/jgappapi.index/typeFilterVodList
 */
export const getCategoryMovies = async (
  categoryId: string,
  page: number = 1,
  filter: CategoryFilter = {}
): Promise<Movie[]> => {
  try {
    const by = filter.by || 'time'
    let sortParam = '最新'
    if (by === 'hits' || by === 'hits_week') sortParam = '周榜'
    else if (by === 'hits_day') sortParam = '日榜'
    else if (by === 'hits_month') sortParam = '月榜'
    else if (by === 'score') sortParam = '最赞'
    else sortParam = '最新'

    const params: Record<string, string | number> = {
      type_id: Number(categoryId),
      page,
      pagesize: 20,
      sort: sortParam
    }
    if (filter.class) params.class = filter.class
    if (filter.area) params.area = filter.area
    if (filter.year) params.year = filter.year
    if (filter.lang) params.lang = filter.lang

    const res: any = await pluginApi.get('typeFilterVodList', { params })
    const list = res.recommend_list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('获取分类视频失败:', error)
    return []
  }
}

/**
 * 获取全部分类列表
 * 插件接口: init 的 type_list 字段
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
 * 按名称搜索视频（优先使用Xunsearch，失败降级到数据库搜索）
 * 插件接口: api.php/jgappapi.index/searchList
 */
export const searchMovies = async (keyword: string): Promise<Movie[]> => {
  try {
    const res: any = await pluginApi.get('searchList', {
      params: { keywords: keyword, page: 1 }
    })
    const list = res.search_list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('搜索视频失败:', error)
    return []
  }
}

/**
 * 高级搜索（返回完整信息包括总数字段）
 * 插件接口: api.php/jgappapi.index/searchList
 */
export const searchMoviesAdvanced = async (keyword: string, page: number = 1, _limit: number = 20): Promise<{ list: Movie[], total: number }> => {
  try {
    const res: any = await pluginApi.get('searchList', {
      params: { keywords: keyword, page }
    })
    const list = (res.search_list || []).map(mapVodToMovie)
    return { list, total: list.length }
  } catch (error) {
    console.error('高级搜索失败:', error)
    return { list: [], total: 0 }
  }
}

/**
 * 获取视频详情（含解析后的播放列表）
 * 插件接口: api.php/jgappapi.index/vodDetail
 */
export const getMovieDetail = async (id: string): Promise<MovieDetail | null> => {
  try {
    const res: any = await pluginApi.get('vodDetail', {
      params: { vod_id: Number(id) }
    })

    const info = res.vod || {}
    if (!info.vod_id) {
      console.error('视频详情加载失败: 视频不存在')
      return null
    }

    let playList: VodSource[] = []
    if (info.vod_play_list && Array.isArray(info.vod_play_list)) {
      playList = info.vod_play_list.map((src: any) => ({
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
