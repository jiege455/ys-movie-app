import React, { Suspense, lazy } from 'react'
import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom'
import { TabBar } from '../components/TabBar/TabBar'
import { PageLoading } from '../components/PageLoading/PageLoading'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 应用路由配置组件
 * 使用 React.lazy + Suspense 实现代码分割，按需加载页面模块
 */

const Home = lazy(() => import('../pages/Home/Home'))
const MovieDetail = lazy(() => import('../pages/MovieDetail/MovieDetail'))
const Player = lazy(() => import('../pages/Player/Player'))
const Login = lazy(() => import('../pages/Login/Login'))
const Profile = lazy(() => import('../pages/Profile/Profile'))
const MessageCenter = lazy(() => import('../pages/MessageCenter/MessageCenter'))
const Search = lazy(() => import('../pages/Search/Search'))
const Topic = lazy(() => import('../pages/Topic/Topic'))
const Category = lazy(() => import('../pages/Category/Category'))
const CategoriesPage = lazy(() => import('../pages/Categories/CategoriesPage'))
const DiscoverPage = lazy(() => import('../pages/Discover/DiscoverPage'))

const HIDDEN_TABBAR_PATHS = ['/player/', '/movie/', '/login', '/messages', '/search']

const TabBarWrapper: React.FC = () => {
  const location = useLocation()
  const shouldHide = HIDDEN_TABBAR_PATHS.some(path => location.pathname.startsWith(path))
  if (shouldHide) return null
  return <TabBar />
}

const NotFoundPage: React.FC = () => (
  <div className="min-h-screen flex items-center justify-center px-4">
    <div className="text-center">
      <h1 className="text-6xl font-bold text-cyan-400 mb-4">404</h1>
      <p className="text-cyan-300 mb-6">页面未找到</p>
      <a href="/" className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors inline-block">
        返回首页
      </a>
    </div>
  </div>
)

export const AppRoutes: React.FC = () => {
  return (
    <Router>
      <div className="pb-14">
        <Suspense fallback={<PageLoading />}>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/movie/:id" element={<MovieDetail />} />
            <Route path="/player/:id" element={<Player />} />
            <Route path="/login" element={<Login />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/messages" element={<MessageCenter />} />
            <Route path="/search" element={<Search />} />
            <Route path="/discover" element={<DiscoverPage />} />
            <Route path="/topic" element={<Topic />} />
            <Route path="/categories" element={<CategoriesPage />} />
            <Route path="/category/:id" element={<Category />} />
            <Route path="*" element={<NotFoundPage />} />
          </Routes>
        </Suspense>
        <TabBarWrapper />
      </div>
    </Router>
  )
}

export default AppRoutes
