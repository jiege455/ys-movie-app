import React, { useEffect, useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  getMessages,
  getMessageSummary,
  markMessageAsRead,
  markAllMessagesAsRead,
  deleteMessage,
  Message,
  MessageSummary
} from '../../api'
import { useTheme } from '../../contexts/ThemeContext'
import { checkLoggedIn } from '../../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 消息中心页面
 * 展示系统消息、通知，支持标记已读和删除
 */

export const MessageCenter: React.FC = () => {
  const navigate = useNavigate()
  const { isDark } = useTheme()
  const [messages, setMessages] = useState<Message[]>([])
  const [summary, setSummary] = useState<MessageSummary>({ total: 0, unread: 0 })
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(1)
  const [hasMore, setHasMore] = useState(true)

  /**
   * 加载消息列表
   */
  const loadMessages = useCallback(async (pageNum: number = 1) => {
    if (!checkLoggedIn()) return
    setLoading(true)
    try {
      const [msgList, msgSummary] = await Promise.all([
        getMessages(pageNum, 20),
        getMessageSummary()
      ])
      if (pageNum === 1) {
        setMessages(msgList)
      } else {
        setMessages(prev => [...prev, ...msgList])
      }
      setSummary(msgSummary)
      setHasMore(msgList.length === 20)
    } catch (error) {
      console.error('加载消息失败:', error)
    } finally {
      setLoading(false)
    }
  }, [])

  /**
   * 初始加载
   */
  useEffect(() => {
    if (!checkLoggedIn()) {
      setLoading(false)
      return
    }
    loadMessages(1)
  }, [loadMessages])

  /**
   * 标记单条消息为已读
   */
  const handleMarkAsRead = async (messageId: string) => {
    const success = await markMessageAsRead(messageId)
    if (success) {
      setMessages(prev =>
        prev.map(msg =>
          msg.id === messageId ? { ...msg, isRead: true } : msg
        )
      )
      setSummary(prev => ({
        ...prev,
        unread: Math.max(0, prev.unread - 1)
      }))
    }
  }

  /**
   * 标记所有消息为已读
   */
  const handleMarkAllAsRead = async () => {
    const success = await markAllMessagesAsRead()
    if (success) {
      setMessages(prev =>
        prev.map(msg => ({ ...msg, isRead: true }))
      )
      setSummary(prev => ({ ...prev, unread: 0 }))
    }
  }

  /**
   * 删除消息
   */
  const handleDelete = async (messageId: string) => {
    if (!confirm('确定要删除这条消息吗？')) return
    const success = await deleteMessage(messageId)
    if (success) {
      setMessages(prev => prev.filter(msg => msg.id !== messageId))
      setSummary(prev => ({
        ...prev,
        total: Math.max(0, prev.total - 1)
      }))
    }
  }

  /**
   * 加载更多
   */
  const handleLoadMore = () => {
    const nextPage = page + 1
    setPage(nextPage)
    loadMessages(nextPage)
  }

  /**
   * 格式化时间
   */
  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp > 1e12 ? timestamp : timestamp * 1000)
    const now = new Date()
    const diff = now.getTime() - date.getTime()
    const days = Math.floor(diff / (1000 * 60 * 60 * 24))

    if (days === 0) {
      const hours = Math.floor(diff / (1000 * 60 * 60))
      if (hours === 0) {
        const minutes = Math.floor(diff / (1000 * 60))
        return minutes <= 0 ? '刚刚' : `${minutes}分钟前`
      }
      return `${hours}小时前`
    }
    if (days === 1) return '昨天'
    if (days < 7) return `${days}天前`
    return date.toLocaleDateString('zh-CN')
  }

  /**
   * 获取消息类型图标和颜色
   */
  const getMessageTypeStyle = (type: string) => {
    switch (type) {
      case 'system':
        return { icon: '🔔', color: 'bg-blue-100 text-blue-600' }
      case 'notice':
        return { icon: '📢', color: 'bg-yellow-100 text-yellow-600' }
      case 'activity':
        return { icon: '🎉', color: 'bg-red-100 text-red-600' }
      default:
        return { icon: '📨', color: 'bg-gray-100 text-gray-600' }
    }
  }

  if (!checkLoggedIn()) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${isDark ? 'bg-gray-900' : 'bg-gray-50'}`}>
        <div className="text-center">
          <p className={`mb-4 ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>请先登录后查看消息</p>
          <button
            onClick={() => navigate('/login')}
            className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors"
          >
            去登录
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className={`min-h-screen ${isDark ? 'bg-gray-900' : 'bg-gray-50'}`}>
      {/* 头部 */}
      <header className={`sticky top-0 z-10 shadow-sm ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
        <div className="max-w-4xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center">
              <button
                onClick={() => navigate(-1)}
                className={`mr-4 ${isDark ? 'text-gray-300 hover:text-white' : 'text-gray-600 hover:text-gray-800'}`}
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                </svg>
              </button>
              <h1 className={`text-xl font-bold ${isDark ? 'text-white' : 'text-gray-800'}`}>
                消息中心
                {summary.unread > 0 && (
                  <span className="ml-2 bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">
                    {summary.unread}
                  </span>
                )}
              </h1>
            </div>
            {summary.unread > 0 && (
              <button
                onClick={handleMarkAllAsRead}
                className="text-red-600 hover:text-red-700 text-sm font-medium"
              >
                全部已读
              </button>
            )}
          </div>
        </div>
      </header>

      {/* 消息列表 */}
      <main className="max-w-4xl mx-auto px-4 py-4">
        {loading && messages.length === 0 ? (
          <div className="flex justify-center items-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600"></div>
          </div>
        ) : messages.length === 0 ? (
          <div className="text-center py-12">
            <svg className="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
            </svg>
            <p className={`text-lg ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>暂无消息</p>
          </div>
        ) : (
          <div className="space-y-3">
            {messages.map((message) => {
              const typeStyle = getMessageTypeStyle(message.type)
              return (
                <div
                  key={message.id}
                  className={`rounded-lg p-4 transition-all ${
                    message.isRead
                      ? isDark ? 'bg-gray-800' : 'bg-white'
                      : isDark ? 'bg-gray-700 border-l-4 border-red-500' : 'bg-white border-l-4 border-red-500 shadow-sm'
                  }`}
                >
                  <div className="flex items-start space-x-3">
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center text-lg ${typeStyle.color}`}>
                      {typeStyle.icon}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-1">
                        <h3 className={`font-semibold truncate ${isDark ? 'text-white' : 'text-gray-800'}`}>
                          {!message.isRead && (
                            <span className="inline-block w-2 h-2 bg-red-500 rounded-full mr-2"></span>
                          )}
                          {message.title}
                        </h3>
                        <span className={`text-xs whitespace-nowrap ml-2 ${isDark ? 'text-gray-500' : 'text-gray-400'}`}>
                          {formatTime(message.createTime)}
                        </span>
                      </div>
                      <p className={`text-sm mb-2 ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                        {message.content}
                      </p>
                      <div className="flex items-center space-x-3">
                        {!message.isRead && (
                          <button
                            onClick={() => handleMarkAsRead(message.id)}
                            className="text-red-600 hover:text-red-700 text-sm font-medium"
                          >
                            标记已读
                          </button>
                        )}
                        {message.link && (
                          <a
                            href={message.link}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-blue-600 hover:text-blue-700 text-sm"
                          >
                            查看详情 →
                          </a>
                        )}
                        <button
                          onClick={() => handleDelete(message.id)}
                          className={`text-sm ${isDark ? 'text-gray-500 hover:text-gray-300' : 'text-gray-400 hover:text-gray-600'}`}
                        >
                          删除
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              )
            })}

            {/* 加载更多 */}
            {hasMore && (
              <div className="text-center py-4">
                <button
                  onClick={handleLoadMore}
                  disabled={loading}
                  className="text-red-600 hover:text-red-700 text-sm font-medium"
                >
                  {loading ? '加载中...' : '加载更多'}
                </button>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  )
}

export default MessageCenter
