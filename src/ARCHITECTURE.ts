/**
 * 项目架构规划文档（内部开发用）
 * 开发者：杰哥网络科技 (qq: 2711793818)
 */

export const ARCHITECTURE = `
===========================================================
  项目架构规划文档
  版本: 1.0
  最后更新: 2026-05-07
  开发者: 杰哥网络科技 (qq: 2711793818)
===========================================================

一、项目概述
────────────────────────────────────────
本系统是一套集视频内容管理、播放、用户交互于一体的全栈Web应用
技术栈: React 19 + TypeScript 5.8 + Vite 6 + Zustand + Tailwind CSS + video.js
后端: PHP + MacCMS (苹果CMS) API
移动端: Flutter (ys_movie_app/)

二、目录结构
────────────────────────────────────────
ys/
├── src/                          # Web前端源代码
│   ├── api/                     # API请求层 - 后端接口封装
│   ├── components/              # 通用UI组件 - 可复用视图组件
│   ├── lib/                     # 通用工具库 - 纯函数工具集
│   ├── pages/                   # 页面组件 - 路由级页面
│   ├── routes/                  # 路由配置 - 页面导航管理
│   ├── store/                   # 状态管理 - Zustand数据仓库
│   ├── types/                   # 类型定义 - TypeScript类型集中管理
│   ├── App.tsx                  # 应用根组件
│   ├── main.tsx                 # 应用入口
│   └── index.css                # 全局样式
├── ys_movie_app/                # Flutter移动端
│   └── backend/                 # PHP后端API (app_api.php)
├── public/                      # 静态资源
├── dist/                        # 构建产物 (自动生成)
├── package.json                 # 项目依赖配置
├── vite.config.ts               # Vite构建配置
├── tsconfig.json                # TypeScript配置
├── tailwind.config.js           # Tailwind CSS配置
└── nginx_baota.conf             # 宝塔Nginx配置

三、模块划分与职责
────────────────────────────────────────

【1】types/ - 类型定义模块
    职责: 集中管理所有TypeScript类型定义，作为类型唯一数据源
    管理范围:
      movie.ts    - 视频/Movie相关类型 (Movie, MovieDetail, VodSource, VodEpisode, BannerMovie)
      user.ts     - 用户/收藏类型 (UserAuth, UserInfo, FavoriteItem)
      comment.ts  - 评论类型 (MovieComment)
      message.ts  - 消息类型 (Message, MessageSummary)
      api.ts      - API通用类型 (ApiResponse, ApiError, AppPageSetting, PaginationParams)
      index.ts    - 统一出口
    规范: 所有业务类型都在此定义，禁止在api/或store/中重复定义

【2】api/ - API请求层模块
    职责: 封装所有后端接口调用，提供统一的数据获取入口
    管理范围:
      index.ts    - Axios实例配置、拦截器、图片URL工具
      vod.ts      - 视频列表、详情、搜索、播放列表解析
      user.ts     - 登录、注册、退出、收藏增删查
      comment.ts  - 评论列表、发表评论
      message.ts  - 消息列表、已读、删除、统计
      app.ts      - APP设置、主题配置
    数据流: api/ → store/ (状态写入) 或 api/ → pages/ (直接消费)
    错误处理规范: 统一catch并返回空值/null，记录错误日志

【3】store/ - 状态管理模块
    职责: 管理应用级共享状态，提供响应式数据流
    管理范围:
      movieStore.ts   - 视频列表、当前视频、加载状态
      playerStore.ts  - 播放器状态 (当前源、集数、历史记录)
      uiStore.ts      - UI交互状态 (TabBar选中、搜索浮窗)
      userStore.ts    - 用户登录状态、收藏列表
      index.ts        - 统一出口
    规范: 单例store，使用Zustand的create模式

【4】components/ - 通用组件模块
    职责: 提供可复用的UI组件，不依赖路由状态
    管理范围:
      MovieCard/        - 视频卡片展示组件
      Carousel/         - Banner轮播组件
      TabBar/           - 底部导航栏组件
      VideoPlayer/      - 视频播放器组件 (基于video.js)
      CommentSection/   - 评论区域组件
      FavoriteButton/   - 收藏按钮组件
      ErrorBoundary/    - 错误边界组件
      PageLoading/      - 页面加载状态组件
    规范: 每个组件一个文件夹(含tsx/css)，通过index.ts统一导出

【5】pages/ - 页面模块
    职责: 路由级页面，组合components实现完整页面功能
    管理范围:
      Home/          - 首页 (Banner + 热门列表 + 搜索入口)
      MovieDetail/   - 视频详情页 (剧集列表 + 评论区 + 收藏)
      Player/        - 播放页 (视频播放器 + 选集)
      Search/        - 搜索页 (搜索结果展示)
      Category/      - 分类页 (按分类浏览)
      Topic/         - 专题页
      Login/         - 登录注册页
      Profile/       - 个人中心页 (资料 + 收藏)
      MessageCenter/ - 消息中心页
      index.ts       - 统一导出
    规范: 每个页面一个文件夹(含tsx/css)，页面间通过路由跳转

【6】routes/ - 路由模块
    职责: 管理页面路由配置、导航守卫、TabBar显示控制
    管理范围:
      AppRoutes.tsx  - 路由定义、TabBar显隐逻辑、404页面
    数据流: routes/AppRoutes.tsx → pages/组件 (通过<Route>)

【7】lib/ - 工具库模块
    职责: 纯函数工具，不依赖React组件树
    管理范围:
      utils.ts  - cn()类名拼接、通用工具函数

四、数据流向图
────────────────────────────────────────

┌─────────────┐
│  后端 MacCMS  │ ← PHP API
└──────┬──────┘
       │ HTTP (Axios)
       ▼
┌─────────────┐
│   api/ 模块  │ ← 接口封装、响应转换、错误处理
└──────┬──────┘
       │
    ┌──┴──────────────────┐
    ▼                     ▼
┌─────────┐        ┌──────────┐
│ store/  │        │ pages/   │
│ 状态仓库 │◄──────►│ 页面组件  │
└────┬────┘        └────┬─────┘
     │                  │
     │            ┌─────┴─────┐
     │            ▼           ▼
     │      ┌──────────┐ ┌──────────┐
     └─────►│components│ │ routes/  │
            │ 通用组件  │ │ 路由配置  │
            └──────────┘ └──────────┘

五、接口定义摘要
────────────────────────────────────────

【视频接口】
  GET  /vod/get_list     → 视频列表 (支持分页/分类/排序/搜索)
  GET  /vod/get_detail   → 视频详情 (含播放列表)
  GET  /app_api.php?ac=search → Xunsearch搜索引擎 (降级到vod/get_list)

【用户接口】
  POST /user/login       → 用户登录 (返回user_id, user_name, user_check)
  POST /user/reg         → 用户注册
  POST /user/logout      → 退出登录
  POST /user/ulog_add    → 添加收藏 (type=4)
  POST /user/ulog_del    → 取消收藏
  GET  /user/ulog_list   → 收藏列表 (type=4, mid=1)
  GET  /user/ulog_check  → 检查收藏状态

【评论接口】
  GET  /comment/get_list  → 评论列表 (rid, offset, limit)
  POST /comment/add       → 发表评论

【消息接口】
  GET  /app_api.php?ac=message_list    → 消息列表
  GET  /app_api.php?ac=message_summary → 消息统计
  POST /app_api.php?ac=message_read    → 标记已读
  POST /app_api.php?ac=message_read_all→ 全部已读
  POST /app_api.php?ac=message_delete  → 删除消息

【系统接口】
  GET  /app/page_setting → APP页面设置 (TabBar配置)

六、开发规范
────────────────────────────────────────

【代码规范】
  1. TypeScript严格模式，禁止any类型(特殊场景需注释说明)
  2. 每个文件头部添加开发者信息注释块
  3. 组件使用React.FC类型标注
  4. API函数统一返回null表示失败，而非抛出异常
  5. 使用cn()工具函数拼接className

【文件命名】
  组件文件: PascalCase (MovieCard.tsx, VideoPlayer.tsx)
  工具文件: camelCase (utils.ts)
  类型文件: camelCase (movie.ts)
  样式文件: 与组件同名 (MovieCard.css)

【组件规范】
  1. 每个组件一个文件夹，包含 .tsx 和 .css
  2. 通过统一index.ts导出
  3. Props通过interface定义，不内联
  4. 使用React.memo对展示组件做性能优化

【Git规范】
  feat: 新功能
  fix: 修复bug
  refactor: 代码重构
  style: 样式修改
  docs: 文档更新
`
