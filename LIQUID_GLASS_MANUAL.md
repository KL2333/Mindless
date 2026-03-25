# Liquid Glass 设计与使用规范手册 (iOS 26 Style)

Liquid Glass 是一种强调通透感、液态流动性和物理折射模拟的 UI 设计语言。它超越了传统的磨砂玻璃（Material Design Glassmorphism），追求更清澈的视觉体验和更锐利的边缘特征。

## 1. 核心设计原则

### 1.1 极致通透感 (Ultimate Transparency)
*   **原则**：追求“清澈见底”的视觉体验，背景内容应几乎无损地透过玻璃。支持用户动态调节通透度。
*   **参数**：
    *   `BackdropFilter` 的 `sigma` 值应严格控制在 `1.0` 到 `15.0` 之间，默认偏向低模糊。
    *   容器表面的 `Color` 属性 Alpha 值应极低（`0.01 - 0.10`），确保光线穿透。

### 1.2 动态边缘与高光 (Dynamic Edge & Highlights)
*   **原则**：边缘应作为视觉辅助而非视觉焦点，其强度应随通透度动态变化。
*   **参数**：
    *   `BorderWidth`：动态范围 `0.5` - `2.0`。
    *   `BorderGradient`：使用 135° 线性渐变，起始点不透明度动态范围 `0.1 - 0.6`，终点 `0.02 - 0.1`。
    *   `Internal Reflection`：内部反射弧线偏移 `2px`，不透明度动态范围 `0.1 - 0.4`。

### 1.3 几何形态 (Geometry)
*   **原则**：圆角应干练、适度，避免过度膨胀感。
*   **参数**：
    *   核心悬浮栏（顶栏/底栏）：`45.0`。
    *   内容卡片/四象限格子：`16.0`。
    *   小型项目/任务项：`8.0`。

### 1.4 色彩动力学 (Color Dynamics)
*   **原则**：禁止使用纯色背景，必须具备动态的非匀质感。
*   **参数**：通过 `SweepGradient` 或 `RadialGradient` 配合低频率动画（约 `0.5Hz`）实现背景色的轻微位移。容器表面的 `Color` 属性 Alpha 值应极低（约 `0.05 - 0.1`）。

## 2. 组件使用指南 (Flutter 实现)

在代码中，应统一使用 `LiquidGlassRefractor` 组件来包裹需要玻璃化处理的内容。

### 2.1 基础用法
```dart
LiquidGlassRefractor(
  borderRadius: 45.0, // 设定圆角
  baseColor: Colors.blue, // 基础色调（会自动应用极低透明度）
  child: YourContent(), // 内部内容
)
```

### 2.2 性能规范
*   **隔离重绘**：由于 `BackdropFilter` 渲染开销较大，所有 Liquid Glass 组件必须使用 `RepaintBoundary` 包裹。
*   **预设 Painter**：在 `CustomPainter` 中预设 `Paint` 对象，避免在 `paint` 方法中频繁实例化。

## 3. 页面适配准则

### 3.1 紧贴原则 (Tight Fit)
内容列表应紧贴悬浮的 Liquid Glass 栏位。例如，列表的顶部 `padding` 应精确等于 `AppBar高度 + 边缘Margin`，不留额外空隙。

### 3.2 边缘强调 (Edge Emphasis)
在复杂背景下（如壁纸），应通过增加边框宽度和对比度来确保 Liquid Glass 容器的可读性。
