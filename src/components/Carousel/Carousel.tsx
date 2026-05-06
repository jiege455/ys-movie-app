import React, { useState, useEffect } from 'react'
import { getImageUrl } from '../../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 首页轮播组件
 * 支持自动轮播与手动切换，兼容 MacCMS 图片地址
 */
interface CarouselProps {
  movies: Array<{
    id: string
    title: string
    poster_path: string
    vote_average: number
    release_date: string
    overview: string
    backdrop_path?: string
    link?: string
  }>
  onMovieClick?: (id: string, vodLink?: string) => void
  autoPlay?: boolean
  interval?: number
}

/**
 * 轮播图组件
 * 用于在首页展示热门电影，支持自动轮播和手动切换
 * 
 * @param props 轮播图属性
 * @returns 轮播图React组件
 */
export const Carousel: React.FC<CarouselProps> = ({
  movies,
  onMovieClick,
  autoPlay = true,
  interval = 5000
}) => {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isAutoPlaying, setIsAutoPlaying] = useState(autoPlay)

  /**
   * 切换到指定索引的图片
   * @param index 目标索引
   */
  const goToSlide = (index: number) => {
    const newIndex = (index + movies.length) % movies.length
    setCurrentIndex(newIndex)
  }

  /**
   * 切换到上一张
   */
  const goToPrevious = () => {
    goToSlide(currentIndex - 1)
  }

  /**
   * 切换到下一张
   */
  const goToNext = () => {
    goToSlide(currentIndex + 1)
  }

  /**
   * 处理轮播图点击事件
   * @param movieId 电影ID
   */
  const handleMovieClick = (movieId: string, vodLink?: string) => {
    if (!onMovieClick) return
    onMovieClick(movieId, vodLink)
  }

  // 自动轮播效果
  useEffect(() => {
    if (!isAutoPlaying || movies.length === 0) return

    const timer = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % movies.length)
    }, interval)

    return () => clearInterval(timer)
  }, [isAutoPlaying, interval, movies.length])

  // 鼠标悬停时暂停自动轮播
  const handleMouseEnter = () => {
    if (autoPlay) {
      setIsAutoPlaying(false)
    }
  }

  const handleMouseLeave = () => {
    if (autoPlay) {
      setIsAutoPlaying(true)
    }
  }

  if (!movies || movies.length === 0) {
    return (
      <div className="w-full h-96 bg-gray-200 rounded-lg flex items-center justify-center">
        <p className="text-gray-500 text-lg">暂无热门电影</p>
      </div>
    )
  }

  const currentMovie = movies[currentIndex]

  return (
    <div 
      className="relative w-full h-96 rounded-lg overflow-hidden shadow-lg"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {/* 背景图片 */}
      <div className="absolute inset-0">
        <img
          src={getImageUrl(currentMovie.backdrop_path || currentMovie.poster_path)}
          alt={currentMovie.title}
          className="w-full h-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-r from-black via-black/50 to-transparent"></div>
      </div>

      {/* 内容区域 */}
      <div className="relative z-10 h-full flex items-center">
        <div className="container mx-auto px-6">
          <div className="max-w-2xl">
            {/* 标题 */}
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-4">
              {currentMovie.title}
            </h2>
            
            {/* 评分和年份 */}
            <div className="flex items-center mb-4">
              <div className="flex items-center mr-6">
                <svg className="w-5 h-5 text-yellow-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                </svg>
                <span className="text-white font-semibold">
                  {currentMovie.vote_average ? currentMovie.vote_average.toFixed(1) : '0.0'}
                </span>
              </div>
              
              <span className="text-gray-300">
                {currentMovie.release_date ? String(currentMovie.release_date).match(/\d{4}/)?.[0] || currentMovie.release_date : ''}
              </span>
            </div>
            
            {/* 简介 */}
            <p className="text-gray-200 text-lg mb-6 line-clamp-3">
              {currentMovie.overview}
            </p>
            
            {/* 播放按钮 */}
            <button
              onClick={() => handleMovieClick(currentMovie.id, currentMovie.link)}
              className="bg-red-600 hover:bg-red-700 text-white px-8 py-3 rounded-lg font-semibold transition-colors duration-300 flex items-center"
            >
              <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
              立即播放
            </button>
          </div>
        </div>
      </div>

      {/* 导航按钮 */}
      <button
        onClick={goToPrevious}
        className="absolute left-4 top-1/2 transform -translate-y-1/2 bg-black bg-opacity-50 hover:bg-opacity-75 text-white p-2 rounded-full transition-all duration-300"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      <button
        onClick={goToNext}
        className="absolute right-4 top-1/2 transform -translate-y-1/2 bg-black bg-opacity-50 hover:bg-opacity-75 text-white p-2 rounded-full transition-all duration-300"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
        </svg>
      </button>

      {/* 指示器 */}
      <div className="absolute bottom-4 left-1/2 transform -translate-x-1/2 flex space-x-2">
        {movies.map((_, index) => (
          <button
            key={index}
            onClick={() => goToSlide(index)}
            className={`w-3 h-3 rounded-full transition-all duration-300 ${
              index === currentIndex 
                ? 'bg-white' 
                : 'bg-white bg-opacity-50 hover:bg-opacity-75'
            }`}
          />
        ))}
      </div>
    </div>
  )
}

export default Carousel
