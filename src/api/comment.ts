/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：评论 API
 * 说明：评论列表、发表评论——走插件 API (app_api.php)
 */

import { jgappApi } from './index'
import type { MovieComment } from '../types'

export type { MovieComment }

export const getComments = async (rid: string, page: number = 1, limit: number = 20): Promise<MovieComment[]> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'get_comments', rid, page, limit }
    })
    if (res?.code === 1 && res.list) {
      return res.list.map((item: any) => ({
        id: String(item.id || ''),
        userName: item.name || '匿名用户',
        content: item.content || '',
        time: item.time || '',
        rid: String(item.rid || rid)
      }))
    }
    return []
  } catch (error) {
    console.error('获取评论失败:', error)
    return []
  }
}

export const addComment = async (rid: string, content: string): Promise<boolean> => {
  try {
    const res: any = await jgappApi.get('', {
      params: { ac: 'add_comment', rid, content }
    })
    return res?.code === 1
  } catch (error) {
    console.error('发送评论失败:', error)
    return false
  }
}
