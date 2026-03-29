// lib/services/persist_notif_service.dart
// 常驻通知栏控制 — 在番茄钟运行时显示带控制按钮的持久通知
// 使用已有的 com.lsz.app/keepalive 通道的 update/dismiss 方法

import 'package:flutter/services.dart';
import '../services/crash_logger.dart';

class PersistNotifService {
  static const _ch = MethodChannel('com.lsz.app/keepalive');
  static bool _active = false;
  static bool _requestedBatteryBoost = false;

  static Future<void> start({
    required int secsLeft,
    required int totalSecs,
    required bool running,
    required String mode,      // 'focus'|'shortBreak'|'longBreak'
    required String? taskName,
    required int cycle,
  }) async {
    _active = true;
    try {
      await _ensureBatteryBoost();
      await _update(
        secsLeft: secsLeft,
        totalSecs: totalSecs,
        running: running,
        mode: mode,
        taskName: taskName,
        cycle: cycle,
      );
    } catch (e) {
      CrashLogger.warn('PersistNotif', 'start failed: $e');
    }
  }

  static Future<void> update({
    required int secsLeft,
    required int totalSecs,
    required bool running,
    required String mode,
    required String? taskName,
    required int cycle,
  }) async {
    if (!_active) return;
    try {
      await _update(
        secsLeft: secsLeft,
        totalSecs: totalSecs,
        running: running,
        mode: mode,
        taskName: taskName,
        cycle: cycle,
      );
    } catch (e) {
      CrashLogger.warn('PersistNotif', 'update failed: $e');
    }
  }

  static Future<void> dismiss() async {
    _active = false;
    try {
      await _ch.invokeMethod('dismiss');
    } catch (e) {
      CrashLogger.warn('PersistNotif', 'dismiss failed: $e');
    }
  }

  static Future<void> _ensureBatteryBoost() async {
    if (_requestedBatteryBoost) return;
    _requestedBatteryBoost = true;
    try {
      await _ch.invokeMethod('primeKeepAlive');
    } catch (e) {
      CrashLogger.warn('PersistNotif', 'prime keepalive failed: $e');
    }
  }

  static Future<void> _update({
    required int secsLeft,
    required int totalSecs,
    required bool running,
    required String mode,
    required String? taskName,
    required int cycle,
  }) async {
    final modeLabel = const {
      'focus':      '专注中',
      'shortBreak': '短暂休息',
      'longBreak':  '长休息',
    }[mode] ?? '专注中';

    final m = secsLeft ~/ 60;
    final s = secsLeft % 60;
    final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final modeEmoji = mode == 'focus' ? '🍅' : mode == 'shortBreak' ? '☕' : '🌙';

    final title = '$modeEmoji $modeLabel — $timeStr (第$cycle轮)';
    final body  = running
        ? (taskName != null ? '▶ $taskName' : '▶ 专注进行中，加油！')
        : (taskName != null ? '⏸ $taskName' : '⏸ 已暂停，点击继续');

    try {
      await _ch.invokeMethod('update', {'title': title, 'body': body});
    } catch (e) {
      CrashLogger.warn('PersistNotif', 'update failed: $e');
    }
  }
}
