import { create } from 'zustand'

/**
 * 开发者：杰哥网络科技
 * 模块：UI 状态管理
 * 说明：管理主题、侧边栏、搜索等UI状态
 */

type Theme = 'light' | 'dark'

interface UIState {
  theme: Theme
  sidebarOpen: boolean
  searchQuery: string

  setTheme: (theme: Theme) => void
  setSidebarOpen: (open: boolean) => void
  setSearchQuery: (query: string) => void

  toggleTheme: () => void
  toggleSidebar: () => void
}

export const useUIStore = create<UIState>((set) => ({
  theme: 'light',
  sidebarOpen: false,
  searchQuery: '',

  setTheme: (theme) => set({ theme }),
  setSidebarOpen: (sidebarOpen) => set({ sidebarOpen }),
  setSearchQuery: (searchQuery) => set({ searchQuery }),

  toggleTheme: () => set((state) => ({
    theme: state.theme === 'light' ? 'dark' : 'light'
  })),

  toggleSidebar: () => set((state) => ({
    sidebarOpen: !state.sidebarOpen
  }))
}))
