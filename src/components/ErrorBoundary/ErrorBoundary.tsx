import React from 'react'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 全局错误边界组件
 * 职责：捕获子组件渲染期间的 JavaScript 错误，防止整个应用崩溃
 */

interface Props {
  children: React.ReactNode
  fallback?: React.ReactNode
}

interface State {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('[ErrorBoundary] 捕获到错误:', error.message)
    console.error('[ErrorBoundary] 组件栈:', errorInfo.componentStack)
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null })
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback

      return (
        <div className="min-h-screen flex items-center justify-center px-4">
          <div className="text-center max-w-md">
            <h1 className="text-3xl font-bold text-cyan-400 mb-4">页面异常</h1>
            <p className="text-cyan-300/70 mb-2">抱歉，页面发生了意外错误</p>
            {this.state.error && (
              <p className="text-red-400 text-sm mb-6 bg-red-400/10 rounded-lg p-3 break-all">
                {this.state.error.message}
              </p>
            )}
            <button
              onClick={this.handleRetry}
              className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors"
            >
              重新加载
            </button>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}

export default ErrorBoundary
