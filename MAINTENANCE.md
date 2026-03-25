# 流水账·Mindless 项目维护手册

> 本文档由 Claude 维护，记录项目规范、操作规则和架构决策。
> 最后更新：β.0.082

---

## 一、版本管理规则

每次改动后必须同步更新以下四处，缺一不可：

| 文件 | 位置 | 操作 |
|------|------|------|
| `pubspec.yaml` | `version: 1.0.0+N` | BUILD_NUMBER +1 |
| `settings_screen.dart` | `关于 · β.0.XXX` 文字 | 同步新版本号 |
| `settings_screen.dart` | `'β.0.XXX'` 字符串（About徽章） | 同步新版本号 |
| `settings_screen.dart` | `_changelog` 列表顶部 | 新增条目 |
| `share_card.dart` | footer 版本字符串 | 同步新版本号 |

### 更新日志规则

- 每次发版必须在 `_changelog` 顶部新增当前版本条目，**不允许跳版本更新**（如从 β.0.057 直接写 β.0.059，中间的 β.0.058 必须有记录）。
- 每个版本条目至少包含 **4 条**描述，说明本次改动的内容、文件、技术细节。
- 条目格式：`('β.0.XXX', '年月', ['改动1', '改动2', ...])`。

### 未来更新方向规则

- 每次发版时，在 `_RoadmapPage._sections` 中至少**新增或更新 4 条**未来更新方向，反映最新规划。
- 已完成的功能状态从「正在实现」移入 `_installed` 已实装板块（不在 _sections 中保留）。

---

## 二、Roadmap 与已实装管理规则

### 状态标签体系

| 标签 | 含义 |
|------|------|
| `正在实现` | 已立项开发中（功能存在于代码中但仍在迭代）|
| `计划中` | 已纳入 backlog，待排期 |
| `研究中` | 方向确定，方案/API 仍在调研 |
| `远期` | 无明确时间表 |

> ⚠️ **原「✅已完成」标签已废弃**，改为「正在实现」。

### 已实装板块规则

- **已实装** = 功能已完成开发、测试通过、正式对用户可用，不再迭代核心逻辑。
- 已实装功能的格式：`('功能名', '简要描述', 'β.X.XXX')` — 第三个字段为首次实装的版本号。

### β实验室 → 设置开关 迁移规则

- β实验室的开关是"试验性"的，供开发期测试用。
- 当"我"明确指示将某功能「实装」时：
  1. 将该功能从 `_BetaRow`（β实验室）删除；
  2. 在「设置」页对应功能区（如「番茄钟设置」「通知设置」）新增正式的 Switch 开关；
  3. 在 Roadmap `_installed` 列表中添加该功能条目；
  4. 功能的开关逻辑和 AppSettings 字段保持不变，只是 UI 归属发生变化。

---

## 三、代码架构速查

### 关键文件路径

| 文件 | 职责 |
|------|------|
| `lib/models/models.dart` | 数据模型：TaskModel、AppSettings、PomSettings、ThemeConfig（15套主题）|
| `lib/providers/app_state.dart` | 全局状态 ChangeNotifier，toggleTask、updatePomSettings 等 |
| `lib/screens/today_screen.dart` | 今日任务页 |
| `lib/screens/quadrant_screen.dart` | 四象限页 |
| `lib/screens/stats_screen_new.dart` | 统计页（Bento 砖块仪表盘）|
| `lib/screens/pomodoro_screen.dart` | 番茄钟主界面 |
| `lib/screens/pomodoro_ambient.dart` | 番茄钟息屏模式 |
| `lib/screens/settings_screen.dart` | 设置页（含 changelog、roadmap）|
| `lib/widgets/share_card.dart` | 一键分享卡片（截图+分享）|
| `lib/services/environment_sound_service.dart` | 环境声分析服务 |
| `lib/services/distraction_detector.dart` | 娱乐App干扰检测 |
| `lib/services/pom_engine.dart` | 番茄钟计时引擎 |
| `lib/services/notification_service.dart` | 通知服务（含插件损坏降级逻辑）|
| `android/.../MainActivity.kt` | 原生 Android 通道实现 |

### 原生 MethodChannel / EventChannel 一览

| Channel | 类型 | 用途 |
|---------|------|------|
| `com.lsz.app/usage_stats` | MethodChannel | 屏幕使用时长统计 |
| `com.lsz.app/device_info` | MethodChannel | 设备信息 |
| `com.lsz.app/live_update` | MethodChannel | 番茄钟常驻通知 |
| `com.lsz.app/notif_repair` | MethodChannel | 通知插件损坏修复、原生通知降级 |
| `com.lsz.app/keepalive` | MethodChannel | WakeLock 保持屏幕常亮 |
| `com.lsz.app/weather` | MethodChannel | 和风天气 API |
| `com.lsz.app/pom_alarm` | MethodChannel | 番茄钟阶段结束铃声+震动+置顶 |
| `com.lsz.app/audio_noise` | MethodChannel | 麦克风单次快照（1.5s，pomodoro采样）|
| `com.lsz.app/audio_noise_stream` | EventChannel | 麦克风实时流（每秒推送一个dB，共30次）|
| `com.lsz.app/share` | MethodChannel | 截图分享 |
| `com.lsz.app/foreground_app` | MethodChannel | 前台App检测（干扰提醒）|

---

## 四、已知常见错误与修复方案

### 1. `DistractionDetector._dismissAlert` → `Missing type parameter`

**原因**：`flutter_local_notifications` 插件的 SharedPreferences 缓存损坏，`.cancel()` 时尝试反序列化失败。

**修复**：`_dismissAlert` 中 try-catch 静默吞掉异常（通知有 `autoCancel: true`，用户点击后自动消失）；`_sendAlert` 中降级到原生通道 `com.lsz.app/notif_repair` 的 `showNative` 方法。

**防复发**：每次 App 启动时 `NotificationService` 会调用 `clearScheduledData` 清理损坏缓存，并切换到原生通道。

### 2. `_PomodoroAmbientScreenState.dispose` → Null check / context.read crash

**原因**：`dispose()` 调用 `context.read<AppState>()` 时 Widget 已从树上卸载，`Element.widget` 为 null。

**修复**：在 `initState()` 中缓存 `_engine = context.read<AppState>().engine`，`dispose()` 改为 `_engine.phaseJustCompleted.removeListener(_onPhase)`。

**原则**：`dispose()` 中严禁使用 `context.read` / `context.watch`，所有需要的引用必须在 `initState` 时缓存到实例字段。

### 3. 息屏模式退出后 App 内亮度不恢复

**原因**：`dispose()` 为同步方法，内部的 `_restoreBrightness()` async Future 在 Widget 销毁后才执行，此时插件已无法操作 Activity。

**修复**：`_exit()` 改为 async，先 `await _restoreBrightness()`，再 `await ScreenBrightness().resetScreenBrightness()`（释放插件亮度锁），最后 `Navigator.pop()`。

---

## 五、环境声分析架构说明

### 数据流

```
用户点击「测量」
  └─> _NoisePageState._startMeasure()
       ├─> 订阅 EnvironmentSoundService.liveDbStream（EventChannel）
       │    每秒收到一个 Double dB 值 → 更新 _liveReadings → 刷新 _LiveDbMeter UI
       └─> 30秒后 onDone 回调
            └─> EnvironmentSoundService.buildReportFromReadings() → 持久化 → 刷新历史
```

### SessionNoiseReport.source 字段

| 值 | 来源 |
|----|------|
| `'manual'` | 统计页手动 30s 测量 |
| `'pomodoro'` | 番茄钟自动抽样（每5分钟一次快照）|

智能建议（`NoiseHistoryStore.buildInsight()`）**仅使用 `source='pomodoro'` 数据**，手动测量不纳入智能分析。

---

## 六、分享卡片单日模式规则

- `isSingleDay = periodDays.length == 1`（任意单日，不限今天）
- 单日时：柱状图显示 anchorDate 前推 7 天的窗口
- 柱状图高亮 = anchorDate（非系统今天）
- Header 日期 = anchorDate（非系统今天）
- 今天分享 → 标签「今日完成」；历史分享 → 「当日完成」


---

## 七、节日主题制作标准流程

每次新增节日主题皮肤，必须完成以下所有步骤，缺一不可。

---

### 第一步：确定节日信息

在动手写代码前，先整理以下资料：

| 项目 | 内容 |
|------|------|
| 节日名称 | 中文全称，如「世界水日」 |
| 主题 key | snake_case，如 `world_water_day` |
| 日期类型 | 固定日期（精确到月日）或浮动日期（农历/规则日） |
| 代表 emoji | 1个，用于日历卡片和详情页 Hero |
| 一句话 tagline | 不超过20字，传达节日精神 |
| 详细介绍 | 2–4段，含节日起源/意义/全球影响/与个人生活的联系 |
| 有趣事实 | 3–5条，数据型或反常识型，令人印象深刻 |
| 主题设计说明 | 解释主色/辅色/背景色的选色理由，与节日意象的对应关系 |

---

### 第二步：设计 ThemeConfig 配色

在 `lib/models/models.dart` 的 `kThemes` Map 中添加新主题。**配色设计原则：**

- **`acc`（主色）**：节日最具代表性的颜色，饱和度适中（不宜过亮），用于按钮/强调/进度条
- **`acc2`（辅色）**：与主色形成呼应或渐变，用于次级强调
- **`bg`（背景）**：极淡的主色调，通常是主色的5–10%透明度叠白
- **`card`（卡片）**：纯白或极接近纯白，保证内容可读
- **`tx`（主文字）**：接近黑色，略带主色调（深蓝/深棕等）
- **`ts`（次要文字）**：主色调的中深色版本
- **`tm`（辅助文字）**：主色调的浅色版本
- **`brd`（边框）**：bg 的稍深版，用于卡片边框
- **`tagColors`**：8个标签色，第1-2个与主题色一致，其余覆盖色彩轮

**示例（世界水日）：**
```dart
'world_water_day': ThemeConfig(
  name: '世界水日',
  bg:   0xFFEFF7FB,  // 水雾蓝白
  card: 0xFFFFFFFF,
  tx:   0xFF0A2840,  // 深海蓝黑
  ts:   0xFF2E6E8E,  // 海蓝
  tm:   0xFF7AAEC8,  // 水蓝
  acc:  0xFF0E86B4,  // 深邃海蓝（主色）
  acc2: 0xFF38C4C8,  // 清澈水绿（辅色）
  // ... 其他字段
)
```

---

### 第三步：注册节日日历数据

在 `lib/services/festival_calendar.dart` 的 `kFestivals` 列表中添加 `FestivalInfo` 条目：

```dart
FestivalInfo(
  id:          'world_water_day',   // 必须与 kThemes key 完全一致
  name:        '世界水日',
  emoji:       '💧',
  month:       3,
  day:         22,                  // 浮动节日 day = -1，并填写 dayLabel
  tagline:     '水是生命之源，保护水资源从每一滴开始',
  description: '...2–4段详细介绍...',
  themeReason: '...配色设计说明...',
  facts: [
    '...事实1...',
    '...事实2...',
    // 3–5条
  ],
),
```

---

### 第四步：接入自动推荐逻辑

在 `lib/models/models.dart` 的 `seasonalThemeSuggestion()` 函数中添加触发条件：

```dart
// 固定日期节日（精确匹配）
if (m == 3 && d == 22) return 'world_water_day';

// 日期范围节日
if (m == 1 || m == 2) return 'lunar_new_year';

// 浮动节日（若无法精确计算，可留给用户手动选择，不加自动推荐）
```

**规则：**
- 精确日期节日**必须**在季节判断之前，避免被春夏秋冬覆盖
- 多个节日同一天时，以更具代表性的为准
- 浮动节日（如农历节日）若无法精确到公历日期，可不加自动推荐，但仍需在日历中显示

---

### 第五步：更新主题页分组

在 `settings_screen.dart` 的 `_SeasonalThemePage._groups` 中，把新主题 key 加入对应分组：

- **传统节日**（`lunar_new_year`, `mid_autumn` 等）
- **世界节日**（`world_water_day` 等联合国/国际节日）

如有新分组，新建一个 `('🌍 分组名', ['key1', 'key2'])` 条目。

---

### 第五步（补充）：主题要彻底——不只是换颜色

> **核心原则（来自用户需求，写入规范）：**
> 节日主题必须做到「一眼看上去，除了颜色之外，哪哪都不一样」。
> 仅仅改变配色是不够的，必须同时替换图标、形状语言、装饰元素、动画风格、文字措辞，
> 让用户感受到这是一套完全不同的「皮肤」，而不只是调了个调色板。

**必须替换/定制的非颜色元素：**

| 元素 | 替换方式 |
|------|----------|
| **底部导航图标** | 节日专属 emoji 或 Icon，如水日用 💧/🌊，春节用 🏮/🧧 |
| **AppBar 标题装饰** | 节日当天在 App 名称旁加节日 emoji 徽章 |
| **番茄钟圆环** | 节日配色替换圆环颜色，息屏模式粒子特效改为节日主题（水日=水波/气泡，春节=烟花/灯笼） |
| **任务完成动画** | 节日专属完成特效（水日=水滴落下，春节=彩带+鞭炮）|
| **按钮形状** | 节日主题可改变按钮圆角半径（水日=更圆润像水滴，冬雪=尖角如冰晶）|
| **分隔线/边框样式** | 节日主题可将直线改为波浪线（水日）、虚线（冰雪）等 |
| **背景纹理** | 可选：节日主题加微妙背景纹理（水日=极淡水波纹，春节=极淡云纹）|
| **时段标签文字** | 节日当天可替换时段文字，如水日「上午」→「晨露」「午间」→「水光」「晚上」→「夜潮」|
| **激励语风格** | 节日当天 `_getRobotGreeting` 加节日专属问候语开头 |
| **设置页图标** | 节日主题下设置各分区的图标可替换为节日相关 emoji |

**实现策略：**
- 轻量级替换优先：时段文字/emoji/问候语改动成本低，必须做
- 中等成本：息屏特效、完成动画，在现有 `_AmbientFxPainter` 框架内扩展
- 可选高成本：背景纹理、按钮形状，仅在重要节日实现

**代码实现方式：**
```dart
// 在需要节日定制的地方，通过 getTodayFestival() 判断：
final festival = getTodayFestival();
final isWaterDay = festival?.id == 'world_water_day';

// 例如时段标签替换：
String blockLabel(String block) {
  if (isWaterDay) {
    return block == 'morning' ? '🌊 晨露' : block == 'afternoon' ? '💧 午间' : '🌙 夜潮';
  }
  return block == 'morning' ? '🌅 上午' : ...;
}
```

### 第六步：全局样式替换检查

切换为新主题后，依次检查以下界面元素是否视觉协调：

| 界面 | 检查点 |
|------|--------|
| 今日页 | 输入框边框/focus 光晕、标签 chip、添加按钮、时段标题色 |
| 统计页 | Bento 砖块背景、进度条颜色、热力图主题色 |
| 番茄钟 | 圆环主色、息屏模式背景色、心流指数颜色 |
| 底部导航 | 选中态颜色、指示器 |
| AppBar | 背景/文字/图标颜色一致性 |
| 分享卡片 | 柱状图 / 完成率环颜色是否跟随主题 |

如发现节日主题下某个元素颜色「突兀」（如深色主题文字用了浅色背景的色值），需在 ThemeConfig 中微调对应字段。

---

### 第七步：在关于页更新节日介绍

`_AboutScreen` → 「节日日历」入口 → `_FestivalCalendarPage` 自动列出所有 `kFestivals` 节日，**无需手动修改**。

`_FestivalDetailPage` 自动渲染：
- Hero 区（emoji + 名称 + 日期 + tagline）
- 节日简介（description，支持 `\n\n` 分段）
- 有趣事实（facts，带编号圆圈）
- 主题配色说明（themeReason + 三色圆形色块）
- 启用主题按钮

---

### 第八步：版本更新

按照「一、版本管理规则」完成四处同步，changelog 必须包含：
1. 新增 `主题名` ThemeConfig 配色说明（主色/辅色/背景色十六进制）
2. `festival_calendar.dart` 新增 FestivalInfo 条目
3. `seasonalThemeSuggestion()` 触发条件（精确日期或日期范围）
4. 主题页分组归属
5. 任何主题视觉微调说明

---

### 快速检查清单

```
□ kThemes 中新增 ThemeConfig（配色完整，16个字段 + tagColors[8]）
□ kFestivals 中新增 FestivalInfo（id/name/emoji/month/day/tagline/description/themeReason/facts）
□ seasonalThemeSuggestion() 加入触发条件（精确日期在前）
□ _SeasonalThemePage._groups 加入对应分组
□ 切换主题后全局视觉检查（6个界面）
□ 关于页节日日历自动显示（无需改动）
□ changelog 更新（4条以上）
□ 版本号四处同步
```

---

## 八、更新日志写作规范（强制）

> **背景**：历史上曾出现以下严重问题，导致用户对版本历史完全失去信任：
> - β.0.052–β.0.059 整段缺失，β.0.066–β.0.078 整段缺失
> - 最新版本条目被反复改名（把别的版本改名成当前版本号），而不是新增
> - β.0.079 被插入到 β.0.065 和 β.0.051 之间，顺序完全错乱
> - 部分版本只有 1–2 条描述，其余版本有 7–8 条，标准极不一致
>
> 以下规范**强制执行**，没有例外。

---

### 8.1 写入时机：每次完成需求就写，当场写

**绝对不允许事后补写**。每一个独立需求完成、版本号 +1 时，立刻在同一次操作里把 changelog 写进去。

❌ 错误做法：
```
// 先 bump 版本号
sed -i 's/β.0.065/β.0.066/' ...
// 忘了写 changelog，下次再补
```

✅ 正确做法：
```python
# bump 版本号 + 写 changelog 在同一个代码块里完成
sed -i 's/β.0.065/β.0.066/' ...
python3 << 'EOF'
entry = """    ('β.0.066', '2026-03', [
      '改动1...',
      '改动2...',
      '改动3...',
      '改动4...',
    ]),
"""
# 插入到 _changelog 顶部
EOF
```

---

### 8.2 插入位置：必须插入到列表最顶部

`_changelog` 列表**倒序排列**，最新版本在最前面。每次新增必须插在已有内容**之前**。

❌ 错误：把新版本条目改名放在原有条目的位置上
❌ 错误：把新版本条目追加到列表末尾
✅ 正确：新版本条目 → 插入到 `static const List<...> _changelog = [` 的下一行

```dart
static const List<(String, String, List<String>)> _changelog = [
    ('β.0.079', '2026-03', [   // ← 最新版本在这里
      '...',
    ]),
    ('β.0.078', '2026-03', [   // ← 上一版本
      '...',
    ]),
    // ... 以此类推
```

---

### 8.3 版本号严格连续，不允许跳号

每一个 BUILD_NUMBER 必须在 `_changelog` 里有对应条目，**一个都不能少**。

- β.0.065 之后下一条必须是 β.0.066，不能是 β.0.067 或其他
- 如果某版本只是编译修复（1行改动），也必须单独写一条记录
- **永远不要把别的版本号改名成当前版本号**，这会覆盖历史记录

检查方法（发版前必须运行）：
```python
import re
c = open('lib/screens/settings_screen.dart').read()
versions = sorted([int(m.group(1)) for m in re.finditer(r"    \('β\.0\.(\d+)'", c)])
current = max(versions)
missing = [v for v in range(min(versions), current+1) if v not in versions]
if missing:
    print("ERROR: 缺失版本", missing)  # 必须为空才能发版
```

---

### 8.4 每个版本条目至少 4 条，内容要有实质意义

**数量要求**：每个版本条目 `List<String>` 至少 4 条，编译修复版本最少 1 条（说明修复了什么）。

**质量要求**：每条描述必须包含：
1. **做了什么**（功能/修复/重构）
2. **改动了哪个文件/类/方法**（具体位置）
3. **技术细节**（如算法/参数/颜色值/行为变化）

❌ 不合格示例：
```
'修复了一个bug',
'更新了UI',
'新增功能',
```

✅ 合格示例：
```
'_DeepFocusBrick 从 cols:2 rows:1 改为 cols:1 rows:2，内容重排为次数+建议时长大字+24h热力条+洞察文字卡',
'新增 _FlowBrick（1×1）：FocusQualityService.avgFlowIndex() 异步加载，阶段emoji+均值大字+_MiniSparkPainter 折线',
```

---

### 8.5 条目文字不得含有未转义的特殊字符

条目是 Dart 单引号字符串，以下字符必须转义或避免：

| 字符 | 处理方式 |
|------|----------|
| `'`（单引号） | 改为 `\'` |
| `\n`（换行） | 用 `\\n` 或直接不写换行 |
| `\`（反斜杠） | 用 `\\` |
| `{` `}`（大括号） | 直接使用，不影响 Dart 编译，但 **Python 朴素计数会误判**，不影响实际编译 |

用 Python 写入时，字符串内的 `\n` 必须用 `\\n`：
```python
entry = """    ('β.0.072', '2026-03', [
      '端午节主题dragon_boat：荷塘碧绿(#2A9C72)×荷白绿',   # ✅
      '说明文字第一行\\n第二行',  # ✅ 用 \\n 而不是真实换行
    ]),
"""
```

---

### 8.6 发版完整流程（按顺序执行，不得跳步）

```
1. 完成需求的代码改动
2. 验证功能正确（目测/测试）
3. pubspec.yaml: version: 1.0.0+N → 1.0.0+(N+1)
4. settings_screen.dart: 「关于 · β.0.XXX」文字 → 新版本号
5. settings_screen.dart: 'β.0.XXX' 字符串（About徽章）→ 新版本号
6. settings_screen.dart: _changelog 顶部插入新条目（≥4条，编译修复≥1条）
7. share_card.dart: footer 版本字符串 → 新版本号
8. MAINTENANCE.md: 最后更新版本 → 新版本号
9. 运行版本连续性检查脚本（见 8.3）
10. 打包 zip
```

**6步之前不能打包**。打包前必须先完成 changelog。

---

### 8.7 审查清单（每次发版前自查）

```
□ pubspec.yaml version 已更新
□ 关于页版本号已更新（共2处：文字+徽章）
□ share_card.dart footer 版本号已更新
□ _changelog 顶部有当前版本条目
□ 当前版本条目 ≥ 4 条（编译修复除外）
□ 当前版本号 = 上一条目版本号 + 1（无跳号）
□ 条目内容有文件名/类名/具体技术细节
□ 条目文字无未转义单引号/真实换行符
□ Python 版本连续性检查通过（missing = []）
□ MAINTENANCE.md 已更新
```

