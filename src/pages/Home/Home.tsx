import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Carousel } from '../../components/Carousel/Carousel'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { getHotMovies, getBannerMovies } from '../../api'
import { useMovieStore } from '../../store/movieStore'

/**
 * 文件名: Home.tsx
 * 作者: by：杰哥 (qq：2711793818)
 * 创建日期: 2026-01-01
 * 说明: 首页页面，负责加载轮播与电影列表，支持搜索与分类跳转
 */
/**
 * 首页组件
 * 展示热门电影轮播图和电影列表
 * 支持电影搜索和分类浏览
 */
export const Home: React.FC = () => {
  const navigate = useNavigate()
  const { movies, setMovies, loading, setLoading } = useMovieStore()
  // 首页轮播数据类型
  type BannerMovie = {
    id: string
    title: string
    poster_path: string
    vote_average: number
    release_date: string
    overview: string
    backdrop_path?: string
    link?: string
  }
  const [hotMovies, setHotMovies] = useState<BannerMovie[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [error, setError] = useState<string | null>(null)

  /**
   * 组件挂载时加载数据
   */
  useEffect(() => {
    loadMovies()
  }, [])

  /**
   * 加载电影数据
   */
  const loadMovies = async () => {
    try {
      setLoading(true)
      setError(null)
      // 先加载轮播数据（优先后端banner）
      const banners = await getBannerMovies()
      setHotMovies(banners)

      // 再加载列表数据（热门）
      const movieData = await getHotMovies(1)
      setMovies(movieData)
    } catch (err) {
      console.error('加载电影数据失败:', err)
      setError('加载数据失败，请检查网络连接')
    } finally {
      setLoading(false)
    }
  }

  /**
   * 处理电影卡片点击事件
   * @param movieId 电影ID
   */
  const handleMovieClick = (movieId: string, vodLink?: string) => {
    if (vodLink && /^https?:\/\//i.test(vodLink)) {
      window.open(vodLink, '_blank')
      return
    }
    navigate(`/movie/${movieId}`)
  }

  /**
   * 处理搜索提交
   * @param e 表单事件
   */
  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (searchQuery.trim()) {
      navigate(`/search?q=${encodeURIComponent(searchQuery.trim())}`)
    }
  }

  /**
   * 处理分类导航
   * @param category 分类名称
   */
  const handleCategoryClick = (category: string) => {
    navigate(`/category/${category}`)
  }

  return (
    <div className="min-h-screen bg-white">
      {/* 顶部搜索（移动端样式） */}
      <div className="px-4 pt-4 pb-2 sticky top-0 bg-white z-10">
        <form onSubmit={handleSearchSubmit} className="relative">
          <input
            type="text"
            placeholder="搜影视、演员..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-4 py-2 pl-10 pr-4 bg-gray-100 rounded-full focus:outline-none"
          />
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg className="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
        </form>
      </div>

      {/* 主要内容 */}
      <main className="px-4 pb-20">
        {/* 错误提示 */}
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
            <p className="text-red-600 text-center">{error}</p>
            <button
              onClick={loadMovies}
              className="mt-2 w-full bg-red-600 hover:bg-red-700 text-white py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        )}

        {/* 轮播图区域 */}
        {hotMovies.length > 0 && (
          <section className="mb-12">
            <h2 className="text-3xl font-bold text-gray-800 mb-6">热门推荐</h2>
            <Carousel
              movies={hotMovies}
              onMovieClick={handleMovieClick}
              autoPlay={true}
              interval={6000}
            />
          </section>
        )}

        {/* 视频列表 */}
        <section>
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-gray-800">热播精选</h2>
            <button 
              onClick={() => handleCategoryClick('movie')}
              className="text-red-600 hover:text-red-700 text-sm"
            >
              查看更多 →
            </button>
          </div>
          
          {loading ? (
            <div className="flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600"></div>
            </div>
          ) : (
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
          )}
          
          {!loading && movies.length === 0 && (
            <div className="text-center py-12">
              <p className="text-gray-500 text-lg">暂无电影数据</p>
            </div>
          )}
        </section>

        {/* 分类导航（简洁移动样式） */}
        <section className="mt-8">
          <h2 className="text-xl font-bold text-gray-800 mb-4">分类浏览</h2>
          <div className="grid grid-cols-4 gap-3">
            {[
              { name: '动作', icon: '🔥', category: 'action' },
              { name: '喜剧', icon: '😄', category: 'comedy' },
              { name: '爱情', icon: '💕', category: 'romance' },
              { name: '科幻', icon: '🚀', category: 'sci-fi' },
              { name: '恐怖', icon: '👻', category: 'horror' },
              { name: '动画', icon: '🎨', category: 'animation' },
              { name: '悬疑', icon: '🔍', category: 'mystery' },
              { name: '战争', icon: '⚔️', category: 'war' }
            ].map((genre) => (
              <button
                key={genre.category}
                onClick={() => handleCategoryClick(genre.category)}
                className="bg-gray-100 rounded-lg p-3 text-center"
              >
                <div className="text-xl mb-1">{genre.icon}</div>
                <div className="text-sm text-gray-800">{genre.name}</div>
              </button>
            ))}
          </div>
        </section>
      </main>
    </div>
  )
}

export default Home
