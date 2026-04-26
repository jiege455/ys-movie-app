import React from 'react'
import { getImageUrl } from '../../api'

/**
 * 电影数据接口
 */
interface MovieProps {
  id: string
  title: string
  poster_path: string
  vote_average: number
  release_date: string
  overview: string
  onClick?: (id: string, vodLink?: string) => void
}

/**
 * 电影卡片组件
 * 用于展示电影的基本信息，包括海报、标题、评分等
 * 支持点击事件，点击后跳转到电影详情页
 * 
 * @param props 电影数据属性
 * @returns 电影卡片React组件
 */
export const MovieCard: React.FC<MovieProps> = ({
  id,
  title,
  poster_path,
  vote_average,
  release_date,
  overview,
  onClick
}) => {
  /**
   * 处理卡片点击事件
   */
  const handleClick = () => {
    if (onClick) {
      onClick(id)
    }
  }

  /**
   * 格式化日期显示
   * @param dateString 日期字符串
   * @returns 格式化后的日期
   */
  const formatDate = (dateString: string) => {
    if (!dateString) return '未知'
    // MacCMS 年份字段已是年份或空字符串
    return dateString
  }

  /**
   * 格式化评分显示
   * @param rating 评分
   * @returns 格式化后的评分
   */
  const formatRating = (rating: number) => {
    if (!rating) return '0.0'
    return rating.toFixed(1)
  }

  return (
    <div 
      className="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow duration-300 cursor-pointer overflow-hidden group"
      onClick={handleClick}
    >
      {/* 电影海报 */}
      <div className="aspect-[2/3] relative overflow-hidden">
        <img
          src={getImageUrl(poster_path)}
          alt={title}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          loading="lazy"
          onError={(e) => {
            // 图片加载失败时的处理
            const target = e.target as HTMLImageElement
            target.src = 'https://via.placeholder.com/300x450?text=No+Image'
          }}
        />
        
        {/* 评分标签 */}
        <div className="absolute top-2 right-2 bg-yellow-500 text-white px-2 py-1 rounded-full text-sm font-bold">
          {formatRating(vote_average)}
        </div>
        
        {/* 悬停遮罩层 */}
        <div className="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all duration-300 flex items-center justify-center">
          <div className="opacity-0 group-hover:opacity-100 transition-opacity duration-300">
            <div className="bg-white bg-opacity-90 rounded-full p-3">
              <svg className="w-8 h-8 text-gray-800" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
            </div>
          </div>
        </div>
      </div>
      
      {/* 电影信息 */}
      <div className="p-4">
        {/* 标题 */}
        <h3 className="font-bold text-lg text-gray-800 mb-2 line-clamp-2">
          {title}
        </h3>
        
        {/* 年份 */}
        <p className="text-sm text-gray-600 mb-2">
          {formatDate(release_date)}
        </p>
        
        {/* 简介 */}
        <p className="text-sm text-gray-700 line-clamp-3">
          {overview || '暂无简介'}
        </p>
      </div>
    </div>
  )
}

export default MovieCard
