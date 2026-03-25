// lib/services/notification_service.dart
//
// ── 根本修复（基于 CrashLogger 诊断）────────────────────────────────────────
//
// 问题根因（已由日志确认）：
//   flutter_local_notifications 18.x 的每个操作都会先调用
//   loadScheduledNotifications()，该方法在数据损坏时永远抛
//   RuntimeException: Missing type parameter。
//   包括：cancelAll、cancel、zonedSchedule、show 全部受影响。
//
// 修复策略（三层降级）：
//   层 1：正常尝试 flutter_local_notifications（兼容未损坏设备）
//   层 2：若失败，调用 com.lsz.app/notif_repair 清除损坏的原生 SP 数据，
//         然后通过 showNative 原生通道直接发通知（不经过插件）
//   层 3：若原生通道也失败，彻底禁用，绝不影响主流程
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'crash_logger.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static FlutterLocalNotificationsPlugin get plugin => _plugin;
  static bool _initialized  = false;
  static bool _pluginBroken = false;   // flutter_local_notifications 已损坏
  static bool _repaired     = false;   // 已执行过数据修复

  static const _repairCh = MethodChannel('com.lsz.app/notif_repair');

  static const _channel = AndroidNotificationDetails(
    'lsz_daily', '每日任务提醒',
    channelDescription: '流水账每日任务提醒',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    playSound: false,
    enableVibration: false,
  );

  // ── 初始化 ────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      _initialized = true;
      CrashLogger.info('NotifSvc', 'init() ok');
    } catch (e, s) {
      _pluginBroken = true;
      CrashLogger.error('NotifSvc', 'init() failed', err: e, stack: s);
    }
  }

  static Future<void> requestPermission() async {
    if (_pluginBroken) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  // ── 修复：清除损坏的 SP 数据 ──────────────────────────────────────────────
  static Future<void> _repair() async {
    if (_repaired) return;
    _repaired = true;
    try {
      final ok = await _repairCh.invokeMethod<bool>('clearScheduledData') ?? false;
      CrashLogger.info('NotifSvc', 'clearScheduledData result=$ok — plugin will be bypassed');
    } catch (e) {
      CrashLogger.warn('NotifSvc', 'repair channel failed: $e');
    }
  }

  // ── 原生通道直接发通知（绕过损坏的插件）─────────────────────────────────
  static Future<void> _nativeShow(int id, String title, String body) async {
    try {
      await _repairCh.invokeMethod('showNative', {
        'id': id, 'title': title, 'body': body,
      });
      CrashLogger.info('NotifSvc', 'nativeShow($id) ok');
    } catch (e) {
      CrashLogger.warn('NotifSvc', 'nativeShow($id) failed: $e');
    }
  }

  // ── 主入口 ────────────────────────────────────────────────────────────────
  static Future<void> scheduleAll({
    required List<String> morning,
    required List<String> afternoon,
    required List<String> evening,
  }) async {
    await init();

    String fmt(List<String> tasks, String empty) => tasks.isEmpty
        ? empty
        : tasks.take(3)
            .map((t) => t.length > 12 ? '${t.substring(0, 12)}…' : t)
            .join('、');

    final titles = ['🌅 上午任务', '☀️ 下午任务', '🌙 晚上任务'];
    final bodies  = [
      fmt(morning,   '今天上午还没有任务，计划一下吧'),
      fmt(afternoon, '今天下午还没有任务，加油！'),
      fmt(evening,   '今天晚上还没有任务，好好休息'),
    ];

    // 层 1：尝试 flutter_local_notifications
    if (!_pluginBroken) {
      bool anyFailed = false;
      // cancel 旧通知（不用 cancelAll，cancelAll 必然失败）
      for (final id in [1, 2, 3]) {
        try { await _plugin.cancel(id); } catch (_) { anyFailed = true; break; }
      }
      if (!anyFailed) {
        for (int i = 0; i < 3; i++) {
          try {
            await _plugin.show(i + 1, titles[i], bodies[i],
                NotificationDetails(android: _channel));
          } catch (_) { anyFailed = true; break; }
        }
      }
      if (!anyFailed) {
        CrashLogger.info('NotifSvc', 'scheduleAll via plugin ok');
        return;
      }
      // 层 1 失败
      _pluginBroken = true;
      CrashLogger.warn('NotifSvc', 'plugin broken, switching to native channel');
      await _repair();
    }

    // 层 2：原生通道直接发通知
    for (int i = 0; i < 3; i++) {
      await _nativeShow(i + 1, titles[i], bodies[i]);
    }
  }
}
