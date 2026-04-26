/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 模块：APP 设置 API
 * 说明：页面配置、广告、主题等系统级接口
 */

import { api } from './index'

// ============================================================
// 类型定义
// ============================================================

export interface AppPageSetting {
  app_tab_topic: number | boolean
  app_tab_topic_name: string
}

// ============================================================
// API 函数
// ============================================================

/**
 * 获取APP页面设置
 */
export const getAppPageSetting = async (): Promise<AppPageSetting | null> => {
  try {
    const res: any = await api.get('/app/page_setting')
    if (res?.code === 1 && res?.data) {
      return {
        app_tab_topic: res.data.app_tab_topic ?? 1,
        app_tab_topic_name: res.data.app_tab_topic_name || '专题'
      }
    }
    return null
  } catch (error) {
    console.error('获取页面设置失败:', error)
    return null
  }
}
