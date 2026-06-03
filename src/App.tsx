import React from 'react'
import { ErrorBoundary } from './components/ErrorBoundary/ErrorBoundary'
import { AppRoutes } from './routes/AppRoutes'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 应用根组件
 * 说明：最外层容器，包裹全局错误边界和路由
 */
const App: React.FC = () => {
  return (
    <ErrorBoundary>
      <AppRoutes />
    </ErrorBoundary>
  )
}

export default App
