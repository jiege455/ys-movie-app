import React, { useState, useEffect, useRef } from 'react'
import { getComments, addComment, checkLoggedIn } from '../../api'
import type { MovieComment } from '../../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 评论组件
 * 展示视频评论列表，支持发送评论
 * 优化：添加评论缓存、减少重复请求、提升加载速度
 */

interface CommentSectionProps {
  vodId: string
}

// 简单的评论缓存，避免重复请求
const commentCache = new Map<string, { data: MovieComment[]; time: number }>()
const CACHE_DURATION = 5 * 60 * 1000 // 5分钟缓存
const CACHE_MAX_SIZE = 50

export const CommentSection: React.FC<CommentSectionProps> = ({ vodId }) => {
  const [comments, setComments] = useState<MovieComment[]>([])
  const [newComment, setNewComment] = useState('')
  const [loading, setLoading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const isMountedRef = useRef(true)

  useEffect(() => {
    isMountedRef.current = true
    if (vodId) {
      loadComments()
    }
    return () => {
      isMountedRef.current = false
    }
  }, [vodId])

  const loadComments = async () => {
    // 先检查缓存
    const cached = commentCache.get(vodId)
    if (cached && Date.now() - cached.time < CACHE_DURATION) {
      setComments(cached.data)
      return
    }

    setLoading(true)
    try {
      const data = await getComments(vodId)
      if (isMountedRef.current) {
        setComments(data)
        // 存入缓存
        if (commentCache.size >= CACHE_MAX_SIZE) {
          const firstKey = commentCache.keys().next().value
          if (firstKey !== undefined) {
            commentCache.delete(firstKey)
          }
        }
        commentCache.set(vodId, { data, time: Date.now() })
      }
    } finally {
      if (isMountedRef.current) {
        setLoading(false)
      }
    }
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
      // 清除缓存，强制刷新
      commentCache.delete(vodId)
      loadComments()
    } else {
      alert('评论发送失败，请稍后重试')
    }
    setSubmitting(false)
  }

  return (
    <div className="rounded-lg shadow-sm p-4 mt-4 glass-card">
      <h3 className="text-lg font-bold mb-4 text-cyan-400">评论 ({comments.length})</h3>

      {/* 评论输入框 */}
      {checkLoggedIn() ? (
        <form onSubmit={handleSubmit} className="mb-4">
          <textarea
            value={newComment}
            onChange={(e) => setNewComment(e.target.value)}
            placeholder="写下你的评论..."
            className="w-full px-3 py-2 border rounded-lg resize-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent outline-none glass-light text-cyan-100 placeholder-cyan-400/50 border-cyan-500/20"
            rows={3}
            maxLength={200}
          />
          <div className="flex justify-between items-center mt-2">
            <span className="text-sm text-cyan-400/40">{newComment.length}/200</span>
            <button
              type="submit"
              disabled={submitting || !newComment.trim()}
              className="bg-cyan-500 hover:bg-cyan-400 disabled:bg-slate-700 text-white px-4 py-1.5 rounded-lg transition-colors text-sm"
            >
              {submitting ? '发送中...' : '发送评论'}
            </button>
          </div>
        </form>
      ) : (
        <div className="rounded-lg p-4 mb-4 text-center glass-light/50 border border-cyan-500/10">
          <p className="text-sm text-cyan-400/60">登录后才能发表评论</p>
        </div>
      )}

      {/* 评论列表 */}
      {loading ? (
        <div className="flex justify-center py-4">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-cyan-400"></div>
        </div>
      ) : (
        <div className="space-y-3">
          {comments.length === 0 ? (
            <p className="text-center py-4 text-sm text-cyan-400/60">暂无评论，快来抢沙发吧</p>
          ) : (
            comments.map((comment) => (
              <div key={comment.id} className="border-b pb-3 last:border-0 border-cyan-500/10">
                <div className="flex items-center justify-between mb-1">
                  <span className="font-medium text-sm text-cyan-200">{comment.userName}</span>
                  <span className="text-xs text-cyan-400/40">{comment.time}</span>
                </div>
                <p className="text-sm text-cyan-300">{comment.content}</p>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}

export default CommentSection
