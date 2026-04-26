import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { userLogin, userRegister } from '../../api'
import { useUserStore } from '../../store/userStore'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 登录/注册页面
 * 用户登录和注册功能
 */

export const Login: React.FC = () => {
  const navigate = useNavigate()
  const { setIsLoggedIn, setUser } = useUserStore()
  const [isRegister, setIsRegister] = useState(false)
  const [userName, setUserName] = useState('')
  const [userPwd, setUserPwd] = useState('')
  const [userPwd2, setUserPwd2] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!userName || !userPwd) {
      setError('请输入用户名和密码')
      return
    }
    setLoading(true)
    setError('')
    const auth = await userLogin(userName, userPwd)
    if (auth) {
      setIsLoggedIn(true)
      setUser(auth)
      navigate(-1)
    } else {
      setError('登录失败，请检查用户名和密码')
    }
    setLoading(false)
  }

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!userName || !userPwd || !userPwd2) {
      setError('请填写所有字段')
      return
    }
    if (userPwd !== userPwd2) {
      setError('两次输入的密码不一致')
      return
    }
    setLoading(true)
    setError('')
    const success = await userRegister(userName, userPwd, userPwd2)
    if (success) {
      setError('')
      setIsRegister(false)
      setUserPwd('')
      setUserPwd2('')
      alert('注册成功，请登录')
    } else {
      setError('注册失败，用户名可能已存在')
    }
    setLoading(false)
  }

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
      <div className="w-full max-w-md bg-white rounded-xl shadow-lg p-8">
        <h1 className="text-2xl font-bold text-center text-gray-800 mb-6">
          {isRegister ? '注册账号' : '用户登录'}
        </h1>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
            <p className="text-red-600 text-sm text-center">{error}</p>
          </div>
        )}

        <form onSubmit={isRegister ? handleRegister : handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">用户名</label>
            <input
              type="text"
              value={userName}
              onChange={(e) => setUserName(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent outline-none"
              placeholder="请输入用户名"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">密码</label>
            <input
              type="password"
              value={userPwd}
              onChange={(e) => setUserPwd(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent outline-none"
              placeholder="请输入密码"
              required
            />
          </div>

          {isRegister && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">确认密码</label>
              <input
                type="password"
                value={userPwd2}
                onChange={(e) => setUserPwd2(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent outline-none"
                placeholder="请再次输入密码"
                required
              />
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white py-2 rounded-lg transition-colors font-medium"
          >
            {loading ? '处理中...' : isRegister ? '注册' : '登录'}
          </button>
        </form>

        <div className="mt-4 text-center">
          <button
            onClick={() => {
              setIsRegister(!isRegister)
              setError('')
            }}
            className="text-red-600 hover:text-red-700 text-sm"
          >
            {isRegister ? '已有账号？去登录' : '没有账号？去注册'}
          </button>
        </div>

        <div className="mt-4 text-center">
          <button
            onClick={() => navigate(-1)}
            className="text-gray-500 hover:text-gray-700 text-sm"
          >
            返回上一页
          </button>
        </div>
      </div>
    </div>
  )
}

export default Login
