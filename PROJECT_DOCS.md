# 项目结构与部署文档
by：杰哥 qq： 2711793818
创建日期：2025-12-27

本文档详细说明了项目的目录结构、各文件用途以及在宝塔面板上的部署流程。

## 1. 项目概览

本项目是一个基于 **Flutter** 开发的影视 APP 客户端，配合 **ThinkPHP (苹果CMS)** 后端 API 运行。

*   **前端 (APP)**: `ys_movie_app` (Flutter 项目)
*   **后端 (API/CMS)**: `maccms10-master` (PHP 项目)

---

## 2. 前端项目结构 (ys_movie_app)

位于 `ys_movie_app/` 目录下。

### 2.1 核心目录 `lib/`

*   **`main.dart`**: 程序入口文件，初始化应用、路由配置、全局 Provider。
*   **`config.dart`**: 全局配置文件，包含 API 基础地址、常量定义等。

#### `lib/pages/` (页面层)
*   `main_page.dart`: 底部导航栏主页，管理首页、排行、我的等 Tab 切换。
*   **`home_page.dart`**: **首页**。展示轮播图、分类推荐、热播视频等。
*   **`detail_page.dart`**: **视频详情页**。包含播放器、选集、简介、猜你喜欢。
*   `vod_list_page.dart`: 视频分类列表页（如筛选电影、电视剧）。
*   `search_page.dart`: 搜索页面，包含热搜词和搜索结果。
*   `ranking_page.dart`: 排行榜页面。
*   `topic_page.dart`: 专题页面。
*   `week_page.dart`: 节目表/更新时间表。
*   `find_link_page.dart`: 发现/短视频/外链页面（如有）。
*   **`profile_page.dart`**: **个人中心**。展示用户信息、历史记录入口、设置入口等。
*   `user_center_pages.dart`: 用户中心相关子页面（如修改资料）。
*   `login_page.dart` / `register_page.dart`: 登录与注册页面。
*   `auth_bottom_sheet.dart`: 底部弹出的登录/注册快捷窗口。
*   `history_page.dart`: 观看历史记录页面。
*   `download_page.dart`: 离线缓存/下载管理页面。
*   `feedback_center_page.dart`: 求片/反馈中心页面。
*   `settings_page.dart`: 设置页面（清除缓存、版本检查等）。

#### `lib/services/` (服务与逻辑层)
*   **`api.dart`**: 封装 HTTP 请求，处理与后端苹果 CMS 的 API 通信（登录、获取视频、评论等）。
*   `store.dart`: 本地存储服务（基于 `SharedPreferences`），保存用户 Token、历史记录等。
*   `m3u8_downloader_service.dart`: 视频下载服务，处理 M3U8 流媒体下载。
*   `player_settings.dart`: 播放器配置服务。
*   `theme_provider.dart`: 主题状态管理（深色/浅色模式）。

#### `lib/widgets/` (组件层)
*   **`flick_custom_controls.dart`**: 自定义的播放器控制栏（横竖屏切换、进度条、倍速、选集等）。
*   `custom_player_controls.dart`: 旧版或通用的播放器控件。

### 2.2 其他重要目录
*   `pubspec.yaml`: 项目依赖管理文件（引入第三方库）。
*   `android/`: Android 原生工程配置（签名、包名、权限）。
*   `assets/`: 静态资源（图片、图标）。

---

## 3. 后端项目结构 (maccms10-master)

位于 `maccms10-master/` 目录下，是标准的苹果 CMS v10 结构。

*   `application/`: 核心逻辑代码（MVC 架构）。
*   `template/`: 网站模板。
*   `static/`: 静态资源（JS/CSS）。
*   `api.php`: API 接口入口。
*   `admin.php`: 后台管理入口。
*   `index.php`: 网站首页入口。

---

## 4. 部署流程 (宝塔面板)

### 4.1 后端部署 (PHP)

1.  **创建站点**:
    *   在宝塔面板 -> 网站 -> 添加站点。
    *   域名填写你的域名（或 IP）。
    *   PHP 版本选择 **7.0 - 7.4** (推荐 7.2)。
    *   数据库选择 MySQL。

2.  **上传源码**:
    *   将 `maccms10-master` 文件夹内的所有文件上传到站点根目录。

3.  **配置伪静态**:
    *   在站点设置 -> 伪静态 -> 选择 `thinkphp` -> 保存。

4.  **安装系统**:
    *   访问 `http://你的域名/install.php`。
    *   按照提示填写数据库信息（在宝塔数据库菜单查看）。
    *   安装完成后，建议修改后台入口文件名（将 `admin.php` 改为其他名字以提高安全性）。

5.  **开放 API**:
    *   进入苹果 CMS 后台 -> 系统 -> 开放 API 配置 -> 开启 API 接口。

### 4.2 前端部署 (Flutter APP)

1.  **配置 API 地址**:
    *   打开 `ys_movie_app/lib/config.dart` (或 `api.dart`)。
    *   找到 `baseUrl` 或类似变量，将其修改为你刚刚部署的后端域名。
    *   例如：`static const String baseUrl = 'http://你的域名/api.php/provide/vod/';`

2.  **编译 APK (Android)**:
    *   确保本地已安装 Flutter 环境和 Android SDK。
    *   在 `ys_movie_app` 目录下打开终端。
    *   运行命令：
        ```bash
        flutter build apk --release
        ```
    *   编译完成后，APK 文件位于 `build/app/outputs/flutter-apk/app-release.apk`。

3.  **分发安装包**:
    *   将生成的 `app-release.apk` 上传到宝塔网站目录（例如 `/download` 目录）。
    *   用户可以通过链接 `http://你的域名/download/app-release.apk` 下载安装。

4.  **编译 Web 版 (可选)**:
    *   运行命令：`flutter build web --release`
    *   将 `build/web` 目录下的所有文件上传到宝塔的一个新站点（或子目录）。
    *   注意：Web 版可能需要配置 Nginx 解决跨域问题或路由问题。

---

## 5. 常见问题

*   **图片加载失败**: 检查后端是否开启了防盗链，或者前端 `Info.plist` / `AndroidManifest.xml` 是否配置了网络权限（默认已配置）。
*   **视频无法播放**: 检查视频源是否支持跨域 (CORS)，或者是否是有效链接。
*   **登录失败**: 检查后端 API 是否正常，以及前端 API 地址是否填写正确。

