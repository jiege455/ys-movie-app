import React, { useEffect, useState, useRef, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getMovieDetail } from '../../api'
import { VideoPlayer } from '../../components/VideoPlayer/VideoPlayer'
import { usePlayerStore } from '../../store/playerStore'
import type { MovieDetail as MovieDetailType, VodEpisode, VodSource } from '../../api/vod'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 视频播放页
 * 修复：
 * 1. 按播放源分组显示剧集（解决多源扁平化导致剧集错乱）
 * 2. 新增播放源切换（保持与详情页一致的操作体验）
 * 3. 动态检测视频宽高比，适配竖屏短剧尺寸
 */

export const Player: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const {
    currentEpisode, setCurrentEpisode,
    activeSourceIndex, setActiveSourceIndex,
    reset
  } = usePlayerStore()
  const [movieData, setMovieData] = useState<MovieDetailType | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [isVerticalVideo, setIsVerticalVideo] = useState(false)
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
      reset()
    }
  }, [id])

  const loadMovieData = useCallback(async (movieId: string, signal: AbortSignal) => {
    try {
      setLoading(true)
      setError(null)
      const data = await getMovieDetail(movieId)
      if (signal.aborted) return
      setMovieData(data)
      if (data?.vod_play_list) {
        const validSources = data.vod_play_list.filter((s: VodSource) => (s.urls?.length || 0) > 0)
        if (validSources.length > 0 && activeSourceIndex >= validSources.length) {
          setActiveSourceIndex(0)
        }
      }
    } catch {
      if (signal.aborted) return
      setError('加载视频信息失败')
    } finally {
      if (!signal.aborted) {
        setLoading(false)
      }
    }
  }, [activeSourceIndex, setActiveSourceIndex])

  const handleEpisodeChange = (index: number) => {
    setCurrentEpisode(index)
  }

  const handleSourceChange = (index: number) => {
    setActiveSourceIndex(index)
    setCurrentEpisode(0)
  }

  const handleBackClick = () => {
    navigate(-1)
  }

  const handleVideoMetadata = useCallback((info: { duration: number; videoWidth: number; videoHeight: number }) => {
    if (info.videoWidth > 0 && info.videoHeight > 0) {
      setIsVerticalVideo(info.videoHeight > info.videoWidth)
    }
  }, [])

  const validSources: VodSource[] = movieData?.vod_play_list?.filter((s: VodSource) => (s.urls?.length || 0) > 0) || []
  const currentSource: VodSource | undefined = validSources[activeSourceIndex]
  const episodes: VodEpisode[] = currentSource?.urls || []

  const getCurrentVideoUrl = () => {
    if (episodes.length > 0 && currentEpisode < episodes.length) {
      return episodes[currentEpisode]?.url || ''
    }
    return ''
  }

  const getCurrentEpisodeName = () => {
    if (episodes.length > 0 && currentEpisode < episodes.length) {
      return episodes[currentEpisode]?.name || `第${currentEpisode + 1}集`
    }
    return currentSource?.name || '正片'
  }

  if (loading) {
    return (
      <div className="min-h-screen glass flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-400 mx-auto mb-4"></div>
          <p className="text-cyan-300">加载中...</p>
        </div>
      </div>
    )
  }

  if (error || !movieData) {
    return (
      <div className="min-h-screen glass flex items-center justify-center">
        <div className="text-center">
          <p className="text-cyan-400/60 mb-4">{error || '视频信息不存在'}</p>
          <button
            onClick={handleBackClick}
            className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors"
          >
            返回
          </button>
        </div>
      </div>
    )
  }

  const videoUrl = getCurrentVideoUrl()

  return (
    <div className="min-h-screen">
      {/* 顶部导航 */}
      <div className="flex items-center px-4 py-3 glass border-b border-cyan-500/20">
        <button
          onClick={handleBackClick}
          className="mr-3 text-cyan-300 hover:text-cyan-100"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <div className="flex-1 min-w-0">
          <h1 className="text-cyan-100 text-lg font-bold truncate">{movieData.title}</h1>
          <p className="text-cyan-400/60 text-sm">
            {currentSource?.name ? `${currentSource.name} · ` : ''}{getCurrentEpisodeName()}
          </p>
        </div>
      </div>

      {/* 视频播放器 - 动态宽高比：竖屏短剧用9/16，横屏用16/9 */}
      <div className={`bg-black ${isVerticalVideo ? 'aspect-[9/16] max-h-[80vh] mx-auto' : 'aspect-video'}`}>
        <VideoPlayer
          key={videoUrl}
          src={videoUrl}
          poster={movieData.backdrop_path || movieData.poster_path}
          onLoadedMetadata={handleVideoMetadata}
        />
      </div>

      {/* 播放源切换标签 */}
      {validSources.length > 1 && (
        <div className="px-4 py-3 border-b border-cyan-500/20">
          <div className="flex flex-wrap gap-2">
            {validSources.map((source, index) => (
              <button
                key={source.name || index}
                onClick={() => handleSourceChange(index)}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 ${
                  index === activeSourceIndex
                    ? 'bg-cyan-500 text-white shadow-lg shadow-cyan-500/30'
                    : 'glass-light text-cyan-300 hover:bg-cyan-500/20 hover:text-cyan-100 border border-cyan-500/20'
                }`}
              >
                {source.name || `源${index + 1}`}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* 选集列表 */}
      {episodes.length > 1 && (
        <div className="px-4 py-4">
          <h3 className="text-cyan-400 text-lg font-semibold mb-3">选集</h3>
          <div className="grid grid-cols-4 gap-2">
            {episodes.map((episode, index) => (
              <button
                key={index}
                onClick={() => handleEpisodeChange(index)}
                className={`py-2 rounded-lg text-sm transition-colors ${
                  index === currentEpisode
                    ? 'bg-cyan-500 text-white'
                    : 'glass-light text-cyan-300 hover:bg-cyan-500/20 border border-cyan-500/20'
                }`}
              >
                {episode.name || `第${index + 1}集`}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* 电影信息 */}
      <div className="px-4 py-4 border-t border-cyan-500/20">
        <h2 className="text-cyan-100 text-xl font-bold mb-2">{movieData.title}</h2>
        {movieData.overview && (
          <p className="text-cyan-300/70 text-sm leading-relaxed">{movieData.overview}</p>
        )}
      </div>
    </div>
  )
}

export default Player