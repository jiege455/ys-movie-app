# Web端画中画(PiP)功能模块开发计划

根据您的需求，我将为根目录下的React项目开发一个基于现代Web API（Document Picture-in-Picture）的独立画中画模块。

> **特别说明**：此计划针对 `e:\phpstudy_pro\WWW\ys` 目录下的 **React/Web项目**，因为您要求的 TypeScript、BroadcastChannel、Jest 等技术栈仅适用于Web环境。如果您原本是想为 Flutter App 开发此功能，请告知，因为 Flutter 需要完全不同的实现方式（Dart/Kotlin/Swift）。

## 1. 模块架构设计

我们将创建一个完全解耦的 `src/lib/pip` 模块：

-   **`PiPManager.ts`**: 核心控制器（单例），负责窗口创建、DOM迁移、样式同步。
-   **`PiPChannel.ts`**: 通信层，封装 `BroadcastChannel` API，实现主窗口与PiP窗口的状态同步。
-   **`types.ts`**: 类型定义文件。
-   **`README.md`**: 模块使用文档和API说明。

## 2. 技术实现方案

### A. 核心功能 (PiPManager)
-   **API 选择**: 使用 Chrome 111+ 引入的 `Document Picture-in-Picture API` (`window.documentPictureInPicture`)，支持自定义 UI 和交互，优于传统的 `<video>` PiP。
-   **DOM 迁移**: 将现有的 `VideoPlayer` 组件 DOM 节点无损移动到新窗口，保持播放状态（无缝衔接）。
-   **样式同步**: 自动遍历主窗口的 `<style>` 和 `<link rel="stylesheet">`，克隆到 PiP 窗口，确保 UI 一致性。

### B. 跨窗口通信 (PiPChannel)
-   **机制**: 使用 `BroadcastChannel` 进行双向通信。
-   **同步数据**: 播放状态 (Play/Pause)、进度 (CurrentTime)、音量 (Volume)、播放源 (Source)。
-   **控制指令**: 主窗口控制条可控制 PiP 视频，PiP 窗口内的交互也能反馈给主逻辑。

### C. 组件改造
1.  **`VideoPlayer.tsx`**: 改造为 `forwardRef`，暴露内部的 `video` 元素和 `video.js` 实例，以便管理器操作 DOM。
2.  **`Player.tsx`**: 集成 `PiPManager`，添加“画中画”切换按钮，处理窗口关闭后的资源回收。

## 3. 质量保障

-   **测试框架**: 安装并配置 `Jest` + `ts-jest`。
-   **测试用例**: 编写 `PiPManager` 的单元测试，模拟窗口打开/关闭和消息发送。
-   **代码规范**: 严格遵循 TypeScript 类型安全，100% JSDoc 注释覆盖。

## 4. 实施步骤

1.  **环境配置**: 安装 Jest 测试依赖。
2.  **核心开发**:
    -   实现 `PiPChannel` 通信类。
    -   实现 `PiPManager` 窗口管理逻辑。
3.  **组件重构**:
    -   修改 `VideoPlayer.tsx` 暴露 Ref。
    -   在 `Player.tsx` 中接入 PiP 功能。
4.  **测试与验证**:
    -   编写测试用例。
    -   在 Chrome/Edge 中进行实机验证。
5.  **文档编写**: 生成 API 文档和使用示例。

请确认是否继续执行此 Web 端开发计划？