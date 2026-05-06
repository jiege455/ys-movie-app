import React, { useState, useEffect } from 'react'
import { addFavorite, removeFavorite, checkFavoriteStatus, checkLoggedIn } from '../../api'
import { useUserStore } from '../../store/userStore'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 收藏按钮组件
 * 支持收藏/取消收藏，自动检测登录状态
 */

interface FavoriteButtonProps {
  vodId: string
  className?: string
}

export const FavoriteButton: React.FC<FavoriteButtonProps> = ({ vodId, className = '' }) => {
  const [favorited, setFavorited] = useState(false)
  const [loading, setLoading] = useState(false)
  const [checking, setChecking] = useState(true)
  const { addFavoriteItem, removeFavoriteItem } = useUserStore()

  useEffect(() => {
    checkStatus()
  }, [vodId])

  const checkStatus = async () => {
    if (!checkLoggedIn()) {
      setChecking(false)
      return
    }
    try {
      const status = await checkFavoriteStatus(vodId)
      setFavorited(status)
    } catch (error) {
      console.error('检查收藏状态失败:', error)
    } finally {
      setChecking(false)
    }
  }

  const handleToggle = async () => {
    if (!checkLoggedIn()) {
      alert('请先登录')
      return
    }

    if (loading || checking) return

    setLoading(true)
    try {
      if (favorited) {
        await removeFavorite(vodId)
        setFavorited(false)
        removeFavoriteItem(vodId)
      } else {
        await addFavorite(vodId)
        setFavorited(true)
        addFavoriteItem({
          id: vodId,
          vodId: vodId,
          title: '',
          poster: '',
          time: Date.now()
        })
      }
    } catch (error) {
      console.error('收藏操作失败:', error)
      alert('操作失败，请稍后重试')
    } finally {
      setLoading(false)
    }
  }

  return (
    <button
      onClick={handleToggle}
      disabled={loading || checking}
      className={`flex items-center space-x-1 px-3 py-1.5 rounded-lg transition-colors text-sm ${
        favorited
          ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30'
          : 'bg-[#0f172a]/80 hover:bg-sky-500/10 text-sky-400/60 hover:text-sky-400 border border-sky-500/20'
      } ${className}`}
    >
      <svg
        className="w-4 h-4"
        fill={favorited ? 'currentColor' : 'none'}
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
        />
      </svg>
      <span>{favorited ? '已收藏' : '收藏'}</span>
    </button>
  )
}

export default FavoriteButton
