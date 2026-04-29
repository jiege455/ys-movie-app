import { create } from 'zustand'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：电影数据状态管理
 * 说明：管理电影列表、当前选中电影、加载状态等
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
  movies: Movie[]
  currentMovie: MovieDetail | null
  loading: boolean
  error: string | null
  currentPage: number
  totalPages: number

  setMovies: (movies: Movie[]) => void
  setCurrentMovie: (movie: MovieDetail | null) => void
  setLoading: (loading: boolean) => void
  setError: (error: string | null) => void
  setCurrentPage: (page: number) => void
  setTotalPages: (pages: number) => void

  addMovies: (movies: Movie[]) => void
  clearMovies: () => void
}

export const useMovieStore = create<MovieState>((set) => ({
  movies: [],
  currentMovie: null,
  loading: false,
  error: null,
  currentPage: 1,
  totalPages: 1,

  setMovies: (movies) => set({ movies }),
  setCurrentMovie: (currentMovie) => set({ currentMovie }),
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error }),
  setCurrentPage: (currentPage) => set({ currentPage }),
  setTotalPages: (totalPages) => set({ totalPages }),

  addMovies: (newMovies) => set((state) => ({
    movies: [...state.movies, ...newMovies]
  })),

  clearMovies: () => set({
    movies: [],
    currentPage: 1,
    totalPages: 1
  })
}))