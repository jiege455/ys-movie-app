import React, { useEffect, useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { getFavorites, userLogout, checkLoggedIn } from '../../api'
import { useUserStore } from '../../store/userStore'
import { useTheme } from '../../contexts/ThemeContext'
import type { FavoriteItem } from '../../store/userStore'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 个人中心页面
 * 展示用户信息、收藏列表、播放记录、主题切换等
 */

export const Profile: React.FC = () => {
  const navigate = useNavigate()
  const { isLoggedIn: loggedIn, user, logout, favorites, setFavorites, setFavoritesLoading } = useUserStore()
  const { theme, toggleTheme, isDark } = useTheme()
  const [activeTab, setActiveTab] = useState<'favorites' | 'history'>('favorites')
  const isMountedRef = useRef(true)

  useEffect(() => {
    if (!checkLoggedIn()) {
      return
    }
    loadFavorites()

    return () => {
      isMountedRef.current = false
    }
  }, [loggedIn])

  const loadFavorites = async () => {
    setFavoritesLoading(true)
    try {
      const data = await getFavorites()
      if (isMountedRef.current) {
        setFavorites(data)
      }
    } finally {
      if (isMountedRef.current) {
        setFavoritesLoading(false)
      }
    }
  }

  const handleLogout = async () => {
    await userLogout()
    logout()
    navigate('/')
  }

  const handleMovieClick = (vodId: string) => {
    navigate(`/movie/${vodId}`)
  }

  // 主题切换按钮组件（复用）
  const ThemeToggleButton = () => (
    <button
      onClick={toggleTheme}
      className="p-2 rounded-lg bg-gray-100 hover:bg-gray-200 transition-colors"
      title={isDark ? '切换到浅色模�? : '切换到暗色模�?}
    >
      {isDark ? (
        <svg className="w-6 h-6 text-yellow-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
        </svg>
      ) : (
        <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
        </svg>
      )}
    </button>
  )

  if (!loggedIn) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        <div className="text-center">
          <div className="flex justify-center mb-4">
            <ThemeToggleButton />
          </div>
          <p className="text-gray-600 mb-4">请先登录</p>
          <button
            onClick={() => navigate('/login')}
            className="bg-sky-500 hover:bg-sky-600 text-white px-6 py-2 rounded-lg transition-colors"
          >
            去登�?          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* 用户信息头部 */}
      <div className="bg-white shadow-sm">
        <div className="max-w-4xl mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <div className="w-16 h-16 bg-sky-500 rounded-full flex items-center justify-center text-white text-2xl font-bold">
                {user?.user_name?.charAt(0)?.toUpperCase() || 'U'}
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-800">{user?.user_name || '用户'}</h1>
                <p className="text-gray-500 text-sm">ID: {user?.user_id || '-'}</p>
              </div>
            </div>
            {/* 主题切换按钮 */}
            <ThemeToggleButton />
          </div>

          <div className="mt-4 flex space-x-4">
            <button
              onClick={handleLogout}
              className="text-sky-500 hover:text-sky-600 text-sm font-medium"
            >
              退出登�?            </button>
          </div>
        </div>
      </div>

      {/* 标签切换 */}
      <div className="max-w-4xl mx-auto px-4 mt-4">
        <div className="bg-white rounded-lg shadow-sm">
          <div className="flex border-b">
            <button
              onClick={() => setActiveTab('favorites')}
              className={`flex-1 py-3 text-center font-medium transition-colors ${
                activeTab === 'favorites'
                  ? 'text-sky-500 border-b-2 border-sky-500'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              我的收藏
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`flex-1 py-3 text-center font-medium transition-colors ${
                activeTab === 'history'
                  ? 'text-sky-500 border-b-2 border-sky-500'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              播放记录
            </button>
          </div>

          <div className="p-4">
            {activeTab === 'favorites' ? (
              <div>
                {favorites.length === 0 ? (
                  <div className="text-center py-8">
                    <p className="text-gray-500">暂无收藏</p>
                    <button
                      onClick={() => navigate('/')}
                      className="mt-2 text-sky-500 hover:text-sky-600 text-sm"
                    >
                      去发现好�?                    </button>
                  </div>
                ) : (
                  <div className="grid grid-cols-3 gap-3">
                    {favorites.map((item: FavoriteItem) => (
                      <div
                        key={item.id}
                        onClick={() => handleMovieClick(item.vodId)}
                        className="cursor-pointer group"
                      >
                        <div className="relative aspect-[2/3] rounded-lg overflow-hidden bg-gray-200">
                          <img
                            src={item.poster || 'https://via.placeholder.com/300x450?text=No+Image'}
                            alt={item.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                            onError={(e) => {
                              const target = e.target as HTMLImageElement
                              target.src = 'https://via.placeholder.com/300x450?text=No+Image'
                            }}
                          />
                        </div>
                        <p className="mt-1 text-sm text-gray-800 truncate">{item.title}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <div className="text-center py-8">
                <p className="text-gray-500">播放记录功能开发中...</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default Profile
