import React, { useState } from 'react'
import { addFavorite, checkLoggedIn } from '../../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 收藏按钮组件
 * 点击收藏视频，未登录时提示登录
 */

interface FavoriteButtonProps {
  vodId: string
  className?: string
}

export const FavoriteButton: React.FC<FavoriteButtonProps> = ({ vodId, className = '' }) => {
  const [favorited, setFavorited] = useState(false)
  const [loading, setLoading] = useState(false)

  const handleFavorite = async () => {
    if (!checkLoggedIn()) {
      alert('请先登录后再收藏')
      return
    }
    if (favorited) {
      alert('已收藏过该视频')
      return
    }
    setLoading(true)
    const success = await addFavorite(vodId)
    if (success) {
      setFavorited(true)
      alert('收藏成功')
    } else {
      alert('收藏失败，请稍后重试')
    }
    setLoading(false)
  }

  return (
    <button
      onClick={handleFavorite}
      disabled={loading || favorited}
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
      <span>{favorited ? '已收藏' : '收藏'}</span>
    </button>
  )
}

export default FavoriteButton
