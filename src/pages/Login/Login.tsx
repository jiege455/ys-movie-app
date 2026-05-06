import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { userLogin, userRegister, ApiResult, UserAuth } from '../../api'
import { useUserStore } from '../../store/userStore'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 登录/注册页面
 * 用户登录和注册功能，注册成功后自动登录
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

  const handleAuthSuccess = (auth: UserAuth, message: string) => {
    setIsLoggedIn(true)
    setUser(auth)
    setError('')
    alert(message)
    navigate(-1)
  }

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!userName || !userPwd) {
      setError('请输入用户名和密码')
      return
    }
    setLoading(true)
    setError('')
    const result: ApiResult<UserAuth> = await userLogin(userName, userPwd)
    if (result.success && result.data) {
      handleAuthSuccess(result.data, '登录成功')
    } else {
      setError(result.message || '登录失败，请检查用户名和密码')
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
    if (userPwd.length < 6) {
      setError('密码长度至少6位')
      return
    }
    setLoading(true)
    setError('')
    const result: ApiResult<UserAuth> = await userRegister(userName, userPwd, userPwd2)
    if (result.success && result.data) {
      handleAuthSuccess(result.data, '注册成功，已自动登录')
    } else {
      setError(result.message || '注册失败，用户名可能已存在')
    }
    setLoading(false)
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4 bg-gray-50">
      <div className="w-full max-w-md rounded-xl shadow-lg p-8 bg-white">
        <h1 className="text-2xl font-bold text-center mb-6 text-gray-800">
          {isRegister ? '注册账号' : '用户登录'}
        </h1>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
            <p className="text-red-600 text-sm text-center">{error}</p>
          </div>
        )}

        <form onSubmit={isRegister ? handleRegister : handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1 text-gray-700">用户名</label>
            <input
              type="text"
              value={userName}
              onChange={(e) => setUserName(e.target.value)}
              className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent outline-none border-gray-300"
              placeholder="请输入用户名"
              required
              minLength={3}
              maxLength={20}
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1 text-gray-700">密码</label>
            <input
              type="password"
              value={userPwd}
              onChange={(e) => setUserPwd(e.target.value)}
              className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent outline-none border-gray-300"
              placeholder="请输入密码"
              required
              minLength={6}
            />
          </div>

          {isRegister && (
            <div>
              <label className="block text-sm font-medium mb-1 text-gray-700">确认密码</label>
              <input
                type="password"
                value={userPwd2}
                onChange={(e) => setUserPwd2(e.target.value)}
                className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent outline-none border-gray-300"
                placeholder="请再次输入密码"
                required
                minLength={6}
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
              setUserPwd('')
              setUserPwd2('')
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
