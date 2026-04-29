import React, { useEffect, useState, useCallback } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { searchMovies } from '../../api'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { useTheme } from '../../contexts/ThemeContext'
import { debounce } from '../../lib/utils'
import type { Movie } from '../../types'

/**
 * 开发者：杰哥网络科技
 * 模块：搜索页面
 * 说明：支持关键词搜索视频，实时展示搜索结果
 */

export const Search: React.FC = () => {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const { isDark } = useTheme()

  const initialQuery = searchParams.get('q') || ''
  const [query, setQuery] = useState(initialQuery)
  const [results, setResults] = useState<Movie[]>([])
  const [loading, setLoading] = useState(false)
  const [searched, setSearched] = useState(false)

  /**
   * 执行搜索
   */
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

  /**
   * 防抖搜索
   */
  const debouncedSearch = useCallback(
    debounce((keyword: string) => {
      doSearch(keyword)
    }, 500),
    [doSearch]
  )

  /**
   * 监听 URL 参数变化，自动搜索
   */
  useEffect(() => {
    const q = searchParams.get('q')
    if (q) {
      setQuery(q)
      doSearch(q)
    }
  }, [searchParams, doSearch])

  /**
   * 处理输入变化
   */
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

  /**
   * 处理表单提交
   */
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (query.trim()) {
      setSearchParams({ q: query.trim() })
    }
  }

  /**
   * 处理电影点击
   */
  const handleMovieClick = (movieId: string) => {
    navigate(`/movie/${movieId}`)
  }

  return (
    <div className={`min-h-screen pb-20 ${isDark ? 'bg-gray-900' : 'bg-white'}`}>
      {/* 搜索栏 */}
      <div className={`sticky top-0 z-10 px-4 py-3 ${isDark ? 'bg-gray-900 border-gray-800' : 'bg-white border-gray-200'} border-b`}>
        <form onSubmit={handleSubmit} className="flex items-center gap-3">
          <div className="relative flex-1">
            <input
              type="text"
              value={query}
              onChange={handleInputChange}
              placeholder="搜索影视、演员..."
              className={`w-full px-4 py-2 pl-10 pr-4 rounded-full focus:outline-none ${
                isDark
                  ? 'bg-gray-800 text-white placeholder-gray-400'
                  : 'bg-gray-100 text-gray-900 placeholder-gray-500'
              }`}
              autoFocus
            />
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg className="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
          </div>
          <button
            type="button"
            onClick={() => navigate(-1)}
            className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}
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
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-sky-500"></div>
          </div>
        )}

        {/* 搜索结果列表 */}
        {!loading && searched && results.length > 0 && (
          <div>
            <p className={`text-sm mb-4 ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
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
            <svg className="mx-auto h-16 w-16 text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className={`text-lg ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
              未找到相关影视
            </p>
            <p className={`text-sm mt-1 ${isDark ? 'text-gray-500' : 'text-gray-400'}`}>
              试试其他关键词
            </p>
          </div>
        )}

        {/* 初始状态提示 */}
        {!searched && (
          <div className="text-center py-16">
            <svg className="mx-auto h-16 w-16 text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <p className={`text-lg ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
              输入关键词搜索影视
            </p>
          </div>
        )}
      </main>
    </div>
  )
}

export default Search
