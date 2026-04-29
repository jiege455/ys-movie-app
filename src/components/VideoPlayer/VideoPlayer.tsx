import React, { useRef, useEffect, useState, useCallback, useImperativeHandle, forwardRef } from 'react'
import videojs from 'video.js'
import 'video.js/dist/video-js.css'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 视频播放器属性接口
 */
interface VideoPlayerProps {
  src: string
  poster?: string
  startTime?: number
  onPlay?: () => void
  onPause?: () => void
  onEnded?: () => void
  onTimeUpdate?: (currentTime: number) => void
  onLoadedMetadata?: (duration: number) => void
  onQualityChange?: (quality: string) => void
  onError?: (error: any) => void
  className?: string
}

/**
 * 播放器对外暴露的方法
 */
export interface VideoPlayerRef {
  seekTo: (time: number) => void
  getCurrentTime: () => number
  getDuration: () => number
  play: () => Promise<void>
  pause: () => void
  isPlaying: () => boolean
  requestPictureInPicture: () => Promise<void>
}

/**
 * 视频播放器组件
 * 基于Video.js封装，支持多种视频格式和播放控制
 * 优化：启用高清渲染、硬件加速、自适应尺寸、清晰度切换、画中画
 */
export const VideoPlayer = forwardRef<VideoPlayerRef, VideoPlayerProps>(({
  src,
  poster,
  startTime = 0,
  onPlay,
  onPause,
  onEnded,
  onTimeUpdate,
  onLoadedMetadata,
  onQualityChange,
  onError,
  className = ''
}, ref) => {
  const videoRef = useRef<HTMLVideoElement>(null)
  const playerRef = useRef<any>(null)
  const isMountedRef = useRef(true)
  const startTimeRef = useRef(startTime)
  const [isLoading, setIsLoading] = useState(true)
  const [hasError, setHasError] = useState(false)
  const [currentQuality, setCurrentQuality] = useState('auto')
  const [qualities, setQualities] = useState<string[]>([])
  const [isPiPSupported, setIsPiPSupported] = useState(false)

  // 同步startTime
  useEffect(() => {
    startTimeRef.current = startTime
  }, [startTime])

  /**
   * 获取视频类型
   */
  const getVideoType = useCallback((url: string): string => {
    if (!url) return 'video/mp4'
    if (url.includes('.m3u8')) return 'application/x-mpegURL'
    if (url.includes('.mpd')) return 'application/dash+xml'
    const ext = url.split('.').pop()?.toLowerCase()
    switch (ext) {
      case 'mp4': return 'video/mp4'
      case 'webm': return 'video/webm'
      case 'ogg': return 'video/ogg'
      default: return 'video/mp4'
    }
  }, [])

  /**
   * 暴露方法给父组件
   */
  useImperativeHandle(ref, () => ({
    seekTo: (time: number) => {
      if (playerRef.current && time >= 0) {
        playerRef.current.currentTime(time)
      }
    },
    getCurrentTime: () => {
      return playerRef.current ? playerRef.current.currentTime() : 0
    },
    getDuration: () => {
      return playerRef.current ? playerRef.current.duration() : 0
    },
    play: async () => {
      if (playerRef.current) {
        try {
          await playerRef.current.play()
        } catch (err) {
          console.error('播放失败:', err)
        }
      }
    },
    pause: () => {
      if (playerRef.current) {
        playerRef.current.pause()
      }
    },
    isPlaying: () => {
      return playerRef.current ? !playerRef.current.paused() : false
    },
    requestPictureInPicture: async () => {
      const video = videoRef.current
      if (video && document.pictureInPictureEnabled) {
        try {
          if (document.pictureInPictureElement) {
            await document.exitPictureInPicture()
          } else {
            await video.requestPictureInPicture()
          }
        } catch (err) {
          console.error('画中画切换失败:', err)
        }
      }
    }
  }))

  /**
   * 初始化Video.js播放器
   */
  useEffect(() => {
    if (!videoRef.current) return

    // 检查画中画支持
    setIsPiPSupported(document.pictureInPictureEnabled || false)

    const player = videojs(videoRef.current, {
      controls: true,
      responsive: true,
      fluid: true,
      preload: 'auto',
      poster: poster || '',
      sources: src ? [{
        src: src,
        type: getVideoType(src)
      }] : [],
      // 高清渲染优化配置
      html5: {
        vhs: {
          overrideNative: true,
          limitRenditionByPlayerDimensions: false,
          useDevicePixelRatio: true,
          allowSeeksWithinUnsafeLiveWindow: true,
          handlePartialData: true,
          // 缓冲优化
          maxBufferLength: 60,
          maxMaxBufferLength: 120,
          // 清晰度选择优化
          experimentalBufferBasedABR: true
        },
        nativeAudioTracks: false,
        nativeVideoTracks: false
      },
      // 控制栏配置
      controlBar: {
        playToggle: true,
        volumePanel: { inline: false },
        currentTimeDisplay: true,
        timeDivider: true,
        durationDisplay: true,
        progressControl: true,
        fullscreenToggle: true,
        remainingTimeDisplay: false,
        pictureInPictureToggle: document.pictureInPictureEnabled || false
      },
      // 用户交互优化
      userActions: {
        click: true,
        doubleClick: true
      },
      // 自动播放策略
      autoplay: false,
      // 循环播放
      loop: false,
      // 静音（某些浏览器自动播放需要）
      muted: false,
      // 语言
      language: 'zh-CN',
      // 错误显示
      errorDisplay: {
        message: '视频加载失败，请刷新页面重试'
      }
    })

    playerRef.current = player

    // 播放器就绪
    player.ready(() => {
      if (!isMountedRef.current) return
      setIsLoading(false)

      // 恢复播放位置
      if (startTimeRef.current > 0) {
        player.currentTime(startTimeRef.current)
      }

      // 绑定事件
      player.on('play', () => { if (isMountedRef.current) onPlay?.() })
      player.on('pause', () => { if (isMountedRef.current) onPause?.() })
      player.on('ended', () => { if (isMountedRef.current) onEnded?.() })
      player.on('timeupdate', () => {
        if (isMountedRef.current) {
          onTimeUpdate?.(player.currentTime())
        }
      })
      player.on('loadedmetadata', () => {
        if (isMountedRef.current) {
          const duration = player.duration() || 0
          onLoadedMetadata?.(duration)
          // 如果有startTime，在这里再次确保跳转
          if (startTimeRef.current > 0 && player.currentTime() < startTimeRef.current) {
            player.currentTime(startTimeRef.current)
          }
        }
      })

      // 错误处理
      player.on('error', () => {
        const error = player.error()
        if (error) {
          console.error('播放器错误:', error.code, error.message)
          if (isMountedRef.current) {
            setHasError(true)
            setIsLoading(false)
            onError?.(error)
          }
        }
      })

      // 等待播放（缓冲）
      player.on('waiting', () => { if (isMountedRef.current) setIsLoading(true) })
      player.on('playing', () => { if (isMountedRef.current) setIsLoading(false) })
      player.on('canplay', () => { if (isMountedRef.current) setIsLoading(false) })

      // HLS/DASH 多码率清晰度处理
      try {
        const tech: any = player.tech({ IWillNotUseThisInPlugins: true })
        if (tech?.vhs) {
          // 获取可用清晰度列表
          tech.vhs.playlists.on('loadedplaylist', () => {
            if (!isMountedRef.current) return
            const playlists = tech.vhs.playlists
            if (playlists?.master?.playlists) {
              const availableQualities = playlists.master.playlists
                .map((p: any, index: number) => {
                  const height = p.attributes?.RESOLUTION?.height
                  return height ? `${height}p` : `清晰度${index + 1}`
                })
                .filter(Boolean)
              // 去重并排序（从高到低）
              const uniqueQualities = Array.from(new Set(availableQualities)) as string[]
              uniqueQualities.sort((a: string, b: string) => {
                const ha = parseInt(a.replace('p', '')) || 0
                const hb = parseInt(b.replace('p', '')) || 0
                return hb - ha
              })
              if (uniqueQualities.length > 1) {
                setQualities(['auto', ...uniqueQualities])
              }
            }
          })

          // 默认选择最高清晰度
          tech.vhs.playlistController_.selectPlaylist = () => {
            const playlists = tech.vhs.playlists
            if (playlists?.master?.playlists) {
              const sorted = playlists.master.playlists
                .filter((p: any) => p.attributes?.BANDWIDTH)
                .sort((a: any, b: any) => b.attributes.BANDWIDTH - a.attributes.BANDWIDTH)
              return sorted[0] || playlists.master.playlists[0]
            }
            return null
          }
        }
      } catch (e) {
        // 非HLS/DASH源，忽略
      }
    })

    return () => {
      isMountedRef.current = false
      if (playerRef.current) {
        playerRef.current.dispose()
        playerRef.current = null
      }
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  /**
   * 更新视频源
   */
  useEffect(() => {
    if (playerRef.current && src) {
      setHasError(false)
      setIsLoading(true)
      playerRef.current.src({
        src: src,
        type: getVideoType(src)
      })
      setQualities([])
      setCurrentQuality('auto')
      // 恢复播放位置
      if (startTimeRef.current > 0) {
        playerRef.current.currentTime(startTimeRef.current)
      }
    }
  }, [src, getVideoType])

  /**
   * 更新海报
   */
  useEffect(() => {
    if (playerRef.current && poster) {
      playerRef.current.poster(poster)
    }
  }, [poster])

  /**
   * 切换清晰度（多码率）
   */
  const handleQualityChange = useCallback((quality: string) => {
    setCurrentQuality(quality)
    onQualityChange?.(quality)

    if (!playerRef.current) return

    try {
      const tech: any = playerRef.current.tech({ IWillNotUseThisInPlugins: true })
      if (tech?.vhs?.playlists?.master?.playlists) {
        const playlists = tech.vhs.playlists.master.playlists
        const currentTime = playerRef.current.currentTime()
        const isPaused = playerRef.current.paused()

        if (quality === 'auto') {
          // 自动选择最高带宽
          tech.vhs.playlistController_.selectPlaylist = () => {
            const sorted = playlists
              .filter((p: any) => p.attributes?.BANDWIDTH)
              .sort((a: any, b: any) => b.attributes.BANDWIDTH - a.attributes.BANDWIDTH)
            return sorted[0] || playlists[0]
          }
        } else {
          // 选择指定清晰度
          const height = parseInt(quality.replace('p', ''))
          const target = playlists.find((p: any) =>
            p.attributes?.RESOLUTION?.height === height
          )
          if (target) {
            tech.vhs.playlistController_.selectPlaylist = () => target
          }
        }

        // 重新加载播放列表并恢复播放位置
        tech.vhs.playlistController_.load()
        if (currentTime > 0) {
          playerRef.current.currentTime(currentTime)
        }
        // 如果之前在播放，继续播放
        if (!isPaused) {
          playerRef.current.play()
        }
      }
    } catch (e) {
      console.log('清晰度切换失败:', e)
    }
  }, [onQualityChange])

  /**
   * 切换画中画
   */
  const togglePictureInPicture = useCallback(async () => {
    const video = videoRef.current
    if (!video || !document.pictureInPictureEnabled) return

    try {
      if (document.pictureInPictureElement) {
        await document.exitPictureInPicture()
      } else {
        await video.requestPictureInPicture()
      }
    } catch (err) {
      console.error('画中画切换失败:', err)
    }
  }, [])

  /**
   * 重试播放
   */
  const handleRetry = useCallback(() => {
    setHasError(false)
    setIsLoading(true)
    if (playerRef.current && src) {
      playerRef.current.src({
        src: src,
        type: getVideoType(src)
      })
    }
  }, [src, getVideoType])

  return (
    <div
      className={`video-player-wrapper ${className}`}
      style={{
        width: '100%',
        height: '100%',
        position: 'relative',
        transform: 'translateZ(0)',
        backfaceVisibility: 'hidden',
        perspective: '1000px'
      }}
    >
      {/* 加载遮罩 */}
      {isLoading && !hasError && (
        <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-60 z-20">
          <div className="text-white text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mx-auto mb-4"></div>
            <p className="text-sm">视频加载中...</p>
          </div>
        </div>
      )}

      {/* 错误提示 */}
      {hasError && (
        <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-80 z-20">
          <div className="text-white text-center px-4">
            <svg className="w-16 h-16 mx-auto mb-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className="text-lg mb-2">视频加载失败</p>
            <p className="text-gray-400 text-sm mb-4">请检查网络连接或稍后重试</p>
            <button
              onClick={handleRetry}
              className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        </div>
      )}

      {/* 清晰度选择器（多码率HLS/DASH源时显示） */}
      {qualities.length > 1 && !hasError && (
        <div className="absolute top-4 right-4 z-30 flex items-center space-x-2">
          <select
            value={currentQuality}
            onChange={(e) => handleQualityChange(e.target.value)}
            className="bg-black bg-opacity-70 text-white px-3 py-1 rounded text-sm border border-gray-600 focus:outline-none focus:border-red-500 backdrop-blur-sm cursor-pointer"
          >
            {qualities.map((q) => (
              <option key={q} value={q} className="bg-gray-800">
                {q === 'auto' ? '自动' : q}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* 画中画按钮 */}
      {isPiPSupported && !hasError && (
        <button
          onClick={togglePictureInPicture}
          className="absolute top-4 z-30 bg-black bg-opacity-70 text-white p-2 rounded backdrop-blur-sm hover:bg-opacity-90 transition-colors"
          title="画中画"
          style={{ right: qualities.length > 1 ? '100px' : '16px' }}
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
        </button>
      )}

      <video
        ref={videoRef}
        className="video-js vjs-default-skin vjs-big-play-centered"
        controls
        preload="auto"
        data-setup="{}"
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'contain',
          imageRendering: 'crisp-edges',
          willChange: 'transform'
        }}
      >
        <p className="vjs-no-js">
          要查看此视频，请启用JavaScript，并考虑升级到支持HTML5视频的Web浏览器。
        </p>
      </video>
    </div>
  )
})

VideoPlayer.displayName = 'VideoPlayer'

export default VideoPlayer
