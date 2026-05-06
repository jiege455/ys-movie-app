import React, { useEffect, useState, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getMovieDetail } from '../../api'
import { VideoPlayer } from '../../components/VideoPlayer/VideoPlayer'
import { usePlayerStore } from '../../store/playerStore'
import type { MovieDetail as MovieDetailType, VodEpisode } from '../../api/vod'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 视频播放页
 * 提供视频播放、选集切换、播放控制等功能
 */

export const Player: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { currentEpisode, setCurrentEpisode } = usePlayerStore()
  const [movieData, setMovieData] = useState<MovieDetailType | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const isMountedRef = useRef(true)

  useEffect(() => {
    if (id) {
      loadMovieData(id)
    }
    return () => {
      isMountedRef.current = false
    }
  }, [id])

  const loadMovieData = async (movieId: string) => {
    try {
      setLoading(true)
      setError(null)
      const data = await getMovieDetail(movieId)
      if (isMountedRef.current) {
        setMovieData(data)
      }
    } catch (err) {
      if (isMountedRef.current) {
        setError('加载视频信息失败')
      }
    } finally {
      if (isMountedRef.current) {
        setLoading(false)
      }
    }
  }

  const handleEpisodeChange = (index: number) => {
    setCurrentEpisode(index)
  }

  const handleBackClick = () => {
    navigate(-1)
  }

  // 获取所有剧集
  const getAllEpisodes = (): VodEpisode[] => {
    if (!movieData?.vod_play_list) return []
    const episodes: VodEpisode[] = []
    movieData.vod_play_list.forEach(source => {
      if (source.urls) {
        episodes.push(...source.urls)
      }
    })
    return episodes
  }

  const episodes = getAllEpisodes()

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
    return '正片'
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-400 mx-auto mb-4"></div>
          <p className="text-cyan-300">加载中...</p>
        </div>
      </div>
    )
  }

  if (error || !movieData) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
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

  return (
    <div className="min-h-screen ">
      {/* 顶部导航 */}
      <div className="flex items-center px-4 py-3 ">
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
          <p className="text-cyan-400/60 text-sm">{getCurrentEpisodeName()}</p>
        </div>
      </div>

      {/* 视频播放器 */}
      <div className="aspect-video bg-black">
        <VideoPlayer
          src={getCurrentVideoUrl()}
          poster={movieData.backdrop_path || movieData.poster_path}
        />
      </div>

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
