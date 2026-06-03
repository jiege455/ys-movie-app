import { create } from 'zustand'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * UI 状态管理
 * 管理侧边栏、搜索等UI状态
 */

interface UIState {
  sidebarOpen: boolean
  searchQuery: string

  setSidebarOpen: (open: boolean) => void
  setSearchQuery: (query: string) => void

  toggleSidebar: () => void
}

export const useUIStore = create<UIState>((set) => ({
  sidebarOpen: false,
  searchQuery: '',

  setSidebarOpen: (sidebarOpen) => set({ sidebarOpen }),
  setSearchQuery: (searchQuery) => set({ searchQuery }),

  toggleSidebar: () => set((state) => ({
    sidebarOpen: !state.sidebarOpen
  }))
}))
