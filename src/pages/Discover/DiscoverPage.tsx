import React, { useEffect, useState, useRef, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { getHotMovies } from '../../api'
import type { Movie } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 发现页面
 * 展示热门影视推荐，支持分类跳转和搜索
 */
export const DiscoverPage: React.FC = () => {
  const navigate = useNavigate()
  const isMountedRef = useRef(true)
  const abortRef = useRef<AbortController | null>(null)

  const [movies, setMovies] = useState<Movie[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [page, setPage] = useState(1)
  const [hasMore, setHasMore] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)

  useEffect(() => {
    isMountedRef.current = true
    loadMovies(1)
    return () => {
      isMountedRef.current = false
      abortRef.current?.abort()
    }
  }, [])

  const loadMovies = useCallback(async (p: number) => {
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller
    if (p === 1) {
      setLoading(true)
    } else {
      setLoadingMore(true)
    }
    setError(null)
    try {
      const data = await getHotMovies(p)
      if (!isMountedRef.current || controller.signal.aborted) return
      if (data.length < 20) {
        setHasMore(false)
      }
      if (p === 1) {
        setMovies(data)
      } else {
        setMovies((prev) => [...prev, ...data])
      }
      setPage(p)
    } catch {
      if (controller.signal.aborted) return
      if (isMountedRef.current) {
        setError('加载失败，请检查网络连接')
      }
    } finally {
      if (isMountedRef.current && !controller.signal.aborted) {
        setLoading(false)
        setLoadingMore(false)
      }
    }
  }, [])

  const handleLoadMore = () => {
    if (!loadingMore && hasMore) {
      loadMovies(page + 1)
    }
  }

  const handleMovieClick = (movieId: string) => {
    navigate(`/movie/${movieId}`)
  }

  return (
    <div className="min-h-screen pb-14">
      {/* 顶部标题 */}
      <div className="sticky top-0 z-10 glass border-b border-cyan-500/20 px-4 py-3">
        <h1 className="text-lg font-bold text-cyan-100">发现精彩</h1>
      </div>

      <main className="px-4 py-4">
        {error && (
          <div className="glass border border-cyan-500/20 rounded-lg p-4 mb-4">
            <p className="text-cyan-400 text-center">{error}</p>
            <button
              onClick={() => loadMovies(1)}
              className="mt-2 w-full bg-cyan-500 hover:bg-cyan-400 text-white py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        )}

        {loading ? (
          <div className="grid grid-cols-3 gap-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="animate-pulse">
                <div className="bg-slate-700/50 rounded-lg aspect-[2/3]" />
                <div className="mt-2 h-3 bg-slate-700/50 rounded w-3/4" />
                <div className="mt-1 h-3 bg-slate-700/50 rounded w-1/2" />
              </div>
            ))}
          </div>
        ) : (
          <>
            <div className="grid grid-cols-3 gap-4">
              {movies.map((movie) => (
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

            {hasMore && (
              <div className="mt-6 text-center">
                <button
                  onClick={handleLoadMore}
                  disabled={loadingMore}
                  className="px-8 py-2 rounded-full glass-card text-cyan-300 hover:text-cyan-100 disabled:opacity-50 transition-colors"
                >
                  {loadingMore ? (
                    <span className="flex items-center justify-center gap-2">
                      <span className="animate-spin inline-block h-4 w-4 border-b-2 border-cyan-400 rounded-full" />
                      加载中...
                    </span>
                  ) : (
                    '加载更多'
                  )}
                </button>
              </div>
            )}

            {!loadingMore && movies.length >= 20 && !hasMore && (
              <div className="mt-6 text-center">
                <p className="text-cyan-400/40 text-sm">已加载全部内容</p>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}

export default DiscoverPage
