import React, { useState, useEffect, useRef } from 'react'
import { addFavorite, removeFavorite, checkFavoriteStatus, checkLoggedIn } from '../../api'
import { useUserStore } from '../../store/userStore'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 收藏按钮组件
 * 支持收藏/取消收藏，自动检测登录状�? * 优化：添加收藏状态缓存、未登录快速返回、减少闪�? */

interface FavoriteButtonProps {
  vodId: string
  title?: string
  poster?: string
  className?: string
}

// 收藏状态缓�?const favoriteCache = new Map<string, { status: boolean; time: number }>()
const CACHE_DURATION = 2 * 60 * 1000 // 2分钟缓存

export const FavoriteButton: React.FC<FavoriteButtonProps> = ({ vodId, title = '', poster = '', className = '' }) => {
  const [favorited, setFavorited] = useState(false)
  const [loading, setLoading] = useState(false)
  const [checking, setChecking] = useState(true)
  const { addFavoriteItem, removeFavoriteItem } = useUserStore()
  const isMountedRef = useRef(true)

  useEffect(() => {
    isMountedRef.current = true
    checkStatus()
    return () => {
      isMountedRef.current = false
    }
  }, [vodId])

  const checkStatus = async () => {
    // 未登录快速返回，不显示加载状�?    if (!checkLoggedIn()) {
      setChecking(false)
      return
    }

    // 检查缓�?    const cached = favoriteCache.get(vodId)
    if (cached && Date.now() - cached.time < CACHE_DURATION) {
      setFavorited(cached.status)
      setChecking(false)
      return
    }

    try {
      const status = await checkFavoriteStatus(vodId)
      if (isMountedRef.current) {
        setFavorited(status)
        favoriteCache.set(vodId, { status, time: Date.now() })
      }
    } catch (error) {
      console.error('检查收藏状态失�?', error)
    } finally {
      if (isMountedRef.current) {
        setChecking(false)
      }
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
        favoriteCache.set(vodId, { status: false, time: Date.now() })
      } else {
        await addFavorite(vodId)
        setFavorited(true)
        addFavoriteItem({
          id: vodId,
          vodId: vodId,
          title: title || '',
          poster: poster || '',
          time: Date.now()
        })
        favoriteCache.set(vodId, { status: true, time: Date.now() })
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
          ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
          : 'glass-light hover:bg-cyan-500/10 text-cyan-400/60 hover:text-cyan-400 border border-cyan-500/20'
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
      <span>{favorited ? '已收�? : '收藏'}</span>
    </button>
  )
}

export default FavoriteButton
