# 流水账 (Liushuizhang) 项目接手与开发指南

欢迎接手 **“流水账”** 项目。这是一个基于 Flutter 构建的高效任务管理与番茄钟专注工具，深度集成了 **Liquid Glass (iOS 26 风格)** 视觉语言。

## 1. 项目概览

- **核心定位**：任务清单 + 四象限管理 + 番茄钟专注 + 统计分析。
- **技术栈**：
    - **框架**：Flutter (SDK >= 3.3.0)
    - **状态管理**：`provider` (全局状态位于 [app_state.dart](file:///d:/jkk/lsz_v2_fix/lib/providers/app_state.dart))
    - **设计规范**：Material 3 + 自定义 Liquid Glass 渲染引擎。
    - **多语言**：支持中英双语 (资源位于 `assets/i18n/`)。

## 2. 核心视觉系统：Liquid Glass

项目最显著的特点是其 **Liquid Glass (液态玻璃)** 风格。这不仅是简单的磨砂效果，而是追求极高通透感、物理折射和边缘高光的视觉体系。

- **核心组件**：[liquid_glass_refractor.dart](file:///d:/jkk/lsz_v2_fix/lib/widgets/liquid_glass_refractor.dart)。所有需要玻璃效果的容器（顶栏、底栏、四象限格子、任务项）均应使用此组件包裹。
- **动态调节**：
    - **通透感**：用户可在“设置 > 时钟样式”中动态调节玻璃的通透程度（从磨砂到究极透明）。
    - **顶栏间距**：支持调节主内容区与悬浮顶栏的垂直偏移（包括负值重叠）。
- **设计手册**：更详细的物理参数和视觉规范请参阅 [LIQUID_GLASS_MANUAL.md](file:///d:/jkk/lsz_v2_fix/LIQUID_GLASS_MANUAL.md)。

## 3. 关键代码目录说明

- `lib/models/`：定义了任务 (`TaskModel`)、设置 (`AppSettings`) 等核心数据模型。
- `lib/providers/`：项目大脑。`AppState` 负责处理所有业务逻辑、持久化存储以及主题配置。
- `lib/screens/`：
    - `today_screen.dart`：今日任务视图。
    - `quadrant_screen.dart`：四象限管理视图（已全面 Liquid Glass 化）。
    - `pomodoro_screen.dart`：番茄钟专注界面。
    - `settings_screen.dart`：包含 UI 定制、间距调节等高级功能。
- `lib/widgets/`：存放通用的 UI 单元，如 `GlobalWallpaperLayer` (全局壁纸层)。

## 4. 最近的重要更新 (Handover Notes)

1.  **端午主题恢复**：已恢复“端午荷塘”主题的内置背景图加载逻辑 ([assets/dragon_boat_bg.jpg](file:///d:/jkk/lsz_v2_fix/assets/dragon_boat_bg.jpg))。
2.  **UI 布局重构**：为了增大视觉面积，应用启用了 `extendBody` 和 `extendBodyBehindAppBar`，使内容能够延伸至透明悬浮栏下方。
3.  **圆角精简化**：根据用户反馈，缩小了四象限页面元素的圆角（格子 `16.0`，任务项 `8.0`），使界面更加干练。

## 5. 开发与编译

- **获取依赖**：`flutter pub get`
- **编译调试 APK**：`flutter build apk --debug`
- **注意事项**：由于使用了复杂的 `BackdropFilter` 和动画，修改 UI 时务必注意使用 `RepaintBoundary` 以保证渲染性能。

---
*愿你在维护这个项目的过程中，也能感受到“究极通透”的开发体验。*
