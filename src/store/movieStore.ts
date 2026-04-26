import { create } from 'zustand'

/**
 * 电影数据状态管理
 */
interface Movie {
  id: string
  title: string
  poster_path: string
  vote_average: number
  release_date: string
  overview: string
}

interface MovieDetail extends Movie {
  runtime?: number
  genres?: Array<{ id: number; name: string }>
  cast?: Array<{ name: string; character: string }>
  crew?: Array<{ name: string; job: string }>
}

interface MovieState {
  // 状态数据
  movies: Movie[]
  currentMovie: MovieDetail | null
  loading: boolean
  error: string | null
  currentPage: number
  totalPages: number
  
  // 操作方法
  setMovies: (movies: Movie[]) => void
  setCurrentMovie: (movie: MovieDetail | null) => void
  setLoading: (loading: boolean) => void
  setError: (error: string | null) => void
  setCurrentPage: (page: number) => void
  setTotalPages: (pages: number) => void
  
  // 业务方法
  addMovies: (movies: Movie[]) => void
  clearMovies: () => void
}

/**
 * 电影数据状态管理Store
 * 用于管理电影列表、当前选中电影、加载状态等
 */
export const useMovieStore = create<MovieState>((set) => ({
  // 初始状态
  movies: [],
  currentMovie: null,
  loading: false,
  error: null,
  currentPage: 1,
  totalPages: 1,
  
  // 基础设置方法
  setMovies: (movies) => set({ movies }),
  setCurrentMovie: (currentMovie) => set({ currentMovie }),
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error }),
  setCurrentPage: (currentPage) => set({ currentPage }),
  setTotalPages: (totalPages) => set({ totalPages }),
  
  // 业务逻辑方法
  addMovies: (newMovies) => set((state) => ({
    movies: [...state.movies, ...newMovies]
  })),
  
  clearMovies: () => set({ 
    movies: [], 
    currentPage: 1,
    totalPages: 1 
  })
}))

/**
 * 播放器状态管理
 */
interface PlayerState {
  // 播放器状态
  isPlaying: boolean
  currentTime: number
  duration: number
  volume: number
  isFullscreen: boolean
  
  // 操作方法
  setIsPlaying: (playing: boolean) => void
  setCurrentTime: (time: number) => void
  setDuration: (duration: number) => void
  setVolume: (volume: number) => void
  setIsFullscreen: (fullscreen: boolean) => void
  
  // 业务方法
  togglePlay: () => void
  toggleFullscreen: () => void
}

/**
 * 播放器状态管理Store
 * 用于管理视频播放状态、进度、音量等
 */
export const usePlayerStore = create<PlayerState>((set) => ({
  // 初始状态
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  volume: 1,
  isFullscreen: false,
  
  // 基础设置方法
  setIsPlaying: (isPlaying) => set({ isPlaying }),
  setCurrentTime: (currentTime) => set({ currentTime }),
  setDuration: (duration) => set({ duration }),
  setVolume: (volume) => set({ volume }),
  setIsFullscreen: (isFullscreen) => set({ isFullscreen }),
  
  // 业务逻辑方法
  togglePlay: () => set((state) => ({ isPlaying: !state.isPlaying })),
  toggleFullscreen: () => set((state) => ({ isFullscreen: !state.isFullscreen }))
}))

/**
 * UI状态管理
 */
interface UIState {
  // UI状态
  theme: 'light' | 'dark'
  sidebarOpen: boolean
  searchQuery: string
  
  // 操作方法
  setTheme: (theme: 'light' | 'dark') => void
  setSidebarOpen: (open: boolean) => void
  setSearchQuery: (query: string) => void
  
  // 业务方法
  toggleTheme: () => void
  toggleSidebar: () => void
}

/**
 * UI状态管理Store
 * 用于管理主题、侧边栏、搜索等UI状态
 */
export const useUIStore = create<UIState>((set) => ({
  // 初始状态
  theme: 'light',
  sidebarOpen: false,
  searchQuery: '',
  
  // 基础设置方法
  setTheme: (theme) => set({ theme }),
  setSidebarOpen: (sidebarOpen) => set({ sidebarOpen }),
  setSearchQuery: (searchQuery) => set({ searchQuery }),
  
  // 业务逻辑方法
  toggleTheme: () => set((state) => ({ 
    theme: state.theme === 'light' ? 'dark' : 'light' 
  })),
  toggleSidebar: () => set((state) => ({ 
    sidebarOpen: !state.sidebarOpen 
  }))
}))