import React, { useEffect, useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { getMessages, markMessageAsRead, deleteMessage } from '../../api'
import { useUserStore } from '../../store/userStore'
import type { Message } from '../../api/message'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 消息中心页面
 * 展示系统通知、评论回复等消息，支持标记已读和删除
 */

export const MessageCenter: React.FC = () => {
  const navigate = useNavigate()
  const { isLoggedIn } = useUserStore()
  const [messages, setMessages] = useState<Message[]>([])
  const [loading, setLoading] = useState(false)
  const [activeTab, setActiveTab] = useState<'all' | 'unread'>('all')
  const isMountedRef = useRef(true)

  useEffect(() => {
    if (isLoggedIn) {
      loadMessages()
    }
    return () => {
      isMountedRef.current = false
    }
  }, [isLoggedIn])

  const loadMessages = async () => {
    setLoading(true)
    try {
      const data = await getMessages()
      if (isMountedRef.current) {
        setMessages(data)
      }
    } catch (error) {
      console.error('加载消息失败:', error)
    } finally {
      if (isMountedRef.current) {
        setLoading(false)
      }
    }
  }

  const handleMarkAsRead = async (messageId: string) => {
    try {
      await markMessageAsRead(messageId)
      setMessages(prev =>
        prev.map(msg =>
          msg.id === messageId ? { ...msg, isRead: true } : msg
        )
      )
    } catch (error) {
      console.error('标记已读失败:', error)
    }
  }

  const handleDelete = async (messageId: string) => {
    try {
      await deleteMessage(messageId)
      setMessages(prev => prev.filter(msg => msg.id !== messageId))
    } catch (error) {
      console.error('删除消息失败:', error)
    }
  }

  const formatTime = (timestamp: number): string => {
    const date = new Date(timestamp)
    return date.toLocaleDateString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const getMessageIcon = (type: string) => {
    switch (type) {
      case 'system':
        return (
          <div className="w-10 h-10 rounded-full bg-cyan-500/20 flex items-center justify-center flex-shrink-0">
            <svg className="w-5 h-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
        )
      case 'comment':
        return (
          <div className="w-10 h-10 rounded-full bg-cyan-500/20 flex items-center justify-center flex-shrink-0">
            <svg className="w-5 h-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </div>
        )
      case 'like':
        return (
          <div className="w-10 h-10 rounded-full bg-cyan-500/20 flex items-center justify-center flex-shrink-0">
            <svg className="w-5 h-5 text-cyan-400" fill="currentColor" viewBox="0 0 24 24">
              <path d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
            </svg>
          </div>
        )
      default:
        return (
          <div className="w-10 h-10 rounded-full bg-cyan-500/20 flex items-center justify-center flex-shrink-0">
            <svg className="w-5 h-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
            </svg>
          </div>
        )
    }
  }

  const filteredMessages = activeTab === 'unread'
    ? messages.filter(msg => !msg.isRead)
    : messages

  const unreadCount = messages.filter(msg => !msg.isRead).length

  if (!isLoggedIn) {
    return (
      <div className="min-h-screen  flex items-center justify-center px-4">
        <div className="text-center">
          <p className="text-cyan-300 mb-4">请先登录查看消息</p>
          <button
            onClick={() => navigate('/login')}
            className="bg-cyan-500 hover:bg-cyan-400 text-white px-6 py-2 rounded-lg transition-colors"
          >
            去登录
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen ">
      {/* 顶部导航 */}
      <div className="sticky top-0 z-10 glass border-b border-cyan-500/20 px-4 py-3 flex items-center">
        <button
          onClick={() => navigate(-1)}
          className="mr-3 text-cyan-300 hover:text-cyan-100"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-lg font-bold text-cyan-100">消息中心</h1>
        {unreadCount > 0 && (
          <span className="ml-2 bg-cyan-500 text-white text-xs px-2 py-0.5 rounded-full">
            {unreadCount}
          </span>
        )}
      </div>

      {/* 标签切换 */}
      <div className="flex border-b  border-cyan-500/20">
        <button
          onClick={() => setActiveTab('all')}
          className={`flex-1 py-3 text-center font-medium transition-colors ${
            activeTab === 'all'
              ? 'text-cyan-400 border-b-2 border-cyan-400'
              : 'text-cyan-400/60 hover:text-cyan-300'
          }`}
        >
          全部消息
        </button>
        <button
          onClick={() => setActiveTab('unread')}
          className={`flex-1 py-3 text-center font-medium transition-colors ${
            activeTab === 'unread'
              ? 'text-cyan-400 border-b-2 border-cyan-400'
              : 'text-cyan-400/60 hover:text-cyan-300'
          }`}
        >
          未读消息
          {unreadCount > 0 && (
            <span className="ml-1 bg-cyan-500 text-white text-xs px-1.5 py-0.5 rounded-full">
              {unreadCount}
            </span>
          )}
        </button>
      </div>

      {/* 消息列表 */}
      <div className="px-4 py-4">
        {loading ? (
          <div className="flex justify-center items-center py-12">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-cyan-400"></div>
          </div>
        ) : (
          <>
            {filteredMessages.length === 0 ? (
              <div className="text-center py-16">
                <svg className="mx-auto h-16 w-16 text-cyan-400/30 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
                </svg>
                <p className="text-cyan-400/60">
                  {activeTab === 'unread' ? '暂无未读消息' : '暂无消息'}
                </p>
              </div>
            ) : (
              <div className="space-y-3">
                {filteredMessages.map((message) => (
                  <div
                    key={message.id}
                    className={`glass-card rounded-lg p-4 ${
                      !message.isRead ? 'border-l-4 border-cyan-400' : ''
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      {getMessageIcon(message.type)}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-1">
                          <h3 className={`font-medium ${!message.isRead ? 'text-cyan-100' : 'text-cyan-400/60'}`}>
                            {message.title}
                          </h3>
                          <span className="text-xs text-cyan-400/40 flex-shrink-0">
                            {formatTime(message.createTime)}
                          </span>
                        </div>
                        <p className="text-sm text-cyan-300 mb-2">{message.content}</p>
                        <div className="flex items-center gap-2">
                          {!message.isRead && (
                            <button
                              onClick={() => handleMarkAsRead(message.id)}
                              className="text-xs text-cyan-400 hover:text-cyan-300"
                            >
                              标记已读
                            </button>
                          )}
                          <button
                            onClick={() => handleDelete(message.id)}
                            className="text-xs text-cyan-400/60 hover:text-cyan-400"
                          >
                            删除
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}

export default MessageCenter
