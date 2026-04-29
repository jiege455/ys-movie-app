import { AppRoutes } from './routes/AppRoutes'
import { ThemeProvider } from './contexts/ThemeContext'

/**
 * 应用主组件
 * 负责渲染整个应用的路由系统，并集成主题切换功能
 *
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * @returns 应用主组件
 */
export default function App() {
  /**
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 作用：应用根组件，渲染路由与底部导航，移动端优先布局
   * 主题：使用 ThemeProvider 统一管理主题状态
   */
  return (
    <ThemeProvider>
      <div className="min-h-screen transition-colors duration-300">
        <AppRoutes />
      </div>
    </ThemeProvider>
  )
}
