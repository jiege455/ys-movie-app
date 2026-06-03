/**
 * 开发者：杰哥网络科技
 * 模块：API 通用类型定义
 */

/** 统一 API 响应格式 */
export interface ApiResponse<T = unknown> {
  code: number
  msg: string
  info?: T
  data?: T
}

/** API 错误类型 */
export type ApiErrorType = 'network' | 'server' | 'business' | 'timeout' | 'unknown'

/** API 错误对象 */
export interface ApiError {
  type: ApiErrorType
  message: string
  statusCode?: number
  originalError?: unknown
}

/** APP 页面设置 */
export interface AppPageSetting {
  app_tab_topic: number | boolean
  app_tab_topic_name: string
}

/** 分页参数 */
export interface PaginationParams {
  page?: number
  limit?: number
}

/** 分页结果 */
export interface PaginationResult<T> {
  list: T[]
  total: number
  page: number
  limit: number
}
