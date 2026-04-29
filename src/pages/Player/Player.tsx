import React, { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { VideoPlayer, VideoPlayerRef } from '../../components/VideoPlayer/VideoPlayer'
import { getMovieDetail, getImageUrl } from '../../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 视频播放页面组件
 * 提供完整的视频播放功能，包括播放控制、全屏、进度记录、画中画等
 */

export const Player: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const playerRef = useRef<VideoPlayerRef>(null)

  // 详情类型
  type VodEpisode = { url: string }
  type VodSource = { urls?: VodEpisode[] }
  type MovieDetail = {
    title: string
    backdrop_path?: string
    poster_path?: string
    vod_play_list?: VodSource[]
    overview?: string
  }

  const [movieData, setMovieData] = useState<MovieDetail | null>(null)
  const [loading, setLoading] = useState(true)
  const [videoUrl, setVideoUrl] = useState('')
  const [startTime, setStartTime] = useState(0)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [currentQuality, setCurrentQuality] = useState('自动')

  /**
   * 组件挂载时加载电影数据
   */
  useEffect(() => {
    if (id) {
      loadMovieData(id)
    }
  }, [id])

  /**
   * 加载电影数据
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 优化：并行加载详情和解析视频地址，减少等待时间
   * @param movieId 电影ID
   */
  const loadMovieData = async (movieId: string) => {
    try {
      setLoading(true)
      const detail = await getMovieDetail(movieId)
      if (!detail) {
        setMovieData(null)
        setLoading(false)
        return
      }
      setMovieData(detail)

      // 并行处理：解析播放地址 + 恢复进度
      const sources = (detail as MovieDetail)?.vod_play_list || []
      let url = ''
      if (sources.length > 0) {
        const firstSource = sources[0]
        const episodes = firstSource?.urls || []
        if (episodes.length > 0) {
          url = String(episodes[0]?.url || '')
        }
      }

      // 恢复上次播放进度
      const saved = getSavedProgress()

      // 同时设置视频地址和进度，减少渲染次数
      if (url) {
        setVideoUrl(url)
      }
      if (saved > 0) {
        setStartTime(saved)
      }
    } catch (error) {
      console.error('加载电影数据失败:', error)
      setMovieData(null)
    } finally {
      setLoading(false)
    }
  }

  /**
   * 处理返回按钮点击
   */
  const handleBackClick = () => {
    navigate(-1)
  }

  /**
   * 处理播放开始事件
   */
  const handlePlay = () => {
    console.log('视频开始播放')
  }

  /**
   * 处理播放暂停事件
   */
  const handlePause = () => {
    console.log('视频暂停播放')
    saveProgress()
  }

  /**
   * 处理播放结束事件
   */
  const handleEnded = () => {
    console.log('视频播放结束')
    // 清除播放进度
    if (id) {
      localStorage.removeItem(`movie_progress_${id}`)
    }
  }

  /**
   * 处理播放时间更新事件
   * @param time 当前播放时间（秒）
   */
  const handleTimeUpdate = (time: number) => {
    setCurrentTime(time)
  }

  /**
   * 处理视频元数据加载完成（获取总时长）
   * @param videoDuration 视频总时长（秒）
   */
  const handleLoadedMetadata = (videoDuration: number) => {
    setDuration(videoDuration)
  }

  /**
   * 处理清晰度切换
   * @param quality 清晰度标识
   */
  const handleQualityChange = (quality: string) => {
    setCurrentQuality(quality === 'auto' ? '自动' : quality)
  }

  /**
   * 处理播放器错误
   */
  const handleError = (error: any) => {
    console.error('播放器错误:', error)
  }

  /**
   * 保存播放进度
   */
  const saveProgress = () => {
    if (id && currentTime > 0) {
      localStorage.setItem(`movie_progress_${id}`, currentTime.toString())
      console.log(`保存播放进度: ${currentTime}秒`)
    }
  }

  /**
   * 获取保存的播放进度
   */
  const getSavedProgress = (): number => {
    if (id) {
      const saved = localStorage.getItem(`movie_progress_${id}`)
      return saved ? parseFloat(saved) : 0
    }
    return 0
  }

  /**
   * 跳转到指定时间播放
   * @param time 目标时间（秒）
   */
  const seekTo = (time: number) => {
    if (playerRef.current) {
      playerRef.current.seekTo(time)
    }
  }

  /**
   * 切换画中画模式
   */
  const togglePictureInPicture = async () => {
    if (playerRef.current) {
      await playerRef.current.requestPictureInPicture()
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mx-auto mb-4"></div>
          <p className="text-white">加载中...</p>
        </div>
      </div>
    )
  }

  if (!movieData) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <p className="text-white mb-4">视频信息不存在</p>
          <button
            onClick={handleBackClick}
            className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors"
          >
            返回
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black">
      {/* 顶部控制栏 */}
      <div className="absolute top-0 left-0 right-0 z-20 bg-gradient-to-b from-black via-transparent to-transparent p-4">
        <div className="flex items-center justify-between">
          <button
            onClick={handleBackClick}
            className="flex items-center text-white hover:text-gray-300 transition-colors"
          >
            <svg className="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            返回
          </button>

          {/* 清晰度显示 */}
          <div className="flex items-center space-x-2">
            <span className="text-white text-sm">清晰度: {currentQuality}</span>
          </div>
        </div>

        {/* 电影标题 */}
        <div className="mt-4">
          <h1 className="text-white text-xl font-bold">{movieData.title}</h1>
        </div>
      </div>

      {/* 视频播放器 */}
      <div className="relative w-full h-screen">
        <VideoPlayer
          ref={playerRef}
          src={videoUrl}
          poster={getImageUrl(movieData.backdrop_path || movieData.poster_path || '')}
          startTime={startTime}
          onPlay={handlePlay}
          onPause={handlePause}
          onEnded={handleEnded}
          onTimeUpdate={handleTimeUpdate}
          onLoadedMetadata={handleLoadedMetadata}
          onQualityChange={handleQualityChange}
          onError={handleError}
          className="w-full h-full"
        />
      </div>

      {/* 底部信息栏 */}
      <div className="absolute bottom-0 left-0 right-0 z-20 bg-gradient-to-t from-black via-transparent to-transparent p-4">
        <div className="bg-black bg-opacity-50 rounded-lg p-4 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <h2 className="text-white text-lg font-bold mb-2">{movieData.title}</h2>
              <p className="text-gray-300 text-sm line-clamp-2">
                {movieData.overview || '暂无简介'}
              </p>
            </div>

            {/* 播放控制按钮 */}
            <div className="flex items-center space-x-2 ml-4">
              <button
                onClick={() => seekTo(Math.max(0, currentTime - 10))}
                className="bg-gray-800 hover:bg-gray-700 text-white p-2 rounded-full transition-colors"
                title="后退10秒"
              >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M8.445 14.832A1 1 0 0010 14v-2.798l5.445 3.63A1 1 0 0017 14V6a1 1 0 00-1.555-.832L10 8.798V6a1 1 0 00-1.555-.832l-6 4a1 1 0 000 1.664l6 4z" />
                </svg>
              </button>

              <button
                onClick={() => seekTo(currentTime + 10)}
                className="bg-gray-800 hover:bg-gray-700 text-white p-2 rounded-full transition-colors"
                title="前进10秒"
              >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M4.555 5.168A1 1 0 003 6v8a1 1 0 001.555.832L10 11.202V14a1 1 0 001.555.832l6-4a1 1 0 000-1.664l-6-4A1 1 0 0010 6v2.798l-5.445-3.63z" />
                </svg>
              </button>
            </div>
          </div>

          {/* 播放进度条 */}
          <div className="mt-4">
            <div className="flex items-center space-x-2 text-white text-sm">
              <span>{formatTime(currentTime)}</span>
              <div className="flex-1 bg-gray-600 rounded-full h-1">
                <div
                  className="bg-red-600 h-1 rounded-full transition-all duration-300"
                  style={{ width: `${getProgressPercentage(currentTime, duration)}%` }}
                ></div>
              </div>
              <span>{formatTime(duration)}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * 格式化时间显示
 * @param seconds 秒数
 * @returns 格式化后的时间字符串 (MM:SS 或 HH:MM:SS)
 */
const formatTime = (seconds: number): string => {
  if (!seconds || isNaN(seconds)) return '00:00'

  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = Math.floor(seconds % 60)

  const parts = []
  if (hours > 0) parts.push(hours.toString().padStart(2, '0'))
  parts.push(minutes.toString().padStart(2, '0'))
  parts.push(secs.toString().padStart(2, '0'))

  return parts.join(':')
}

/**
 * 获取播放进度百分比
 * @param current 当前时间
 * @param total 总时长
 * @returns 进度百分比
 */
const getProgressPercentage = (current: number, total: number): number => {
  if (!total || total <= 0) return 0
  return Math.min(100, Math.max(0, (current / total) * 100))
}

export default Player
