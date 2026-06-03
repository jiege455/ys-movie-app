/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 分类状态管理
 * 管理分类数据加载与缓存，数据来源为插件 API (app_api.php ac=init)
 */
import { create } from 'zustand'
import type { Category } from '../types'
import { getCategories } from '../api'

interface CategoryState {
  categories: Category[]
  loading: boolean
  error: string | null
  lastFetchTime: number

  loadCategories: (force?: boolean) => Promise<void>
}

const CACHE_DURATION = 5 * 60 * 1000

export const useCategoryStore = create<CategoryState>((set, get) => ({
  categories: [],
  loading: false,
  error: null,
  lastFetchTime: 0,

  loadCategories: async (force = false) => {
    const { loading, lastFetchTime, categories } = get()

    if (loading) return

    const now = Date.now()
    if (!force && categories.length > 0 && now - lastFetchTime < CACHE_DURATION) {
      return
    }

    set({ loading: true, error: null })
    try {
      const data = await getCategories()
      if (data.length > 0) {
        set({ categories: data, lastFetchTime: Date.now() })
      } else {
        set({ error: '暂无分类数据' })
      }
    } catch {
      set({ error: '加载分类失败，请检查网络连接' })
    } finally {
      set({ loading: false })
    }
  }
}))
