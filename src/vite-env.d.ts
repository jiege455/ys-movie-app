/// <reference types="vite/client" />

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * Vite 环境变量类型声明
 */

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string
  readonly VITE_APP_API_URL: string
  readonly VITE_IMAGE_BASE_URL: string
  readonly VITE_APP_NAME: string
  readonly VITE_DEBUG: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
