import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Carousel } from '../../components/Carousel/Carousel'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { getHotMovies, getBannerMovies } from '../../api'
import { useMovieStore } from '../../store/movieStore'
import type { BannerMovie } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 首页页面
 * 负责加载轮播与电影列表，支持搜索与分类跳转
 */
export const Home: React.FC = () => {
  const navigate = useNavigate()
  const { movies, setMovies, loading, setLoading } = useMovieStore()

  const [hotMovies, setHotMovies] = useState<BannerMovie[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadMovies()
  }, [])

  const loadMovies = async () => {
    try {
      setLoading(true)
      setError(null)
      const banners = await getBannerMovies()
      setHotMovies(banners)
      const movieData = await getHotMovies(1)
      setMovies(movieData)
    } catch (err) {
      console.error('加载电影数据失败:', err)
      setError('加载数据失败，请检查网络连接')
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

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (searchQuery.trim()) {
      navigate(`/search?q=${encodeURIComponent(searchQuery.trim())}`)
    }
  }

  const handleCategoryClick = (category: string) => {
    navigate(`/category/${category}`)
  }

  return (
    <div className="min-h-screen">
      {/* 顶部搜索（移动端样式） */}
      <div className="px-4 pt-4 pb-2 sticky top-0 z-10 glass">
        <form onSubmit={handleSearchSubmit} className="relative">
          <input
            type="text"
            placeholder="搜影视、演员..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-4 py-2 pl-10 pr-4 rounded-full focus:outline-none glass-light text-cyan-100 placeholder-cyan-400/50 border border-cyan-500/20 focus:border-cyan-400/50"
          />
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg className="h-5 w-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
        </form>
      </div>

      {/* 主要内容 */}
      <main className="px-4 pb-20">
        {/* 错误提示 */}
        {error && (
          <div className="glass border border-cyan-500/20 rounded-lg p-4 mb-4">
            <p className="text-cyan-400 text-center">{error}</p>
            <button
              onClick={loadMovies}
              className="mt-2 w-full bg-cyan-500 hover:bg-cyan-400 text-white py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        )}

        {/* 轮播图区域 */}
        {hotMovies.length > 0 && (
          <section className="mb-12">
            <h2 className="text-3xl font-bold mb-6 text-cyan-400">热门推荐</h2>
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
            <h2 className="text-xl font-bold text-cyan-400">热播精选</h2>
            <button
              onClick={() => handleCategoryClick('movie')}
              className="text-cyan-400 hover:text-cyan-300 text-sm"
            >
              查看更多 →
            </button>
          </div>

          {loading ? (
            <div className="flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-400"></div>
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
              <p className="text-lg text-cyan-400/60">暂无电影数据</p>
            </div>
          )}
        </section>

        {/* 分类导航（简洁移动样式） */}
        <section className="mt-8">
          <h2 className="text-xl font-bold mb-4 text-cyan-400">分类浏览</h2>
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
                className="rounded-lg p-3 text-center glass-card hover:bg-cyan-500/10 transition-colors"
              >
                <div className="text-xl mb-1">{genre.icon}</div>
                <div className="text-sm text-cyan-300">{genre.name}</div>
              </button>
            ))}
          </div>
        </section>
      </main>
    </div>
  )
}

export default Home
