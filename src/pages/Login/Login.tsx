import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { userLogin, userRegister } from '../../api'
import { useUserStore } from '../../store/userStore'
import { useTheme } from '../../contexts/ThemeContext'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 登录/注册页面
 * 用户登录和注册功�? */

export const Login: React.FC = () => {
  const navigate = useNavigate()
  const { setIsLoggedIn, setUser } = useUserStore()
  const { isDark } = useTheme()
  const [isRegister, setIsRegister] = useState(false)
  const [userName, setUserName] = useState('')
  const [userPwd, setUserPwd] = useState('')
  const [userPwd2, setUserPwd2] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!userName || !userPwd) {
      setError('请输入用户名和密�?)
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
      setError('登录失败，请检查用户名和密�?)
    }
    setLoading(false)
  }

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!userName || !userPwd || !userPwd2) {
      setError('请填写所有字�?)
      return
    }
    if (userPwd !== userPwd2) {
      setError('两次输入的密码不一�?)
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
      setError('注册失败，用户名可能已存�?)
    }
    setLoading(false)
  }

  return (
    <div className={`min-h-screen flex items-center justify-center px-4 ${isDark ? 'bg-gray-900' : 'bg-gray-50'}`}>
      <div className={`w-full max-w-md rounded-xl shadow-lg p-8 ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
        <h1 className={`text-2xl font-bold text-center mb-6 ${isDark ? 'text-white' : 'text-gray-800'}`}>
          {isRegister ? '注册账号' : '用户登录'}
        </h1>

        {error && (
          <div className="bg-sky-50 border border-sky-200 rounded-lg p-3 mb-4">
            <p className="text-sky-500 text-sm text-center">{error}</p>
          </div>
        )}

        <form onSubmit={isRegister ? handleRegister : handleLogin} className="space-y-4">
          <div>
            <label className={`block text-sm font-medium mb-1 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>用户�?/label>
            <input
              type="text"
              value={userName}
              onChange={(e) => setUserName(e.target.value)}
              className={`w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-sky-500 focus:border-transparent outline-none ${isDark ? 'bg-gray-700 border-gray-600 text-white placeholder-gray-400' : 'border-gray-300'}`}
              placeholder="请输入用户名"
              required
            />
          </div>

          <div>
            <label className={`block text-sm font-medium mb-1 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>密码</label>
            <input
              type="password"
              value={userPwd}
              onChange={(e) => setUserPwd(e.target.value)}
              className={`w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-sky-500 focus:border-transparent outline-none ${isDark ? 'bg-gray-700 border-gray-600 text-white placeholder-gray-400' : 'border-gray-300'}`}
              placeholder="请输入密�?
              required
            />
          </div>

          {isRegister && (
            <div>
              <label className={`block text-sm font-medium mb-1 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>确认密码</label>
              <input
                type="password"
                value={userPwd2}
                onChange={(e) => setUserPwd2(e.target.value)}
                className={`w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-sky-500 focus:border-transparent outline-none ${isDark ? 'bg-gray-700 border-gray-600 text-white placeholder-gray-400' : 'border-gray-300'}`}
                placeholder="请再次输入密�?
                required
              />
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-sky-500 hover:bg-sky-600 disabled:bg-gray-400 text-white py-2 rounded-lg transition-colors font-medium"
          >
            {loading ? '处理�?..' : isRegister ? '注册' : '登录'}
          </button>
        </form>

        <div className="mt-4 text-center">
          <button
            onClick={() => {
              setIsRegister(!isRegister)
              setError('')
            }}
            className="text-sky-500 hover:text-sky-600 text-sm"
          >
            {isRegister ? '已有账号？去登录' : '没有账号？去注册'}
          </button>
        </div>

        <div className="mt-4 text-center">
          <button
            onClick={() => navigate(-1)}
            className="text-gray-500 hover:text-gray-700 text-sm"
          >
            返回上一�?          </button>
        </div>
      </div>
    </div>
  )
}

export default Login
