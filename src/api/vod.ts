/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：视频(VOD) API
 * 说明：所有视频接口统一走 杰哥插件 API (jgappApi → app_api.php)
 *       插件内部通过 think\Db 直接查询 CMS 数据库，无需开启 CMS 接口开关
 */

import { jgappApi } from './index'
import type { Movie, BannerMovie, MovieDetail, VodSource, VodEpisode, Category, TypeRecommendSection } from '../types'

export type { Movie, BannerMovie, MovieDetail, VodSource, VodEpisode, TypeRecommendSection }

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
 * 插件接口: ac=init
 */
export const getHomeData = async (): Promise<HomeData | null> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'init' }
    })
    if (res?.code !== 1) {
      console.error('首页数据加载失败:', res?.msg)
      return null
    }

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
 * 插件接口: ac=list
 */
export const getHotMovies = async (page: number = 1): Promise<Movie[]> => {
  try {
    const limit = 20
    const res: any = await jgappApi.get('', {
      params: { ac: 'list', pg: page, pagesize: limit, by: 'hits_week' }
    })
    const list = res?.list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('获取热门视频失败:', error)
    return []
  }
}

/**
 * 获取Banner轮播图数据（推荐级别9）
 * 插件接口: ac=init 已包含，单独调时用 ac=list 带 level 参数
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
 * 按分类获取视频列表（支持分页）
 * 插件接口: ac=list&t=type_id
 */
export const getCategoryMovies = async (categoryId: string, page: number = 1): Promise<Movie[]> => {
  try {
    const limit = 20
    const res: any = await jgappApi.get('', {
      params: { ac: 'list', t: categoryId, pg: page, pagesize: limit, by: 'time' }
    })
    const list = res?.list || []
    return list.map(mapVodToMovie)
  } catch (error) {
    console.error('获取分类视频失败:', error)
    return []
  }
}

/**
 * 获取全部分类列表
 * 插件接口: ac=init 的 type_list 字段
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
 * 插件接口: ac=search（app_api.php 内部自动处理降级）
 */
export const searchMovies = async (keyword: string): Promise<Movie[]> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'search', wd: keyword, page: 1, limit: 20 }
    })
    if (res?.code === 1 && res.list) {
      return res.list.map(mapVodToMovie)
    }
    return []
  } catch (error) {
    console.error('搜索视频失败:', error)
    return []
  }
}

/**
 * 高级搜索（返回完整信息包括总数和搜索来源）
 * 插件接口: ac=search
 */
export const searchMoviesAdvanced = async (keyword: string, page: number = 1, limit: number = 20): Promise<{ list: Movie[], total: number, source: string }> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'search', wd: keyword, page, limit }
    })
    if (res?.code === 1) {
      return {
        list: (res.list || []).map(mapVodToMovie),
        total: res.total || 0,
        source: res.source || 'database'
      }
    }
    return { list: [], total: 0, source: 'database' }
  } catch (error) {
    console.error('高级搜索失败:', error)
    return { list: [], total: 0, source: 'database' }
  }
}

/**
 * 获取视频详情（含解析后的播放列表）
 * 插件接口: ac=detail&ids=vod_id
 */
export const getMovieDetail = async (id: string): Promise<MovieDetail | null> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'detail', ids: id }
    })
    if (res?.code !== 1 || !res.list || res.list.length === 0) {
      console.error('视频详情加载失败:', res?.msg)
      return null
    }
    const info = res.list[0] || {}

    let playList: VodSource[] = []
    if (info.vod_play_list && Array.isArray(info.vod_play_list)) {
      playList = info.vod_play_list.map((src: any) => ({
        name: src.show || src.name,
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
