import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig(({ mode }) => ({
  plugins: [react()],

  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },

  server: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': {
        target: mode === 'development' ? 'http://localhost:8080' : '/',
        changeOrigin: true,
      },
    },
  },

  build: {
    target: 'es2020',
    sourcemap: mode === 'development',
    minify: 'esbuild',
    esbuild: {
      drop: mode === 'production' ? ['console', 'debugger'] : [],
    },
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          if (id.includes('node_modules/video.js')) {
            return 'vendor-videojs'
          }
          if (id.includes('node_modules/react') || id.includes('node_modules/react-dom') || id.includes('node_modules/react-router')) {
            return 'vendor-react'
          }
          if (id.includes('node_modules/zustand')) {
            return 'vendor-zustand'
          }
          if (id.includes('node_modules/axios')) {
            return 'vendor-axios'
          }
          if (id.includes('node_modules')) {
            return 'vendor-other'
          }
          return undefined
        },
      },
    },
  },
}))
