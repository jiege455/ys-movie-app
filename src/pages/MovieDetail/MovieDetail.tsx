import React, { useEffect, useState, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getMovieDetail } from '../../api'
import { CommentSection } from '../../components/CommentSection/CommentSection'
import { FavoriteButton } from '../../components/FavoriteButton/FavoriteButton'
import { useMovieStore } from '../../store/movieStore'
import { usePlayerStore } from '../../store/playerStore'
import type { MovieDetail as MovieDetailType, VodEpisode } from '../../api/vod'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 电影详情页
 * 展示电影详细信息、播放按钮、收藏、评论等
 */

export const MovieDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { currentMovie, setCurrentMovie, loading, setLoading } = useMovieStore()
  const { setCurrentEpisode } = usePlayerStore()
  const [error, setError] = useState<string | null>(null)
  const [movieData, setMovieData] = useState<MovieDetailType | null>(null)
  const isMountedRef = useRef(true)

  useEffect(() => {
    if (id) {
      loadMovieData(id)
    }
    return () => {
      isMountedRef.current = false
    }
  }, [id])

  const loadMovieData = async (movieId: string) => {
    try {
      setLoading(true)
      setError(null)
      const data = await getMovieDetail(movieId)
      if (isMountedRef.current) {
        setMovieData(data)
        if (data) {
          setCurrentMovie(data)
        }
      }
    } catch (err) {
      if (isMountedRef.current) {
        setError('加载电影信息失败')
      }
    } finally {
      if (isMountedRef.current) {
        setLoading(false)
      }
    }
  }

  const handlePlayClick = (episodeIndex: number = 0) => {
    setCurrentEpisode(episodeIndex)
    navigate(`/player/${id}`)
  }

  const handleBackClick = () => {
    navigate(-1)
  }

  // 获取所有剧集（从所有播放源中收集）
  const getAllEpisodes = (): VodEpisode[] => {
    if (!movieData?.vod_play_list) return []
    const episodes: VodEpisode[] = []
    movieData.vod_play_list.forEach(source => {
      if (source.urls) {
        episodes.push(...source.urls)
      }
    })
    return episodes
  }

  const episodes = getAllEpisodes()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600 mx-auto mb-4"></div>
          <p className="text-gray-600">加载中...</p>
        </div>
      </div>
    )
  }

  if (error || !movieData) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <p className="text-gray-600 mb-4">{error || '电影信息不存在'}</p>
          <button
            onClick={handleBackClick}
            className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors mr-2"
          >
            返回
          </button>
          {error && (
            <button
              onClick={() => id && loadMovieData(id)}
              className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen pb-20 bg-white">
      {/* 顶部导航 */}
      <div className="sticky top-0 z-10 border-b px-4 py-3 flex items-center shadow-sm bg-white border-gray-200">
        <button
          onClick={handleBackClick}
          className="mr-3 text-gray-700 hover:text-gray-900"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-lg font-bold truncate text-gray-900">{movieData.title}</h1>
      </div>

      <div className="px-4 py-4">
        {/* 海报与基本信息 */}
        <div className="flex gap-4 mb-6">
          <div className="w-32 flex-shrink-0">
            <div className="relative aspect-[2/3] rounded-lg overflow-hidden shadow-lg bg-gray-200">
              <img
                src={movieData.poster_path || 'https://via.placeholder.com/300x450?text=No+Image'}
                alt={movieData.title}
                className="w-full h-full object-cover"
                onError={(e) => {
                  const target = e.target as HTMLImageElement
                  target.src = 'https://via.placeholder.com/300x450?text=No+Image'
                }}
              />
            </div>
          </div>

          <div className="flex-1 min-w-0">
            <h2 className="text-xl font-bold mb-2 text-gray-900">{movieData.title}</h2>

            {movieData.vote_average > 0 && (
              <div className="flex items-center mb-2">
                <span className="text-yellow-500 mr-1">★</span>
                <span className="text-sm text-gray-600">{movieData.vote_average.toFixed(1)}</span>
              </div>
            )}

            {movieData.release_date && (
              <p className="text-sm text-gray-500 mb-1">
                上映: {movieData.release_date}
              </p>
            )}

            {/* 操作按钮 */}
            <div className="flex gap-2 mt-3">
              <button
                onClick={() => handlePlayClick(0)}
                className="flex-1 bg-red-600 hover:bg-red-700 text-white py-2 rounded-lg transition-colors font-medium text-sm"
              >
                立即播放
              </button>
              <FavoriteButton vodId={movieData.id} />
            </div>
          </div>
        </div>

        {/* 剧情简介 */}
        {movieData.overview && (
          <div className="mb-6">
            <h3 className="text-lg font-semibold mb-2 text-gray-800">剧情简介</h3>
            <p className="text-sm text-gray-600 leading-relaxed">
              {movieData.overview}
            </p>
          </div>
        )}

        {/* 播放列表 */}
        {episodes.length > 0 && (
          <div className="mb-6">
            <h3 className="text-lg font-semibold mb-3 text-gray-800">选集播放</h3>
            <div className="grid grid-cols-4 gap-2">
              {episodes.map((episode, index) => (
                <button
                  key={index}
                  onClick={() => handlePlayClick(index)}
                  className="bg-gray-100 hover:bg-red-100 hover:text-red-600 py-2 rounded-lg text-sm transition-colors text-gray-700"
                >
                  {episode.name || `第${index + 1}集`}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* 评论区 */}
        <div className="border-t border-gray-200 pt-6">
          <CommentSection vodId={movieData.id} />
        </div>
      </div>
    </div>
  )
}

export default MovieDetail
