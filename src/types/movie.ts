/**
 * 开发者：杰哥网络科技
 * 模块：视频(VOD)相关类型定义
 */

/** 基础视频信息 */
export interface Movie {
  id: string
  title: string
  poster_path: string
  vote_average: number
  release_date: string
  overview: string
}

/** 轮播图视频（扩展背景图和链接） */
export interface BannerMovie extends Movie {
  backdrop_path: string
  link: string
}

/** 视频详情（含播放列表） */
export interface MovieDetail extends Movie {
  backdrop_path: string
  vod_play_list: VodSource[]
}

/** 播放剧集 */
export interface VodEpisode {
  name?: string
  url: string
}

/** 播放源 */
export interface VodSource {
  name?: string
  urls?: VodEpisode[]
}

/** 分类信息（从 MacCMS 获取的真实分类数据） */
export interface Category {
  type_id: string
  type_name: string
  type_pid: string
  type_sort: number
  type_logo?: string
  type_en?: string
  children?: Category[]
}

/** 首页分类推荐区块（电影/电视剧/动漫/综艺各自的热播列表） */
export interface TypeRecommendSection {
  type_id: string
  type_name: string
  list: Movie[]
}

/** 分类视频筛选参数 */
export interface CategoryFilter {
  class?: string
  area?: string
  year?: string
  lang?: string
  by?: string
}
