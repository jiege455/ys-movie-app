/**
 * 开发者：杰哥网络科技
 * 模块：用户相关类型定义
 */

/** 用户认证信息 */
export interface UserAuth {
  user_id: string
  user_name: string
  user_check: string
  auth_token?: string
  user_nick_name?: string
  user_avatar?: string
}

/** 用户详细信息 */
export interface UserInfo {
  user_id: string
  user_name: string
  user_nick_name: string
  user_phone: string
  user_reg_time: number
}

/** 收藏项 */
export interface FavoriteItem {
  id: string
  vodId: string
  title: string
  poster: string
  time: number
}
