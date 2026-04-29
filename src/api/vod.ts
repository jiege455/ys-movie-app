/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：视频(VOD) API
 * 说明：视频列表、详情、搜索相关接口
 */

import axios from 'axios'
import { api } from './index'

// ============================================================
// 类型定义
// ============================================================

export interface Movie {
  id: string
  title: string
  poster_path: string
  vote_average: number
  release_date: string
  overview: string
}

export interface BannerMovie extends Movie {
  backdrop_path: string
  link: string
}

export interface MovieDetail extends Movie {
  backdrop_path: string
  vod_play_list: VodSource[]
}

export interface VodEpisode {
  name?: string
  url: string
}

export interface VodSource {
  name?: string
  urls?: VodEpisode[]
}

// ============================================================
// 数据映射
// ============================================================

const mapVodToMovie = (v: any): Movie => ({
  id: String(v.vod_id),
  title: v.vod_name,
  poster_path: v.vod_pic || '',
  vote_average: Number(v.vod_score || 0),
  release_date: String(v.vod_year || ''),
  overview: v.vod_remarks || ''
})

// ============================================================
// API 函数
// ============================================================

/**
 * 获取热门视频列表（按周热度）
 */
export const getHotMovies = async (page: number = 1): Promise<Movie[]> => {
  try {
    const limit = 20
    const offset = (page - 1) * limit
    const res: any = await api.get('/vod/get_list', {
      params: { offset, limit, orderby: 'hits_week' }
    })
    const rows = res?.info?.rows || []
    return rows.map(mapVodToMovie)
  } catch (error) {
    console.error('获取热门视频失败:', error)
    return []
  }
}

/**
 * 获取Banner轮播图数据（推荐级别9）
 */
export const getBannerMovies = async (): Promise<BannerMovie[]> => {
  try {
    const res: any = await api.get('/vod/get_list', {
      params: { limit: 5, orderby: 'hits_week', level: 9 }
    })
    const rows = res?.info?.rows || []
    return rows.map((v: any) => ({
      id: String(v.vod_id),
      title: v.vod_name,
      poster_path: v.vod_pic || '',
      backdrop_path: v.vod_pic_slide || v.vod_pic || '',
      vote_average: Number(v.vod_score || 0),
      release_date: String(v.vod_year || ''),
      overview: v.vod_remarks || '',
      link: v.vod_link || ''
    }))
  } catch (error) {
    console.error('获取Banner失败:', error)
    return []
  }
}

/**
 * 按分类获取视频列表
 */
export const getCategoryMovies = async (categoryId: string, page: number = 1): Promise<Movie[]> => {
  try {
    const limit = 20
    const offset = (page - 1) * limit
    const res: any = await api.get('/vod/get_list', {
      params: { type_id: categoryId, offset, limit, orderby: 'time' }
    })
    const rows = res?.info?.rows || []
    return rows.map(mapVodToMovie)
  } catch (error) {
    console.error('获取分类视频失败:', error)
    return []
  }
}

/**
 * 按名称搜索视频（优先使用Xunsearch，失败降级到MacCMS原生搜索）
 * 说明：Xunsearch搜索速度更快，支持模糊匹配
 */
export const searchMovies = async (keyword: string): Promise<Movie[]> => {
  try {
    // 优先调用Xunsearch搜索（app_api.php）
    const appApiBase = import.meta.env.VITE_APP_API_URL || '/app_api.php'
    const res: any = await axios.get(appApiBase, {
      params: { ac: 'search', wd: keyword, page: 1, limit: 20 },
      timeout: 10000
    })
    if (res?.data?.code === 1 && res.data.list) {
      return res.data.list.map((v: any) => ({
        id: String(v.vod_id),
        title: v.vod_name,
        poster_path: v.vod_pic || '',
        vote_average: Number(v.vod_score || 0),
        release_date: String(v.vod_year || ''),
        overview: v.vod_remarks || ''
      }))
    }
    // Xunsearch失败，降级到MacCMS原生搜索
    console.warn('Xunsearch搜索失败，降级到数据库搜索')
  } catch (error) {
    console.warn('Xunsearch搜索异常，降级到数据库搜索:', error)
  }

  // 降级：使用MacCMS原生搜索
  try {
    const res: any = await api.get('/vod/get_list', {
      params: { vod_name: keyword, limit: 20 }
    })
    const rows = res?.info?.rows || []
    return rows.map(mapVodToMovie)
  } catch (error) {
    console.error('搜索视频失败:', error)
    return []
  }
}

/**
 * 高级搜索（Xunsearch，返回完整信息包括总数和搜索来源）
 * 说明：需要显示搜索结果总数时使用此接口
 */
export const searchMoviesAdvanced = async (keyword: string, page: number = 1, limit: number = 20): Promise<{ list: Movie[], total: number, source: string }> => {
  try {
    // 优先调用Xunsearch搜索（app_api.php）
    const appApiBase = import.meta.env.VITE_APP_API_URL || '/app_api.php'
    const res: any = await axios.get(appApiBase, {
      params: { ac: 'search', wd: keyword, page, limit },
      timeout: 10000
    })
    if (res?.data?.code === 1) {
      const list = (res.data.list || []).map((v: any) => ({
        id: String(v.vod_id),
        title: v.vod_name,
        poster_path: v.vod_pic || '',
        vote_average: Number(v.vod_score || 0),
        release_date: String(v.vod_year || ''),
        overview: v.vod_remarks || ''
      }))
      return {
        list,
        total: res.data.total || 0,
        source: res.data.source || 'database'
      }
    }
    // Xunsearch失败，降级到MacCMS原生搜索
    console.warn('Xunsearch高级搜索失败，降级到数据库搜索')
  } catch (error) {
    console.warn('Xunsearch高级搜索异常，降级到数据库搜索:', error)
  }

  // 降级：使用MacCMS原生搜索
  try {
    const res: any = await api.get('/vod/get_list', {
      params: { vod_name: keyword, limit }
    })
    const rows = res?.info?.rows || []
    return {
      list: rows.map(mapVodToMovie),
      total: res?.info?.total || 0,
      source: 'database'
    }
  } catch (error) {
    console.error('高级搜索降级失败:', error)
    return { list: [], total: 0, source: 'database' }
  }
}

/**
 * 获取视频详情（含解析后的播放列表）
 */
export const getMovieDetail = async (id: string): Promise<MovieDetail | null> => {
  try {
    const res: any = await api.get('/vod/get_detail', { params: { vod_id: id } })
    const info = res?.info || {}

    // 播放列表兼容处理：MacCMS可能返回不同格式
    let playList: VodSource[] = []
    if (info.vod_play_list && Array.isArray(info.vod_play_list)) {
      playList = info.vod_play_list
    } else if (info.vod_play_url) {
      // 兼容：有些版本返回vod_play_url字符串，需要解析
      // 格式："源1$$$第1集$url1#第2集$url2$$$源2$$$..."
      playList = parseVodPlayUrl(info.vod_play_url)
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

/**
 * 解析MacCMS的vod_play_url字符串为结构化播放列表
 * 格式："源1名称$$$第1集$url1#第2集$url2$$$源2名称$$$..."
 */
function parseVodPlayUrl(playUrl: string): VodSource[] {
  if (!playUrl) return []

  const sources: VodSource[] = []
  // MacCMS格式：源名$$$集1$URL1#集2$URL2$$$源名2$$$...
  const sourceParts = playUrl.split('$$$')

  for (let i = 0; i < sourceParts.length; i += 2) {
    const sourceName = sourceParts[i] || '默认源'
    const episodesStr = sourceParts[i + 1] || ''

    if (!episodesStr) continue

    const episodes: VodEpisode[] = []
    const episodeParts = episodesStr.split('#')

    for (const ep of episodeParts) {
      const dollarIndex = ep.lastIndexOf('$')
      if (dollarIndex > 0) {
        const epName = ep.substring(0, dollarIndex)
        const epUrl = ep.substring(dollarIndex + 1)
        if (epUrl) {
          episodes.push({ name: epName || undefined, url: epUrl })
        }
      }
    }

    if (episodes.length > 0) {
      sources.push({ name: sourceName, urls: episodes })
    }
  }

  return sources.length > 0 ? sources : [{ urls: [{ url: playUrl }] }]
}
