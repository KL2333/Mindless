// lib/services/distraction_detector.dart
// 专注干扰检测器
// 在番茄钟专注阶段，每30秒检测前台App
// 检测到娱乐类App（bilibili/抖音等）时发送通知提醒用户

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DistractionDetector {
  static const _ch      = MethodChannel('com.lsz.app/foreground_app');
  static const _repairCh = MethodChannel('com.lsz.app/notif_repair');
  static const _notifId = 8888;

  static Timer? _timer;
  static bool _enabled = false;
  static int _alertCount = 0;
  static FlutterLocalNotificationsPlugin? _notif;

  static bool get isEnabled => _enabled;
  static void setEnabled(bool v) => _enabled = v;
  /// 本次专注会话中触发的娱乐App提醒次数（供心流指数扣分使用）
  static int get distractionCount => _alertCount;

  static void init(FlutterLocalNotificationsPlugin notif) {
    _notif = notif;
  }

  /// 开始检测（番茄钟专注开始时调用）
  static void startMonitoring() {
    if (!_enabled) return;
    _alertCount = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  /// 停止检测（番茄钟结束/暂停时调用）
  static void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _dismissAlert();
  }

  static Future<void> _check() async {
    try {
      final pkg = await _ch.invokeMethod<String>('getCurrentApp');
      if (pkg == null) return;
      final isDistraction = await _ch.invokeMethod<bool>(
          'isDistractionApp', {'package': pkg}) ?? false;
      if (isDistraction) {
        _alertCount++;
        await _sendAlert(pkg);
      }
    } catch (_) {}
  }

  static String _appName(String pkg) {
    const names = {
      'tv.danmaku.bili': 'Bilibili',
      'com.bilibili.app.in': 'Bilibili 国际版',
      'com.ss.android.ugc.aweme': '抖音',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.kuaishou.nebula': '快手',
      'com.smile.gifmaker': '快手极速版',
      'com.sina.weibo': '微博',
      'com.xiaohongshu.android': '小红书',
      'tv.danmaku.bilibilihd': 'Bilibili HD',
      'com.tencent.weishi': '微视',
    };
    return names[pkg] ?? pkg.split('.').last;
  }

  static Future<void> _sendAlert(String pkg) async {
    final name = _appName(pkg);
    final messages = [
      '🍅 检测到你正在使用 $name',
      '番茄钟还在跑！$name 可以等专注结束再看～',
      '专注中途看 $name 会打断心流，再坚持一下！',
      '第 $_alertCount 次提醒：$name 的精彩内容专注结束后再看吧 💪',
    ];
    final msg = messages[(_alertCount - 1).clamp(0, messages.length - 1)];

    // 触发原生全屏通知（如果支持）
    try {
      await _ch.invokeMethod('showFullscreenDistraction', {
        'appName': name,
        'count': _alertCount,
        'message': msg,
      });
    } catch (_) {
      // 降级到普通通知
      try {
        await _notif?.show(
          _notifId,
          '⚠ 专注提醒',
          msg,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'lsz_distraction_alert',
              '专注干扰提醒',
              channelDescription: '检测到娱乐App时发送提醒',
              importance: Importance.high,
              priority: Priority.high,
              onlyAlertOnce: false,
              autoCancel: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      } catch (_) {
        // 插件损坏时降级到原生通道
        try {
          await _repairCh.invokeMethod('showNative', {
            'id': _notifId,
            'title': '⚠ 专注提醒',
            'body': msg,
          });
        } catch (_) {}
      }
    }
  }

  static Future<void> _dismissAlert() async {
    // 先尝试插件取消；若 Missing type parameter 异常则静默忽略
    // 原生侧会在下次 clearScheduledData 时自动清理
    try {
      await _notif?.cancel(_notifId);
    } catch (_) {
      // Intentionally swallowed — plugin cache may be corrupted.
      // The notification will auto-dismiss on user tap (autoCancel: true).
    }
  }
}

