// lib/services/crash_logger.dart
// ─────────────────────────────────────────────────────────────────────────────
// CrashLogger — 操作日志 + 异常日志 + 崩溃前快照
//
// 设计原则：
//   • 零依赖：仅用 SharedPreferences（项目已有）
//   • 环形缓冲：最多保留 600 条，超出时丢弃最旧的
//   • 分级：ACTION / INFO / WARN / ERROR / FATAL
//   • 线程安全：所有写操作通过单一队列异步提交，不阻塞 UI
//   • 低开销：正常运行时每条日志仅做字符串拼接，不 I/O
//   • 崩溃前快照：Flutter 全局错误自动记录为 ERROR/FATAL 级别
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { action, info, warn, error, fatal }

class LogEntry {
  final String ts;       // ISO 时间戳
  final LogLevel level;
  final String tag;      // 模块标签（如 "PomTimer", "TaskAdd"）
  final String msg;      // 主消息
  final String? detail;  // 堆栈/额外信息

  const LogEntry({
    required this.ts,
    required this.level,
    required this.tag,
    required this.msg,
    this.detail,
  });

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
    ts:     j['ts'] as String,
    level:  LogLevel.values[j['lv'] as int],
    tag:    j['tag'] as String,
    msg:    j['msg'] as String,
    detail: j['det'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'ts':  ts,
    'lv':  level.index,
    'tag': tag,
    'msg': msg,
    if (detail != null) 'det': detail,
  };

  String get levelLabel {
    switch (level) {
      case LogLevel.action: return 'ACT';
      case LogLevel.info:   return 'INF';
      case LogLevel.warn:   return 'WRN';
      case LogLevel.error:  return 'ERR';
      case LogLevel.fatal:  return 'FTL';
    }
  }

  @override
  String toString() => '[$ts][$levelLabel][$tag] $msg'
      '${detail != null ? "\n    $detail" : ""}';
}

class CrashLogger {
  static const _kKey       = 'lsz_crashlog_v1';
  static const _kMaxEntries = 600;

  // 内存缓冲（UI 随时读取，无需 await）
  static final List<LogEntry> _buffer = [];
  static bool _dirty = false;
  static Timer? _flushTimer;
  static SharedPreferences? _prefs;

  // ── 初始化（在 main() 最早调用）────────────────────────────────────────────
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromDisk();
    _hookFlutterErrors();
    _hookIsolateErrors();
    log(LogLevel.info, 'CrashLogger', 'Logger initialized — buffer=${_buffer.length} entries');
  }

  // ── 公共日志方法 ────────────────────────────────────────────────────────────
  static void log(LogLevel level, String tag, String msg, {String? detail}) {
    final entry = LogEntry(
      ts:    _now(),
      level: level,
      tag:   tag,
      msg:   msg,
      detail: detail,
    );
    _buffer.add(entry);
    // 环形：超出上限时丢掉最旧的 20%
    if (_buffer.length > _kMaxEntries) {
      _buffer.removeRange(0, _kMaxEntries ~/ 5);
    }
    _dirty = true;
    _scheduleSave();

    // 控制台输出（debug 模式）
    if (kDebugMode) {
      debugPrint('LSZ ${entry.levelLabel} [$tag] $msg'
          '${detail != null ? "\n  $detail" : ""}');
    }
  }

  /// 快捷方法
  static void action(String tag, String msg) => log(LogLevel.action, tag, msg);
  /// Record every user tap/gesture, even ones that don't produce state changes
  static void tap(String widget, String detail) =>
      log(LogLevel.action, 'TAP:$widget', detail);
  static void info(String tag, String msg)    => log(LogLevel.info,   tag, msg);
  static void warn(String tag, String msg)    => log(LogLevel.warn,   tag, msg);
  static void error(String tag, String msg, {Object? err, StackTrace? stack}) {
    log(LogLevel.error, tag, msg,
        detail: _formatError(err, stack));
  }
  static void fatal(String tag, String msg, {Object? err, StackTrace? stack}) {
    log(LogLevel.fatal, tag, msg,
        detail: _formatError(err, stack));
    // fatal 立即强制落盘
    _saveNow();
  }

  // ── 读取 ────────────────────────────────────────────────────────────────────
  static List<LogEntry> get entries => List.unmodifiable(_buffer);

  /// 生成可分享的文本报告
  static String buildReport() {
    final sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('流水账 · Mindless  Crash / Operation Log');
    sb.writeln('Generated: ${_now()}');
    sb.writeln('Entries: ${_buffer.length}');
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln();

    // 优先显示 ERROR / FATAL，再显示完整时序
    final errors = _buffer.where((e) =>
        e.level == LogLevel.error || e.level == LogLevel.fatal).toList();
    if (errors.isNotEmpty) {
      sb.writeln('──── ERRORS & FATALS ────');
      for (final e in errors) sb.writeln(e);
      sb.writeln();
    }

    sb.writeln('──── FULL LOG (newest last) ────');
    for (final e in _buffer) sb.writeln(e);
    return sb.toString();
  }

  static void clear() {
    _buffer.clear();
    _dirty = true;
    _saveNow();
    log(LogLevel.info, 'CrashLogger', 'Log cleared by user');
  }

  // ── Flutter 全局错误拦截 ────────────────────────────────────────────────────
  static void _hookFlutterErrors() {
    // Flutter 框架异常（widget build 报错等）
    FlutterError.onError = (details) {
      final isLayout = details.library?.contains('rendering') ?? false;
      final level = isLayout ? LogLevel.error : LogLevel.fatal;
      log(level, 'FlutterError',
          details.exceptionAsString(),
          detail: details.stack?.toString().split('\n').take(12).join('\n'));
      // 仍走原来的报告路径（控制台打印）
      FlutterError.presentError(details);
    };

    // 非 Flutter 的 Dart 异常（async 未捕获等）
    PlatformDispatcher.instance.onError = (error, stack) {
      fatal('PlatformDispatcher',
          error.toString(),
          err: error, stack: stack);
      return true; // 表示已处理
    };
  }

  // ── Isolate 错误拦截 ────────────────────────────────────────────────────────
  static void _hookIsolateErrors() {
    final port = ReceivePort();
    Isolate.current.addErrorListener(port.sendPort);
    port.listen((msg) {
      if (msg is List && msg.length >= 2) {
        log(LogLevel.fatal, 'IsolateError', msg[0].toString(),
            detail: msg[1]?.toString());
      }
    });
  }

  // ── 持久化 ──────────────────────────────────────────────────────────────────
  static void _loadFromDisk() {
    try {
      final raw = _prefs?.getString(_kKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _buffer.addAll(list.map((e) =>
          LogEntry.fromJson(e as Map<String, dynamic>)));
    } catch (e) {
      // 日志本身损坏，静默丢弃
      _prefs?.remove(_kKey);
    }
  }

  static void _scheduleSave() {
    _flushTimer?.cancel();
    // 3 秒防抖后写盘
    _flushTimer = Timer(const Duration(seconds: 3), _saveNow);
  }

  static void _saveNow() {
    if (!_dirty || _prefs == null) return;
    try {
      final json = jsonEncode(_buffer.map((e) => e.toJson()).toList());
      _prefs!.setString(_kKey, json);
      _dirty = false;
    } catch (_) {}
  }

  // ── 工具 ────────────────────────────────────────────────────────────────────
  static String _now() {
    final t = DateTime.now();
    return '${t.year}-'
        '${t.month.toString().padLeft(2,'0')}-'
        '${t.day.toString().padLeft(2,'0')} '
        '${t.hour.toString().padLeft(2,'0')}:'
        '${t.minute.toString().padLeft(2,'0')}:'
        '${t.second.toString().padLeft(2,'0')}.'
        '${t.millisecond.toString().padLeft(3,'0')}';
  }

  static String? _formatError(Object? err, StackTrace? stack) {
    if (err == null && stack == null) return null;
    final sb = StringBuffer();
    if (err != null) sb.writeln(err);
    if (stack != null) {
      // 只保留前 15 帧，避免日志过长
      final frames = stack.toString().split('\n').take(15);
      sb.write(frames.join('\n'));
    }
    return sb.toString().trim();
  }
}
