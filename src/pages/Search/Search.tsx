import React, { useEffect, useState, useCallback } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { searchMovies } from '../../api'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { debounce } from '../../lib/utils'
import type { Movie } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 搜索页面
 * 支持关键词搜索视频，实时展示搜索结果
 */

export const Search: React.FC = () => {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()

  const initialQuery = searchParams.get('q') || ''
  const [query, setQuery] = useState(initialQuery)
  const [results, setResults] = useState<Movie[]>([])
  const [loading, setLoading] = useState(false)
  const [searched, setSearched] = useState(false)

  const doSearch = useCallback(async (keyword: string) => {
    if (!keyword.trim()) {
      setResults([])
      setSearched(false)
      return
    }
    setLoading(true)
    setSearched(true)
    try {
      const movies = await searchMovies(keyword.trim())
      setResults(movies)
    } catch (error) {
      console.error('搜索出错:', error)
      setResults([])
    } finally {
      setLoading(false)
    }
  }, [])

  const debouncedSearch = useCallback(
    debounce((keyword: string) => {
      doSearch(keyword)
    }, 500),
    [doSearch]
  )

  useEffect(() => {
    const q = searchParams.get('q')
    if (q) {
      setQuery(q)
      doSearch(q)
    }
  }, [searchParams, doSearch])

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value
    setQuery(value)
    if (value.trim()) {
      debouncedSearch(value)
    } else {
      setResults([])
      setSearched(false)
    }
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (query.trim()) {
      setSearchParams({ q: query.trim() })
    }
  }

  const handleMovieClick = (movieId: string) => {
    navigate(`/movie/${movieId}`)
  }

  return (
    <div className="min-h-screen pb-20 bg-[#0a0e1a]">
      {/* 搜索栏 */}
      <div className="sticky top-0 z-10 px-4 py-3 glass border-b border-sky-500/20">
        <form onSubmit={handleSubmit} className="flex items-center gap-3">
          <div className="relative flex-1">
            <input
              type="text"
              value={query}
              onChange={handleInputChange}
              placeholder="搜索影视、演员..."
              className="w-full px-4 py-2 pl-10 pr-4 rounded-full focus:outline-none bg-[#0f172a]/80 text-sky-100 placeholder-sky-400/50 border border-sky-500/20"
              autoFocus
            />
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg className="h-5 w-5 text-sky-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
          </div>
          <button
            type="button"
            onClick={() => navigate(-1)}
            className="text-sm text-sky-400/60"
          >
            取消
          </button>
        </form>
      </div>

      {/* 搜索结果 */}
      <main className="px-4 py-4">
        {/* 加载中 */}
        {loading && (
          <div className="flex justify-center items-center py-12">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-sky-400"></div>
          </div>
        )}

        {/* 搜索结果列表 */}
        {!loading && searched && results.length > 0 && (
          <div>
            <p className="text-sm mb-4 text-sky-400/60">
              找到 {results.length} 个结果
            </p>
            <div className="grid grid-cols-3 gap-4">
              {results.map((movie) => (
                <MovieCard
                  key={movie.id}
                  id={movie.id}
                  title={movie.title}
                  poster_path={movie.poster_path}
                  vote_average={movie.vote_average}
                  release_date={movie.release_date}
                  overview={movie.overview}
                  onClick={handleMovieClick}
                />
              ))}
            </div>
          </div>
        )}

        {/* 无结果 */}
        {!loading && searched && results.length === 0 && (
          <div className="text-center py-16">
            <svg className="mx-auto h-16 w-16 text-sky-400/30 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className="text-lg text-sky-400/60">
              未找到相关影视
            </p>
            <p className="text-sm mt-1 text-sky-400/40">
              试试其他关键词
            </p>
          </div>
        )}

        {/* 初始状态提示 */}
        {!searched && (
          <div className="text-center py-16">
            <svg className="mx-auto h-16 w-16 text-sky-400/30 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <p className="text-lg text-sky-400/60">
              输入关键词搜索影视
            </p>
          </div>
        )}
      </main>
    </div>
  )
}

export default Search
