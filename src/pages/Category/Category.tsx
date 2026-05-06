import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, useLocation } from 'react-router-dom'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { getCategoryMovies } from '../../api'
import { useTheme } from '../../contexts/ThemeContext'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 分类详情页
 * 展示指定分类下的视频列表
 */
export const Category: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const location = useLocation()
  const { isDark } = useTheme()
  // 优先从路由状态获取名称，默认显示“分类”
  const categoryName = location.state?.name || '分类'
  
  const [movies, setMovies] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (id) {
      loadMovies(id)
    }
  }, [id])

  const loadMovies = async (categoryId: string) => {
    try {
      setLoading(true)
      setError(null)
      const data = await getCategoryMovies(categoryId)
      setMovies(data)
    } catch (e) {
      console.error(e)
      setError('加载分类数据失败，请稍后重试')
    } finally {
      setLoading(false)
    }
  }

  const handleMovieClick = (movieId: string, vodLink?: string) => {
    if (vodLink && /^https?:\/\//i.test(vodLink)) {
      window.open(vodLink, '_blank')
      return
    }
    navigate(`/movie/${movieId}`)
  }

  return (
    <div className={`min-h-screen pb-14 ${isDark ? 'bg-gray-900' : 'bg-white'}`}>
      {/* 顶部导航 */}
      <div className={`sticky top-0 z-10 border-b px-4 py-3 flex items-center shadow-sm ${isDark ? 'bg-gray-900 border-gray-700' : 'bg-white border-gray-200'}`}>
        <button 
          onClick={() => navigate(-1)} 
          className={`mr-3 ${isDark ? 'text-gray-300 hover:text-white' : 'text-gray-700 hover:text-gray-900'}`}
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className={`text-lg font-bold truncate ${isDark ? 'text-white' : 'text-gray-900'}`}>{categoryName}</h1>
      </div>

      {/* 视频列表 */}
      <main className="px-4 py-4">
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
            <p className="text-red-600 text-center">{error}</p>
            <button
              onClick={() => id && loadMovies(id)}
              className="mt-2 w-full bg-red-600 hover:bg-red-700 text-white py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        )}

        {loading ? (
          <div className="flex justify-center items-center py-20">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-red-600"></div>
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
                <p className={isDark ? 'text-gray-400' : 'text-gray-500'}>暂无该分类数据</p>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}

export default Category
