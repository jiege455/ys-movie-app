# 项目开发规范 (Project Rules)

## 开发者信息
- 开发者：杰哥网络科技 (qq: 2711793818)
- 每个页面/组件文件头部必须添加开发者备注注释块
- 页面样式需与系统整体保持统一的蓝黑主题风格

## 技术栈
- 前端：React 19 + TypeScript 5.8 + Vite 6 + Zustand + Tailwind CSS 3
- 视频播放器：video.js 8.x
- 后端：PHP + MacCMS(苹果CMS) API
- 移动端：Flutter (ys_movie_app/)

## 代码规范
1. TypeScript 严格模式，所有类型从 `src/types/` 集中导入
2. 组件统一放在 `src/components/`，通过 index.ts 导出
3. 页面统一放在 `src/pages/`，通过 index.ts 导出
4. API 请求统一放在 `src/api/`，通过 index.ts 导出
5. 状态管理统一放在 `src/store/`，通过 index.ts 导出
6. 禁止在 api/、store/ 中重复定义类型，统一从 types/ 导入
7. 组件文件命名：PascalCase（如 MovieCard.tsx）
8. 工具文件命名：camelCase（如 utils.ts）
9. 每个文件的类型导入单独分组
10. 使用 cn() 工具函数拼接 className（来自 lib/utils.ts）

## 样式规范
1. 使用 Tailwind CSS 工具类，避免内联 style
2. 通用玻璃效果使用 .glass / .glass-light / .glass-card
3. 颜色采用蓝黑主题：bg-slate-900, bg-cyan-*, text-cyan-*
4. 响应式优先移动端，使用 sm: md: lg: 断点

## 架构层次
```
types/     ← 类型定义（唯一数据源）
api/       ← 接口封装（调用后端 API）
store/     ← 状态管理（Zustand 仓库）
lib/       ← 工具函数（纯函数）
components/← 通用组件（可复用 UI）
pages/     ← 页面组件（路由级）
routes/    ← 路由配置（导航管理）
```

## 错误处理
1. API 函数统一 try/catch，失败返回 null
2. 页面级使用 ErrorBoundary 包裹
3. 组件内部使用 isMountedRef 防止内存泄漏

## 部署相关
- 使用宝塔面板管理 Nginx 配置
- 后端 PHP 文件放在网站根目录
- 前端构建产物放在 dist/ 目录
- Nginx 配置参考 nginx_baota.conf

## 构建命令
- 开发模式：npm run dev
- 构建生产：npm run build
- 类型检查：npx tsc -b --noEmit
- 代码检查：npm run lint

## ⚠️ 编码安全铁律（血的教训，必须遵守！）

### 背景
历史上多次因为编码损坏导致 CI 编译失败，损失大量时间。根本原因是 AI 编辑工具在 Windows 上可能以错误编码写入文件。

### 铁律 1：严禁修改包含中文的文件时不验证编码
- **每次修改 `.dart`/`.tsx`/`.ts`/`.php` 文件后，必须执行以下验证**：
  1. 检查文件是否为纯 UTF-8（无 BOM）：`python -c "open('file.dart','rb').read()[:3]"` 不应输出 `efbbbf`
  2. 全仓库扫描破损字符串：执行 `python scan_broken_strings.py` 确保输出 `SCAN COMPLETE` 且无问题
  3. 全仓库扫描注释吞代码：确保 `///` 或 `//` 行不含 Dart/TS 关键字

### 铁律 2：编码损坏的三大症状
1. **注释吞代码**：`// 中文?  void myMethod()` — 方法声明和注释在同一行，被编译器忽略
2. **字符串引号丢失**：`Text('乱码中文?)` — 闭合单引号 `'` (0x27) 被损坏为 `?` (0x3F)
3. **UTF-8 BOM 残留**：文件头三个字节是 `EF BB BF`，导致部分编译器报错

### 铁律 3：修复方法
- **禁止**用 SearchReplace 修编码问题（乱码文本无法精准匹配）
- **必须**用 Python 字节级脚本操作：读 `rb` → 定位 `0x27` 位置 → 替换为正确中文 → 写 `wb`
- 备用文件（如 `api_backup.dart`）可不修，但不能被 import

### 铁律 4：提交前检查
```bash
# Flutter 文件检查
cd ys_movie_app
python scan_broken_strings.py   # 应输出 "SCAN COMPLETE" 且无其他

# 前端文件检查  
cd ..
npx tsc -b --noEmit 2>&1 | head -20
npm run build 2>&1 | tail -5
```

## 添加新功能流程
1. 先在 types/ 定义所需类型
2. 在 api/ 封装新接口
3. 在 store/ 添加状态（如需要）
4. 在 components/ 创建新组件（如需要）
5. 在 pages/ 创建新页面
6. 在 routes/ 注册路由
7. 执行编码安全检查（见上方铁律）
8. 验证类型检查和构建
