import React, { useEffect, useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAppPageSetting, AppPageSetting } from '../../api'
import { MovieCard } from '../../components/MovieCard/MovieCard'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 专题页面
 * 动态读取插件后台页面设置，展示可自定义的专题名称
 */

export const Topic: React.FC = () => {
  const navigate = useNavigate()
  const [topicName, setTopicName] = useState('专题')
  const [movies, setMovies] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const isMountedRef = useRef(true)

  useEffect(() => {
    loadTopicData()
    return () => {
      isMountedRef.current = false
    }
  }, [])

  const loadTopicData = async () => {
    try {
      setLoading(true)
      setError(null)
      const setting = await getAppPageSetting()
      if (isMountedRef.current) {
        if (setting?.app_tab_topic_name) {
          setTopicName(setting.app_tab_topic_name)
        }
        // 专题数据暂时为空，后续可从API获取
        setMovies([])
      }
    } catch (e) {
      if (isMountedRef.current) {
        setError('加载专题数据失败')
      }
    } finally {
      if (isMountedRef.current) {
        setLoading(false)
      }
    }
  }

  const handleMovieClick = (movieId: string) => {
    navigate(`/movie/${movieId}`)
  }

  return (
    <div className="min-h-screen pb-14 bg-white">
      {/* 顶部导航 */}
      <div className="sticky top-0 z-10 border-b px-4 py-3 flex items-center shadow-sm bg-white border-gray-200">
        <button
          onClick={() => navigate(-1)}
          className="mr-3 text-gray-700 hover:text-gray-900"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-lg font-bold truncate text-gray-900">{topicName}</h1>
      </div>

      {/* 专题内容 */}
      <main className="px-4 py-4">
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
            <p className="text-red-600 text-center">{error}</p>
            <button
              onClick={loadTopicData}
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
                <p className="text-gray-500">暂无专题内容</p>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}

export default Topic
