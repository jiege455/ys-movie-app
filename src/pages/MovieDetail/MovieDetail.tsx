import React, { useEffect, useState, useRef, Suspense, lazy } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getMovieDetail } from '../../api'
import { usePlayerStore } from '../../store/playerStore'
import type { MovieDetail as MovieDetailType, VodSource } from '../../api/vod'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 电影详情页
 * 展示电影详细信息、播放按钮、收藏、评论等
 * 优化：骨架屏、图片懒加载、组件懒加载、并行数据请求
 * 修复：播放源按插件解析管理分组显示，支持多播放源切换
 */

// 懒加载非首屏组件
const CommentSection = lazy(() => import('../../components/CommentSection/CommentSection').then(m => ({ default: m.CommentSection })))
const FavoriteButton = lazy(() => import('../../components/FavoriteButton/FavoriteButton').then(m => ({ default: m.FavoriteButton })))

/**
 * 骨架屏组件 - 详情页加载占位
 */
const MovieDetailSkeleton: React.FC = () => (
  <div className="min-h-screen pb-20 animate-pulse">
    {/* 顶部导航骨架 */}
    <div className="sticky top-0 z-10 glass border-b border-cyan-500/20 px-4 py-3 flex items-center">
      <div className="w-6 h-6 rounded bg-cyan-500/20"></div>
      <div className="ml-3 h-5 w-32 rounded bg-cyan-500/20"></div>
    </div>

    <div className="px-4 py-4">
      {/* 海报与基本信息骨架 */}
      <div className="flex gap-4 mb-6">
        <div className="w-32 flex-shrink-0">
          <div className="aspect-[2/3] rounded-lg bg-cyan-500/10"></div>
        </div>
        <div className="flex-1 min-w-0 space-y-2">
          <div className="h-6 w-3/4 rounded bg-cyan-500/20"></div>
          <div className="h-4 w-16 rounded bg-cyan-500/10"></div>
          <div className="h-4 w-24 rounded bg-cyan-500/10"></div>
          <div className="flex gap-2 mt-3">
            <div className="flex-1 h-9 rounded-lg bg-cyan-500/20"></div>
            <div className="w-16 h-9 rounded-lg bg-cyan-500/10"></div>
          </div>
        </div>
      </div>

      {/* 剧情简介骨架 */}
      <div className="mb-6 space-y-2">
        <div className="h-5 w-16 rounded bg-cyan-500/20"></div>
        <div className="h-4 w-full rounded bg-cyan-500/10"></div>
        <div className="h-4 w-5/6 rounded bg-cyan-500/10"></div>
        <div className="h-4 w-4/5 rounded bg-cyan-500/10"></div>
      </div>

      {/* 播放源骨架 */}
      <div className="mb-6">
        <div className="h-5 w-16 rounded bg-cyan-500/20 mb-3"></div>
        <div className="flex gap-2 mb-3">
          <div className="h-8 w-20 rounded-lg bg-cyan-500/20"></div>
          <div className="h-8 w-20 rounded-lg bg-cyan-500/10"></div>
        </div>
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="h-9 rounded-lg bg-cyan-500/10"></div>
          ))}
        </div>
      </div>
    </div>
  </div>
)

export const MovieDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { setCurrentEpisode, setActiveSourceIndex: storeSetSource } = usePlayerStore()
  const [movieData, setMovieData] = useState<MovieDetailType | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [activeSourceIndex, setActiveSourceIndex] = useState(0)
  const abortRef = useRef<AbortController | null>(null)

  useEffect(() => {
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller
    if (id) {
      loadMovieData(id, controller.signal)
    }
    return () => {
      controller.abort()
    }
  }, [id])

  const loadMovieData = async (movieId: string, signal: AbortSignal) => {
    try {
      setLoading(true)
      setError(null)
      const data = await getMovieDetail(movieId)
      if (signal.aborted) return
      setMovieData(data)
      if (data?.vod_play_list) {
        const firstValidIndex = data.vod_play_list.findIndex((s: VodSource) => (s.urls?.length || 0) > 0)
        setActiveSourceIndex(firstValidIndex >= 0 ? firstValidIndex : 0)
      }
    } catch {
      if (signal.aborted) return
      setError('加载电影信息失败')
    } finally {
      if (!signal.aborted) {
        setLoading(false)
      }
    }
  }

  const handlePlayClick = (episodeIndex: number = 0) => {
    setCurrentEpisode(episodeIndex)
    storeSetSource(activeSourceIndex)
    navigate(`/player/${id}`)
  }

  const handleBackClick = () => {
    navigate(-1)
  }

  // 获取当前选中的播放源
  const currentSource = movieData?.vod_play_list?.[activeSourceIndex]
  const currentEpisodes = currentSource?.urls || []

  // 获取所有有效的播放源（有剧集的）
  const validSources = movieData?.vod_play_list?.filter((s: VodSource) => (s.urls?.length || 0) > 0) || []

  if (loading) {
    return <MovieDetailSkeleton />
  }

  if (error || !movieData) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <p className="text-cyan-300 mb-4">{error || '电影信息不存在'}</p>
          <button
            onClick={handleBackClick}
            className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors mr-2"
          >
            返回
          </button>
          {error && (
            <button
              onClick={() => {
              if (id) {
                const controller = new AbortController()
                abortRef.current?.abort()
                abortRef.current = controller
                loadMovieData(id, controller.signal)
              }
            }}
              className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen pb-20">
      {/* 顶部导航 */}
      <div className="sticky top-0 z-10 glass border-b border-cyan-500/20 px-4 py-3 flex items-center">
        <button
          onClick={handleBackClick}
          className="mr-3 text-cyan-300 hover:text-cyan-100"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-lg font-bold truncate text-cyan-100">{movieData.title}</h1>
      </div>

      <div className="px-4 py-4">
        {/* 海报与基本信息 */}
        <div className="flex gap-4 mb-6">
          <div className="w-32 flex-shrink-0">
            <div className="relative aspect-[2/3] rounded-lg overflow-hidden shadow-lg glass-light">
              <img
                src={movieData.poster_path || ''}
                alt={movieData.title}
                className="w-full h-full object-cover"
                loading="lazy"
                decoding="async"
                onError={(e) => {
                  const target = e.target as HTMLImageElement
                  target.style.display = 'none'
                  const parent = target.parentElement
                  if (parent && !parent.querySelector('.img-fallback')) {
                    const fallback = document.createElement('div')
                    fallback.className = 'img-fallback absolute inset-0 flex items-center justify-center bg-slate-800'
                    fallback.innerHTML = '<span class="text-cyan-400/40 text-xs">暂无图片</span>'
                    parent.appendChild(fallback)
                  }
                }}
              />
            </div>
          </div>

          <div className="flex-1 min-w-0">
            <h2 className="text-xl font-bold mb-2 text-cyan-100">{movieData.title}</h2>

            {movieData.vote_average > 0 && (
              <div className="flex items-center mb-2">
                <span className="text-cyan-400 mr-1">★</span>
                <span className="text-sm text-cyan-300">{movieData.vote_average.toFixed(1)}</span>
              </div>
            )}

            {movieData.release_date && (
              <p className="text-sm text-cyan-400/60 mb-1">
                上映: {movieData.release_date}
              </p>
            )}

            {/* 操作按钮 */}
            <div className="flex gap-2 mt-3">
              <button
                onClick={() => handlePlayClick(0)}
                className="flex-1 bg-cyan-500 hover:bg-cyan-400 active:bg-cyan-600 text-white py-2 rounded-lg transition-colors font-medium text-sm active:scale-95 transform"
              >
                立即播放
              </button>
              <Suspense fallback={<div className="w-16 h-9 rounded-lg bg-cyan-500/10 animate-pulse"></div>}>
                <FavoriteButton vodId={movieData.id} />
              </Suspense>
            </div>
          </div>
        </div>

        {/* 剧情简介 */}
        {movieData.overview && (
          <div className="mb-6">
            <h3 className="text-lg font-semibold mb-2 text-cyan-400">剧情简介</h3>
            <p className="text-sm text-cyan-300 leading-relaxed">
              {movieData.overview}
            </p>
          </div>
        )}

        {/* 播放列表 - 按播放源分组显示 */}
        {validSources.length > 0 && (
          <div className="mb-6">
            <h3 className="text-lg font-semibold mb-3 text-cyan-400">选集播放</h3>

            {/* 播放源切换标签 - 多个源才显示 */}
            {validSources.length > 1 && (
              <div className="flex flex-wrap gap-2 mb-3">
                {validSources.map((source, index) => {
                  // 找到该 source 在原始数组中的索引
                  const originalIndex = movieData.vod_play_list?.findIndex(
                    (s: VodSource) => s.name === source.name
                  ) ?? index
                  const isActive = originalIndex === activeSourceIndex
                  return (
                    <button
                      key={source.name || index}
                      onClick={() => setActiveSourceIndex(originalIndex)}
                      className={`
                        px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200
                        ${isActive
                          ? 'bg-cyan-500 text-white shadow-lg shadow-cyan-500/30'
                          : 'glass-light text-cyan-300 hover:bg-cyan-500/20 hover:text-cyan-100 border border-cyan-500/20'
                        }
                      `}
                    >
                      {source.name || `源${index + 1}`}
                    </button>
                  )
                })}
              </div>
            )}

            {/* 当前播放源的剧集列表 */}
            {currentEpisodes.length > 0 && (
              <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
                {currentEpisodes.map((episode, index) => (
                  <button
                    key={index}
                    onClick={() => handlePlayClick(index)}
                    className="glass-light hover:bg-cyan-500/20 hover:text-cyan-100 active:scale-95 transform py-2.5 rounded-lg text-sm transition-all text-cyan-300 border border-cyan-500/20"
                  >
                    {episode.name || `第${index + 1}集`}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 评论区 - 懒加载 */}
        <div className="border-t border-cyan-500/20 pt-6">
          <Suspense fallback={
            <div className="animate-pulse space-y-3">
              <div className="h-5 w-24 rounded bg-cyan-500/20"></div>
              <div className="h-20 rounded-lg bg-cyan-500/10"></div>
            </div>
          }>
            <CommentSection vodId={movieData.id} />
          </Suspense>
        </div>
      </div>
    </div>
  )
}

export default MovieDetail
