import React from 'react'
import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom'
import { Home, MovieDetail, Player, Topic, Category, Login, Profile } from '../pages'
import { TabBar } from '../components/TabBar/TabBar'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 应用路由配置组件
 * 定义所有页面路由和对应的组件
 */

/**
 * 底部导航包装器
 * 在播放页和详情页隐藏TabBar
 */
const TabBarWrapper: React.FC = () => {
  const location = useLocation()
  const hideTabBarPaths = ['/player/', '/movie/', '/login']
  const shouldHide = hideTabBarPaths.some(path => location.pathname.startsWith(path))

  if (shouldHide) return null
  return <TabBar />
}

export const AppRoutes: React.FC = () => {
  return (
    <Router>
      <div className="pb-14">
        <Routes>
          {/* 首页 */}
          <Route path="/" element={<Home />} />

          {/* 详情与播放器（不显示底部导航） */}
          <Route path="/movie/:id" element={<MovieDetail />} />
          <Route path="/player/:id" element={<Player />} />

          {/* 用户相关页面 */}
          <Route path="/login" element={<Login />} />
          <Route path="/profile" element={<Profile />} />

          {/* 发现/分类/我的（暂用首页占位） */}
          <Route path="/discover" element={<Home />} />
          {/* 专题页面：仅显示自定义名称 */}
          <Route path="/topic" element={<Topic />} />
          <Route path="/categories" element={<Home />} />
          <Route path="/category/:id" element={<Category />} />

          {/* 404 */}
          <Route path="*" element={<Home />} />
        </Routes>
        {/* 底部TabBar，播放页和详情页自动隐藏 */}
        <TabBarWrapper />
      </div>
    </Router>
  )
}

export default AppRoutes
