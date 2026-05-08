/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：评论 API
 * 说明：评论列表、发表评论——走 JgApp 插件接口 (api.php/jgappapi.index/commentList/sendComment)
 *       无需额外上传 php 文件到宝塔
 */

import { pluginApi } from './index'
import type { MovieComment } from '../types'

export type { MovieComment }

export const getComments = async (rid: string, page: number = 1, limit: number = 20): Promise<MovieComment[]> => {
  try {
    const res: any = await pluginApi.get('commentList', {
      params: { vod_id: Number(rid), page, limit }
    })
    const list = res?.comment_list || []
    if (list.length > 0) {
      return list.map((item: any) => ({
        id: String(item.comment_id || item.id || ''),
        userName: item.comment_name || item.name || '匿名用户',
        content: item.comment_content || item.content || '',
        time: item.comment_time || item.time || '',
        rid: String(item.comment_rid || item.rid || rid)
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
    const res: any = await pluginApi.get('sendComment', {
      params: { vod_id: Number(rid), comment: content }
    })
    return res?.code === 1 || res?.status === true || !!res?.comment
  } catch (error) {
    console.error('发送评论失败:', error)
    return false
  }
}
