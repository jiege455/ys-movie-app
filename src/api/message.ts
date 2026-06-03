/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：消息中心 API
 * 说明：系统消息通知——走 JgApp 插件接口 (api.php/jgappapi.index/noticeList/noticeDetail)
 *       无需额外上传 php 文件到宝塔
 * 修复：已读/删除状态使用 localStorage 持久化，避免刷新丢失
 */

import { pluginApi } from "./index"
import type { Message, MessageSummary } from "../types"

export type { Message, MessageSummary }

const READ_IDS_KEY = "_msg_read_ids"
const DELETED_IDS_KEY = "_msg_deleted_ids"

const getStoredIds = (key: string): Set<string> => {
  try {
    const raw = localStorage.getItem(key)
    return raw ? new Set(JSON.parse(raw)) : new Set()
  } catch { return new Set() }
}

const saveStoredIds = (key: string, ids: Set<string>) => {
  try { localStorage.setItem(key, JSON.stringify([...ids])) } catch {}
}

export const getMessages = async (page: number = 1, limit: number = 20): Promise<Message[]> => {
  try {
    const res: any = await pluginApi.get("noticeList", {
      params: { page, limit }
    })
    const list = res?.notice_list || []
    const readIds = getStoredIds(READ_IDS_KEY)
    const deletedIds = getStoredIds(DELETED_IDS_KEY)
    if (list.length > 0) {
      return list
        .filter((item: any) => {
          const id = String(item.msg_id || item.id || "")
          return !deletedIds.has(id)
        })
        .map((item: any) => {
          const id = String(item.msg_id || item.id || "")
          return {
            id,
            title: item.msg_title || item.title || "系统消息",
            content: item.msg_content || item.content || "",
            type: item.msg_type || item.type || "system",
            isRead: !!(item.msg_is_read || item.is_read || item.isRead) || readIds.has(id),
            createTime: item.msg_time || item.create_time || item.time || Date.now(),
            link: item.msg_link || item.link || undefined
          }
        })
    }
    return []
  } catch (error) {
    console.error("获取消息列表失败:", error)
    return []
  }
}

export const getMessageSummary = async (): Promise<MessageSummary> => {
  try {
    const messages = await getMessages(1, 100)
    const unread = messages.filter((m) => !m.isRead).length
    return { total: messages.length, unread }
  } catch {
    return { total: 0, unread: 0 }
  }
}

export const markMessageAsRead = async (messageId: string): Promise<boolean> => {
  try {
    const ids = getStoredIds(READ_IDS_KEY)
    ids.add(messageId)
    saveStoredIds(READ_IDS_KEY, ids)
    return true
  } catch { return false }
}

export const markAllMessagesAsRead = async (): Promise<boolean> => {
  try {
    saveStoredIds(READ_IDS_KEY, new Set())
    return true
  } catch { return false }
}

export const deleteMessage = async (messageId: string): Promise<boolean> => {
  try {
    const ids = getStoredIds(DELETED_IDS_KEY)
    ids.add(messageId)
    saveStoredIds(DELETED_IDS_KEY, ids)
    return true
  } catch { return false }
}