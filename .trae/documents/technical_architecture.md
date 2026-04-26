# 影视App技术架构文档

## 系统架构
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   用户端 (React) │    │   第三方API     │    │   宝塔面板       │
│   - 页面展示     │◄──►│   - 影视数据     │    │   - Nginx部署   │
│   - 用户交互     │    │   - 搜索服务     │    │   - 静态文件     │
│   - 视频播放     │    │   - 详情信息     │    │   - 域名配置     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 前端架构

### 项目结构
```
src/
├── components/          # 公共组件
│   ├── MovieCard/     # 电影卡片组件
│   ├── VideoPlayer/   # 视频播放器组件
│   └── Carousel/      # 轮播图组件
├── pages/              # 页面组件
│   ├── Home/          # 首页
│   ├── Category/      # 分类页
│   ├── Detail/        # 详情页
│   └── Player/        # 播放页
├── hooks/              # 自定义Hook
│   ├── useMovies.ts   # 电影数据Hook
│   └── usePlayer.ts   # 播放器Hook
├── utils/              # 工具函数
│   ├── api.ts         # API接口
│   └── format.ts      # 格式化函数
└── store/              # 状态管理
    └── movieStore.ts   # 电影数据状态

```

### 技术栈
- **React 18**: 现代化UI框架
- **TypeScript**: 类型安全
- **Vite**: 构建工具
- **Tailwind CSS**: 样式框架
- **Zustand**: 状态管理
- **React Router**: 路由管理
- **Video.js**: 视频播放

### 组件设计原则
1. **单一职责**: 每个组件只负责一个功能
2. **可复用性**: 通用组件抽象化
3. **响应式**: 移动端优先设计
4. **性能优化**: 懒加载、缓存策略

## API接口设计

### 影视数据API
```typescript
interface MovieAPI {
  // 获取热门电影
  getHotMovies(page: number): Promise<Movie[]>
  
  // 搜索电影
  searchMovies(keyword: string): Promise<Movie[]>
  
  // 获取电影详情
  getMovieDetail(id: string): Promise<MovieDetail>
  
  // 获取播放地址
  getPlayUrl(id: string): Promise<string>
}
```

### 数据模型
```typescript
interface Movie {
  id: string
  title: string
  cover: string
  rating: number
  year: number
  type: 'movie' | 'tv'
  description: string
}

interface MovieDetail extends Movie {
  actors: string[]
  director: string
  duration: string
  genres: string[]
  episodes?: Episode[]  // 电视剧集数
}
```

## 部署架构

### 宝塔面板配置
1. **Nginx配置**: 静态文件服务
2. **域名绑定**: 支持自定义域名
3. **HTTPS配置**: SSL证书管理
4. **缓存策略**: CDN加速

### 构建优化
- **代码分割**: 路由级别代码分割
- **图片优化**: WebP格式、懒加载
- **缓存策略**: 浏览器缓存、Service Worker
- **压缩**: Gzip压缩、代码混淆

## 性能指标
- **首屏加载**: < 3秒
- **交互响应**: < 100ms
- **视频缓冲**: < 2秒
- **移动端适配**: 100%兼容

## 安全考虑
- **XSS防护**: 输入验证、输出编码
- **CSRF防护**: Token验证
- **内容安全**: 合法内容审核
- **用户隐私**: 数据加密存储