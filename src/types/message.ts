/**
 * 开发者：杰哥网络科技
 * 模块：消息相关类型定义
 */

export interface Message {
  id: string
  title: string
  content: string
  type: 'system' | 'notice' | 'activity'
  isRead: boolean
  createTime: number
  link?: string
}

export interface MessageSummary {
  total: number
  unread: number
}
