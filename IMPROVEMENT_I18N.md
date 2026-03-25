# 国际化系统改进方案

**目标：** 从硬编码静态存储改为灵活的JSON+管理器系统  
**工作量：** 4-6小时  
**复杂度：** ⭐⭐ 简单

---

## 改进概述

### 当前问题
```dart
// ❌ 问题：每次新增翻译都要改代码，且易遗漏英文
class L {
  static String get today => _s('今日', 'Today');
  static String get quadrant => _s('四象限', 'Matrix');
  // ... 60多个getters，维护困难
}
```

### 改进后效果
```dart
// ✅ 优点：纯配置，支持IDE提示，支持参数，支持嵌套路径
L.today;           // '今日'
L.get('screens.today.addHint');  // '记录一件事…'
L.common.hello({'name': 'Alice'}); // '你好，Alice'
```

---

## 实现步骤

### 步骤1: 创建JSON翻译文件

**文件：`assets/i18n/zh.json`**
```json
{
  "screens": {
    "today": {
      "title": "今日",
      "addHint": "记录一件事…",
      "addTomorrow": "计划明日一件事…",
      "noTasks": "今日暂无待办"
    },
    "quadrant": {
      "title": "四象限",
      "description": "拖拽分配任务优先级"
    },
    "stats": {
      "title": "统计",
      "vitalityTitle": "时段活力分析",
      "deviationTitle": "预估偏差曲线"
    },
    "pomodoro": {
      "title": "番茄钟",
      "start": "开始",
      "pause": "暂停",
      "resume": "继续",
      "reset": "重置"
    },
    "settings": {
      "title": "设置",
      "appearance": "外观",
      "language": "语言"
    }
  },
  "common": {
    "save": "保存",
    "cancel": "取消",
    "delete": "删除",
    "add": "添加",
    "edit": "编辑",
    "close": "关闭",
    "ok": "确定",
    "error": "错误",
    "success": "成功"
  },
  "time": {
    "morning": "上午",
    "afternoon": "下午",
    "evening": "晚上",
    "today": "今日",
    "tomorrow": "明日"
  },
  "blocks": {
    "morning": {
      "name": "上午",
      "emoji": "🌅",
      "color": 4285476906
    },
    "afternoon": {
      "name": "下午",
      "emoji": "☀️",
      "color": 3869860544
    },
    "evening": {
      "name": "晚上",
      "emoji": "🌙",
      "color": 4030806328
    }
  },
  "metadata": {
    "language": "zh",
    "region": "CN",
    "version": "1.0"
  }
}
```

**文件：`assets/i18n/en.json`**
```json
{
  "screens": {
    "today": {
      "title": "Today",
      "addHint": "Add a task…",
      "addTomorrow": "Plan for tomorrow…",
      "noTasks": "No tasks today"
    },
    "quadrant": {
      "title": "Matrix",
      "description": "Drag to assign task priority"
    },
    "stats": {
      "title": "Stats",
      "vitalityTitle": "Vitality by slot",
      "deviationTitle": "Plan vs Actual"
    },
    "pomodoro": {
      "title": "Focus",
      "start": "Start",
      "pause": "Pause",
      "resume": "Resume",
      "reset": "Reset"
    },
    "settings": {
      "title": "Settings",
      "appearance": "Appearance",
      "language": "Language"
    }
  },
  "common": {
    "save": "Save",
    "cancel": "Cancel",
    "delete": "Delete",
    "add": "Add",
    "edit": "Edit",
    "close": "Close",
    "ok": "OK",
    "error": "Error",
    "success": "Success"
  },
  "time": {
    "morning": "Morning",
    "afternoon": "Afternoon",
    "evening": "Evening",
    "today": "Today",
    "tomorrow": "Tomorrow"
  },
  "blocks": {
    "morning": {
      "name": "Morning",
      "emoji": "🌅",
      "color": 4285476906
    },
    "afternoon": {
      "name": "Afternoon",
      "emoji": "☀️",
      "color": 3869860544
    },
    "evening": {
      "name": "Evening",
      "emoji": "🌙",
      "color": 4030806328
    }
  },
  "metadata": {
    "language": "en",
    "region": "US",
    "version": "1.0"
  }
}
```

### 步骤2: 创建i18n管理器类

**文件：`lib/services/i18n_manager.dart`**
```dart
import 'dart:convert';
import 'package:flutter/services.dart';

/// 国际化管理器 - 支持嵌套路径、参数插值、动态语言切换
class I18nManager {
  static final I18nManager _instance = I18nManager._();
  
  factory I18nManager() => _instance;
  
  I18nManager._();
  
  Map<String, dynamic> _zhData = {};
  Map<String, dynamic> _enData = {};
  String _currentLang = 'zh';
  
  /// 初始化：从assets加载翻译文件
  Future<void> init(String? initialLang) async {
    _currentLang = initialLang ?? 'zh';
    
    try {
      // 加载中文
      final zhJson = await rootBundle.loadString('assets/i18n/zh.json');
      _zhData = jsonDecode(zhJson) as Map<String, dynamic>;
      
      // 加载英文
      final enJson = await rootBundle.loadString('assets/i18n/en.json');
      _enData = jsonDecode(enJson) as Map<String, dynamic>;
      
      print('[I18n] ✅ Loaded zh (${_zhData.length} keys) & en');
    } catch (e) {
      print('[I18n] ❌ Failed to load i18n files: $e');
      _zhData = {};
      _enData = {};
    }
  }
  
  /// 设置当前语言
  void setLanguage(String lang) {
    if (lang != 'zh' && lang != 'en') {
      print('[I18n] ⚠️ Unsupported language: $lang, fallback to zh');
      _currentLang = 'zh';
    } else {
      _currentLang = lang;
    }
  }
  
  /// 获取当前语言
  String get currentLanguage => _currentLang;
  
  /// 获取翻译：支持嵌套路径 e.g. 'screens.today.title'
  /// 支持参数插值 e.g. 'Hello, {name}'
  String get(String key, [Map<String, dynamic>? params]) {
    final data = _currentLang == 'zh' ? _zhData : _enData;
    final result = _getNestedValue(data, key) ?? key; // fallback to key
    
    // 参数插值
    if (params != null && result is String) {
      var text = result;
      params.forEach((k, v) {
        text = text.replaceAll('{$k}', v.toString());
      });
      return text;
    }
    
    return result is String ? result : key;
  }
  
  /// 内部：获取嵌套值 (e.g. screens.today.title)
  dynamic _getNestedValue(Map<String, dynamic> data, String path) {
    final keys = path.split('.');
    dynamic current = data;
    
    for (final key in keys) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null; // path not found
      }
    }
    
    return current;
  }
  
  /// 检查键是否存在 (用于调试)
  bool has(String key) {
    final data = _currentLang == 'zh' ? _zhData : _enData;
    return _getNestedValue(data, key) != null;
  }
  
  /// 列出所有键 (用于调试/IDE提示生成)
  List<String> allKeys({bool recurse = true}) {
    final keys = <String>[];
    void collect(Map<String, dynamic> map, String prefix) {
      map.forEach((k, v) {
        final fullKey = prefix.isEmpty ? k : '$prefix.$k';
        if (v is Map<String, dynamic> && recurse) {
          collect(v, fullKey);
        } else if (v is String) {
          keys.add(fullKey);
        }
      });
    }
    collect(_zhData, '');
    return keys;
  }
}

// 单例实例
final i18n = I18nManager();
```

### 步骤3: 创建便利访问类（带IDE提示）

**文件：`lib/l10n/l10n.dart`（重写）**
```dart
import '../services/i18n_manager.dart';

/// 国际化便利类，提供快速访问和IDE智能提示
class L {
  // 静态访问函数 (支持嵌套路径和参数)
  static String get(String key, [Map<String, dynamic>? params]) {
    return i18n.get(key, params);
  }
  
  // ────────────────────────────────────────────────────────
  // 屏幕标签 (IDE 智能提示)
  // ────────────────────────────────────────────────────────
  
  static String get screenTodayTitle => i18n.get('screens.today.title');
  static String get screenTodayAddHint => i18n.get('screens.today.addHint');
  static String get screenTodayAddTomorrow => i18n.get('screens.today.addTomorrow');
  static String get screenTodayNoTasks => i18n.get('screens.today.noTasks');
  
  static String get screenQuadrantTitle => i18n.get('screens.quadrant.title');
  static String get screenQuadrantDesc => i18n.get('screens.quadrant.description');
  
  static String get screenStatsTitle => i18n.get('screens.stats.title');
  static String get screenStatsVitalityTitle => i18n.get('screens.stats.vitalityTitle');
  static String get screenStatsDeviationTitle => i18n.get('screens.stats.deviationTitle');
  
  static String get screenPomodoroTitle => i18n.get('screens.pomodoro.title');
  static String get screenPomodoroStart => i18n.get('screens.pomodoro.start');
  static String get screenPomodoroPause => i18n.get('screens.pomodoro.pause');
  static String get screenPomodoroResume => i18n.get('screens.pomodoro.resume');
  static String get screenPomodoroReset => i18n.get('screens.pomodoro.reset');
  
  static String get screenSettingsTitle => i18n.get('screens.settings.title');
  static String get screenSettingsAppearance => i18n.get('screens.settings.appearance');
  static String get screenSettingsLanguage => i18n.get('screens.settings.language');
  
  // ────────────────────────────────────────────────────────
  // 通用文本 (IDE 智能提示)
  // ────────────────────────────────────────────────────────
  
  static String get commonSave => i18n.get('common.save');
  static String get commonCancel => i18n.get('common.cancel');
  static String get commonDelete => i18n.get('common.delete');
  static String get commonAdd => i18n.get('common.add');
  static String get commonEdit => i18n.get('common.edit');
  static String get commonClose => i18n.get('common.close');
  static String get commonOk => i18n.get('common.ok');
  static String get commonError => i18n.get('common.error');
  static String get commonSuccess => i18n.get('common.success');
  
  // ────────────────────────────────────────────────────────
  // 时间相关 (IDE 智能提示)
  // ────────────────────────────────────────────────────────
  
  static String get timeMorning => i18n.get('time.morning');
  static String get timeAfternoon => i18n.get('time.afternoon');
  static String get timeEvening => i18n.get('time.evening');
  static String get timeToday => i18n.get('time.today');
  static String get timeTomorrow => i18n.get('time.tomorrow');
  
  // ────────────────────────────────────────────────────────
  // 时段块定义
  // ────────────────────────────────────────────────────────
  
  static Map<String, Map<String, dynamic>> get blocks => {
    'morning': {
      'name': i18n.get('blocks.morning.name'),
      'emoji': i18n.get('blocks.morning.emoji'),
      'color': i18n.get('blocks.morning.color'),
    },
    'afternoon': {
      'name': i18n.get('blocks.afternoon.name'),
      'emoji': i18n.get('blocks.afternoon.emoji'),
      'color': i18n.get('blocks.afternoon.color'),
    },
    'evening': {
      'name': i18n.get('blocks.evening.name'),
      'emoji': i18n.get('blocks.evening.emoji'),
      'color': i18n.get('blocks.evening.color'),
    },
  };
  
  // ────────────────────────────────────────────────────────
  // 设置当前语言 (从AppState调用)
  // ────────────────────────────────────────────────────────
  
  static Future<void> init(String lang) => i18n.init(lang);
  static void setLanguage(String lang) => i18n.setLanguage(lang);
}
```

### 步骤4: 集成到main.dart

**文件：`lib/main.dart`（修改）**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CrashLogger 最早初始化...
  await CrashLogger.init();
  
  // ✅ 新增：初始化i18n系统
  await L.init('zh'); // 从AppSettings加载lang会在buildState中调用setLanguage
  
  // 其他初始化...
  // ...
  
  runApp(ChangeNotifierProvider(
    create: (_) => AppState()..load(),
    child: const LiuShuiZhangApp(),
  ));
}
```

**在LiuShuiZhangApp.build中**
```dart
@override
Widget build(BuildContext context) {
  final state = context.watch<AppState>();
  
  // ✅ 改进：在此处设置当前语言
  L.setLanguage(state.settings.lang);
  
  // 后续代码...
}
```

### 步骤5: 迁移现有代码

**示例：从旧代码迁移**

❌ 旧代码（lib/screens/today_screen.dart）
```dart
Text(L.today, style: ...),
Text(L.addHint, style: ...),
import '../l10n/l10n.dart';
```

✅ 新代码
```dart
Text(L.screenTodayTitle, style: ...),
Text(L.screenTodayAddHint, style: ...),
import '../l10n/l10n.dart';
```

或支持新方式
```dart
Text(L.get('screens.today.title'), style: ...),
Text(L.get('screens.today.addHint'), style: ...),
```

### 步骤6: 配置Flutter资源

**文件：`pubspec.yaml`（修改）**
```yaml
flutter:
  uses-material-design: true
  
  assets:
    - assets/about_icon.png
    - assets/dragon_boat_bg.jpg
    - assets/i18n/zh.json        # ✅ 新增
    - assets/i18n/en.json        # ✅ 新增
```

---

## 新系统优点

### 1. 可扩展性 ✅
```dart
// 支持第三种语言只需新增json文件和一行代码
// assets/i18n/ja.json
// _jaData = jsonDecode(await rootBundle.loadString('assets/i18n/ja.json'));
```

### 2. IDE智能提示 ✅
```dart
// 编辑器会自动列出所有可用的getters
L.screen[Tab + Enter]  // IDE shows all 30+ statically defined getters
L.common[Tab + Enter]  // IDE shows all common keys
```

### 3. 参数支持 ✅
```dart
// 添加新翻译只需在JSON中定义，代码自动支持
// JSON: "greeting": "你好, {name}!"
String msg = L.get('common.greeting', {'name': 'Alice'}); // 你好, Alice!
```

### 4. 嵌套路径 ✅
```dart
// 支持任意深度的路径
String title = L.get('app.screens.form.sections.personal.age.label');
```

### 5. 调试友好 ✅
```dart
// 检查键是否存在
bool exists = i18n.has('screens.today.title');

// 列出所有翻译键（用于验证）
List<String> allKeys = i18n.allKeys();
```

### 6. 第三方集成 ✅
- 可输出所有翻译键到Crowdin/OneSky
- CI/CD: 检查所有语言键完整性
- 翻译管理工具支持JSON格式

---

## 工作量估计

| 任务 | 时间 |
|------|------|
| 创建JSON文件 | 1 小时 |
| 编写i18n管理器类 | 1 小时 |
| 创建便利访问类(L) | 0.5 小时 |
| 集成到main.dart | 0.25 小时 |
| 迁移现有代码 | 1.5 小时 |
| 测试 + 调试 | 0.75 小时 |
| **总计** | **4.5-5 小时** |

---

## 向后兼容性

所有现有代码可保持不变：
```dart
// 旧代码仍然工作
L.today           // 内部调用 L.get('screens.today.title')
L.quadrant        // 内部调用 L.get('screens.quadrant.title')
```

可逐步迁移到新系统，无需一次性改所有文件。

---

## 测试清单

- [ ] JSON文件格式验证
- [ ] i18n.init() 成功加载数据
- [ ] L.screenTodayTitle 返回正确翻译
- [ ] L.get('screens.today.title') 返回相同值
- [ ] setLanguage() 切换语言成功
- [ ] 参数插值正确
- [ ] 空键返回键本身作为fallback
- [ ] addHint等"老"getters仍然工作
- [ ] 节日主题的blocks数据正确
