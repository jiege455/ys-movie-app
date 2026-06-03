# 项目说明（狐狸影视 App）

## 一、项目概览

- **项目类型**：Flutter 影视 App（前端），后端为 **MacCMS10**（通过 `api.php` 和自定义 `app_api.php` 提供 JSON 接口）
- **主要功能**：
  - 首页推荐、分类筛选、排行榜
  - 搜索影片、查看详情、播放视频
  - 选集、多线路切换、弹幕、评论
  - 收藏、播放历史、本地缓存下载
  - 反馈报错、求片、消息中心、个人中心
- **主要技术栈**：
  - `Flutter` + `Dart`
  - 状态管理：`provider`
  - 网络：`dio`
  - 播放器：`video_player` + `chewie`
  - 本地存储：`shared_preferences`

## 二、目录结构与主要文件用途

### 1. 根目录

- `pubspec.yaml`  
  - Flutter 依赖管理文件，声明所有三方包和 SDK 版本。
- `config.dart`  
  - 全局配置类 `AppConfig`，配置后端 `baseUrl`（MacCMS 的 `api.php` 地址）。
- `README.md`  
  - 原始项目的简要说明。
- `user_rules.md`（当前文件）  
  - 给 AI 工具阅读的项目说明与约定，描述项目结构、用途和部署流程。

### 2. `lib/` 目录

- `main.dart`  
  - 应用入口，创建 `MacApi` 的全局 `Provider`，配置路由，启动 `MainPage` 作为首页。

- `config.dart`  
  - 定义 `AppConfig.baseUrl`，用于配置后端 API 地址。更换服务器时只需要修改此处。

#### 2.1 服务层 `lib/services/`

- `services/api.dart`  
  - 封装所有与 MacCMS10 通信的 HTTP 接口：  
    - APP 初始化（banner、推荐、分类）  
    - 筛选、搜索、排行榜  
    - 影片详情与播放列表解析  
    - 用户登录、注册、收藏、历史记录同步  
    - 评论、弹幕、反馈、求片、消息列表等
- `services/store.dart`  
  - 使用 `shared_preferences` 封装本地存储：  
    - 本地收藏列表  
    - 本地播放历史（含进度秒数）  
    - 本地缓存下载记录（保存本地文件路径）  

#### 2.2 页面层 `lib/pages/`

- `main_page.dart`  
  - App 主框架，底部 `BottomNavigationBar` 包含：首页、排行榜、我的。

- `home_page.dart`  
  - 首页 Tab 结构，包含：  
    - 顶部轮播图（banner）  
    - 推荐影片列表  
    - 分类 Tab + 筛选 + 分页加载  

- `ranking_page.dart`  
  - 排行榜页面：日榜、周榜、月榜切换，展示热门影片。

- `search_page.dart`  
  - 搜索页面：热搜词展示、搜索结果列表，点击进入详情。

- `detail_page.dart`  
  - 影片详情主页面：  
    - 视频播放器区域（播放、倍速、片头片尾设置、弹幕开关）  
    - 标题、年份、地区、分类、简介（可展开收起）  
    - 功能按钮：收藏、下载、分享、催更、片头片尾设置  
    - Tab：选集 / 评论  
    - 选集列表、多线路切换、展开全部集数  
    - 评论列表、评论输入、弹幕发送入口  
    - 相关推荐网格列表  

- `history_page.dart`  
  - 播放记录页面：展示本地历史记录，点击可继续观看。

- `vod_list_page.dart`  
  - 通用视频列表页面：用于“我的收藏”“我的缓存”等，接收通用 `items` 列表。

- `profile_page.dart`  
  - “我的”个人中心页面：  
    - 顶部头像、登录状态、积分等  
    - 中间是观看历史缩略图横向列表  
    - 下方九宫格功能：收藏、缓存、求片、反馈、消息中心、分享、检查升级、清理缓存  

- `login_page.dart`  
  - 独立登录页面：用户名+密码，调用 `MacApi.login`，成功后返回个人中心。

- `register_page.dart`  
  - 注册页面：注册新账号并自动登录。

- `feedback_center_page.dart`  
  - 反馈中心页面集合：  
    - 反馈报错  
    - 求片找片  
    - 消息中心  

### 3. 播放器相关（简要）

- 播放器实现集中在 `detail_page.dart` 内部：  
  - 使用 `VideoPlayerController` 加载网络视频  
  - 使用 `ChewieController` 提供基础播放控件  
  - 自定义逻辑：  
    - 播放进度监听 + 自动下一集  
    - 片头/片尾跳过秒数设置  
    - 播放速度设置  
    - 画中画小窗模式（在详情页内缩小播放器）  
    - 弹幕覆盖层、弹幕开关、发送弹幕  

## 三、部署流程（后端 + 前端）

### 1. 后端（MacCMS10）部署步骤（适配宝塔）

1. 在宝塔面板中创建站点，将 MacCMS10 程序上传并解压。  
2. 根据官方安装流程初始化数据库、后台账号。  
3. 确保网站可通过 `http://域名/api.php` 或 `https://域名/api.php` 访问。  
4. 将提供的 `backend/app_api.php` 文件上传到网站根目录（与 `api.php` 同级）：  
   - 该文件提供 App 专用 JSON 接口（用户登录/注册、评论、弹幕等）。  
5. 在 MacCMS 后台安装/启用与本 App 兼容的 JSON 插件（如 GetApp 插件），并开启跨域/APP 接口权限。  

### 2. 前端（Flutter App）部署与配置

1. 在 `lib/config.dart` 中配置你的后端地址：  
   ```dart
   static const String baseUrl = 'https://你的域名/api.php';
   ```  
2. 在 Windows 上安装 Flutter 开发环境与 Android SDK（若仅打包可简化）。  
3. 在项目根目录执行依赖安装：  
   ```bash
   flutter pub get
   ```  
4. 运行静态检查（可选，但推荐）：  
   ```bash
   flutter analyze
   ```  
5. 打包 Android 安装包（Release）：  
   ```bash
   flutter build apk --release
   ```  
   编译成功后，安装包路径为：  
   `build/app/outputs/flutter-apk/app-release.apk`  

6. 将生成的 `app-release.apk` 通过数据线、APK 分发平台或网页下载的方式安装到 Android 手机上测试。  

## 四、当前开发进度（概览）

- ✅ 首页（轮播、推荐、分类筛选）已完成。  
- ✅ 排行榜（天/周/月）已完成。  
- ✅ 搜索功能（热搜 + 结果列表）已完成。  
- ✅ 详情页：播放、简介、选集、评论、相关推荐功能已实现，正在持续优化 UI 布局和交互。  
- ✅ 本地收藏、播放历史、缓存下载逻辑已实现。  
- ✅ 反馈报错、求片、消息中心基础功能已接通。  
- ✅ “我的”个人中心页面整体 UI 已搭建，登录 / 注册 / 云端同步已打通。  
- 🔄 播放器 UI 仍在对齐参考截图：  
  - 细节包括：画中画按钮布局、弹幕入口位置、选集/评论 Tab 的样式与位置等。  

> 说明：  
> 本文件主要面向 AI 辅助工具和后续开发者，用于快速理解项目结构、后端依赖与打包流程。  
> 若需调整服务器地址、接口路径或 UI 风格，请优先检查 `config.dart`、`services/api.dart` 和 `lib/pages` 下对应页面。

