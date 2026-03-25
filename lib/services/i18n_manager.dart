import 'dart:convert';
import 'package:flutter/services.dart';

/// 国际化管理器 - 支持嵌套路径、参数插值、动态语言切换
class I18nManager {
  static final I18nManager _instance = I18nManager._();
  
  factory I18nManager() => _instance;
  
  static I18nManager get instance => _instance;
  
  I18nManager._();
  
  Map<String, dynamic> _zhData = {};
  Map<String, dynamic> _enData = {};
  String _currentLang = 'zh';
  String _currentTheme = 'warm';
  
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

  /// 设置当前主题（用于主题专用术语切换）
  void setTheme(String theme) {
    _currentTheme = theme;
  }
  
  /// 获取当前语言
  String get currentLanguage => _currentLang;
  
  /// 获取翻译：支持多级回退机制
  /// 优先级：当前语言主题专用 -> 当前语言通用 -> 默认语言(zh)主题专用 -> 默认语言(zh)通用 -> 空字符串
  String get(String key, [Map<String, dynamic>? params]) {
    // 1. 尝试当前语言
    final data = _currentLang == 'zh' ? _zhData : _enData;
    final themeKey = 'theme_terms.$_currentTheme.$key';
    
    dynamic result = _getNestedValue(data, themeKey) ?? _getNestedValue(data, key);
    
    // 2. 如果没找到，且当前不是中文，尝试回退到中文
    if (result == null && _currentLang != 'zh') {
      result = _getNestedValue(_zhData, themeKey) ?? _getNestedValue(_zhData, key);
    }

    // 3. 最终回退：如果还是 null，为了防止显示原始变量名，返回空字符串（生产环境）或带标记的键名（开发环境）
    if (result == null) {
      // 在开发模式下打印日志，方便定位缺失的键
      String fallback = '';
      assert(() {
        print('[I18n] ⚠️ Missing key: $key (Theme: $_currentTheme, Lang: $_currentLang)');
        fallback = '[$key]';
        return true;
      }());
      return fallback;
    }
    
    // 参数插值
    if (params != null && result is String) {
      var text = result;
      params.forEach((k, v) {
        final regex = RegExp('\\{\\{?\\s*$k\\s*\\}?\\}');
        text = text.replaceAll(regex, v.toString());
      });
      return text;
    }
    
    return result is String ? result : result?.toString() ?? '';
  }

  /// 获取原始对象（如 List 或 Map），用于复杂翻译结构
  dynamic getRaw(String key) {
    final data = _currentLang == 'zh' ? _zhData : _enData;
    
    // 优先尝试获取主题专用术语
    final themeKey = 'theme_terms.$_currentTheme.$key';
    final themeResult = _getNestedValue(data, themeKey);
    
    return themeResult ?? _getNestedValue(data, key);
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
        } else if (v is String || v is int) {
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
