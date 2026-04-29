import { create } from 'zustand'
import { UserAuth, getUserAuth, checkLoggedIn } from '../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 用户状态管理
 * 管理登录状态、用户信息、收藏列表等
 */

/**
 * 收藏项
 */
export interface FavoriteItem {
  id: string
  vodId: string
  title: string
  poster: string
  time: number
}

/**
 * 用户状态接口
 */
interface UserState {
  // 状态数据
  isLoggedIn: boolean
  user: UserAuth | null
  favorites: FavoriteItem[]
  favoritesLoading: boolean

  // 操作方法
  setIsLoggedIn: (loggedIn: boolean) => void
  setUser: (user: UserAuth | null) => void
  setFavorites: (favorites: FavoriteItem[]) => void
  setFavoritesLoading: (loading: boolean) => void

  // 业务方法
  initUser: () => void
  logout: () => void
  addFavoriteItem: (item: FavoriteItem) => void
  removeFavoriteItem: (id: string) => void
}

/**
 * 用户状态管理Store
 * 用于管理用户登录状态、收藏列表等
 */
export const useUserStore = create<UserState>((set) => ({
  // 初始状态
  isLoggedIn: checkLoggedIn(),
  user: getUserAuth(),
  favorites: [],
  favoritesLoading: false,

  // 基础设置方法
  setIsLoggedIn: (isLoggedIn) => set({ isLoggedIn }),
  setUser: (user) => set({ user }),
  setFavorites: (favorites) => set({ favorites }),
  setFavoritesLoading: (favoritesLoading) => set({ favoritesLoading }),

  // 业务逻辑方法
  initUser: () => {
    const loggedIn = checkLoggedIn()
    const user = getUserAuth()
    set({ isLoggedIn: loggedIn, user })
  },

  logout: () => {
    localStorage.removeItem('user_auth')
    set({ isLoggedIn: false, user: null, favorites: [] })
  },

  addFavoriteItem: (item) => set((state) => ({
    favorites: [item, ...state.favorites]
  })),

  // 开发者：杰哥网络科技 (qq: 2711793818)
  // 修复：统一转为字符串比较，避免类型不匹配导致删除失败
  removeFavoriteItem: (id) => set((state) => ({
    favorites: state.favorites.filter((f) => String(f.id) !== String(id))
  }))
}))
