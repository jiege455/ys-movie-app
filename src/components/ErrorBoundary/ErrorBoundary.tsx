import React, { Component, type ReactNode } from 'react'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 错误边界组件
 * 捕获子组件渲染错误，防止整个应用白屏
 */

interface Props {
  children: ReactNode
  fallback?: ReactNode
}

interface State {
  hasError: boolean
  error?: Error
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary 捕获到错误:', error, errorInfo)
  }

  handleReset = () => {
    this.setState({ hasError: false, error: undefined })
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback
      }

      return (
        <div className="min-h-screen flex items-center justify-center  px-4">
          <div className="text-center">
            <svg
              className="mx-auto h-16 w-16 text-cyan-400/30 mb-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.5}
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
            <h2 className="text-xl font-bold text-cyan-100 mb-2">
              页面出错了
            </h2>
            <p className="text-cyan-400/60 mb-6">
              抱歉，页面加载时遇到了问题
            </p>
            <button
              onClick={this.handleReset}
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
