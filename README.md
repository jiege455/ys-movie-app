# 🎬 影视App

一个现代化的影视观看应用，基于React + TypeScript + Vite开发，支持电影浏览、详情查看和在线播放功能。

## ✨ 功能特性

### 🎯 核心功能
- **电影浏览**：展示热门电影和最新电影
- **搜索功能**：支持关键词搜索电影
- **电影详情**：展示电影信息、演员表、剧情简介
- **在线播放**：集成Video.js视频播放器
- **分类筛选**：按类型、年份等条件筛选

### 📱 用户体验
- **响应式设计**：完美适配移动端和桌面端
- **流畅动画**：页面切换和交互动画
- **加载优化**：图片懒加载和代码分割
- **深色模式**：支持明暗主题切换

### 🔧 技术特性
- **现代化技术栈**：React 18 + TypeScript + Vite
- **状态管理**：Zustand轻量级状态管理
- **UI框架**：Tailwind CSS原子化CSS
- **路由管理**：React Router v6
- **视频播放**：Video.js专业视频播放器

## 🚀 快速开始

### 📋 环境要求
- Node.js >= 18.0.0
- npm >= 9.0.0

### 📦 安装依赖
```bash
npm install
```

### 🏃‍♂️ 开发模式
```bash
npm run dev
```
访问 http://localhost:5173 查看应用

### 🔨 构建项目
```bash
npm run build
```

### 📊 预览构建结果
```bash
npm run preview
```

## 📁 项目结构

```
src/
├── components/          # 公共组件
│   ├── Carousel/        # 轮播图组件
│   ├── MovieCard/       # 电影卡片组件
│   └── VideoPlayer/     # 视频播放器组件
├── pages/               # 页面组件
│   ├── Home/            # 首页
│   ├── MovieDetail/     # 电影详情页
│   └── Player/          # 视频播放页
├── hooks/               # 自定义Hook
├── utils/               # 工具函数
│   └── api.ts           # API接口封装
├── store/               # 状态管理
│   └── movieStore.ts    # 电影数据状态
├── routes/              # 路由配置
│   └── AppRoutes.tsx    # 应用路由
└── App.tsx              # 应用主组件
```

## 🎨 设计说明

### 🎯 设计理念
- **简洁现代**：采用卡片式布局，视觉层次清晰
- **用户友好**：直观的导航和操作体验
- **性能优先**：优化的加载速度和响应性能
- **可扩展性**：模块化设计，易于功能扩展

### 🌈 色彩方案
- **主色调**：红色系（#dc2626）- 突出影视主题
- **辅助色**：灰色系 - 提供良好的视觉层次
- **强调色**：黄色系 - 用于评分和重要元素

### 📐 布局规范
- **栅格系统**：基于Tailwind CSS的响应式栅格
- **间距规范**：使用4的倍数进行间距设计
- **字体层级**：限制在4-5个字体大小层级

## 🔌 API集成

### 🎬 电影数据源
目前使用The Movie Database (TMDB) API作为数据源，支持：
- 热门电影获取
- 电影搜索
- 电影详情查询
- 演员和制作人员信息

### 🔑 API配置
在 `src/utils/api.ts` 文件中配置你的API key：
```typescript
const API_KEY = 'your_real_api_key_here'  // 替换为你的TMDB API key
```

### 🌐 代理配置（可选）
如需在服务器端代理API请求，参考 `nginx_baota.conf` 文件中的代理配置。

## 🚀 部署指南

### 🏗️ 宝塔面板部署

#### 1. 构建项目
```bash
npm run build
```

#### 2. 宝塔面板配置
1. 登录宝塔面板
2. 创建新网站，设置域名
3. 网站根目录指向 `dist` 文件夹
4. 复制 `nginx_baota.conf` 内容到网站配置

#### 3. 运行部署脚本（Windows）
```bash
deploy.bat
```

#### 4. 运行部署脚本（Linux/Mac）
```bash
./deploy.sh
```

### 📋 详细部署说明
参考 `deploy_baota.md` 文件获取完整的部署指南。

## 🔧 开发指南

### 🎯 添加新功能
1. 在 `src/pages` 中创建新的页面组件
2. 在 `src/routes/AppRoutes.tsx` 中添加路由
3. 在 `src/components` 中创建可复用组件
4. 在 `src/store` 中添加状态管理逻辑

### 🎨 样式定制
- 修改 `tailwind.config.js` 文件来自定义主题
- 在 `src/index.css` 中添加全局样式
- 使用Tailwind CSS类名进行组件样式设计

### 🔌 API扩展
- 在 `src/utils/api.ts` 中添加新的API接口
- 遵循现有的错误处理和模拟数据模式

## 🐛 常见问题

### Q: 视频无法播放？
A: 检查视频URL是否支持跨域访问，确保视频格式正确。

### Q: API调用失败？
A: 确认API key是否正确配置，检查网络连接状态。

### Q: 构建失败？
A: 运行 `npm run check` 检查TypeScript错误，确保所有依赖正确安装。

### Q: 移动端显示异常？
A: 检查响应式样式是否正确，使用浏览器开发者工具测试不同设备尺寸。

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [React](https://reactjs.org/) - 用于构建用户界面的JavaScript库
- [Vite](https://vitejs.dev/) - 下一代前端构建工具
- [Tailwind CSS](https://tailwindcss.com/) - 实用优先的CSS框架
- [Video.js](https://videojs.com/) - 开源HTML5视频播放器
- [TMDB](https://www.themoviedb.org/) - 提供电影数据的API服务

## 📞 联系方式

如有问题或建议，请通过以下方式联系：
- 提交 Issue
- 发送邮件

---

**⭐ 如果这个项目对你有帮助，请给个Star支持一下！**