import React, { useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { useCategoryStore } from '../../store/categoryStore'
import type { Category } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 全部分类列表页
 * 数据来源：插件 API (app_api.php ac=init)
 */

const CATEGORY_ICONS: Record<string, string> = {
  '1': '🎬', '2': '📺', '3': '🎭', '4': '🎵',
  '5': '🔥', '6': '😄', '7': '💕', '8': '🚀',
  '9': '👻', '10': '🎨', '11': '🔍', '12': '⚔️',
  '13': '📖', '14': '🎤', '15': '🏃', '16': '🌍',
  '17': '👶', '18': '🎪', '19': '📰', '20': '🎯'
}

const getIcon = (cat: Category): string => {
  const idx = parseInt(cat.type_id, 10)
  if (!isNaN(idx) && idx > 0 && idx <= 20) {
    return CATEGORY_ICONS[String(idx)] || '🎬'
  }
  const icons = Object.values(CATEGORY_ICONS)
  return icons[idx % icons.length] || '🎬'
}

export const CategoriesPage: React.FC = () => {
  const navigate = useNavigate()
  const { categories, loadCategories, loading, error } = useCategoryStore()
  const isMountedRef = useRef(true)

  useEffect(() => {
    isMountedRef.current = true
    loadCategories(true)
    return () => { isMountedRef.current = false }
  }, [])

  const handleCategoryClick = (cat: Category) => {
    navigate(`/category/${cat.type_id}`, { state: { name: cat.type_name } })
  }

  return (
    <div className="min-h-screen pb-14">
      <div className="sticky top-0 z-10 glass border-b border-cyan-500/20 px-4 py-3 flex items-center">
        <button
          onClick={() => navigate(-1)}
          className="mr-3 text-cyan-300 hover:text-cyan-100"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-lg font-bold text-cyan-100">全部分类</h1>
      </div>

      <main className="px-4 py-4">
        {loading ? (
          <div className="flex justify-center items-center py-20">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-cyan-400"></div>
          </div>
        ) : error ? (
          <div className="glass border border-cyan-500/20 rounded-lg p-6 text-center">
            <p className="text-cyan-400 mb-3">{error}</p>
            <button
              onClick={() => loadCategories(true)}
              className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        ) : categories.length > 0 ? (
          <div className="grid grid-cols-3 gap-3">
            {categories.map((cat) => (
              <button
                key={cat.type_id}
                onClick={() => handleCategoryClick(cat)}
                className="rounded-lg p-4 text-center glass-card hover:bg-cyan-500/10 transition-colors"
              >
                <div className="text-2xl mb-2">{getIcon(cat)}</div>
                <div className="text-sm text-cyan-300 truncate">{cat.type_name}</div>
              </button>
            ))}
          </div>
        ) : (
          <div className="text-center py-20">
            <p className="text-cyan-400/60">暂无分类数据</p>
          </div>
        )}
      </main>
    </div>
  )
}

export default CategoriesPage
