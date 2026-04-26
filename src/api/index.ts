import axios from 'axios'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：API 统一入口
 * 说明：所有后端 API 调用都从这里导出，按业务模块拆分
 *       vod.ts  - 视频相关
 *       user.ts - 用户/收藏相关
 *       comment.ts - 评论相关
 *       app.ts  - APP设置相关
 */

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api.php'

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true
})

/**
 * 请求拦截器：自动携带用户登录凭证
 * 说明：MacCMS原生接口依赖Cookie中的user_id/user_name/user_check
 */
api.interceptors.request.use(
  (config) => {
    // 从localStorage获取登录信息
    const authStr = localStorage.getItem('user_auth')
    if (authStr) {
      try {
        const auth = JSON.parse(authStr)
        // MacCMS通过Cookie验证，这里确保withCredentials已启用
        // 如果后端支持Header验证，可以取消下面注释
        // config.headers['X-User-Id'] = auth.user_id
        // config.headers['X-User-Name'] = auth.user_name
        // config.headers['X-User-Check'] = auth.user_check
      } catch {
        // 解析失败，忽略
      }
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

api.interceptors.response.use(
  (response) => response.data,
  (error) => {
    console.error('API请求错误:', error)
    return Promise.reject(error)
  }
)

/**
 * 统一API响应格式
 */
export interface ApiResponse<T = any> {
  code: number
  msg: string
  info?: T
  data?: T
}

/**
 * 返回图片URL（MacCMS 已是完整地址则直接返回，否则拼接域名）
 */
export const getImageUrl = (path: string) => {
  if (!path) return 'https://via.placeholder.com/300x450?text=No+Image'
  if (/^https?:\/\//i.test(path)) return path
  // MacCMS 可能返回相对路径，需要拼接域名
  const baseUrl = import.meta.env.VITE_IMAGE_BASE_URL || ''
  if (baseUrl) {
    return baseUrl + path
  }
  return 'https://via.placeholder.com/300x450?text=No+Image'
}

// 统一导出所有模块
export * from './vod'
export * from './user'
export * from './comment'
export * from './app'
