import { create } from 'zustand'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 播放器状态管理
 * 管理视频播放状态、进度、音量等
 */

interface PlayerState {
  isPlaying: boolean
  currentTime: number
  duration: number
  volume: number
  isFullscreen: boolean
  currentEpisode: number

  setIsPlaying: (playing: boolean) => void
  setCurrentTime: (time: number) => void
  setDuration: (duration: number) => void
  setVolume: (volume: number) => void
  setIsFullscreen: (fullscreen: boolean) => void
  setCurrentEpisode: (episode: number) => void

  togglePlay: () => void
  toggleFullscreen: () => void
}

export const usePlayerStore = create<PlayerState>((set) => ({
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  volume: 1,
  isFullscreen: false,
  currentEpisode: 0,

  setIsPlaying: (isPlaying) => set({ isPlaying }),
  setCurrentTime: (currentTime) => set({ currentTime }),
  setDuration: (duration) => set({ duration }),
  setVolume: (volume) => set({ volume }),
  setIsFullscreen: (isFullscreen) => set({ isFullscreen }),
  setCurrentEpisode: (currentEpisode) => set({ currentEpisode }),

  togglePlay: () => set((state) => ({ isPlaying: !state.isPlaying })),
  toggleFullscreen: () => set((state) => ({ isFullscreen: !state.isFullscreen }))
}))
