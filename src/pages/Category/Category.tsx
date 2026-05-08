import React, { useEffect, useState, useRef, useMemo, useCallback } from 'react'
import { useParams, useNavigate, useLocation } from 'react-router-dom'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { getCategoryMovies } from '../../api'
import { useCategoryStore } from '../../store/categoryStore'
import type { Movie } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 分类详情页
 * 展示指定分类下的视频列表，数据来源：插件 API (app_api.php ac=list)
 */
export const Category: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const location = useLocation()
  const { categories, loadCategories } = useCategoryStore()

  const isMountedRef = useRef(true)

  const categoryName = useMemo(() => {
    if (location.state?.name) return location.state.name as string
    const found = categories.find((c) => c.type_id === id)
    return found?.type_name || '分类'
  }, [location.state?.name, categories, id])

  const [movies, setMovies] = useState<Movie[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    isMountedRef.current = true
    loadCategories()
    if (id) {
      loadMovies(id)
    }
    return () => { isMountedRef.current = false }
  }, [id])

  const loadMovies = useCallback(async (categoryId: string) => {
    try {
      setLoading(true)
      setError(null)
      const data = await getCategoryMovies(categoryId)
      if (!isMountedRef.current) return
      setMovies(data)
    } catch (e) {
      console.error(e)
      if (isMountedRef.current) {
        setError('加载分类数据失败，请稍后重试')
      }
    } finally {
      if (isMountedRef.current) {
        setLoading(false)
      }
    }
  }, [])

  const handleMovieClick = (movieId: string, vodLink?: string) => {
    if (vodLink && /^https?:\/\//i.test(vodLink)) {
      window.open(vodLink, '_blank')
      return
    }
    navigate(`/movie/${movieId}`)
  }

  return (
    <div className="min-h-screen pb-14 ">
      {/* 顶部导航 */}
      <div className="sticky top-0 z-10 glass border-b border-cyan-500/20 px-4 py-3 flex items-center">
        <button
          onClick={() => navigate(-1)}
          className="mr-3 text-cyan-300 hover:text-cyan-100"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-lg font-bold truncate text-cyan-100">{categoryName}</h1>
      </div>

      {/* 视频列表 */}
      <main className="px-4 py-4">
        {error && (
          <div className="bg-cyan-500/10 border border-cyan-500/20 rounded-lg p-4 mb-4">
            <p className="text-cyan-400 text-center">{error}</p>
            <button
              onClick={() => id && loadMovies(id)}
              className="mt-2 w-full bg-cyan-500 hover:bg-cyan-400 text-white py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        )}

        {loading ? (
          <div className="flex justify-center items-center py-20">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-cyan-400"></div>
          </div>
        ) : (
          <>
            {movies.length > 0 ? (
              <div className="grid grid-cols-3 gap-3">
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
            ) : (
              <div className="text-center py-20">
                <p className="text-cyan-400/60">暂无该分类数据</p>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}

export default Category
