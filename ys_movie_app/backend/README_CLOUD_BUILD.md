# ☁️ 云端打包系统使用说明

**开发者：杰哥网络科技 (qq: 2711793818)**

## 系统概述

此系统基于 **GitHub Actions** 实现免费的云端APK构建：
- ✅ GitHub Actions对**公开仓库完全免费**，无额度限制
- ✅ **源码不会暴露在GitHub仓库中**，构建时从外部服务器下载
- ✅ 用户在MacCMS后台一键打包，直接下载APK

## 文件说明

| 文件 | 说明 |
|------|------|
| `cloud_build.php` | 核心API接口，处理打包请求 |
| `cloud_build.yml` | GitHub Actions工作流模板 |
| `download_source.php` | 源码下载接口（带鉴权） |
| `cloud_build_admin.html` | 后台管理页面 |
| `cloud_build.sql` | 数据库表结构 |

## 部署步骤

### 1. 创建GitHub模板仓库

1. 登录你的GitHub账号
2. 创建一个新的**公开仓库**，例如 `flutter-build-template`
3. 将 `cloud_build.yml` 上传到 `.github/workflows/` 目录
4. 提交并推送

### 2. 配置服务器

1. **创建源码包**：
   ```bash
   # 将你的Flutter项目打包为zip
   cd ys_movie_app
   zip -r ../flutter_app_source.zip . -x "build/*" -x ".git/*"
   ```

2. **上传到服务器**：
   - 将 `flutter_app_source.zip` 上传到服务器
   - 确保 `download_source.php` 中的 `$config['source_path']` 指向正确路径

3. **修改配置**：
   编辑 `cloud_build.php`，填写以下配置：
   ```php
   $githubConfig = [
       'token' => 'ghp_你的GitHubToken',  // GitHub Personal Access Token
       'template_owner' => '你的GitHub用户名',
       'template_repo' => 'flutter-build-template',
       'source_url' => 'https://你的域名.com/download_source.php',
       'source_token' => '设置一个随机字符串作为下载鉴权Token',
   ];
   ```

4. **修改下载接口配置**：
   编辑 `download_source.php`：
   ```php
   $config = [
       'token' => '与cloud_build.php中相同的source_token',
       'source_path' => '/正确的路径/flutter_app_source.zip',
   ];
   ```

### 3. 创建数据库表

在MacCMS数据库中执行 `cloud_build.sql`

### 4. 测试

1. 访问 `cloud_build_admin.html`
2. 填写APP配置
3. 点击"开始打包"
4. 等待构建完成，下载APK

## GitHub Token获取方法

1. 登录GitHub → Settings → Developer settings → Personal access tokens
2. 点击 "Generate new token (classic)"
3. 勾选以下权限：
   - `repo` (完整仓库权限)
   - `workflow` (Actions工作流权限)
4. 生成后复制Token，填入配置

## 安全说明

1. **源码安全**：完整Flutter源码只存在于你的服务器和GitHub Actions运行时内存中，不会提交到GitHub仓库
2. **Token安全**：GitHub Token请妥善保管，不要泄露
3. **下载鉴权**：源码下载接口带有Token鉴权和IP限流，防止恶意下载

## 工作原理

```
MacCMS后台
    ↓ 用户填写配置，点击打包
cloud_build.php
    ↓ 调用GitHub API，从模板仓库创建新仓库
    ↓ 上传build_config.json（配置信息）
    ↓ 触发GitHub Actions工作流
GitHub Actions
    ↓ 读取build_config.json
    ↓ 从服务器下载Flutter源码（带鉴权）
    ↓ 替换APP名称、包名、版本、API地址等配置
    ↓ 构建Release APK
    ↓ 上传APK到GitHub Release
    ↓ 删除源码（安全清理）
用户
    ↓ 查询构建状态
    ↓ 从GitHub Release下载APK
```

## 常见问题

**Q: 构建失败怎么办？**
A: 查看GitHub Actions日志，通常是Flutter环境问题或配置错误。

**Q: 可以构建iOS吗？**
A: 可以，需要修改工作流使用macOS runner，并配置iOS签名。

**Q: 构建后的仓库会自动删除吗？**
A: 当前版本不会自动删除，你可以手动删除或添加自动清理逻辑。
