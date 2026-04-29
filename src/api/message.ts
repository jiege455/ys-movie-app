/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：消息中心 API
 * 说明：系统消息、通知相关接口
 */

import { api } from './index'

// ============================================================
// 类型定义
// ============================================================

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

// ============================================================
// API 函数
// ============================================================

/**
 * 获取消息列表
 */
export const getMessages = async (page: number = 1, limit: number = 20): Promise<Message[]> => {
  try {
    const res: any = await api.get('/app_api.php', {
      params: { ac: 'message_list', page, limit }
    })
    if (res?.code === 1 && res?.info?.list) {
      return res.info.list.map((item: any) => ({
        id: String(item.msg_id || item.id || ''),
        title: item.msg_title || item.title || '系统消息',
        content: item.msg_content || item.content || '',
        type: item.msg_type || item.type || 'system',
        isRead: !!(item.msg_is_read || item.is_read || item.isRead),
        createTime: item.msg_time || item.create_time || item.time || Date.now(),
        link: item.msg_link || item.link || undefined
      }))
    }
    return []
  } catch (error) {
    console.error('获取消息列表失败:', error)
    return []
  }
}

/**
 * 获取消息统计（总数和未读数）
 */
export const getMessageSummary = async (): Promise<MessageSummary> => {
  try {
    const res: any = await api.get('/app_api.php', {
      params: { ac: 'message_summary' }
    })
    if (res?.code === 1 && res?.info) {
      return {
        total: res.info.total || 0,
        unread: res.info.unread || 0
      }
    }
    return { total: 0, unread: 0 }
  } catch (error) {
    console.error('获取消息统计失败:', error)
    return { total: 0, unread: 0 }
  }
}

/**
 * 标记消息为已读
 */
export const markMessageAsRead = async (messageId: string): Promise<boolean> => {
  try {
    const res: any = await api.post('/app_api.php', { ac: 'message_read', msg_id: messageId })
    return res?.code === 1
  } catch (error) {
    console.error('标记已读失败:', error)
    return false
  }
}

/**
 * 标记所有消息为已读
 */
export const markAllMessagesAsRead = async (): Promise<boolean> => {
  try {
    const res: any = await api.post('/app_api.php', { ac: 'message_read_all' })
    return res?.code === 1
  } catch (error) {
    console.error('标记全部已读失败:', error)
    return false
  }
}

/**
 * 删除消息
 */
export const deleteMessage = async (messageId: string): Promise<boolean> => {
  try {
    const res: any = await api.post('/app_api.php', { ac: 'message_delete', msg_id: messageId })
    return res?.code === 1
  } catch (error) {
    console.error('删除消息失败:', error)
    return false
  }
}
