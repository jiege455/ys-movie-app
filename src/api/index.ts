import axios from 'axios'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：API 统一入口
 * 说明：所有后端 API 调用都从这里导出，按业务模块拆分
 *       vod.ts  - 视频相关
 *       user.ts - 用户/收藏相关
 *       comment.ts - 评论相关
 *       app.ts  - APP设置相关
 *
 * 【重要】所有数据接口统一走 杰哥插件 API (app_api.php)
 * 插件内部通过 think\Db 直接查询 CMS 数据库，无需开启 CMS 后台接口开关
 */

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || `${window.location.origin}/api.php`
const JGAPP_API_URL = import.meta.env.VITE_APP_API_URL || `${window.location.origin}/app_api.php`

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true
})

/**
 * 杰哥插件 API 实例
 * 通过 app_api.php 直接操作 CMS 数据库，不依赖 CMS 原生接口开关
 * 接口采用 ac=action 方式调用：ac=init, ac=list, ac=detail 等
 */
export const jgappApi = axios.create({
  baseURL: JGAPP_API_URL,
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true
})

api.interceptors.request.use(
  (config) => {
    const authStr = localStorage.getItem('user_auth')
    if (authStr) {
      try { JSON.parse(authStr) } catch { /* 忽略 */ }
    }
    return config
  },
  (error) => Promise.reject(error)
)

api.interceptors.response.use(
  (response) => {
    if (response.data && typeof response.data === 'object' && 'code' in response.data) {
      return response.data
    }
    return response
  },
  (error) => {
    console.error('API请求错误:', error)
    return Promise.reject(error)
  }
)

jgappApi.interceptors.response.use(
  (response) => {
    if (response.data && typeof response.data === 'object' && 'code' in response.data) {
      return response.data
    }
    return response
  },
  (error) => {
    console.error('插件API请求错误:', error)
    return Promise.reject(error)
  }
)

export type { ApiResponse } from '../types'

export const getImageUrl = (path: string) => {
  if (!path) return 'https://via.placeholder.com/300x450?text=No+Image'
  if (/^https?:\/\//i.test(path)) return path
  const baseUrl = import.meta.env.VITE_IMAGE_BASE_URL || ''
  if (baseUrl) {
    return baseUrl + path
  }
  return 'https://via.placeholder.com/300x450?text=No+Image'
}

export * from './vod'
export * from './user'
export * from './comment'
export * from './app'
export * from './message'
