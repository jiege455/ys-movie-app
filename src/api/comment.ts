/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：评论 API
 * 说明：评论列表、发表评论相关接口
 */

import { api } from './index'
import type { MovieComment } from '../types'

export type { MovieComment }

export const getComments = async (rid: string, page: number = 1, limit: number = 20): Promise<MovieComment[]> => {
  try {
    const res: any = await api.get('/comment/get_list', {
      params: { rid, offset: (page - 1) * limit, limit }
    })
    if (res?.code === 1 && res?.info?.rows) {
      return res.info.rows.map((item: any) => {
        let timeStr = ''
        if (item.comment_time) {
          const timestamp = typeof item.comment_time === 'string'
            ? parseInt(item.comment_time, 10)
            : item.comment_time
          if (!isNaN(timestamp)) {
            const ms = timestamp > 1e12 ? timestamp : timestamp * 1000
            timeStr = new Date(ms).toLocaleString('zh-CN')
          }
        }
        return {
          id: String(item.comment_id || ''),
          userName: item.comment_name || item.user_name || '匿名用户',
          content: item.comment_content || item.content || '',
          time: timeStr,
          rid: String(item.comment_rid || item.rid || rid)
        }
      })
    }
    return []
  } catch (error) {
    console.error('获取评论失败:', error)
    return []
  }
}

export const addComment = async (rid: string, content: string): Promise<boolean> => {
  try {
    const res: any = await api.post('/comment/add', {
      comment_rid: rid,
      comment_content: content,
      comment_mid: 1
    })
    return res?.code === 1
  } catch (error) {
    console.error('发送评论失败:', error)
    return false
  }
}
