import React, { useRef, useEffect, useState, useCallback, useImperativeHandle, forwardRef, useMemo } from 'react'
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
 * 修复：动态快进步长、键盘快捷键过滤、画中画状态同步、iOS全屏兼容、播放速度记忆
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
  const [isInPiP, setIsInPiP] = useState(false)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [playbackRate, setPlaybackRate] = useState(() => {
    // 开发者：杰哥网络科技
    // 修复：从 localStorage 读取用户上次设置的播放速度
    const saved = localStorage.getItem('video_playback_rate')
    return saved ? parseFloat(saved) : 1
  })

  // 同步startTime
  useEffect(() => {
    startTimeRef.current = startTime
  }, [startTime])

  /**
   * 动态计算跳过时间
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：根据视频时长动态调整快进/后退步长
   */
  const skipTime = useMemo(() => {
    if (!duration) return 10
    if (duration < 300) return 5
    if (duration < 1800) return 10
    return 30
  }, [duration])

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
   * 快进
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：使用动态步长
   */
  const handleForward = useCallback(() => {
    if (playerRef.current) {
      const newTime = Math.min(currentTime + skipTime, duration || 0)
      playerRef.current.currentTime(newTime)
    }
  }, [currentTime, duration, skipTime])

  /**
   * 后退
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：使用动态步长
   */
  const handleBackward = useCallback(() => {
    if (playerRef.current) {
      const newTime = Math.max(currentTime - skipTime, 0)
      playerRef.current.currentTime(newTime)
    }
  }, [currentTime, skipTime])

  /**
   * 切换画中画
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：增加状态同步和桌面窗口交互优化
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
   * 进入全屏（兼容 iOS Safari）
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：增加 webkit 前缀兼容
   */
  const enterFullscreen = useCallback(() => {
    const player = playerRef.current
    if (!player) return

    const el = player.el() as HTMLElement & {
      webkitEnterFullscreen?: () => void
      webkitRequestFullscreen?: () => void
    }

    if (el.requestFullscreen) {
      el.requestFullscreen()
    } else if (el.webkitRequestFullscreen) {
      el.webkitRequestFullscreen()
    } else if (el.webkitEnterFullscreen) {
      el.webkitEnterFullscreen()
    }
    setIsFullscreen(true)
  }, [])

  /**
   * 退出全屏（兼容 iOS Safari）
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：增加 webkit 前缀兼容
   */
  const exitFullscreen = useCallback(() => {
    const doc = document as Document & {
      webkitExitFullscreen?: () => void
      webkitCancelFullScreen?: () => void
    }

    if (document.exitFullscreen) {
      document.exitFullscreen()
    } else if (doc.webkitExitFullscreen) {
      doc.webkitExitFullscreen()
    } else if (doc.webkitCancelFullScreen) {
      doc.webkitCancelFullScreen()
    }
    setIsFullscreen(false)
  }, [])

  /**
   * 切换全屏
   */
  const toggleFullscreen = useCallback(() => {
    if (isFullscreen) {
      exitFullscreen()
    } else {
      enterFullscreen()
    }
  }, [isFullscreen, enterFullscreen, exitFullscreen])

  /**
   * 切换播放速度
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：保存用户偏好到 localStorage
   */
  const handlePlaybackRateChange = useCallback((rate: number) => {
    setPlaybackRate(rate)
    localStorage.setItem('video_playback_rate', rate.toString())
    if (playerRef.current) {
      playerRef.current.playbackRate(rate)
    }
  }, [])

  /**
   * 初始化Video.js播放器
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：
   * 1. 增加 src 有效性检查，避免空源初始化失败
   * 2. 优化加载策略：preload 改为 metadata，减少初始加载时间
   * 3. 优化缓冲配置，提升播放流畅度
   * 4. 增加视频源预连接，加速首帧加载
   */
  useEffect(() => {
    if (!videoRef.current) return
    if (!src || src.trim() === '') return

    setIsPiPSupported(document.pictureInPictureEnabled || false)

    // 预连接视频源域名，加速 DNS 解析和 TCP 握手
    try {
      const url = new URL(src)
      const link = document.createElement('link')
      link.rel = 'preconnect'
      link.href = url.origin
      document.head.appendChild(link)
    } catch (_) {
      // 相对路径或无效 URL，忽略
    }

    const player = videojs(videoRef.current, {
      controls: true,
      responsive: true,
      fluid: true,
      // 开发者：杰哥网络科技
      // 优化：preload 从 auto 改为 metadata，只加载元数据，大幅减少初始加载时间
      // 用户点击播放后再加载视频内容
      preload: 'metadata',
      poster: poster || '',
      sources: [{
        src: src,
        type: getVideoType(src)
      }],
      playbackRates: [0.5, 0.75, 1, 1.25, 1.5, 2],
      html5: {
        vhs: {
          overrideNative: true,
          limitRenditionByPlayerDimensions: true,
          useDevicePixelRatio: true,
          allowSeeksWithinUnsafeLiveWindow: true,
          handlePartialData: true,
          // 开发者：杰哥网络科技
          // 优化：减少缓冲长度，加快首帧播放
          maxBufferLength: 30,
          maxMaxBufferLength: 60,
          // 启用快速质量切换
          experimentalBufferBasedABR: true
        },
        nativeAudioTracks: false,
        nativeVideoTracks: false
      },
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
      userActions: {
        click: true,
        doubleClick: true
      },
      autoplay: false,
      loop: false,
      muted: false,
      language: 'zh-CN',
      errorDisplay: {
        message: '视频加载失败，请刷新页面重试'
      }
    })

    playerRef.current = player

    // 应用保存的播放速度
    if (playbackRate !== 1) {
      player.playbackRate(playbackRate)
    }

    player.ready(() => {
      if (!isMountedRef.current) return
      setIsLoading(false)

      if (startTimeRef.current > 0) {
        player.currentTime(startTimeRef.current)
      }

      player.on('play', () => { if (isMountedRef.current) onPlay?.() })
      player.on('pause', () => { if (isMountedRef.current) onPause?.() })
      player.on('ended', () => { if (isMountedRef.current) onEnded?.() })
      player.on('timeupdate', () => {
        if (isMountedRef.current) {
          const time = player.currentTime()
          setCurrentTime(time)
          onTimeUpdate?.(time)
        }
      })
      player.on('loadedmetadata', () => {
        if (isMountedRef.current) {
          const dur = player.duration() || 0
          setDuration(dur)
          onLoadedMetadata?.(dur)
          if (startTimeRef.current > 0 && player.currentTime() < startTimeRef.current) {
            player.currentTime(startTimeRef.current)
          }
        }
      })

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

      player.on('waiting', () => { if (isMountedRef.current) setIsLoading(true) })
      player.on('playing', () => { if (isMountedRef.current) setIsLoading(false) })
      player.on('canplay', () => { if (isMountedRef.current) setIsLoading(false) })

      // 全屏状态监听
      const handleFullscreenChange = () => {
        setIsFullscreen(!!document.fullscreenElement)
      }
      document.addEventListener('fullscreenchange', handleFullscreenChange)

      // HLS/DASH 多码率清晰度处理
      try {
        const tech: any = player.tech({ IWillNotUseThisInPlugins: true })
        if (tech?.vhs) {
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
   * 画中画状态同步
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：监听 enter/leave 事件，确保状态同步
   */
  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    const handleEnterPiP = () => setIsInPiP(true)
    const handleLeavePiP = () => setIsInPiP(false)

    video.addEventListener('enterpictureinpicture', handleEnterPiP)
    video.addEventListener('leavepictureinpicture', handleLeavePiP)

    return () => {
      video.removeEventListener('enterpictureinpicture', handleEnterPiP)
      video.removeEventListener('leavepictureinpicture', handleLeavePiP)
    }
  }, [])

  /**
   * 键盘快捷键
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 修复：增加输入框焦点判断，避免在输入时触发
   */
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // 如果焦点在输入框/文本域内，不处理快捷键
      const target = e.target as HTMLElement
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable) {
        return
      }

      // 空格键：播放/暂停
      if (e.code === 'Space') {
        e.preventDefault()
        if (playerRef.current) {
          if (playerRef.current.paused()) {
            playerRef.current.play()
          } else {
            playerRef.current.pause()
          }
        }
      }
      // 方向键右：快进
      if (e.code === 'ArrowRight') {
        e.preventDefault()
        handleForward()
      }
      // 方向键左：后退
      if (e.code === 'ArrowLeft') {
        e.preventDefault()
        handleBackward()
      }
      // F 键：全屏切换
      if (e.code === 'KeyF') {
        e.preventDefault()
        toggleFullscreen()
      }
      // M 键：静音切换
      if (e.code === 'KeyM') {
        e.preventDefault()
        if (playerRef.current) {
          playerRef.current.muted(!playerRef.current.muted())
        }
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [handleForward, handleBackward, toggleFullscreen])

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
          tech.vhs.playlistController_.selectPlaylist = () => {
            const sorted = playlists
              .filter((p: any) => p.attributes?.BANDWIDTH)
              .sort((a: any, b: any) => b.attributes.BANDWIDTH - a.attributes.BANDWIDTH)
            return sorted[0] || playlists[0]
          }
        } else {
          const height = parseInt(quality.replace('p', ''))
          const target = playlists.find((p: any) =>
            p.attributes?.RESOLUTION?.height === height
          )
          if (target) {
            tech.vhs.playlistController_.selectPlaylist = () => target
          }
        }

        tech.vhs.playlistController_.load()
        if (currentTime > 0) {
          playerRef.current.currentTime(currentTime)
        }
        if (!isPaused) {
          playerRef.current.play()
        }
      }
    } catch (e) {
      console.log('清晰度切换失败:', e)
    }
  }, [onQualityChange])

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
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-400 mx-auto mb-4"></div>
            <p className="text-sm">视频加载中...</p>
          </div>
        </div>
      )}

      {/* 错误提示 */}
      {hasError && (
        <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-80 z-20">
          <div className="text-white text-center px-4">
            <svg className="w-16 h-16 mx-auto mb-4 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className="text-lg mb-2">视频加载失败</p>
            <p className="text-cyan-400/60 text-sm mb-4">请检查网络连接或稍后重试</p>
            <button
              onClick={handleRetry}
              className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        </div>
      )}

      {/* 清晰度选择器 */}
      {qualities.length > 1 && !hasError && (
        <div className="absolute top-4 right-4 z-30 flex items-center space-x-2">
          <select
            value={currentQuality}
            onChange={(e) => handleQualityChange(e.target.value)}
            className="bg-black/70 text-white px-3 py-1 rounded text-sm border border-cyan-500/30 focus:outline-none focus:border-cyan-400 backdrop-blur-sm cursor-pointer"
          >
            {qualities.map((q) => (
              <option key={q} value={q} className="glass-light">
                {q === 'auto' ? '自动' : q}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* 播放速度选择器 */}
      {!hasError && (
        <div
          className="absolute top-4 z-30 flex items-center space-x-2"
          style={{ right: qualities.length > 1 ? '160px' : '80px' }}
        >
          <select
            value={playbackRate}
            onChange={(e) => handlePlaybackRateChange(parseFloat(e.target.value))}
            className="bg-black/70 text-white px-2 py-1 rounded text-sm border border-cyan-500/30 focus:outline-none focus:border-cyan-400 backdrop-blur-sm cursor-pointer"
          >
            <option value={0.5} className="glass-light">0.5x</option>
            <option value={0.75} className="glass-light">0.75x</option>
            <option value={1} className="glass-light">1x</option>
            <option value={1.25} className="glass-light">1.25x</option>
            <option value={1.5} className="glass-light">1.5x</option>
            <option value={2} className="glass-light">2x</option>
          </select>
        </div>
      )}

      {/* 画中画按钮 */}
      {isPiPSupported && !hasError && (
        <button
          onClick={togglePictureInPicture}
          className={`absolute top-4 z-30 bg-black/70 text-white p-2 rounded backdrop-blur-sm hover:bg-opacity-90 transition-colors ${isInPiP ? 'bg-cyan-500' : ''}`}
          title={isInPiP ? '退出画中画' : '画中画'}
          style={{ right: qualities.length > 1 ? '100px' : '16px' }}
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
        </button>
      )}

      {/* 画中画桌面窗口提示 */}
      {isInPiP && (
        <div className="absolute bottom-4 left-1/2 transform -translate-x-1/2 z-30 bg-black bg-opacity-80 text-white px-4 py-2 rounded-lg text-sm backdrop-blur-sm">
          画中画模式 - 按 ESC 或点击视频退出
        </div>
      )}

      {/* 开发者：杰哥网络科技 (qq: 2711793818) */}
      {/* 修复：移除 video 标签的 preload 属性，避免与 Video.js 配置冲突 */}
      <video
        ref={videoRef}
        className="video-js vjs-default-skin vjs-big-play-centered"
        controls
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
