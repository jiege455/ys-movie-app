import React, { useState, useEffect } from 'react'
import { getComments, addComment, checkLoggedIn } from '../../api'
import type { Comment } from '../../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 评论组件
 * 展示视频评论列表，支持发送评论
 */

interface CommentSectionProps {
  vodId: string
}

export const CommentSection: React.FC<CommentSectionProps> = ({ vodId }) => {
  const [comments, setComments] = useState<Comment[]>([])
  const [newComment, setNewComment] = useState('')
  const [loading, setLoading] = useState(false)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (vodId) {
      loadComments()
    }
  }, [vodId])

  const loadComments = async () => {
    setLoading(true)
    const data = await getComments(vodId)
    setComments(data)
    setLoading(false)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newComment.trim()) return
    if (!checkLoggedIn()) {
      alert('请先登录后再评论')
      return
    }
    setSubmitting(true)
    const success = await addComment(vodId, newComment.trim())
    if (success) {
      setNewComment('')
      loadComments()
    } else {
      alert('评论发送失败，请稍后重试')
    }
    setSubmitting(false)
  }

  return (
    <div className="rounded-lg shadow-sm p-4 mt-4 bg-white">
      <h3 className="text-lg font-bold mb-4 text-gray-800">评论 ({comments.length})</h3>

      {/* 评论输入框 */}
      {checkLoggedIn() ? (
        <form onSubmit={handleSubmit} className="mb-4">
          <textarea
            value={newComment}
            onChange={(e) => setNewComment(e.target.value)}
            placeholder="写下你的评论..."
            className="w-full px-3 py-2 border rounded-lg resize-none focus:ring-2 focus:ring-red-500 focus:border-transparent outline-none border-gray-300"
            rows={3}
            maxLength={200}
          />
          <div className="flex justify-between items-center mt-2">
            <span className="text-sm text-gray-400">{newComment.length}/200</span>
            <button
              type="submit"
              disabled={submitting || !newComment.trim()}
              className="bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white px-4 py-1.5 rounded-lg transition-colors text-sm"
            >
              {submitting ? '发送中...' : '发送评论'}
            </button>
          </div>
        </form>
      ) : (
        <div className="rounded-lg p-4 mb-4 text-center bg-gray-50">
          <p className="text-sm text-gray-500">登录后才能发表评论</p>
        </div>
      )}

      {/* 评论列表 */}
      {loading ? (
        <div className="flex justify-center py-4">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-red-600"></div>
        </div>
      ) : (
        <div className="space-y-3">
          {comments.length === 0 ? (
            <p className="text-center py-4 text-sm text-gray-500">暂无评论，快来抢沙发吧</p>
          ) : (
            comments.map((comment) => (
              <div key={comment.id} className="border-b pb-3 last:border-0 border-gray-100">
                <div className="flex items-center justify-between mb-1">
                  <span className="font-medium text-sm text-gray-800">{comment.userName}</span>
                  <span className="text-xs text-gray-400">{comment.time}</span>
                </div>
                <p className="text-sm text-gray-600">{comment.content}</p>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}

export default CommentSection
