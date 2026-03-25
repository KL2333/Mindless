// lib/services/pom_engine.dart
//
// PomEngine — completely isolated pomodoro timer logic.
//
// Design principles:
//   • Zero Flutter widget dependency (no BuildContext, no AnimationController)
//   • Single ChangeNotifier owned by AppState, never disposed while app runs
//   • Phase completion signalled via phaseJustCompleted ValueNotifier
//     (UI watches it, resets to null after reading — no callbacks)
//   • Timer is ALWAYS cancelled before any state mutation
//   • Wall-clock (_endAt) is the single source of truth when resuming

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'package:flutter/services.dart';
import 'crash_logger.dart';

// ── Keepalive channel ─────────────────────────────────────────────────────────
// Talks to native Android to hold WakeLock and start foreground notification
// while timer is running, ensuring the timer is not killed in background.
class _KeepAlive {
  static const _ch = MethodChannel('com.lsz.app/keepalive');
  static bool _active = false;

  static Future<void> acquire() async {
    if (_active) return;
    try {
      await _ch.invokeMethod('acquire');
      _active = true;
      CrashLogger.info('Keepalive', 'WakeLock acquired');
    } catch (e) {
      CrashLogger.warn('Keepalive', 'acquire failed: $e');
    }
  }

  static Future<void> release() async {
    if (!_active) return;
    try {
      await _ch.invokeMethod('release');
      _active = false;
      CrashLogger.info('Keepalive', 'WakeLock released');
    } catch (e) {
      CrashLogger.warn('Keepalive', 'release failed: $e');
    }
  }
}

class PomEngine extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  PomMode  mode   = PomMode.focus;
  int  secsLeft   = 0;
  int  totalSecs  = 0;
  int  cycle      = 1;
  int  focusRoundsSinceLongBreak = 0;
  bool running    = false;
  bool initialized = false;
  int? selTaskId;
  int  sessionFocusSecs = 0;
  /// 本次专注会话的暂停次数（start→pause 每次 +1，start/reset 归零）
  int  pauseCount = 0;

  // Signals phase completion to UI. UI reads .value, then resets to null.
  final ValueNotifier<PomMode?> phaseJustCompleted = ValueNotifier(null);

  // Called by AppState when a phase completes, so it can persist focus time.
  void Function(int secs, int? taskId)? onFocusTimeFlush;
  void Function(int secs, String date)? onUnboundFocusFlush;

  // ── Internal ───────────────────────────────────────────────────────────────
  Timer?    _timer;
  DateTime? _endAt;   // absolute wall-clock time when current phase ends

  double get progress =>
      totalSecs > 0 ? (totalSecs - secsLeft) / totalSecs : 0.0;

  // ── Init ───────────────────────────────────────────────────────────────────
  void init(PomSettings s) {
    if (initialized) return;
    mode      = PomMode.focus;
    secsLeft  = s.focusMins * 60;
    totalSecs = secsLeft;
    initialized = true;
    notifyListeners();
  }

  void reinit(PomSettings s) {
    if (running) return;
    mode      = PomMode.focus;
    secsLeft  = s.focusMins * 60;
    totalSecs = secsLeft;
    initialized = true;
    notifyListeners();
  }

  // ── Controls ───────────────────────────────────────────────────────────────
  void start(PomSettings s) {
    _cancelTimer();
    if (secsLeft <= 0) reinit(s);
    running = true;
    pauseCount = 0; // reset interruptions for new session
    _endAt  = DateTime.now().add(Duration(seconds: secsLeft));
    _timer  = Timer.periodic(const Duration(seconds: 1), (_) => _tick(s));
    CrashLogger.action('PomEngine', 'start mode=${mode.name} secs=$secsLeft cycle=$cycle task=$selTaskId');
    _KeepAlive.acquire();
    notifyListeners();
  }

  void pause() {
    _cancelTimer();
    running = false;
    _endAt  = null;
    _flushSession();
    pauseCount++;
    CrashLogger.action('PomEngine', 'pause mode=${mode.name} secs=$secsLeft');
    _KeepAlive.release();
    notifyListeners();
  }

  void reset(PomSettings s) {
    _cancelTimer();
    _flushSession();
    running    = false;
    mode       = PomMode.focus;
    cycle      = 1;
    focusRoundsSinceLongBreak = 0;
    sessionFocusSecs = 0;
    pauseCount = 0;
    secsLeft   = s.focusMins * 60;
    totalSecs  = secsLeft;
    _endAt     = null;
    CrashLogger.action('PomEngine', 'reset');
    _KeepAlive.release();
    notifyListeners();
  }

  void skip(PomSettings s) {
    _cancelTimer();
    _flushSession();
    running = false;
    _endAt  = null;
    _advance(s);
    CrashLogger.action('PomEngine', 'skip → mode=${mode.name}');
    notifyListeners();
  }

  void selectTask(int? id) {
    selTaskId = id;
    notifyListeners();
  }

  /// Called on app resume — re-syncs with wall clock.
  void catchUp(PomSettings s) {
    if (!running || _endAt == null) return;

    _cancelTimer(); // cancel before any state change

    final remaining = _endAt!.difference(DateTime.now()).inSeconds;

    if (remaining <= 0) {
      // Phase ended in background
      if (mode == PomMode.focus) {
        sessionFocusSecs += secsLeft.clamp(0, 99999);
      }
      secsLeft = 0;
      running  = false;
      _endAt   = null;
      _flushSession();

      final completedMode = mode;
      _advance(s);
      notifyListeners();

      // Signal UI after a brief delay so the build triggered by notifyListeners
      // above has settled before UI tries to setState.
      Future.delayed(const Duration(milliseconds: 60), () {
        phaseJustCompleted.value = completedMode;
        Future.delayed(const Duration(milliseconds: 50), () {
          phaseJustCompleted.value = null;
        });
        if (s.autoNext) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!running) start(s);
          });
        }
      });
    } else {
      final elapsed = secsLeft - remaining;
      if (elapsed > 0) {
        if (mode == PomMode.focus) sessionFocusSecs += elapsed;
        secsLeft = remaining;
      }
      // Restart timer
      _endAt  = DateTime.now().add(Duration(seconds: secsLeft));
      _timer  = Timer.periodic(const Duration(seconds: 1), (_) => _tick(s));
      notifyListeners();
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────
  void _tick(PomSettings s) {
    if (!running) { _cancelTimer(); return; }

    secsLeft = (secsLeft - 1).clamp(0, 99999);
    if (mode == PomMode.focus) sessionFocusSecs++;

    if (secsLeft <= 0) {
      _cancelTimer();
      running = false;
      _endAt  = null;
      _flushSession();

      CrashLogger.info('PomEngine', 'phase done mode=${mode.name} cycle=$cycle sessionFocus=${sessionFocusSecs}s');
      final completedMode = mode;
      _advance(s);
      notifyListeners();

      // Signal UI asynchronously — never call setState from a Timer callback
      Future.microtask(() {
        phaseJustCompleted.value = completedMode;
        Future.delayed(const Duration(milliseconds: 50), () {
          phaseJustCompleted.value = null;
        });
        if (s.autoNext) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!running) start(s);
          });
        }
      });
      return;
    }
    notifyListeners();
  }

  void _advance(PomSettings s) {
    if (mode == PomMode.focus) {
      focusRoundsSinceLongBreak++;
      if (focusRoundsSinceLongBreak >= s.longBreakInterval) {
        mode     = PomMode.longBreak;
        secsLeft = s.longBreakMins * 60;
        focusRoundsSinceLongBreak = 0;
      } else {
        mode     = PomMode.shortBreak;
        secsLeft = s.breakMins * 60;
      }
    } else {
      cycle++;
      mode     = PomMode.focus;
      secsLeft = s.focusMins * 60;
    }
    totalSecs = secsLeft;
  }

  void _flushSession() {
    if (sessionFocusSecs <= 0) return;
    final secs = sessionFocusSecs;
    sessionFocusSecs = 0;
    onFocusTimeFlush?.call(secs, selTaskId);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    _KeepAlive.release();
    phaseJustCompleted.dispose();
    super.dispose();
  }
}
