import React, { useEffect, useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAppPageSetting, getHotMovies } from '../../api'
import { MovieCard } from '../../components/MovieCard/MovieCard'
import type { Movie } from '../../types'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 专题页面
 * 动态读取插件后台页面设置，展示可自定义的专题名�? */

export const Topic: React.FC = () => {
  const navigate = useNavigate()
  const [topicName, setTopicName] = useState('专题')
  const [movies, setMovies] = useState<Movie[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const isMountedRef = useRef(true)
  const abortRef = useRef<AbortController | null>(null)

  useEffect(() => {
    loadTopicData()
    return () => {
      isMountedRef.current = false
      abortRef.current?.abort()
    }
  }, [])

  const loadTopicData = async () => {
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller
    try {
      setLoading(true)
      setError(null)
      const setting = await getAppPageSetting()
      if (!isMountedRef.current || controller.signal.aborted) return
      if (setting?.app_tab_topic_name) {
        setTopicName(setting.app_tab_topic_name)
      }
      // �����ߣ��ܸ�����Ƽ� (qq: 2711793818)
      // �޸�������ר��ӰƬ���ݣ�����ר��ר��API��ʹ������ӰƬ��Ϊ���ˣ�
      if (!isMountedRef.current || controller.signal.aborted) return
      try {
        const topicMovies = await getHotMovies(1)
        if (isMountedRef.current && !controller.signal.aborted) {
          setMovies(topicMovies)
        }
      } catch {
        if (isMountedRef.current && !controller.signal.aborted) {
          setMovies([])
        }
      }
    } catch {
      if (controller.signal.aborted) return
      if (isMountedRef.current) {
        setError('加载专题数据失败')
      }
    } finally {
      if (isMountedRef.current && !controller.signal.aborted) {
        setLoading(false)
      }
    }
  }

  const handleMovieClick = (movieId: string) => {
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
        <h1 className="text-lg font-bold truncate text-cyan-100">{topicName}</h1>
      </div>

      {/* 专题内容 */}
      <main className="px-4 py-4">
        {error && (
          <div className="bg-cyan-500/10 border border-cyan-500/20 rounded-lg p-4 mb-4">
            <p className="text-cyan-400 text-center">{error}</p>
            <button
              onClick={loadTopicData}
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
                <p className="text-cyan-400/60">暂无专题内容</p>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}

export default Topic
