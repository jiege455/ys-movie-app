/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：用户 API
 * 说明：登录、注册、退出、收藏相关接口
 */

import { api } from './index'

// ============================================================
// 类型定义
// ============================================================

export interface UserAuth {
  user_id: string
  user_name: string
  user_check: string
}

export interface UserInfo {
  user_id: string
  user_name: string
  user_nick_name: string
  user_phone: string
  user_reg_time: number
}

export interface FavoriteItem {
  id: string
  vodId: string
  title: string
  poster: string
  time: number
}

export interface ApiResult<T = unknown> {
  success: boolean
  data?: T
  message: string
}

// ============================================================
// 本地存储工具
// ============================================================

const AUTH_KEY = 'user_auth'
const AUTH_EXPIRE_KEY = 'user_auth_expire'
const AUTH_EXPIRE_DAYS = 7

export const saveUserAuth = (auth: UserAuth) => {
  localStorage.setItem(AUTH_KEY, JSON.stringify(auth))
  const expireTime = Date.now() + AUTH_EXPIRE_DAYS * 24 * 60 * 60 * 1000
  localStorage.setItem(AUTH_EXPIRE_KEY, String(expireTime))
}

export const getUserAuth = (): UserAuth | null => {
  try {
    const expireTime = localStorage.getItem(AUTH_EXPIRE_KEY)
    if (expireTime && Date.now() > parseInt(expireTime, 10)) {
      clearUserAuth()
      return null
    }
    const auth = localStorage.getItem(AUTH_KEY)
    return auth ? JSON.parse(auth) : null
  } catch {
    return null
  }
}

export const clearUserAuth = () => {
  localStorage.removeItem(AUTH_KEY)
  localStorage.removeItem(AUTH_EXPIRE_KEY)
}

export const checkLoggedIn = (): boolean => {
  return getUserAuth() !== null
}

// ============================================================
// API 函数
// ============================================================

/**
 * 用户登录
 */
export const userLogin = async (userName: string, userPwd: string): Promise<ApiResult<UserAuth>> => {
  try {
    const res: any = await api.post('/user/login', { user_name: userName, user_pwd: userPwd })
    if (res?.code === 1 && res?.info) {
      const auth: UserAuth = {
        user_id: String(res.info.user_id),
        user_name: res.info.user_name,
        user_check: res.info.user_check
      }
      saveUserAuth(auth)
      return { success: true, data: auth, message: '登录成功' }
    }
    return { success: false, message: res?.msg || '登录失败，请检查用户名和密码' }
  } catch (error) {
    console.error('登录失败:', error)
    return { success: false, message: '网络错误，请稍后重试' }
  }
}

/**
 * 用户注册
 */
export const userRegister = async (userName: string, userPwd: string, userPwd2: string): Promise<ApiResult<UserAuth>> => {
  try {
    const res: any = await api.post('/user/reg', {
      user_name: userName,
      user_pwd: userPwd,
      user_pwd2: userPwd2
    })
    if (res?.code === 1 && res?.info) {
      const auth: UserAuth = {
        user_id: String(res.info.user_id),
        user_name: res.info.user_name,
        user_check: res.info.user_check
      }
      saveUserAuth(auth)
      return { success: true, data: auth, message: '注册成功' }
    }
    return { success: false, message: res?.msg || '注册失败，用户名可能已存在' }
  } catch (error) {
    console.error('注册失败:', error)
    return { success: false, message: '网络错误，请稍后重试' }
  }
}

/**
 * 用户退出登录
 */
export const userLogout = async (): Promise<ApiResult<null>> => {
  try {
    const res: any = await api.post('/user/logout')
    clearUserAuth()
    if (res?.code === 1) {
      return { success: true, message: '退出成功' }
    }
    return { success: true, message: '已退出登录' }
  } catch (error) {
    console.error('退出失败:', error)
    clearUserAuth()
    return { success: true, message: '已清除登录状态' }
  }
}

// ============================================================
// 收藏 API
// ============================================================

/**
 * 添加收藏
 */
export const addFavorite = async (rid: string | number, mid: number = 1): Promise<ApiResult<null>> => {
  try {
    const res: any = await api.post('/user/ulog_add', {
      mid: mid,
      type: 4,
      rid: rid
    })
    if (res?.code === 1) {
      return { success: true, message: '收藏成功' }
    }
    return { success: false, message: res?.msg || '收藏失败' }
  } catch (error) {
    console.error('添加收藏失败:', error)
    return { success: false, message: '网络错误，请稍后重试' }
  }
}

/**
 * 取消收藏
 */
export const removeFavorite = async (rid: string | number, mid: number = 1): Promise<ApiResult<null>> => {
  try {
    const res: any = await api.post('/user/ulog_del', {
      mid: mid,
      type: 4,
      rid: rid
    })
    if (res?.code === 1) {
      return { success: true, message: '已取消收藏' }
    }
    return { success: false, message: res?.msg || '取消收藏失败' }
  } catch (error) {
    console.error('取消收藏失败:', error)
    return { success: false, message: '网络错误，请稍后重试' }
  }
}

/**
 * 获取收藏列表
 */
export const getFavorites = async (page: number = 1, limit: number = 20): Promise<FavoriteItem[]> => {
  try {
    const res: any = await api.get('/user/ulog_list', {
      params: { type: 4, mid: 1, page, limit }
    })
    if (res?.code === 1 && res?.info?.list) {
      return res.info.list.map((item: any) => {
        const data = item.data || item.vod_data || {}
        return {
          id: String(item.ulog_id || item.id || ''),
          vodId: String(item.ulog_rid || item.rid || ''),
          title: data.name || data.vod_name || item.vod_name || '未知标题',
          poster: data.pic || data.vod_pic || item.vod_pic || '',
          time: item.ulog_time || item.time || 0
        }
      })
    }
    return []
  } catch (error) {
    console.error('获取收藏失败:', error)
    return []
  }
}

/**
 * 检查是否已收藏
 */
export const checkFavoriteStatus = async (rid: string | number, mid: number = 1): Promise<boolean> => {
  try {
    const res: any = await api.get('/user/ulog_check', {
      params: { type: 4, mid: mid, rid: rid }
    })
    return res?.code === 1 && res?.info?.is_favorite === 1
  } catch (error) {
    console.error('检查收藏状态失败:', error)
    return false
  }
}
