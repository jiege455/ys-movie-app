import { AppRoutes } from './routes/AppRoutes'

/**
 * 应用主组件
 * 负责渲染整个应用的路由系统
 *
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * @returns 应用主组件
 */
export default function App() {
  /**
   * 开发者：杰哥网络科技 (qq: 2711793818)
   * 作用：应用根组件，渲染路由与底部导航，移动端优先布局
   */
  return (
    <div className="min-h-screen">
      <AppRoutes />
    </div>
  )
}
