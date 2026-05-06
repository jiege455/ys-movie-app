import React, { useEffect, useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { getFavorites, userLogout, checkLoggedIn } from '../../api'
import { useUserStore } from '../../store/userStore'
import type { FavoriteItem } from '../../store/userStore'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 个人中心页面
 * 展示用户信息、收藏列表、播放记录、主题切换等
 */

export const Profile: React.FC = () => {
  const navigate = useNavigate()
  const { isLoggedIn: loggedIn, user, logout, favorites, setFavorites, setFavoritesLoading } = useUserStore()
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

  if (!loggedIn) {
    return (
      <div className="min-h-screen bg-[#0a0e1a] flex items-center justify-center px-4">
        <div className="text-center">
          <p className="text-sky-300 mb-4">请先登录</p>
          <button
            onClick={() => navigate('/login')}
            className="bg-sky-500 hover:bg-sky-400 text-white px-6 py-2 rounded-lg transition-colors"
          >
            去登录
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-[#0a0e1a]">
      {/* 用户信息头部 */}
      <div className="glass">
        <div className="max-w-4xl mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <div className="w-16 h-16 bg-sky-500 rounded-full flex items-center justify-center text-white text-2xl font-bold">
                {user?.user_name?.charAt(0)?.toUpperCase() || 'U'}
              </div>
              <div>
                <h1 className="text-xl font-bold text-sky-100">{user?.user_name || '用户'}</h1>
                <p className="text-sky-400/60 text-sm">ID: {user?.user_id || '-'}</p>
              </div>
            </div>
          </div>

          <div className="mt-4 flex space-x-4">
            <button
              onClick={() => navigate('/messages')}
              className="text-sky-400 hover:text-sky-300 text-sm font-medium flex items-center"
            >
              <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              消息中心
            </button>
            <button
              onClick={handleLogout}
              className="text-sky-400 hover:text-sky-300 text-sm font-medium"
            >
              退出登录
            </button>
          </div>
        </div>
      </div>

      {/* 标签切换 */}
      <div className="max-w-4xl mx-auto px-4 mt-4">
        <div className="glass-card rounded-lg">
          <div className="flex border-b border-sky-500/20">
            <button
              onClick={() => setActiveTab('favorites')}
              className={`flex-1 py-3 text-center font-medium transition-colors ${
                activeTab === 'favorites'
                  ? 'text-sky-400 border-b-2 border-sky-400'
                  : 'text-sky-400/60 hover:text-sky-300'
              }`}
            >
              我的收藏
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`flex-1 py-3 text-center font-medium transition-colors ${
                activeTab === 'history'
                  ? 'text-sky-400 border-b-2 border-sky-400'
                  : 'text-sky-400/60 hover:text-sky-300'
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
                    <p className="text-sky-400/60">暂无收藏</p>
                    <button
                      onClick={() => navigate('/')}
                      className="mt-2 text-sky-400 hover:text-sky-300 text-sm"
                    >
                      去发现好剧
                    </button>
                  </div>
                ) : (
                  <div className="grid grid-cols-3 gap-3">
                    {favorites.map((item: FavoriteItem) => (
                      <div
                        key={item.id}
                        onClick={() => handleMovieClick(item.vodId)}
                        className="cursor-pointer group"
                      >
                        <div className="relative aspect-[2/3] rounded-lg overflow-hidden bg-[#1e293b]">
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
                        <p className="mt-1 text-sm text-sky-200 truncate">{item.title}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <div className="text-center py-8">
                <p className="text-sky-400/60">播放记录功能开发中...</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default Profile
