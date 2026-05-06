import React, { useEffect, useState } from 'react'
import { NavLink } from 'react-router-dom'
import { getAppPageSetting, AppPageSetting } from '../../api'

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 底部TabBar导航，仿主流视频App，包含 首页/发现/分类/我的
 * 使用 NavLink 高亮当前标签；移动端优先的样式
 */
export const TabBar: React.FC = () => {
  const itemCls = ({ isActive }: { isActive: boolean }) =>
    `flex flex-col items-center justify-center flex-1 py-2 ${isActive ? 'text-red-600' : 'text-gray-600'}`

  /**
   * 通过插件页面设置动态控制标签名称与显示
   */
  const [pageSetting, setPageSetting] = useState<AppPageSetting | null>(null)

  /**
   * 加载页面设置（只用于获取"专题"自定义名称）
   */
  useEffect(() => {
    const load = async () => {
      const setting = await getAppPageSetting()
      setPageSetting(setting)
    }
    load()
  }, [])

  const topicEnabled = !!(pageSetting?.app_tab_topic === 1 || pageSetting?.app_tab_topic === true)
  const topicName = pageSetting?.app_tab_topic_name || '专题'

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t shadow bg-white border-gray-200">
      <div className="flex">
        <NavLink to="/" className={itemCls}>
          <span className="text-sm">首页</span>
        </NavLink>
        <NavLink to="/discover" className={itemCls}>
          <span className="text-sm">发现</span>
        </NavLink>
        {topicEnabled && (
          <NavLink to="/topic" className={itemCls}>
            <span className="text-sm">{topicName}</span>
          </NavLink>
        )}
        <NavLink to="/categories" className={itemCls}>
          <span className="text-sm">分类</span>
        </NavLink>
        <NavLink to="/profile" className={itemCls}>
          <span className="text-sm">我的</span>
        </NavLink>
      </div>
    </nav>
  )
}

export default TabBar
