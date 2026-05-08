# 🎬 YS Movie App (狐狸影视)

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

一款基于 Flutter 开发的高颜值、功能强大的跨平台影视聚合 APP，完美对接 MacCMS10 后端。支持 Android 和 iOS 双端。

> **开发者**：杰哥  
> **QQ**：2711793818  
> **项目状态**：持续维护中 🚀

---

## ✨ 核心功能

*   **海量资源**：无缝对接 MacCMS10，支持电影、电视剧、综艺、动漫、短剧等多种分类。
*   **极致播放体验**：
    *   内置强大播放器，支持手势控制（左侧亮度、右侧音量、水平进度）。
    *   支持 **画中画 (PiP)** 模式，看剧聊天两不误。
    *   支持 **倍速播放** (0.5x - 3.0x)。
    *   支持 **DLNA 投屏**，一键投射到电视大屏。
*   **离线缓存**：支持 M3U8 视频下载，断点续传，随时随地离线观看。
*   **会员系统**：
    *   完整的用户注册/登录流程。
    *   积分系统、会员等级、观看权限控制。
    *   支持卡密充值或在线支付（需自行对接）。
*   **互动社区**：
    *   视频评论、弹幕互动。
    *   求片反馈、系统公告。
*   **多端适配**：完美适配各种尺寸的手机和平板设备。

---

## 🛠️ 技术栈

*   **框架**: Flutter (Dart)
*   **网络请求**: Dio + DioCookieManager
*   **状态管理**: Provider
*   **播放器**: Better Player (深度定制版) + Video Player
*   **本地存储**: SharedPreferences
*   **投屏**: dlna_dart
*   **其他**: Webview, ImagePicker, UrlLauncher 等

---

## 📂 目录结构

```
lib/
├── config.dart          # 全局配置文件 (修改 API 地址)
├── main.dart            # APP 入口
├── pages/               # 页面层
│   ├── home_page.dart   # 首页
│   ├── detail_page.dart # 视频详情页
│   ├── profile_page.dart# 个人中心
│   └── ...
├── services/            # 服务层
│   ├── api.dart         # API 接口封装 (核心)
│   ├── store.dart       # 数据存储
│   └── ...
├── widgets/             # 组件层
└── ...

backend/
└── app_api.php          # MacCMS 后端接口文件 (必须部署)

plugins/
└── better_player/       # 本地定制播放器插件
```

---

## 🚀 快速开始

### 1. 环境准备

确保本地已安装：
*   Flutter SDK (>=3.0.0)
*   Android Studio / VS Code
*   JDK 11+

### 2. 后端部署 (关键步骤)

本项目需要配合 MacCMS10 使用：

1.  将项目根目录下的 `backend/app_api.php` 文件上传至你的 MacCMS 网站 **根目录**。
2.  确保文件权限为 `644` 或 `755`。
3.  **宝塔面板用户注意**：
    *   如果配置了伪静态，请确保不拦截 `app_api.php`。
    *   无需额外配置跨域，接口文件已内置 CORS 头。

### 3. 前端配置

打开 `lib/config.dart`，修改你的站点地址：

```dart
class AppConfig {
  // 修改为你的 MacCMS 域名，必须带 http/https，不能以 / 结尾
  static const String baseUrl = 'http://your-domain.com/api.php';
  
  static const String appName = '你的APP名称';
}
```

### 4. 运行与打包

```bash
# 获取依赖
flutter pub get

# 运行调试 (Android)
flutter run

# 打包 Release APK
flutter build apk --release
```

---

## 🔐 密钥与安全 (重要)

请注意以下两类密钥的安全，**严禁将包含真实密钥的文件上传到公共仓库！**

### 1. 仓库管理密钥 (app_api.php)

`backend/app_api.php` 文件中包含一个 **管理接口密钥**，用于控制索引重建和数据更新。默认值为 `c71dce53653260a4`。

**⚠️ 警告：**
*   **必须修改**：部署到服务器前，请务必将 `app_api.php` 中的 `$key` 变量修改为复杂的随机字符串。
*   **防止恶意调用**：此 Key 保护了 `buildIndex` 和 `update` 等高权限接口，泄漏可能导致数据风险或服务器负载过高。

### 2. Android 签名密钥 (key.properties)

如果你需要打包正式发布的 APK，需要配置签名密钥。

*   **生成密钥**：使用 Android Studio 或 keytool 生成 `upload-keystore.jks` 文件。
*   **配置文件**：在 `android/` 目录下创建 `key.properties`，内容如下：
    ```properties
    storePassword=你的密钥库密码
    keyPassword=你的密钥密码
    keyAlias=你的密钥别名
    storeFile=你的密钥文件路径 (例如 ../upload-keystore.jks)
    ```
*   **Git 忽略**：本项目已在 `.gitignore` 中忽略了 `key.properties` 和 `*.jks`，请勿手动强制提交。

### 3. 在线打包与 GitHub 同步密钥 (Cloud.php)

如果你使用了 MacCMS 后台的 **在线打包** 功能，并配置了自动同步到 GitHub 仓库，相关密钥存储在以下文件中：

*   **文件位置**: `maccms10-master/addons/jgapp/src/jgappapi/Cloud.php`
*   **用途**: 存储 GitHub Personal Access Token (PAT)，用于授权在线打包服务 (`api.jgapp.tv`) 将构建结果推送回你的 GitHub 仓库。
*   **⚠️ 绝对机密**:
    *   此文件包含你的 GitHub 核心权限，**绝对不能** 分发给客户或上传到公共仓库。
    *   如果你是分发插件给客户，打包前 **必须删除** 此文件。
    *   如果你在本地开发，请确保 `.gitignore` 包含了此文件（或手动不要提交它）。

---

## 📝 常见问题

**Q: 首页加载失败？**  
A: 请检查 `lib/config.dart` 中的 `baseUrl` 是否正确，并确保 `app_api.php` 已上传到服务器且能通过浏览器直接访问 (例如访问 `http://域名/app_api.php` 应该返回 API Ready)。

**Q: 视频无法播放？**  
A: 请检查视频源是否支持跨域，或者是否为有效直链。部分加密资源可能需要特定的解析接口支持。

**Q: 投屏搜不到设备？**  
A: 确保手机和电视连接在同一个 WiFi 网络下。

---

## 🤝 贡献与反馈

欢迎提交 Issue 或 Pull Request。
如有定制开发需求，请联系开发者：**杰哥 (QQ: 2711793818)**。

---

**By 杰哥**
