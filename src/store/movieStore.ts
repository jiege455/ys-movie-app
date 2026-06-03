import { create } from 'zustand'
import type { Movie } from '../types'

interface MovieState {
  movies: Movie[]
  loading: boolean
  error: string | null
  currentPage: number
  totalPages: number

  setMovies: (movies: Movie[]) => void
  setLoading: (loading: boolean) => void
  setError: (error: string | null) => void
  setCurrentPage: (page: number) => void
  setTotalPages: (pages: number) => void

  addMovies: (movies: Movie[]) => void
  clearMovies: () => void
}

export const useMovieStore = create<MovieState>((set) => ({
  movies: [],
  loading: false,
  error: null,
  currentPage: 1,
  totalPages: 1,

  setMovies: (movies) => set({ movies }),
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