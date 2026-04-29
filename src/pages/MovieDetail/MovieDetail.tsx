import React, { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getMovieDetail, getImageUrl } from '../../api'
import { useMovieStore } from '../../store/movieStore'
import { useTheme } from '../../contexts/ThemeContext'
import { FavoriteButton } from '../../components/FavoriteButton/FavoriteButton'
import { CommentSection } from '../../components/CommentSection/CommentSection'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 电影详情页组件
 * 展示电影的详细信息，包括简介、演员表、制作人员等
 * 提供播放按钮跳转到播放页面
 */
export const MovieDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { isDark } = useTheme()
  const { currentMovie, setCurrentMovie } = useMovieStore()
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // 本地类型定义（与全局 Store 结构保持一致）
  type Genre = { id: number; name: string }
  type Cast = { name: string; character: string }
  type Crew = { name: string; job: string }
  type CurrentMovie = {
    id: string
    title: string
    poster_path: string
    vote_average: number
    release_date: string
    overview: string
    runtime?: number
    genres?: Genre[]
    cast?: Cast[]
    crew?: Crew[]
  }

  /**
   * 组件挂载时加载电影详情
   */
  useEffect(() => {
    if (id) {
      loadMovieData(id)
    }
  }, [id])

  /**
   * 加载电影数据
   * @param movieId 电影ID
   */
  const loadMovieData = async (movieId: string) => {
    try {
      setLoading(true)
      setError(null)
      const detail = await getMovieDetail(movieId)
      if (!detail) {
        setError('未找到该视频信息')
        setCurrentMovie(null)
        return
      }
      setCurrentMovie(detail as CurrentMovie)
    } catch (err) {
      console.error('加载电影数据失败:', err)
      setError('加载视频详情失败，请检查网络连接')
      setCurrentMovie(null)
    } finally {
      setLoading(false)
    }
  }

  /**
   * 处理播放按钮点击事件
   */
  const handlePlayClick = () => {
    if (id) {
      navigate(`/player/${id}`)
    }
  }

  /**
   * 处理返回按钮点击事件
   */
  const handleBackClick = () => {
    navigate(-1)
  }

  /**
   * 格式化电影时长
   * @param minutes 分钟数
   * @returns 格式化后的时长字符串
   */
  const formatRuntime = (minutes: number) => {
    if (!minutes) return '未知'
    const hours = Math.floor(minutes / 60)
    const mins = minutes % 60
    return hours > 0 ? `${hours}小时${mins}分钟` : `${mins}分钟`
  }

  /**
   * 格式化日期
   * @param dateString 日期字符串
   * @returns 格式化后的日期
   */
  const formatDate = (dateString: string) => {
    if (!dateString) return '未知'
    // MacCMS返回的是年份字符串，直接返回或提取年份
    const yearMatch = String(dateString).match(/\d{4}/)
    if (yearMatch) return yearMatch[0]
    return dateString
  }

  if (loading) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${isDark ? 'bg-gray-900' : 'bg-gray-50'}`}>
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600 mx-auto mb-4"></div>
          <p className={isDark ? 'text-gray-400' : 'text-gray-600'}>加载中...</p>
        </div>
      </div>
    )
  }

  if (error || !currentMovie) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${isDark ? 'bg-gray-900' : 'bg-gray-50'}`}>
        <div className="text-center">
          <p className={`mb-4 ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>{error || '电影信息不存在'}</p>
          <button
            onClick={handleBackClick}
            className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors mr-2"
          >
            返回
          </button>
          {error && (
            <button
              onClick={() => id && loadMovieData(id)}
              className="bg-gray-600 hover:bg-gray-700 text-white px-6 py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className={`min-h-screen ${isDark ? 'bg-gray-900' : 'bg-gray-50'}`}>
      {/* 头部导航 */}
      <header className={`shadow-sm ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center">
            <button
              onClick={handleBackClick}
              className={`flex items-center mr-4 ${isDark ? 'text-gray-300 hover:text-white' : 'text-gray-600 hover:text-gray-800'}`}
            >
              <svg className="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
              返回
            </button>
            <h1 className={`text-xl font-bold ${isDark ? 'text-white' : 'text-gray-800'}`}>电影详情</h1>
          </div>
        </div>
      </header>

      {/* 主要内容 */}
      <main className="container mx-auto px-4 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* 左侧：电影海报 */}
          <div className="lg:col-span-1">
            <div className={`rounded-lg shadow-lg overflow-hidden ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
              <img
                src={getImageUrl(currentMovie.poster_path)}
                alt={currentMovie.title}
                className="w-full h-auto object-cover"
                onError={(e) => {
                  const target = e.target as HTMLImageElement
                  target.src = 'https://via.placeholder.com/500x750?text=No+Image'
                }}
              />
            </div>
          </div>

          {/* 右侧：电影信息 */}
          <div className="lg:col-span-2">
            <div className={`rounded-lg shadow-lg p-6 ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
              {/* 标题和评分 */}
              <div className="flex items-start justify-between mb-4">
                <div>
                  <h1 className={`text-3xl font-bold mb-2 ${isDark ? 'text-white' : 'text-gray-800'}`}>
                    {currentMovie.title}
                  </h1>
                  <div className={`flex items-center space-x-4 text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                    <span>上映时间: {formatDate(currentMovie.release_date)}</span>
                    {currentMovie.runtime && (
                      <span>片长: {formatRuntime(currentMovie.runtime)}</span>
                    )}
                  </div>
                </div>

                <div className="flex items-center bg-yellow-500 text-white px-3 py-1 rounded-full">
                  <svg className="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                  <span className="font-bold">
                    {currentMovie.vote_average ? currentMovie.vote_average.toFixed(1) : '0.0'}
                  </span>
                </div>
              </div>

              {/* 类型标签 */}
              {currentMovie.genres && currentMovie.genres.length > 0 && (
                <div className="mb-6">
                  <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-800'}`}>类型</h3>
                  <div className="flex flex-wrap gap-2">
                    {currentMovie.genres.map((genre) => (
                      <span
                        key={genre.id}
                        className="bg-red-100 text-red-800 px-3 py-1 rounded-full text-sm"
                      >
                        {genre.name}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* 剧情简介 */}
              <div className="mb-6">
                <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-800'}`}>剧情简介</h3>
                <p className={`leading-relaxed ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>
                  {currentMovie.overview || '暂无简介'}
                </p>
              </div>

              {/* 演员表 */}
              {currentMovie.cast && currentMovie.cast.length > 0 && (
                <div className="mb-6">
                  <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-800'}`}>主要演员</h3>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {currentMovie.cast.slice(0, 6).map((actor, index) => (
                      <div key={index} className="flex items-center space-x-3">
                        <div className={`w-12 h-12 rounded-full flex items-center justify-center ${isDark ? 'bg-gray-700' : 'bg-gray-200'}`}>
                          <svg className="w-6 h-6 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
                          </svg>
                        </div>
                        <div>
                          <p className={`font-medium ${isDark ? 'text-gray-200' : 'text-gray-800'}`}>{actor.name}</p>
                          <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>{actor.character}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* 制作人员 */}
              {currentMovie.crew && currentMovie.crew.length > 0 && (
                <div className="mb-6">
                  <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-800'}`}>制作团队</h3>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {currentMovie.crew.slice(0, 4).map((member, index) => (
                      <div key={index} className="flex items-center space-x-3">
                        <div className={`w-12 h-12 rounded-full flex items-center justify-center ${isDark ? 'bg-gray-700' : 'bg-gray-200'}`}>
                          <svg className="w-6 h-6 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
                          </svg>
                        </div>
                        <div>
                          <p className={`font-medium ${isDark ? 'text-gray-200' : 'text-gray-800'}`}>{member.name}</p>
                          <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>{member.job}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* 播放按钮 */}
              <div className="flex space-x-4">
                <button
                  onClick={handlePlayClick}
                  className="bg-red-600 hover:bg-red-700 text-white px-8 py-3 rounded-lg font-semibold transition-colors duration-300 flex items-center"
                >
                  <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                  </svg>
                  立即播放
                </button>

                <FavoriteButton vodId={id || ''} />
              </div>
            </div>
          </div>
        </div>

        {/* 评论区域 */}
        {id && <CommentSection vodId={id} />}
      </main>
    </div>
  )
}

export default MovieDetail
