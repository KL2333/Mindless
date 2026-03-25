# 迁移执行指南

**完整改进计划** - 从现状到新架构的分步指南  
**总工时：** 12-18小时  
**风险等级：** 🟡 中等（可完全向后兼容）

---

## 📋 全流程概览

```
Week 1            Week 2             Week 3
┌─────────┐      ┌──────────┐      ┌──────────┐
│ Phase 1 │  →   │ Phase 2  │  →   │ Phase 3  │
│ i18n    │      │ 主题系统 │      │ 测试+优化│
└─────────┘      └──────────┘      └──────────┘
 4-5 hours       8-12 hours        2-4 hours
```

---

## 🔴 Phase 1: 国际化系统改造 (4-5小时)

### 任务 1.1: 创建i18n文件结构 (45min)

```bash
# 1. 创建assets目录
mkdir -p assets/i18n

# 2. 创建JSON文件（见IMPROVEMENT_I18N.md中的JSON内容）
# - assets/i18n/zh.json
# - assets/i18n/en.json
```

✅ **检查清单**
- [ ] JSON文件格式正确（用JSONLint验证）
- [ ] 所有键在两个文件中成对出现
- [ ] 颜色值为整数格式(0xFF...)

### 任务 1.2: 编写i18n管理器 (60min)

创建文件：`lib/services/i18n_manager.dart`

✅ **测试代码**
```dart
// 在main.dart中测试
void testI18n() async {
  await i18n.init('zh');
  assert(i18n.get('screens.today.title') == '今日');
  
  i18n.setLanguage('en');
  assert(i18n.get('screens.today.title') == 'Today');
  
  print('✅ i18n基础功能正常');
}
```

### 任务 1.3: 创建便利类L (45min)

创建文件：`lib/l10n/l10n.dart`（重写）

✅ **测试代码**
```dart
void testL() {
  L.setLanguage('zh');
  assert(L.screenTodayTitle == '今日');
  assert(L.get('screens.today.addHint') == '记录一件事…');
  
  print('✅ L访问类工作正常');
}
```

### 任务 1.4: 集成到main.dart (30min)

**修改 lib/main.dart**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 添加以下两行
  await L.init('zh');  // ✅ 新增
  await CrashLogger.init();
  
  // ... 其他初始化
}

class LiuShuiZhangApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    // 修改这行
    L.setLanguage(state.settings.lang);  // ✅ 改进
    
    // ... 后续代码
  }
}
```

### 任务 1.5: 验证和测试 (30min)

❌ **验证项**
```dart
// 运行以下测试确保没有破坏现有功能
flutter test test/i18n_test.dart

// 手动测试
1. 打开设置 → 语言选项
2. 切换 中文 ↔ English
3. 确保所有页面文本正确显示
4. 确保L.xxx快速访问都工作
```

✅ **成功标记**
- [ ] JSON文件在assets中
- [ ] i18n.dart能正确加载
- [ ] L类所有getters都工作
- [ ] 语言切换生效
- [ ] 没有崩溃或错误

---

## 🟡 Phase 2: 主题系统重构 (8-12小时)

### 任务 2.1: 创建主题目录结构 (30min)

```bash
# 1. 创建目录结构
mkdir -p lib/theme/themes
cd lib/theme/themes

# 2. 创建空文件表单
touch {
  base_theme.dart,
  core_colors.dart,
  standard_themes.dart,
  seasonal_themes.dart,
  festival_themes.dart,
  theme_registry.dart,
  theme_validator.dart
}
```

### 任务 2.2: 编写基础主题类 (90min)

创建文件：`lib/theme/themes/base_theme.dart`

代码参考：[IMPROVEMENT_THEME.md](./IMPROVEMENT_THEME.md) 步骤2

✅ **测试代码**
```dart
void testBaseTheme() {
  final warmTheme = WarmTheme();
  
  // 测试基础属性
  assert(warmTheme.name == '暖米');
  assert(warmTheme.bg == 0xFFF7F4EF);
  assert(warmTheme.tx == 0xFF2C2A26);
  
  // 测试转换
  final config = warmTheme.toThemeConfig();
  assert(config.name == '暖米');
  
  // 测试验证
  final issues = warmTheme.validate();
  print('Warm theme validation: ${issues.isEmpty ? "✅ Pass" : issues}');
}
```

### 任务 2.3: 提取共享调色板 (60min)

创建文件：`lib/theme/themes/core_colors.dart`

代码参考：[IMPROVEMENT_THEME.md](./IMPROVEMENT_THEME.md) 步骤3

✅ **断言检查**
```dart
void testCoreColors() {
  assert(CoreColors.warmBg == 0xFFF7F4EF);
  assert(CoreColors.tagColors.length == 8);
  print('✅ CoreColors 定义正确');
}
```

### 任务 2.4: 実装所有主题类 (4小时)

创建文件：
- `lib/theme/themes/standard_themes.dart` (7个基础主题)
- `lib/theme/themes/seasonal_themes.dart` (4个季节主题)
- `lib/theme/themes/festival_themes.dart` (4个节日主题)

✅ **检查清单**
每个主题需验证：
```dart
void validateTheme(BaseTheme theme) {
  // 1. 调用toThemeConfig()能返回ThemeConfig
  final config = theme.toThemeConfig();
  assert(config.name == theme.name);
  
  // 2. 所有颜色值都是有效的0xFFRRGGBB格式
  assert(theme.bg.toString().startsWith('0xFF'));
  
  // 3. tagColors有8个值
  assert(theme.tagColors.length == 8);
  
  // 4. 对比度检查
  final issues = theme.validate();
  if (issues.isNotEmpty) {
    print('⚠️ ${theme.name}: ${issues.join(", ")}');
  }
  
  print('✅ ${theme.name} theme OK');
}
```

### 任务 2.5: 创建主题注册表 (60min)

创建文件：`lib/theme/themes/theme_registry.dart`

代码参考：[IMPROVEMENT_THEME.md](./IMPROVEMENT_THEME.md) 步骤6

✅ **验证所有主题**
```dart
void testThemeRegistry() {
  // 1. 文件创建且所有21个主题都注册
  final allThemes = ThemeRegistry.getNames();
  print('总主题数: ${allThemes.length}');
  assert(allThemes.length == 21);
  assert(allThemes.contains('warm'));
  assert(allThemes.contains('dragon_boat'));
  
  // 2. 可转换为ThemeConfig
  for (final name in allThemes) {
    final config = ThemeRegistry.toThemeConfig(name);
    assert(config != null);
  }
  
  // 3. 颜色值与旧系统完全相同
  final oldWarm = kThemes['warm']!;
  final newWarm = ThemeRegistry.toThemeConfig('warm');
  assert(oldWarm.bg == newWarm.bg);
  assert(oldWarm.acc == newWarm.acc);
  assert(oldWarm.tagColors == newWarm.tagColors);
  
  print('✅ 主题注册表 OK');
}
```

### 任务 2.6: 集成到AppTheme (45min)

修改文件：`lib/theme/app_theme.dart`

```dart
// 改动最少：只需更改themeData()方法
import 'themes/theme_registry.dart';

static ThemeData themeData(String themeName) {
  final theme = ThemeRegistry.get(themeName);
  if (theme == null) {
    // 回退
    return themeData('warm');
  }
  
  final t = theme.toThemeConfig();
  
  // ... 保持其余的完全不变
}

static ThemeConfig of(String name) {
  final theme = ThemeRegistry.get(name);
  return theme?.toThemeConfig() ?? 
         ThemeRegistry.get('warm')!.toThemeConfig();
}
```

### 任务 2.7: 测试主题系统 (90min)

❌ **完整的主题切换测试**
```dart
void testThemeSwitching() {
  // 1. 所有主题可成功加载
  for (final name in ['warm', 'green', 'indigo', 'dark', 'dragon_boat']) {
    final data = AppTheme.themeData(name);
    assert(data != null);
    assert(data.scaffoldBackgroundColor != null);
  }
  
  // 2. 主题的Material 3 ColorScheme有效
  final warmTheme = AppTheme.themeData('warm');
  assert(warmTheme.colorScheme.primary != null);
  assert(warmTheme.colorScheme.onPrimary != null);
  
  // 3. 对比度检查
  ThemeRegistry.validateAll(); // 打印所有主题验证结果
  
  print('✅ 主题系统集成 OK');
}
```

✅ **手动测试**
```
1. 打开设置 → 外观 → 主题
2. 逐个选择所有21个主题
3. 检查：
   - 背景色正确
   - 按钮色正确  
   - 文本色正确
   - 无闪烁或渲染错误
4. 尝试深色模式切换
5. 检查所有页面主题一致性
```

---

## 🟢 Phase 3: 测试与优化 (2-4小时)

### 任务 3.1: 自动化测试 (90min)

创建文件：`test/architecture_test.dart`

```dart
void main() {
  group('Architecture Tests', () {
    test('i18n system', () {
      // 见上面的testI18n()示例
    });
    
    test('theme system', () {
      // 见上面的testThemeRegistry()示例
    });
    
    test('backward compatibility', () {
      // 确保旧代码仍然工作
      final oldWarm = kThemes['warm']!;
      final newWarm = ThemeRegistry.toThemeConfig('warm');
      expect(oldWarm.bg, equals(newWarm.bg));
    });
  });
}
```

运行测试：
```bash
flutter test test/architecture_test.dart
```

### 任务 3.2: 集成测试 (60min)

```dart
void testIntegration() {
  group('Integration Tests', () {
    testWidgets('Lang switching works', (tester) async {
      await tester.pumpWidget(const LiuShuiZhangApp());
      
      // 检查中文显示
      expect(find.text('今日'), findsOneWidget);
      
      // 导航到设置，切换到英文
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      
      // 切换语言
      // ... (细节省略)
      
      // 检查英文显示
      expect(find.text('Today'), findsOneWidget);
    });
    
    testWidgets('Theme switching works', (tester) async {
      await tester.pumpWidget(const LiuShuiZhangApp());
      
      // 导航到设置 → 主题
      // 选择'dragon_boat'主题
      // 验证UI更新
      
      // expect(...);
    });
  });
}
```

### 任务 3.3: 性能验证 (45min)

检查清单：
- [ ] App启动时间无明显增加（应 < 200ms额外延迟）
- [ ] 主题切换仍然流畅（无帧丢失）
- [ ] 语言切换无延迟
- [ ] 内存占用正常（JSON加载 < 500KB）

验证命令：
```bash
# 检查启动时间
flutter run --profile
# 在DevTools中查看Timeline

# 检查内存使用
flutter run --profile
# 在DevTools中查看Memory tab
```

### 任务 3.4: 文档和清理 (60min)

更新文档：
- [ ] [ARCHITECTURE_ASSESSMENT.md](./ARCHITECTURE_ASSESSMENT.md) - 标记完成
- [ ] [IMPROVEMENT_I18N.md](./IMPROVEMENT_I18N.md) - 补充实施细节
- [ ] [IMPROVEMENT_THEME.md](./IMPROVEMENT_THEME.md) - 补充实施细节
- [ ] 创建 [MIGRATION_CHECKLIST.md](./MIGRATION_CHECKLIST.md)

清理：
- [ ] 检查是否所有旧的l10n/l10n.dart中的getters都被新系统覆盖
- [ ] 检查是否有遗留的硬编码字符串未进i18n系统
- [ ] 验证git diff中没有意外的改动

---

## 🎯 验收标准

### ✅ Phase 1完成标准
- i18n系统成功初始化
- L类所有getters可用
- 语言切换生效
- 无错误或警告

### ✅ Phase 2完成标准
- 所有21个主题加载成功
- 主题配置与旧系统数值完全相同
- 主题切换正常
- 颜色对比度验证通过
- 代码重复率 < 20%

### ✅ Phase 3完成标准
- 自动化测试全部通过
- 集成测试全部通过
- 性能指标达标
- 文档完整

---

## 📊 工作量详表

| 任务 | 时间 | 完成度 |
|------|------|-------|
| 1.1 i18n文件结构 | 45 min | □ |
| 1.2 i18n管理器 | 60 min | □ |
| 1.3 L便利类 | 45 min | □ |
| 1.4 main.dart集成 | 30 min | □ |
| 1.5 验证测试 | 30 min | □ |
| **Phase 1 小计** | **210 min** | |
| 2.1 目录结构 | 30 min | □ |
| 2.2 BaseTheme | 90 min | □ |
| 2.3 CoreColors | 60 min | □ |
| 2.4 所有主题 | 240 min | □ |
| 2.5 ThemeRegistry | 60 min | □ |
| 2.6 AppTheme集成 | 45 min | □ |
| 2.7 主题测试 | 90 min | □ |
| **Phase 2 小计** | **615 min** | |
| 3.1 自动化测试 | 90 min | □ |
| 3.2 集成测试 | 60 min | □ |
| 3.3 性能验证 | 45 min | □ |
| 3.4 文档清理 | 60 min | □ |
| **Phase 3 小计** | **255 min** | |
| **总计** | **1080 min (18h)** | |

---

## ⚠️ 风险和缓解措施

| 风险 | 严重度 | 缓解措施 |
|------|--------|---------|
| JSON文件加载失败 | 🔴 | 添加try-catch，提供回退值 |
| 主题颜色不匹配 | 🟡 | 逐一验证每个主题值 |
| 性能下降 | 🟡 | JSON预加载，避免运行时解析 |
| 向后兼容性破裂 | 🔴 | 保留kThemes导出，使用adapter模式 |

---

## 📝 检查清单

### 前置条件
- [ ] 代码已备份或在版本控制中
- [ ] 没有未提交的改动
- [ ] CI/CD环境准备好

### Phase 1
- [ ] JSON文件创建且格式正确
- [ ] i18n_manager.dart编写并测试
- [ ] l10n.dart重写完成
- [ ] main.dart集成无错误
- [ ] 语言切换功能验证

### Phase 2
- [ ] 所有7个目录结构创建
- [ ] BaseTheme编写完成
- [ ] 21个主题全部定义
- [ ] ThemeRegistry注册完成
- [ ] AppTheme.themeData()集成
- [ ] 主题切换功能验证
- [ ] 对比度验证通过

### Phase 3
- [ ] 自动化测试全部通过
- [ ] 集成测试通过
- [ ] 性能验证通过
- [ ] 文档更新完成
- [ ] 代码审查通过

---

## 🚀 快速启动

**如果你现在就想开始，从这里开始：**

1. **今天(30分钟)**
   ```bash
   mkdir -p assets/i18n lib/theme/themes
   # 复制JSON文件到assets/i18n/
   ```

2. **明天(2小时)**
   ```bash
   # 编写i18n_manager.dart
   # 编写base_theme.dart
   ```

3. **后天(4小时)**
   ```bash
   # 定义所有主题
   # 创建ThemeRegistry
   ```

4. **集成+测试(2小时)**
   ```bash
   flutter test
   flutter run
   ```

**预计总时间：8-10小时**

---

## 🔗 参考链接

- [国际化系统详细方案](./IMPROVEMENT_I18N.md) - 完整代码示例
- [主题系统详细方案](./IMPROVEMENT_THEME.md) - 完整代码示例
- [总体架构评估](./ARCHITECTURE_ASSESSMENT.md) - 设计理由
