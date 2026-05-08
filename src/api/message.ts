/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：消息中心 API
 * 说明：系统消息、通知——走插件 API (app_api.php)
 *       插件目前仅支持 message_list 接口，
 *       其余操作(统计/标记已读/删除)暂时通过客户端模拟实现
 */

import { jgappApi } from './index'
import type { Message, MessageSummary } from '../types'

export type { Message, MessageSummary }

export const getMessages = async (page: number = 1, limit: number = 20): Promise<Message[]> => {
  try {
    const res: any = await jgappApi.get('', {
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
 * 获取消息统计（基于已获取的消息列表客户端计算）
 */
export const getMessageSummary = async (): Promise<MessageSummary> => {
  try {
    const messages = await getMessages(1, 100)
    const unread = messages.filter((m) => !m.isRead).length
    return { total: messages.length, unread }
  } catch {
    return { total: 0, unread: 0 }
  }
}

/**
 * 标记单条消息已读 —— 客户端本地标记
 * 后续扩展：插件增加 message_read 接口后改为服务端标记
 */
export const markMessageAsRead = async (messageId: string): Promise<boolean> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'message_read', msg_id: messageId }
    })
    if (res?.code === 1) return true
  } catch { /* 插件暂不支持，客户端标记即可 */ }
  return true
}

/**
 * 标记全部已读 —— 客户端本地标记
 * 后续扩展：插件增加 message_read_all 接口后改为服务端标记
 */
export const markAllMessagesAsRead = async (): Promise<boolean> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'message_read_all' }
    })
    if (res?.code === 1) return true
  } catch { /* 插件暂不支持，客户端标记即可 */ }
  return true
}

/**
 * 删除消息 —— 客户端本地删除
 * 后续扩展：插件增加 message_delete 接口后改为服务端删除
 */
export const deleteMessage = async (messageId: string): Promise<boolean> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'message_delete', msg_id: messageId }
    })
    if (res?.code === 1) return true
  } catch { /* 插件暂不支持，客户端标记即可 */ }
  return true
}
