import React, { useEffect, useState } from 'react'
import { getAppPageSetting, AppPageSetting } from '../../api'
import { useNavigate } from 'react-router-dom'
import { useTheme } from '../../contexts/ThemeContext'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 专题页面
 * 动态读取插件后台页面设置，展示可自定义的专题名称
 */
export const Topic: React.FC = () => {
  const navigate = useNavigate()
  const { isDark } = useTheme()
  const [pageSetting, setPageSetting] = useState<AppPageSetting | null>(null)
  const title = pageSetting?.app_tab_topic_name || '专题'

  /**
   * 加载插件页面设置，获取专题页名称
   */
  useEffect(() => {
    const load = async () => {
      const setting = await getAppPageSetting()
      setPageSetting(setting)
    }
    load()
  }, [])

  /**
   * 返回上一页
   */
  const handleBack = () => navigate(-1)

  return (
    <div className={`min-h-screen ${isDark ? 'bg-gray-900' : 'bg-white'}`}>
      {/* 顶部栏 */}
      <div className={`sticky top-0 z-10 border-b px-4 py-3 flex items-center ${isDark ? 'bg-gray-900 border-gray-700' : 'bg-white border-gray-200'}`}>
        <button
          onClick={handleBack}
          className={`mr-3 ${isDark ? 'text-gray-300 hover:text-white' : 'text-gray-700 hover:text-gray-900'}`}
          aria-label="返回"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className={`text-xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>{title}</h1>
      </div>

      {/* 内容区：仅展示标题占位，不加载其他数据 */}
      <main className="px-4 py-6">
        <div className={isDark ? 'text-gray-400' : 'text-gray-600'}>
          该页面名称已与插件后台页面设置对接，仅显示自定义的专题名称。
        </div>
      </main>
    </div>
  )
}

export default Topic
