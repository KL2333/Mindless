
import 'dart:convert';
import 'dart:io';

/// Mocking rootBundle for testing
class MockRootBundle {
  static Future<String> loadString(String path) async {
    return File(path).readAsStringSync();
  }
}

// Minimal reproduction of the real I18nManager for verification
class I18nManager {
  Map<String, dynamic> _zhData = {};
  String _currentLang = 'zh';
  String _currentTheme = 'warm';

  void init(String zhJson) {
    _zhData = jsonDecode(zhJson) as Map<String, dynamic>;
  }

  void setTheme(String theme) {
    _currentTheme = theme;
    print('[Test] 🎭 Switched to theme: $theme');
  }

  /// The NEW robust logic from i18n_manager.dart
  String get(String key) {
    final data = _zhData; // Simulating zh as current
    final themeKey = 'theme_terms.$_currentTheme.$key';
    
    // 1. Try theme override
    dynamic result = _getNestedValue(data, themeKey);
    if (result != null) {
      // print('[Test] ✅ Found theme override for $key');
      return result.toString();
    }
    
    // 2. Try default path
    result = _getNestedValue(data, key);
    if (result != null) {
      // print('[Test] ✅ Found default for $key');
      return result.toString();
    }

    // 3. Robust fallback: NO RAW KEY
    // print('[Test] ⚠️ Missing key: $key');
    return '[Missing: $key]'; // Simulate development mode
  }

  dynamic _getNestedValue(Map<String, dynamic> data, String path) {
    final keys = path.split('.');
    dynamic current = data;
    for (final key in keys) {
      if (current is Map<String, dynamic> && (current as Map).containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }
}

void main() {
  final zhJson = File('assets/i18n/zh.json').readAsStringSync();
  final i18n = I18nManager();
  i18n.init(zhJson);
  
  final testKeys = [
    'screens.settings.beta.weather',
    'screens.settings.weather.pinnedEffect',
    'screens.about.roadmapData.sections.task.title',
    'screens.settings.festivals.world_tb_day.name',
    'non_existent_key_for_testing'
  ];
  
  print('--- Testing with theme: warm ---');
  i18n.setTheme('warm');
  for (var key in testKeys) {
    print('  $key => ${i18n.get(key)}');
  }

  print('\n--- Testing with theme: black_hole ---');
  i18n.setTheme('black_hole');
  for (var key in testKeys) {
    print('  $key => ${i18n.get(key)}');
  }

  print('\n--- Verification of theme override ---');
  // Add a test for a key that has a theme override
  // In black_hole theme, many keys are overridden
  final overrideKey = 'screens.today.title';
  i18n.setTheme('warm');
  print('  $overrideKey (warm) => ${i18n.get(overrideKey)}');
  i18n.setTheme('black_hole');
  print('  $overrideKey (black_hole) => ${i18n.get(overrideKey)}');
}
