// lib/beta/living_island_service.dart
//
// 调用原生 PomodoroLiveService（Kotlin ForegroundService）。
//
// ── 为什么这样实现才能上 ColorOS 流体云/灵动岛 ─────────────────────────────
//   ColorOS 12+（流体云）/ ColorOS 16（灵动岛）的要求：
//   1. 通知必须来自一个正在运行的 ForegroundService（前台服务）
//   2. NotificationChannel importance = IMPORTANCE_HIGH
//   3. 使用 DecoratedCustomViewStyle + setCustomContentView/setCustomBigContentView
//      提供胶囊（compact）和展开（expanded）两套 RemoteViews 布局
//   4. 通知 ongoing = true，silent = true（无声无震动）
//   5. setColor + setColorized = true（ColorOS 用此染色胶囊边框）
//   上述 1、3 两条 flutter_local_notifications 无法满足，因此必须走原生 Service。
//
// 非 OPPO/OnePlus/Realme 设备：同样走这套通知，效果为标准持久通知条。
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/pom_engine.dart';

class LivingIslandService {
  static const _ch = MethodChannel('com.lsz.app/live_update');

  static bool _active = false;
  static Timer? _syncTimer;

  /// 启动/更新灵动岛。
  static Future<void> show(PomEngine pom, String? taskName) async {
    _active = true;
    await _send(pom, taskName);
    _startSyncTimer(pom, taskName);
  }

  /// 更新（不重启 timer）——外部每秒调用。
  static Future<void> update(PomEngine pom, String? taskName) async {
    if (!_active) return;
    await _send(pom, taskName);
  }

  /// 关闭灵动岛通知。
  static Future<void> dismiss() async {
    _active = false;
    _syncTimer?.cancel();
    _syncTimer = null;
    try { await _ch.invokeMethod('dismiss'); } catch (_) {}
  }

  static Future<void> _send(PomEngine pom, String? taskName) async {
    try {
      await _ch.invokeMethod('show', {
        'secsLeft':  pom.secsLeft,
        'totalSecs': pom.totalSecs,
        'phase':     _phaseStr(pom.mode),
        'taskName':  taskName,
        'cycle':     pom.cycle,
        'running':   pom.running,
      });
    } catch (_) {}
  }

  // 每 5 秒从 Flutter 侧向原生同步一次绝对剩余秒数，消除 drift
  static void _startSyncTimer(PomEngine pom, String? taskName) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_active) { _syncTimer?.cancel(); return; }
      await _send(pom, taskName);
    });
  }

  static String _phaseStr(PomMode mode) {
    switch (mode) {
      case PomMode.focus:      return 'focus';
      case PomMode.longBreak:  return 'long_break';
      case PomMode.shortBreak: return 'short_break';
    }
  }
}
