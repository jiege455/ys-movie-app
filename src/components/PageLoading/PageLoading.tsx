import React from 'react'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 通用页面加载状态组件
 */
export const PageLoading: React.FC<{ text?: string }> = ({ text = '加载中...' }) => (
  <div className="min-h-screen flex items-center justify-center">
    <div className="flex flex-col items-center gap-4">
      <div className="w-10 h-10 border-4 border-cyan-400/30 border-t-cyan-400 rounded-full animate-spin" />
      <span className="text-cyan-300 text-sm">{text}</span>
    </div>
  </div>
)

export default PageLoading
