import { create } from "zustand"
import type { UserAuth } from "../types"
import { getUserAuth, checkLoggedIn } from "../api"

export type { FavoriteItem } from "../types"

interface UserState {
  isLoggedIn: boolean
  user: UserAuth | null
  favorites: import("../types").FavoriteItem[]
  favoritesLoading: boolean

  setIsLoggedIn: (loggedIn: boolean) => void
  setUser: (user: UserAuth | null) => void
  setFavorites: (favorites: import("../types").FavoriteItem[]) => void
  setFavoritesLoading: (loading: boolean) => void

  initUser: () => void
  logout: () => void
  addFavoriteItem: (item: import("../types").FavoriteItem) => void
  removeFavoriteItem: (id: string) => void
}

const safeCheckLoggedIn = (): boolean => { try { return checkLoggedIn() } catch { return false } }
const safeGetUserAuth = (): UserAuth | null => { try { return getUserAuth() } catch { return null } }

export const useUserStore = create<UserState>((set) => ({
  isLoggedIn: safeCheckLoggedIn(),
  user: safeGetUserAuth(),
  favorites: [],
  favoritesLoading: false,

  setIsLoggedIn: (isLoggedIn) => set({ isLoggedIn }),
  setUser: (user) => set({ user }),
  setFavorites: (favorites) => set({ favorites }),
  setFavoritesLoading: (favoritesLoading) => set({ favoritesLoading }),

  initUser: () => {
    const loggedIn = safeCheckLoggedIn()
    const user = safeGetUserAuth()
    set({ isLoggedIn: loggedIn, user })
  },

  logout: () => {
    localStorage.removeItem("user_auth")
    set({ isLoggedIn: false, user: null, favorites: [], favoritesLoading: false })
  },

  addFavoriteItem: (item) => set((state) => ({
    favorites: [item, ...state.favorites]
  })),

  removeFavoriteItem: (id) => set((state) => ({
    favorites: state.favorites.filter((f) => String(f.id) !== String(id))
  }))
}))