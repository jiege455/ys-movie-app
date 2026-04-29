import React, { useState, useEffect } from 'react'
import { addFavorite, removeFavorite, checkFavoriteStatus, checkLoggedIn } from '../../api'
import { useUserStore } from '../../store/userStore'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 收藏按钮组件
 * 支持收藏/取消收藏，自动同步收藏状态
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

  /**
   * 组件挂载时检查收藏状态
   */
  useEffect(() => {
    if (!vodId || !checkLoggedIn()) {
      setChecking(false)
      return
    }

    const checkStatus = async () => {
      setChecking(true)
      try {
        const isFav = await checkFavoriteStatus(vodId)
        setFavorited(isFav)
      } catch (error) {
        console.error('检查收藏状态失败:', error)
      } finally {
        setChecking(false)
      }
    }

    checkStatus()
  }, [vodId])

  /**
   * 处理收藏/取消收藏
   */
  const handleFavorite = async () => {
    if (!checkLoggedIn()) {
      alert('请先登录后再收藏')
      return
    }

    if (loading || checking) return

    setLoading(true)
    try {
      if (favorited) {
        const result = await removeFavorite(vodId)
        if (result.success) {
          setFavorited(false)
          removeFavoriteItem(vodId)
          alert('已取消收藏')
        } else {
          alert(result.message || '取消收藏失败')
        }
      } else {
        const result = await addFavorite(vodId)
        if (result.success) {
          setFavorited(true)
          addFavoriteItem({
            id: vodId,
            vodId: vodId,
            title: '',
            poster: '',
            time: Date.now()
          })
          alert('收藏成功')
        } else {
          alert(result.message || '收藏失败')
        }
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
      onClick={handleFavorite}
      disabled={loading || checking}
      className={`flex items-center space-x-1 px-3 py-1.5 rounded-lg transition-colors text-sm ${
        favorited
          ? 'bg-red-100 text-red-600'
          : 'bg-gray-100 hover:bg-red-50 text-gray-600 hover:text-red-600'
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
      <span>{checking ? '加载中...' : favorited ? '已收藏' : '收藏'}</span>
    </button>
  )
}

export default FavoriteButton
