// lib/services/share_service.dart
// 一键截图分享 + 周报/月报生成
// 使用 path_provider 保存临时文件，通过 Android Intent 分享

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import '../providers/app_state.dart';

class ShareService {
  static const _intentCh = MethodChannel('com.lsz.app/share');

  // ── Screenshot share ──────────────────────────────────────────────────────
  /// Capture the widget bound to [key] and share via Android intent.
  static Future<bool> shareWidget(GlobalKey key, {String filename = 'lsz_share'}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return false;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      return await shareBytes(byteData.buffer.asUint8List(), filename: '$filename.png');
    } catch (e) {
      return false;
    }
  }

  static Future<bool> shareBytes(Uint8List bytes, {required String filename}) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await _shareFile(file.path, 'image/png');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _shareFile(String path, String mimeType) async {
    try {
      await _intentCh.invokeMethod('shareFile', {'path': path, 'mime': mimeType});
    } catch (_) {
      // Fallback: copy to clipboard notification
    }
  }

  static Future<void> shareText(String text, {String subject = ''}) async {
    try {
      await _intentCh.invokeMethod('shareText', {'text': text, 'subject': subject});
    } catch (_) {}
  }

  /// Share a file via Android intent.
  static Future<void> shareFile(String path, {String mime = 'text/plain'}) async {
    try {
      await _intentCh.invokeMethod('shareFile', {
        'path': path,
        'mime': mime,
      });
    } catch (_) {}
  }

  // ── Weekly / Monthly Report ───────────────────────────────────────────────
  static String buildWeeklyReport(AppState state) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final buf = StringBuffer();

    buf.writeln('📊 流水账 · 本周报告');
    buf.writeln('${_fmt(weekStart)} — ${_fmt(now)}');
    buf.writeln('═' * 30);

    // Task stats
    int totalTasks = 0, doneTasks = 0;
    int totalFocusSecs = 0;
    final tagStats = <String, int>{};

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      final dayTasks = state.tasks.where((t) => t.createdAt == dateKey || t.rescheduledTo == dateKey).toList();
      final dayDone  = dayTasks.where((t) => t.done && t.doneAt == dateKey).toList();
      totalTasks += dayTasks.length;
      doneTasks  += dayDone.length;
      totalFocusSecs += dayTasks.fold(0, (s, t) => s + t.focusSecs);
      totalFocusSecs += state.settings.unboundFocusByDate[dateKey] ?? 0;

      for (final t in dayDone) {
        for (final tag in t.tags) {
          tagStats[tag] = (tagStats[tag] ?? 0) + 1;
        }
      }

      final pct = dayTasks.isNotEmpty ? (dayDone.length / dayTasks.length * 100).round() : 0;
      final bar = _progressBar(pct);
      buf.writeln('${_weekday(date.weekday)}  $bar  ${dayDone.length}/${dayTasks.length} ($pct%)');
    }

    buf.writeln('─' * 30);
    buf.writeln('✅ 总完成：$doneTasks / $totalTasks 件');
    buf.writeln('⏱ 总专注：${_fmtDuration(totalFocusSecs)}');
    if (totalTasks > 0) {
      buf.writeln('📈 完成率：${(doneTasks / totalTasks * 100).round()}%');
    }

    if (tagStats.isNotEmpty) {
      buf.writeln('─' * 30);
      buf.writeln('🏷 标签分布：');
      final sorted = tagStats.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      for (final e in sorted.take(5)) {
        buf.writeln('  ${e.key}  ×${e.value}');
      }
    }

    buf.writeln('─' * 30);
    buf.writeln('由 流水账 App 生成 · ${_fmt(now)}');
    return buf.toString();
  }

  static String buildMonthlyReport(AppState state) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final buf = StringBuffer();

    buf.writeln('📊 流水账 · ${now.month}月报告');
    buf.writeln('${_fmt(monthStart)} — ${_fmt(now)}');
    buf.writeln('═' * 30);

    int totalTasks = 0, doneTasks = 0;
    int totalFocusSecs = 0;
    final dayCompletion = <String, double>{};

    for (int d = 1; d <= now.day; d++) {
      final date = DateTime(now.year, now.month, d);
      final dateKey = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      final dayTasks = state.tasks.where((t) => t.createdAt == dateKey || t.rescheduledTo == dateKey).toList();
      final dayDone  = dayTasks.where((t) => t.done && t.doneAt == dateKey).toList();
      totalTasks += dayTasks.length;
      doneTasks  += dayDone.length;
      totalFocusSecs += dayTasks.fold(0, (s, t) => s + t.focusSecs);
      totalFocusSecs += state.settings.unboundFocusByDate[dateKey] ?? 0;
      if (dayTasks.isNotEmpty) {
        dayCompletion[dateKey] = dayDone.length / dayTasks.length;
      }
    }

    // Mini heat map (5 columns)
    buf.writeln('热力完成日历：');
    final days = List.generate(now.day, (i) {
      final dateKey = '${now.year}-${now.month.toString().padLeft(2,'0')}-${(i+1).toString().padLeft(2,'0')}';
      final c = dayCompletion[dateKey];
      if (c == null) return '⬜';
      if (c >= 0.8) return '🟩';
      if (c >= 0.5) return '🟨';
      if (c > 0)    return '🟧';
      return '🟥';
    });
    for (int i = 0; i < days.length; i += 7) {
      buf.writeln(days.sublist(i, (i + 7).clamp(0, days.length)).join(''));
    }

    buf.writeln('─' * 30);
    buf.writeln('✅ 总完成：$doneTasks / $totalTasks 件');
    buf.writeln('⏱ 总专注：${_fmtDuration(totalFocusSecs)}');
    if (totalTasks > 0) {
      buf.writeln('📈 月完成率：${(doneTasks / totalTasks * 100).round()}%');
    }

    // Best day
    if (dayCompletion.isNotEmpty) {
      final best = dayCompletion.entries.reduce((a, b) => a.value >= b.value ? a : b);
      buf.writeln('🏆 最佳日期：${best.key} (${(best.value * 100).round()}%)');
    }

    buf.writeln('─' * 30);
    buf.writeln('由 流水账 App 生成 · ${_fmt(now)}');
    return buf.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}';

  static String _weekday(int w) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${days[(w - 1).clamp(0, 6)]}';
  }

  static String _progressBar(int pct) {
    final filled = (pct / 10).round().clamp(0, 10);
    return '[${'█' * filled}${'░' * (10 - filled)}]';
  }

  static String _fmtDuration(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}小时${m}分';
    return '${m}分钟';
  }
}
