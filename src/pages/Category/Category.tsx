import React, { useEffect, useState, useRef, useMemo, useCallback } from 'react'
import { useParams, useNavigate, useLocation } from 'react-router-dom'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import { getCategoryMovies } from '../../api'
import { useCategoryStore } from '../../store/categoryStore'
import type { Movie, CategoryFilter } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 分类详情页（含筛选）
 * 展示指定分类下的视频列表，支持按类型/地区/年份/排序筛选
 * 数据来源：插件 API (app_api.php ac=list)
 */

const FILTER_CLASS = ['全部', '动作', '喜剧', '爱情', '科幻', '恐怖', '动画', '悬疑', '战争', '剧情', '伦理', '记录']
const FILTER_AREA = ['全部', '大陆', '香港', '台湾', '美国', '韩国', '日本', '泰国', '印度', '英国', '法国', '其他']
const FILTER_YEAR = ['全部', '2025', '2024', '2023', '2022', '2021', '2020', '2019', '2018', '更早']
const FILTER_SORT = [
  { label: '最新', value: 'time' },
  { label: '最热', value: 'hits' },
  { label: '好评', value: 'score' }
]

export const Category: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const location = useLocation()
  const { categories, loadCategories } = useCategoryStore()

  const isMountedRef = useRef(true)
  const abortRef = useRef<AbortController | null>(null)

  const categoryName = useMemo(() => {
    if (location.state?.name) return location.state.name as string
    const found = categories.find((c) => c.type_id === id)
    return found?.type_name || '分类'
  }, [location.state?.name, categories, id])

  const [movies, setMovies] = useState<Movie[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [activeFilter, setActiveFilter] = useState<'class' | 'area' | 'year' | null>(null)
  const [classFilter, setClassFilter] = useState('全部')
  const [areaFilter, setAreaFilter] = useState('全部')
  const [yearFilter, setYearFilter] = useState('全部')
  const [sortBy, setSortBy] = useState('time')

  useEffect(() => {
    isMountedRef.current = true
    loadCategories()
    return () => {
      isMountedRef.current = false
      abortRef.current?.abort()
    }
  }, [])

  useEffect(() => {
    if (id && isMountedRef.current) {
      loadMovies()
    }
  }, [id, classFilter, areaFilter, yearFilter, sortBy])

  const buildFilter = useCallback((): CategoryFilter => ({
    class: classFilter !== '全部' ? classFilter : undefined,
    area: areaFilter !== '全部' ? areaFilter : undefined,
    year: yearFilter !== '全部' ? (yearFilter === '更早' ? '2017' : yearFilter) : undefined,
    by: sortBy
  }), [classFilter, areaFilter, yearFilter, sortBy])

  const loadMovies = useCallback(async () => {
    if (!id) return
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller
    try {
      setLoading(true)
      setError(null)
      const data = await getCategoryMovies(id, 1, buildFilter())
      if (!isMountedRef.current || controller.signal.aborted) return
      setMovies(data)
    } catch (e) {
      if (controller.signal.aborted) return
      console.error(e)
      if (isMountedRef.current) {
        setError('加载分类数据失败，请稍后重试')
      }
    } finally {
      if (isMountedRef.current && !controller.signal.aborted) {
        setLoading(false)
      }
    }
  }, [id, buildFilter])

  const handleMovieClick = (movieId: string, vodLink?: string) => {
    if (vodLink && /^https?:\/\//i.test(vodLink)) {
      window.open(vodLink, '_blank')
      return
    }
    navigate(`/movie/${movieId}`)
  }

  const toggleFilter = (type: 'class' | 'area' | 'year') => {
    setActiveFilter((prev) => (prev === type ? null : type))
  }

  return (
    <div className="min-h-screen pb-14">
      <div className="sticky top-0 z-20 bg-slate-950/90 backdrop-blur-md border-b border-cyan-500/20 px-4 py-3 flex items-center">
        <button
          onClick={() => navigate(-1)}
          className="mr-3 text-cyan-300 hover:text-cyan-100"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-lg font-bold truncate text-cyan-100 flex-1">{categoryName}</h1>
        <div className="flex gap-1">
          {FILTER_SORT.map((s) => (
            <button
              key={s.value}
              onClick={() => setSortBy(s.value)}
              className={`px-2 py-1 text-xs rounded-full transition-colors ${
                sortBy === s.value
                  ? 'bg-cyan-500 text-white'
                  : 'glass-card text-cyan-300 hover:text-cyan-100'
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>
      </div>

      {/* 筛选栏 */}
      <div className="sticky top-[49px] z-10 bg-slate-950/80 backdrop-blur-sm border-b border-cyan-500/10 px-4 py-2">
        <div className="flex gap-2">
          <button
            onClick={() => toggleFilter('class')}
            className={`px-3 py-1 text-xs rounded-full transition-colors ${
              classFilter !== '全部' || activeFilter === 'class'
                ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/40'
                : 'glass-card text-cyan-400/70'
            }`}
          >
            类型{classFilter !== '全部' ? `: ${classFilter}` : ''}
          </button>
          <button
            onClick={() => toggleFilter('area')}
            className={`px-3 py-1 text-xs rounded-full transition-colors ${
              areaFilter !== '全部' || activeFilter === 'area'
                ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/40'
                : 'glass-card text-cyan-400/70'
            }`}
          >
            地区{areaFilter !== '全部' ? `: ${areaFilter}` : ''}
          </button>
          <button
            onClick={() => toggleFilter('year')}
            className={`px-3 py-1 text-xs rounded-full transition-colors ${
              yearFilter !== '全部' || activeFilter === 'year'
                ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/40'
                : 'glass-card text-cyan-400/70'
            }`}
          >
            年份{yearFilter !== '全部' ? `: ${yearFilter}` : ''}
          </button>
        </div>

        {/* 展开的筛选面板 */}
        {activeFilter === 'class' && (
          <div className="mt-2 flex flex-wrap gap-2">
            {FILTER_CLASS.map((c) => (
              <button
                key={c}
                onClick={() => { setClassFilter(c); setActiveFilter(null) }}
                className={`px-3 py-1 text-xs rounded-full transition-colors ${
                  classFilter === c
                    ? 'bg-cyan-500 text-white'
                    : 'glass-card text-cyan-400/70 hover:text-cyan-200'
                }`}
              >
                {c}
              </button>
            ))}
          </div>
        )}

        {activeFilter === 'area' && (
          <div className="mt-2 flex flex-wrap gap-2">
            {FILTER_AREA.map((a) => (
              <button
                key={a}
                onClick={() => { setAreaFilter(a); setActiveFilter(null) }}
                className={`px-3 py-1 text-xs rounded-full transition-colors ${
                  areaFilter === a
                    ? 'bg-cyan-500 text-white'
                    : 'glass-card text-cyan-400/70 hover:text-cyan-200'
                }`}
              >
                {a}
              </button>
            ))}
          </div>
        )}

        {activeFilter === 'year' && (
          <div className="mt-2 flex flex-wrap gap-2">
            {FILTER_YEAR.map((y) => (
              <button
                key={y}
                onClick={() => { setYearFilter(y); setActiveFilter(null) }}
                className={`px-3 py-1 text-xs rounded-full transition-colors ${
                  yearFilter === y
                    ? 'bg-cyan-500 text-white'
                    : 'glass-card text-cyan-400/70 hover:text-cyan-200'
                }`}
              >
                {y}
              </button>
            ))}
          </div>
        )}
      </div>

      <main className="px-4 py-4">
        {error && (
          <div className="bg-cyan-500/10 border border-cyan-500/20 rounded-lg p-4 mb-4">
            <p className="text-cyan-400 text-center">{error}</p>
            <button
              onClick={loadMovies}
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
