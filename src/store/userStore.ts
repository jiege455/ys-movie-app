import { create } from 'zustand'
import type { UserAuth } from '../types'
import { getUserAuth, checkLoggedIn } from '../api'

export type { FavoriteItem } from '../types'

interface UserState {
  isLoggedIn: boolean
  user: UserAuth | null
  favorites: import('../types').FavoriteItem[]
  favoritesLoading: boolean

  setIsLoggedIn: (loggedIn: boolean) => void
  setUser: (user: UserAuth | null) => void
  setFavorites: (favorites: import('../types').FavoriteItem[]) => void
  setFavoritesLoading: (loading: boolean) => void

  initUser: () => void
  logout: () => void
  addFavoriteItem: (item: import('../types').FavoriteItem) => void
  removeFavoriteItem: (id: string) => void
}

export const useUserStore = create<UserState>((set) => ({
  isLoggedIn: checkLoggedIn(),
  user: getUserAuth(),
  favorites: [],
  favoritesLoading: false,

  setIsLoggedIn: (isLoggedIn) => set({ isLoggedIn }),
  setUser: (user) => set({ user }),
  setFavorites: (favorites) => set({ favorites }),
  setFavoritesLoading: (favoritesLoading) => set({ favoritesLoading }),

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

  removeFavoriteItem: (id) => set((state) => ({
    favorites: state.favorites.filter((f) => String(f.id) !== String(id))
  }))
}))
