import React, { useEffect, useState, useRef, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { Carousel } from '../../components/Carousel/Carousel'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { getHomeData } from '../../api'
import type { BannerMovie, Movie, Category } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 首页页面
 * 通过插件 API (app_api.php ac=init) 一次请求获取轮播图+推荐+分类数据
 */

const CATEGORY_ICONS: Record<string, string> = {
  '1': '🎬', '2': '📺', '3': '🎭', '4': '🎵',
  '5': '🔥', '6': '😄', '7': '💕', '8': '🚀',
  '9': '👻', '10': '🎨', '11': '🔍', '12': '⚔️',
  '13': '📖', '14': '🎤', '15': '🏃', '16': '🌍',
  '17': '👶', '18': '🎪', '19': '📰', '20': '🎯'
}

const getIcon = (cat: Category): string => {
  const idx = parseInt(cat.type_id, 10)
  if (!isNaN(idx) && idx > 0 && idx <= 20) {
    return CATEGORY_ICONS[String(idx)] || '🎬'
  }
  const icons = Object.values(CATEGORY_ICONS)
  return icons[idx % icons.length] || '🎬'
}

const CATEGORY_DISPLAY_LIMIT = 8

export const Home: React.FC = () => {
  const navigate = useNavigate()
  const isMountedRef = useRef(true)

  const [banners, setBanners] = useState<BannerMovie[]>([])
  const [movies, setMovies] = useState<Movie[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    isMountedRef.current = true
    loadHomeData()
    return () => { isMountedRef.current = false }
  }, [])

  const loadHomeData = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const data = await getHomeData()
      if (!isMountedRef.current) return
      if (data) {
        setBanners(data.banners)
        setMovies(data.hotMovies)
        setCategories(data.categories)
      } else {
        setError('加载数据失败，请检查网络连接')
      }
    } catch (err) {
      console.error('加载首页数据失败:', err)
      if (isMountedRef.current) {
        setError('加载数据失败，请检查网络连接')
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

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (searchQuery.trim()) {
      navigate(`/search?q=${encodeURIComponent(searchQuery.trim())}`)
    }
  }

  const handleCategoryClick = (categoryId: string, categoryName: string) => {
    navigate(`/category/${categoryId}`, { state: { name: categoryName } })
  }

  const displayCategories = categories.slice(0, CATEGORY_DISPLAY_LIMIT)

  return (
    <div className="min-h-screen">
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

      <main className="px-4 pb-20">
        {error && (
          <div className="glass border border-cyan-500/20 rounded-lg p-4 mb-4">
            <p className="text-cyan-400 text-center">{error}</p>
            <button
              onClick={loadHomeData}
              className="mt-2 w-full bg-cyan-500 hover:bg-cyan-400 text-white py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        )}

        {banners.length > 0 && (
          <section className="mb-12">
            <h2 className="text-3xl font-bold mb-6 text-cyan-400">热门推荐</h2>
            <Carousel
              movies={banners}
              onMovieClick={handleMovieClick}
              autoPlay={true}
              interval={6000}
            />
          </section>
        )}

        <section>
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-cyan-400">热播精选</h2>
            {displayCategories.length > 0 && (
              <button
                onClick={() => handleCategoryClick(displayCategories[0].type_id, displayCategories[0].type_name)}
                className="text-cyan-400 hover:text-cyan-300 text-sm"
              >
                查看更多 →
              </button>
            )}
          </div>

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

        <section className="mt-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold text-cyan-400">分类浏览</h2>
            <button
              onClick={() => navigate('/categories')}
              className="text-cyan-400 hover:text-cyan-300 text-sm"
            >
              全部分类 →
            </button>
          </div>
          {loading ? (
            <div className="grid grid-cols-4 gap-3">
              {Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className="animate-pulse rounded-lg p-3 glass-card">
                  <div className="h-8 bg-slate-700/50 rounded mb-2" />
                  <div className="h-3 bg-slate-700/50 rounded w-2/3 mx-auto" />
                </div>
              ))}
            </div>
          ) : displayCategories.length > 0 ? (
            <div className="grid grid-cols-4 gap-3">
              {displayCategories.map((cat) => (
                <button
                  key={cat.type_id}
                  onClick={() => handleCategoryClick(cat.type_id, cat.type_name)}
                  className="rounded-lg p-3 text-center glass-card hover:bg-cyan-500/10 transition-colors"
                >
                  <div className="text-xl mb-1">{getIcon(cat)}</div>
                  <div className="text-sm text-cyan-300 truncate">{cat.type_name}</div>
                </button>
              ))}
            </div>
          ) : (
            <div className="text-center py-8">
              <p className="text-cyan-400/50 text-sm">暂无分类数据</p>
            </div>
          )}
        </section>
      </main>
    </div>
  )
}

export default Home
