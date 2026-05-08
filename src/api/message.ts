/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：消息中心 API
 * 说明：系统消息通知——走 JgApp 插件接口 (api.php/jgappapi.index/noticeList/noticeDetail)
 *       无需额外上传 php 文件到宝塔
 */

import { pluginApi } from './index'
import type { Message, MessageSummary } from '../types'

export type { Message, MessageSummary }

export const getMessages = async (page: number = 1, limit: number = 20): Promise<Message[]> => {
  try {
    const res: any = await pluginApi.get('noticeList', {
      params: { page, limit }
    })
    const list = res?.notice_list || []
    if (list.length > 0) {
      return list.map((item: any) => ({
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
 * 获取消息统计（基于消息列表客户端计算）
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
export const markMessageAsRead = async (_messageId: string): Promise<boolean> => {
  // 插件暂未提供消息已读接口，客户端本地标记
  return true
}

/**
 * 标记全部已读 —— 客户端本地标记
 * 后续扩展：插件增加 message_read_all 接口后改为服务端标记
 */
export const markAllMessagesAsRead = async (): Promise<boolean> => {
  // 插件暂未提供消息已读接口，客户端本地标记
  return true
}

/**
 * 删除消息 —— 客户端本地删除
 * 后续扩展：插件增加 message_delete 接口后改为服务端删除
 */
export const deleteMessage = async (_messageId: string): Promise<boolean> => {
  // 插件暂未提供删除消息接口，客户端本地处理
  return true
}
