import React, { useState, useEffect, useCallback } from 'react'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 首页轮播组件
 * 支持自动轮播与手动切换，兼容 MacCMS 图片地址
 */

interface CarouselMovie {
  id: string
  title: string
  poster_path: string
  vote_average: number
  release_date: string
  overview: string
  backdrop_path?: string
  link?: string
}

interface CarouselProps {
  movies: CarouselMovie[]
  onMovieClick: (movieId: string, vodLink?: string) => void
  autoPlay?: boolean
  interval?: number
}

export const Carousel: React.FC<CarouselProps> = ({
  movies,
  onMovieClick,
  autoPlay = true,
  interval = 5000
}) => {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isAutoPlaying, setIsAutoPlaying] = useState(autoPlay)

  const goToNext = useCallback(() => {
    setCurrentIndex((prev) => (prev + 1) % movies.length)
  }, [movies.length])

  const goToPrev = useCallback(() => {
    setCurrentIndex((prev) => (prev - 1 + movies.length) % movies.length)
  }, [movies.length])

  const goToSlide = (index: number) => {
    setCurrentIndex(index)
  }

  useEffect(() => {
    if (!isAutoPlaying || movies.length <= 1) return

    const timer = setInterval(goToNext, interval)
    return () => clearInterval(timer)
  }, [isAutoPlaying, interval, goToNext, movies.length])

  const handleMouseEnter = () => setIsAutoPlaying(false)
  const handleMouseLeave = () => setIsAutoPlaying(autoPlay)

  if (movies.length === 0) return null

  const currentMovie = movies[currentIndex]

  return (
    <div
      className="relative w-full overflow-hidden rounded-xl shadow-lg"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {/* 轮播内容 */}
      <div className="relative aspect-[16/9] glass-light">
        <img
          src={currentMovie.backdrop_path || currentMovie.poster_path}
          alt={currentMovie.title}
          className="w-full h-full object-cover"
          onError={(e) => {
            const target = e.target as HTMLImageElement
            target.src = 'https://via.placeholder.com/800x450?text=No+Image'
          }}
        />

        {/* 渐变遮罩 */}
        <div className="absolute inset-0 bg-gradient-to-t from-[#0a0e1a] via-transparent to-transparent" />

        {/* 电影信息 */}
        <div className="absolute bottom-0 left-0 right-0 p-4">
          <h3
            className="text-white text-xl font-bold mb-1 cursor-pointer hover:text-cyan-400 transition-colors"
            onClick={() => onMovieClick(currentMovie.id, currentMovie.link)}
          >
            {currentMovie.title}
          </h3>
          <div className="flex items-center space-x-3 text-sm text-cyan-300">
            <span className="flex items-center">
              <span className="text-cyan-400 mr-1">★</span>
              {currentMovie.vote_average.toFixed(1)}
            </span>
            <span>{currentMovie.release_date}</span>
          </div>
        </div>
      </div>

      {/* 导航按钮 */}
      {movies.length > 1 && (
        <>
          <button
            onClick={goToPrev}
            className="absolute left-2 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full glass text-white flex items-center justify-center hover:bg-cyan-500/50 transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <button
            onClick={goToNext}
            className="absolute right-2 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full glass text-white flex items-center justify-center hover:bg-cyan-500/50 transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </button>

          {/* 指示器 */}
          <div className="absolute bottom-4 right-4 flex space-x-2">
            {movies.map((_, index) => (
              <button
                key={index}
                onClick={() => goToSlide(index)}
                className={`w-2 h-2 rounded-full transition-colors ${
                  index === currentIndex ? 'bg-cyan-400' : 'bg-cyan-400/30'
                }`}
              />
            ))}
          </div>
        </>
      )}
    </div>
  )
}

export default Carousel
