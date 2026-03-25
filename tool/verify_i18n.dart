
import 'dart:convert';
import 'dart:io';

void main() {
  print('🔍 Starting i18n verification for ALL files in lib/...\n');

  final zhFile = File('assets/i18n/zh.json');
  final enFile = File('assets/i18n/en.json');

  final libDir = Directory('lib');
  final allDartFiles = libDir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  verifyFiles(allDartFiles, zhFile, 'zh.json');
  verifyFiles(allDartFiles, enFile, 'en.json');
}

void verifyFiles(List<File> dartFiles, File jsonFile, String name) {
  if (!jsonFile.existsSync()) {
    print('❌ Error: $name not found.');
    return;
  }

  // 1. Extract keys from ALL .dart files
  final usedKeys = <String>{};
  final keyRegex = RegExp(r"(?:i18n\.get(?:Raw)?|L\.get)\('([^']+)'");
  
  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    final matches = keyRegex.allMatches(content);
    for (final m in matches) {
      usedKeys.add(m.group(1)!);
    }
  }

  // 2. Load and flatten JSON
  final jsonContent = jsonFile.readAsStringSync();
  if (jsonContent.isEmpty) {
    print('❌ Error: $name is empty.');
    return;
  }
  final data = jsonDecode(jsonContent) as Map<String, dynamic>;
  final existingKeys = <String>{};

  void flatten(Map<String, dynamic> data, String prefix) {
    data.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        flatten(value, fullKey);
      } else {
        existingKeys.add(fullKey);
      }
    });
  }
  flatten(data, '');

  // 3. Compare
  final missingKeys = <String>[];
  for (final key in usedKeys) {
    // 忽略一些带变量的键（如 'screens.today.overdueItems'）
    if (key.contains('{{') || key.isEmpty) continue;
    if (!existingKeys.contains(key)) {
      missingKeys.add(key);
    }
  }

  // 4. Report
  if (missingKeys.isEmpty) {
    print('✅ Success! All ${usedKeys.length} unique keys in $name exist.');
  } else {
    print('❌ Found ${missingKeys.length} missing keys out of ${usedKeys.length} in $name:');
    missingKeys.sort();
    for (final key in missingKeys) {
      print('   - $key');
    }
    print('');
  }
}

