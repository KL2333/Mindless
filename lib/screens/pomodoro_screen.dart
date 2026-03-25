// lib/screens/pomodoro_screen.dart — β.0.028 完全重做
// 美术方向：专注≈炉火，呼吸节律，任务卡沉浸感
// 结构：
//   • 全屏背景色随模式渐变（focus=暖橙，break=冷蓝）
//   • 顶部：状态芯片 + 轮次点
//   • 主区：大圆环 + 时间数字（可点击进息屏）
//   • 底部抽屉：任务选择（可上滑展开）
//   • 右侧：玻璃时间刻度条
//   • 控制行悬浮在底部

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../l10n/l10n.dart';
import '../services/pom_engine.dart';
import '../widgets/pomodoro_ring.dart';
import '../widgets/time_ruler.dart';
import '../services/crash_logger.dart';
import '../widgets/shared_widgets.dart';
import '../beta/beta_flags.dart';
import 'pomodoro_ambient.dart';
import 'pom_history_screen.dart';
import '../services/persist_notif_service.dart';
import '../services/distraction_detector.dart';
import '../services/environment_sound_service.dart';
import '../services/focus_quality_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ListenableBuilder(
      listenable: appState.engine,
      builder: (context, _) => _PomBody(appState: appState),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PomBody extends StatefulWidget {
  final AppState appState;
  const _PomBody({required this.appState});
  @override State<_PomBody> createState() => _PomBodyState();
}

class _PomBodyState extends State<_PomBody> with TickerProviderStateMixin {
  // Phase-done toast
  String? _toast;
  // Task drawer expansion
  bool _drawerOpen = false;
  // Breathing animation
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  // Glow pulse when running
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  
  late Map<UIField, String> _ui;

  @override
  void initState() {
    super.initState();
    _refreshUI();
    _breathCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.94, end: 1.04)
        .animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    widget.appState.engine.phaseJustCompleted.addListener(_onPhase);
    widget.appState.engine.addListener(_onEngineTickForNotif);
    widget.appState.engine.addListener(_onEngineTickForFlow);
    _loadFlowBaseline();
  }

  void _refreshUI() {
    _ui = DisplayAdapter.getDisplayData(
      PomodoroPageState(widget.appState.engine.mode == PomMode.shortBreak || 
                        widget.appState.engine.mode == PomMode.longBreak)
    );
  }

  // ── 心流指数会话追踪 ────────────────────────────────────────────────────
  // 每秒采样心流指数，session 结束时取均值存入 FocusQualityEntry
  double _flowSum = 0;
  int    _flowSampleCount = 0;
  double _historyBaseline = 0.5; // 共享给会话内计算

  double get _sessionAvgFlow => _flowSampleCount > 0
      ? (_flowSum / _flowSampleCount).clamp(0.0, 1.0)
      : 0.0;

  Future<void> _loadFlowBaseline() async {
    final avg = await FocusQualityService.avgCompositeScore(days: 14);
    if (mounted) setState(() {
      _historyBaseline = avg > 0 ? (avg / 100).clamp(0.0, 1.0) : 0.5;
    });
  }

  // 每 engine tick 采样当前心流指数，只在专注阶段运行时采样
  void _onEngineTickForFlow() {
    final e = widget.appState.engine;
    if (!e.running || e.mode != PomMode.focus) return;
    if (e.totalSecs <= 0) return;
    final a = (e.sessionFocusSecs / e.totalSecs).clamp(0.0, 1.0);
    final b = (1.0 - e.pauseCount * 0.25).clamp(0.0, 1.0);
    final c = e.progress.clamp(0.0, 1.0);
    final d = _historyBaseline;
    final f = (1.0 - DistractionDetector.distractionCount * 0.30).clamp(0.0, 1.0);
    final sample = a * 0.35 + b * 0.25 + c * 0.20 + d * 0.10 + f * 0.10;
    _flowSum += sample;
    _flowSampleCount++;
  }

  @override
  void dispose() {
    widget.appState.engine.phaseJustCompleted.removeListener(_onPhase);
    widget.appState.engine.removeListener(_onEngineTickForNotif);
    widget.appState.engine.removeListener(_onEngineTickForFlow);
    PersistNotifService.dismiss();
    _breathCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _onEngineTickForNotif() {
    if (!betaPersistNotif(widget.appState.settings)) return;
    final engine = widget.appState.engine;
    if (!engine.running) return;
    if (engine.secsLeft % 10 != 0) return;
    final task = widget.appState.tasks
        .where((t) => t.id == engine.selTaskId).firstOrNull;
    PersistNotifService.update(
      secsLeft: engine.secsLeft, running: engine.running,
      mode: engine.mode.name, taskName: task?.text, cycle: engine.cycle);
  }

  static const _alarmCh = MethodChannel('com.lsz.app/pom_alarm');

  Future<void> _ringAlarm() async {
    final pom = widget.appState.settings.pom;
    try {
      await _alarmCh.invokeMethod('ring', {
        'sound': pom.alarmSound,
        'vibrate': pom.alarmVibrate,
      });
    } catch (_) {}
  }

  Future<void> _stopAlarm() async {
    try { await _alarmCh.invokeMethod('stop'); } catch (_) {}
  }

  Future<void> _onPhase() async {
    final mode = widget.appState.engine.phaseJustCompleted.value;
    if (mode == null || !mounted) return;

    // Temporarily disable autoNext so the engine doesn't start the next phase
    // while the fullscreen alert is showing. We'll trigger start manually after.
    final wasAutoNext = widget.appState.settings.pom.autoNext;
    if (wasAutoNext) {
      widget.appState.settings.pom.autoNext = false;
    }

    if (mode == PomMode.focus) {
      // Stop distraction monitoring and env sound sampling
      DistractionDetector.stopMonitoring();
      final noiseReport = await EnvironmentSoundService.stopAndRecord();

      // Save objective quality entry
      final engine = widget.appState.engine;
      final now = DateTime.now();
      final objectiveScore = engine.totalSecs > 0
          ? 1.0 - (engine.secsLeft / engine.totalSecs)
          : 1.0;
      final entry = FocusQualityEntry(
        date: widget.appState.todayKey,
        hour: now.hour,
        sessionMins: (engine.totalSecs / 60).round(),
        objectiveScore: objectiveScore.clamp(0.0, 1.0),
        taskId: engine.selTaskId?.toString(),
        noiseLevel: noiseReport.samples.isNotEmpty
            ? EnvironmentSoundService.levelLabel(noiseReport.dominantLevel)
            : null,
        flowIndex: _flowSampleCount > 0 ? _sessionAvgFlow : null,
      );
      FocusQualityService.addEntry(entry);
      // Reset flow accumulator for next session
      _flowSum = 0;
      _flowSampleCount = 0;

      // Ring alarm first
      await _ringAlarm();

      // Full-screen phase alert — blocks until user taps to dismiss
      if (mounted) {
        await _showPhaseAlert(
          isFocus: true,
          noiseReport: noiseReport,
        );
      }
    } else {
      // Break ended
      await _ringAlarm();
      if (mounted) {
        await _showPhaseAlert(isFocus: false);
      }
    }

    // Restore autoNext and start next phase if it was enabled
    if (wasAutoNext && mounted) {
      widget.appState.settings.pom.autoNext = true;
      final engine = widget.appState.engine;
      if (!engine.running) {
        engine.start(widget.appState.settings.pom);
      }
    }
  }

  /// Full-screen overlay alert. Vibration/ringtone persist until dismissed.
  /// Tap anywhere on screen to dismiss. No buttons shown.
  Future<void> _showPhaseAlert({
    required bool isFocus,
    SessionNoiseReport? noiseReport,
  }) async {
    final tc  = widget.appState.themeConfig;
    final acc = Color(tc.acc);
    final pom = widget.appState.settings.pom;
    int? ratingSelected;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.92),
      pageBuilder: (ctx, anim, _) => StatefulBuilder(
        builder: (ctx, setSt) => WillPopScope(
          onWillPop: () async => false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.mediumImpact();
              if (ratingSelected != null) {
                FocusQualityService.rateLastSession(ratingSelected!);
              }
              Navigator.of(ctx).pop();
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Pulse ring icon ─────────────────────────────────
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.85, end: 1.0),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOut,
                        builder: (_, scale, child) => Transform.scale(
                            scale: scale, child: child),
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: acc.withOpacity(0.20),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: acc.withOpacity(0.55), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                  color: acc.withOpacity(0.30),
                                  blurRadius: 28, spreadRadius: 4),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isFocus ? '✅' : '🍅',
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Title ───────────────────────────────────────────
                      Text(
                        isFocus ? L.get('screens.pomodoro.focusComplete') : L.get('screens.pomodoro.breakComplete'),
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isFocus
                            ? L.get('screens.pomodoro.focusMsg', {'mins': pom.focusMins})
                            : L.get('screens.pomodoro.breakMsg'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15,
                            color: Colors.white.withOpacity(0.75)),
                      ),

                      // ── Noise badge ─────────────────────────────────────
                      if (isFocus && noiseReport != null &&
                          noiseReport.samples.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(L.get('screens.pomodoro.environmentNoise', {'assessment': noiseReport.assessment}),
                            style: TextStyle(fontSize: 11,
                                color: Colors.white.withOpacity(0.80))),
                        ),
                      ],

                      // ── Quality rating (focus end only) ─────────────────
                      if (isFocus && widget.appState.settings.focusQualityEnabled) ...[
                        const SizedBox(height: 32),
                        Text(L.get('screens.pomodoro.qualityQuestion'),
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (i) {
                            final score = i + 1;
                            const emojis = ['😩','😕','😐','😊','🔥'];
                            final labels = [
                              L.get('screens.pomodoro.quality1'),
                              L.get('screens.pomodoro.quality2'),
                              L.get('screens.pomodoro.quality3'),
                              L.get('screens.pomodoro.quality4'),
                              L.get('screens.pomodoro.quality5'),
                            ];
                            final isSelected = ratingSelected == score;
                            return GestureDetector(
                              onTap: () {
                                setSt(() => ratingSelected = score);
                                HapticFeedback.lightImpact();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? acc.withOpacity(0.28)
                                      : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: isSelected ? acc
                                          : Colors.white.withOpacity(0.25),
                                      width: 1.5),
                                ),
                                child: Column(children: [
                                  Text(emojis[i],
                                      style: const TextStyle(fontSize: 24)),
                                  const SizedBox(height: 4),
                                  Text(labels[i], style: TextStyle(
                                      fontSize: 9.5,
                                      color: isSelected ? acc
                                          : Colors.white.withOpacity(0.65),
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.normal)),
                                ]),
                              ),
                            );
                          }),
                        ),
                      ],

                      const SizedBox(height: 48),
                      Text(L.get('screens.pomodoro.tapToContinue'),
                          style: TextStyle(fontSize: 13,
                              color: Colors.white.withOpacity(0.35),
                              letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Dismissed — stop alarm (vibration + ringtone) and clear screen flags
    await _stopAlarm();
  }


  void _showQualityRating(SessionNoiseReport noiseReport) {
    final tc = widget.appState.themeConfig;
    final acc = Color(tc.acc);
    int? selected;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Color(tc.brd),
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(L.get('screens.pomodoro.qualityQuestion'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: Color(tc.tx))),
          const SizedBox(height: 4),
          if (noiseReport.samples.isNotEmpty)
            Text(L.get('screens.pomodoro.environmentNoise', {'assessment': noiseReport.assessment}),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final score = i + 1;
              final emojis = ['😩','😕','😐','😊','🔥'];
              final labels = [
                L.get('screens.pomodoro.quality1'),
                L.get('screens.pomodoro.quality2'),
                L.get('screens.pomodoro.quality3'),
                L.get('screens.pomodoro.quality4'),
                L.get('screens.pomodoro.quality5'),
              ];
              final isSelected = selected == score;
              return GestureDetector(
                onTap: () {
                  setSt(() => selected = score);
                  HapticFeedback.lightImpact();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? acc.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? acc : Color(tc.brd), width: 1.5)),
                  child: Column(children: [
                    Text(emojis[i], style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(labels[i], style: TextStyle(fontSize: 9.5,
                        color: isSelected ? acc : Color(tc.ts),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
                  ])));
            })),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (selected != null) {
                FocusQualityService.rateLastSession(selected!);
              }
              Navigator.pop(ctx);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected != null ? acc : Color(tc.brd),
                borderRadius: BorderRadius.circular(14)),
              child: Text(selected != null ? L.submit : L.skip,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: selected != null ? Colors.white : Color(tc.tm))))),
        ]),
      )));
  }

  void _start() {
    CrashLogger.tap('PomodoroScreen', 'start task=${widget.appState.engine.selTaskId}');
    HapticFeedback.mediumImpact();
    widget.appState.pomStart();
    // Start distraction monitoring if enabled
    if (widget.appState.settings.distractionAlertEnabled) {
      DistractionDetector.startMonitoring();
    }
    // Start env noise sampling if enabled
    if (widget.appState.settings.noisePomEnabled) {
      EnvironmentSoundService.startSessionSampling();
    }
  }

  void _pause() {
    CrashLogger.tap('PomodoroScreen', 'pause');
    HapticFeedback.lightImpact();
    widget.appState.pomPause();
    DistractionDetector.stopMonitoring();
  }

  void _openAmbient() {
    Navigator.push(context, PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => const PomodoroAmbientScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final engine  = appState.engine;
    final tc      = appState.themeConfig;
    final s       = appState.settings.pom;

    final isFocus = engine.mode == PomMode.focus;
    final accent  = isFocus ? Color(tc.acc) : Color(tc.acc2);
    final bgBase  = Colors.transparent;

    final m   = engine.secsLeft ~/ 60;
    final sec = engine.secsLeft % 60;
    final timeStr = '${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';

    final hasStarted = engine.sessionFocusSecs > 0 ||
        (engine.secsLeft < engine.totalSecs && engine.secsLeft > 0);

    // Today + overdue tasks for task selection
    final today = appState.todayKey;
    final availTasks = appState.tasks.where((t) {
      if (t.done || t.ignored) return false;
      if (t.createdAt == today || t.rescheduledTo == today) return true;
      if (t.originalDate.compareTo(today) < 0) return true;
      return false;
    }).toList();

    // Sessions for time ruler
    final sessions = <(double, int, bool)>[];
    for (final t in appState.tasks) {
      if (t.focusSecs <= 0) continue;
      if (t.createdAt != today && t.doneAt != today) continue;
      if (t.doneHour != null) {
        sessions.add((t.doneHour! - t.focusSecs / 3600.0, t.focusSecs ~/ 60, true));
      }
    }

    // Bound task name
    final boundTask = engine.selTaskId != null
        ? availTasks.where((t) => t.id == engine.selTaskId).firstOrNull
        : null;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: bgBase,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        color: isFocus
            ? Color.lerp(bgBase, accent, engine.running ? 0.055 : 0.02)!
            : Color.lerp(bgBase, accent, engine.running ? 0.045 : 0.015)!,
        child: isLandscape
            ? _buildLandscape(context, appState, engine, s, tc, accent,
                isFocus, hasStarted, timeStr, boundTask, availTasks, sessions, bgBase)
            : Stack(children: [

          // ── Background pulse rings (running only) ─────────────────
          if (engine.running)
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) {
                return Positioned.fill(child: CustomPaint(
                  painter: _PulsePainter(
                    color: accent.withOpacity(0.04 * _glowAnim.value),
                    progress: engine.progress,
                  ),
                ));
              }),

          // ── Main scrollable content ───────────────────────────────
          Positioned.fill(child: Column(children: [
            // Dynamic spacing based on top bar height
            Builder(builder: (context) {
              final state = context.watch<AppState>();
              final topPad = MediaQuery.of(context).padding.top;
              final showClock = state.settings.showTopClock;
              final appBarHeight = showClock ? 78.0 : 46.0;
              final topMargin = 8.0;
              return SizedBox(height: topPad + appBarHeight + topMargin + 8 + state.settings.topBarOffset); // Precise spacing + Dynamic Offset
            }),
            // ── Status row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                // Mode chip
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: accent.withOpacity(0.25), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: engine.running ? accent : accent.withOpacity(0.4),
                        boxShadow: engine.running ? [BoxShadow(
                            color: accent.withOpacity(0.6),
                            blurRadius: 4, spreadRadius: 1)] : null),
                    ),
                    const SizedBox(width: 7),
                    Text(_modeLabel(engine.mode, engine.running),
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: accent)),
                  ]),
                ),
                const SizedBox(width: 10),
                // Cycle pips
                Row(children: List.generate(s.longBreakInterval, (i) {
                  final filled = i < engine.focusRoundsSinceLongBreak;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200 + i * 50),
                    curve: Curves.elasticOut,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: filled ? 9 : 6, height: filled ? 9 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? accent : Color(tc.brd),
                      boxShadow: filled ? [BoxShadow(
                          color: accent.withOpacity(0.45), blurRadius: 5)] : null),
                  );
                })),
                const Spacer(),
                // Round label
                Text(L.get('screens.pomodoro.roundCount', {'count': engine.cycle}),
                  style: TextStyle(fontSize: 11, color: Color(tc.tm))),
                const SizedBox(width: 4),
                // History button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showPomHistory(context),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.history_rounded, size: 18, color: Color(tc.tm)))),
                const SizedBox(width: 2),
                // Settings button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showSettingsSheet(context, appState, tc, s, accent),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.tune_rounded, size: 18, color: Color(tc.tm)))),
              ])),

            const SizedBox(height: 4),

            // ── Hint line ───────────────────────────────────────────
            Center(
              child: Text(_nextLabel(engine.mode, engine, s),
                style: TextStyle(fontSize: 10.5, color: Color(tc.tm)))),

            // ── 时长快切 Ticker（紧凑双轨，位于轮次点下方）───────────
            if (!engine.running)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 32, right: 32),
                child: _DualTimerTicker(
                  focusMins: s.focusMins,
                  breakMins: s.breakMins,
                  accent: accent,
                  accent2: Color(tc.acc2),
                  tc: tc,
                  onFocusTap: (mins) {
                    HapticFeedback.selectionClick();
                    appState.updatePomSettings(focusMins: mins);
                  },
                  onBreakTap: (mins) {
                    HapticFeedback.selectionClick();
                    appState.updatePomSettings(breakMins: mins);
                  },
                ),
              ),

            const Spacer(flex: 2),

            // ── Main ring ───────────────────────────────────────────
            // Ensure the ring has a stable size and doesn't compress
            SizedBox(
              height: MediaQuery.of(context).size.width * 0.72,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: AnimatedBuilder(
                  animation: _breathAnim,
                  builder: (_, child) => Transform.scale(
                    scale: engine.running ? _breathAnim.value : 1.0,
                    child: child),
                  child: PomodoroRing(
                    progress: engine.progress,
                    timeStr: timeStr,
                    ringColor: accent,
                    textColor: Color(tc.tx),
                    running: engine.running,
                    isBreak: !isFocus,
                    showProgress: s.showProgress,
                    onTimeTap: _openAmbient,
                  )))),

            const Spacer(flex: 1),

            // ── Bound task name ─────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: boundTask != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 4),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _drawerOpen = !_drawerOpen),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: accent.withOpacity(0.18))),
                        child: Row(children: [
                          Container(width: 4, height: 4,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: accent)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(boundTask.text,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12,
                                color: Color(tc.tx)))),
                          Icon(Icons.swap_vert_rounded,
                              size: 14, color: Color(tc.tm)),
                        ]))))
                : Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 4),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _drawerOpen = !_drawerOpen),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(tc.brd).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Color(tc.brd).withOpacity(0.6),
                              style: BorderStyle.solid)),
                        child: Row(children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: Color(tc.tm)),
                          const SizedBox(width: 8),
                          Text(L.get('screens.pomodoro.tapToBindTask'),
                            style: TextStyle(fontSize: 12,
                                color: Color(tc.tm))),
                          const Spacer(),
                          Icon(Icons.expand_more_rounded,
                              size: 16, color: Color(tc.tm)),
                        ])))),
            ),

            // ── 心流指数 + 本轮时长 ──────────────────────────────────
            if (engine.running && engine.mode == PomMode.focus)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 24, right: 24),
                child: _FlowIndexBar(engine: engine, tc: tc, accent: accent)),

            if (s.trackTime && engine.sessionFocusSecs > 0 &&
                !(engine.running && engine.mode == PomMode.focus))
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 24, right: 24),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.timer_outlined, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text(L.get('screens.pomodoro.sessionDuration', {'duration': _fmtSecs(engine.sessionFocusSecs)}),
                    style: TextStyle(fontSize: 10, color: Color(tc.ts))),
                ])),

            const Spacer(flex: 1),

            // ── Controls ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                // Reset
                _CtrlBtn(
                  icon: Icons.refresh_rounded,
                  size: 22, color: Color(tc.ts), tc: tc,
                  onTap: () {
                    CrashLogger.tap('PomodoroScreen', 'reset');
                    HapticFeedback.lightImpact();
                    widget.appState.pomReset();
                  }),
                // Play/Pause — big
                _BigPlayBtn(
                  running: engine.running,
                  hasStarted: hasStarted,
                  color: accent,
                  onTap: engine.running ? _pause : _start),
                // Skip
                _CtrlBtn(
                  icon: Icons.skip_next_rounded,
                  size: 22, color: Color(tc.ts), tc: tc,
                  onTap: () {
                    CrashLogger.tap('PomodoroScreen',
                        'skip mode=${engine.mode.name}');
                    HapticFeedback.lightImpact();
                    widget.appState.pomSkip();
                  }),
              ])),

            // ── Auto-next + toast ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Column(children: [
                // Toast
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: _toast != null
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                        child: Text(_toast!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: accent,
                              fontWeight: FontWeight.w600)))
                    : const SizedBox.shrink()),
                // Auto-next row
                Row(children: [
                  Icon(Icons.loop_rounded, size: 12, color: Color(tc.tm)),
                  const SizedBox(width: 5),
                  Text(L.get('screens.pomodoro.autoNext'),
                      style: TextStyle(fontSize: 10.5, color: Color(tc.tm))),
                  const Spacer(),
                  AppSwitch(value: s.autoNext, tc: tc,
                      onChanged: (v) => appState.updatePomSettings(autoNext: v)),
                ]),
              ])),

            // (drawer is shown as overlay in Stack, not inline)

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ])),

          // ── Disc time ruler — glass window on LEFT side ─────────
          if (s.showRuler)
          Positioned(
            top: MediaQuery.of(context).size.height * s.rulerTopFrac,
            height: MediaQuery.of(context).size.height * s.rulerHeightFrac,
            left: s.rulerLeft,
            width: s.rulerWidth,
            child: TimeRuler(
              focusMins: s.focusMins,
              breakMins: s.breakMins,
              pomRunning: engine.running,
              isFocusMode: isFocus,
              accentColor: accent,
              trackColor: Color(tc.nb).withOpacity(0.90),
              lineColor: accent.withOpacity(0.55),
              textColor: Color(tc.ts),
              breakColor: Color(tc.acc2),
              sessions: sessions,
              width: s.rulerWidth,
            )),


          // ── Task drawer overlay — above ruler ─────────────────────
          if (_drawerOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _drawerOpen = false),
                child: Container(color: Colors.black.withOpacity(0.38)))),
            Positioned(
              left: 0, right: 0, bottom: 0,
              top: MediaQuery.of(context).size.height * 0.30,
              child: _TaskDrawer(
                tasks: availTasks, engine: engine,
                tc: tc, accent: accent, appState: appState,
                onClose: () => setState(() => _drawerOpen = false))),
          ],
        ]),  // Stack children end (= Stack close)
      ),     // AnimatedContainer
    );
  }

  // ── 横屏布局 ─────────────────────────────────────────────────────────────
  Widget _buildLandscape(
      BuildContext context, AppState appState, PomEngine engine,
      PomSettings s, ThemeConfig tc, Color accent, bool isFocus,
      bool hasStarted, String timeStr, TaskModel? boundTask,
      List<TaskModel> availTasks, List<(double, int, bool)> sessions,
      Color bgBase) {
    final safePad = MediaQuery.of(context).padding;
    return Stack(children: [

      // Background pulse
      if (engine.running)
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Positioned.fill(child: CustomPaint(
            painter: _PulsePainter(
              color: accent.withOpacity(0.04 * _glowAnim.value),
              progress: engine.progress)))),

      // ── 横屏：左侧信息 | 右侧圆环+控制 ────────────────────────────────
      Positioned.fill(child: Padding(
        padding: EdgeInsets.only(
          left: safePad.left + 8,
          right: safePad.right + 8,
          top: safePad.top + 4,
          bottom: safePad.bottom + 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── 左列：刻度条 + 状态信息 + 任务绑定 ───────────────────────
          SizedBox(width: 200, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部状态行
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withOpacity(0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: engine.running ? accent : accent.withOpacity(0.4),
                        boxShadow: engine.running ? [BoxShadow(
                          color: accent.withOpacity(0.6), blurRadius: 4)] : null)),
                    const SizedBox(width: 6),
                    Text(_modeLabel(engine.mode, engine.running),
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: accent)),
                  ])),
                const SizedBox(width: 8),
                Text(L.get('screens.pomodoro.roundCount', {'count': engine.cycle}),
                  style: TextStyle(fontSize: 10, color: Color(tc.tm))),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showPomHistory(context),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.history_rounded, size: 16, color: Color(tc.tm)))),
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showSettingsSheet(context, appState, tc, s, accent),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.tune_rounded, size: 16, color: Color(tc.tm)))),
              ]),
              const SizedBox(height: 6),
              // 轮次点
              Row(children: List.generate(s.longBreakInterval, (i) {
                final filled = i < engine.focusRoundsSinceLongBreak;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200 + i * 50),
                  curve: Curves.elasticOut,
                  margin: const EdgeInsets.only(right: 4),
                  width: filled ? 8 : 5, height: filled ? 8 : 5,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: filled ? accent : Color(tc.brd)));
              })),
              const SizedBox(height: 8),
              // 提示文字
              Text(_nextLabel(engine.mode, engine, s),
                style: TextStyle(fontSize: 10, color: Color(tc.tm))),
              const SizedBox(height: 8),
              // ── 时长快切 Ticker（横屏紧凑版）────────────────────────
              if (!engine.running) ...[
                _DualTimerTicker(
                  focusMins: s.focusMins,
                  breakMins: s.breakMins,
                  accent: accent,
                  accent2: Color(tc.acc2),
                  tc: tc,
                  onFocusTap: (mins) {
                    HapticFeedback.selectionClick();
                    appState.updatePomSettings(focusMins: mins);
                  },
                  onBreakTap: (mins) {
                    HapticFeedback.selectionClick();
                    appState.updatePomSettings(breakMins: mins);
                  },
                ),
                const SizedBox(height: 6),
              ],
              const Spacer(),
              // 绑定任务
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _drawerOpen = !_drawerOpen),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: boundTask != null
                        ? accent.withOpacity(0.08)
                        : Color(tc.brd).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: boundTask != null
                          ? accent.withOpacity(0.18)
                          : Color(tc.brd).withOpacity(0.6))),
                  child: Row(children: [
                    Icon(boundTask != null
                        ? Icons.task_alt_rounded
                        : Icons.add_circle_outline_rounded,
                      size: 13, color: boundTask != null ? accent : Color(tc.tm)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      boundTask?.text ?? L.get('screens.pomodoro.tapToBindTask'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11,
                        color: boundTask != null ? Color(tc.tx) : Color(tc.tm)))),
                    Icon(Icons.expand_more_rounded, size: 13, color: Color(tc.tm)),
                  ]))),
              const SizedBox(height: 8),
              // 心流指数（专注运行时）
              if (engine.running && engine.mode == PomMode.focus)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _FlowIndexBar(engine: engine, tc: tc, accent: accent)),
              // 本轮专注时间
              if (s.trackTime && engine.sessionFocusSecs > 0 &&
                  !(engine.running && engine.mode == PomMode.focus))
                Row(children: [
                  Icon(Icons.timer_outlined, size: 11, color: accent),
                  const SizedBox(width: 3),
                  Text(L.get('screens.pomodoro.sessionDuration', {'duration': _fmtSecs(engine.sessionFocusSecs)}),
                    style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
                ]),
              const SizedBox(height: 4),
              // Toast
              if (_toast != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(_toast!, style: TextStyle(
                    fontSize: 11, color: accent, fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              // Auto-next
              Row(children: [
                Icon(Icons.loop_rounded, size: 11, color: Color(tc.tm)),
                const SizedBox(width: 4),
                Text(L.get('screens.pomodoro.autoNext'),
                  style: TextStyle(fontSize: 10, color: Color(tc.tm))),
                const Spacer(),
                AppSwitch(value: s.autoNext, tc: tc,
                  onChanged: (v) => appState.updatePomSettings(autoNext: v)),
              ]),
            ])),

          const SizedBox(width: 12),

          // ── 右列：圆盘刻度条 + 圆环 + 控制按钮 ──────────────────────
          Expanded(child: Stack(alignment: Alignment.center, children: [
            // 圆环（中央）
            LayoutBuilder(builder: (_, constraints) {
              final diameter = constraints.maxHeight * 0.72;
              return Center(
                child: AnimatedBuilder(
                  animation: _breathAnim,
                  builder: (_, child) => Transform.scale(
                    scale: engine.running ? _breathAnim.value : 1.0,
                    child: child),
                  child: SizedBox(width: diameter, height: diameter,
                    child: PomodoroRing(
                      progress: engine.progress,
                      timeStr: timeStr,
                      ringColor: accent,
                      textColor: Color(tc.tx),
                      running: engine.running,
                      isBreak: !isFocus,
                      showProgress: s.showProgress,
                      onTimeTap: _openAmbient))));
            }),
            // 控制按钮行（底部）
            Positioned(
              bottom: 8, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CtrlBtn(
                    icon: Icons.refresh_rounded,
                    size: 22, color: Color(tc.ts), tc: tc,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      appState.pomReset();
                    }),
                  const SizedBox(width: 24),
                  _BigPlayBtn(
                    running: engine.running,
                    hasStarted: hasStarted,
                    color: accent,
                    onTap: engine.running ? _pause : _start),
                  const SizedBox(width: 24),
                  _CtrlBtn(
                    icon: Icons.skip_next_rounded,
                    size: 22, color: Color(tc.ts), tc: tc,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      appState.pomSkip();
                    }),
                ])),
            // 刻度条（左侧）
            if (s.showRuler)
            Positioned(
              left: 6,
              top: MediaQuery.of(context).size.height * s.rulerTopFrac,
              height: MediaQuery.of(context).size.height * s.rulerHeightFrac,
              width: s.rulerWidth,
              child: TimeRuler(
                focusMins: s.focusMins, breakMins: s.breakMins,
                pomRunning: engine.running, isFocusMode: isFocus,
                accentColor: accent,
                trackColor: Color(tc.nb).withOpacity(0.90),
                lineColor: accent.withOpacity(0.55),
                textColor: Color(tc.ts),
                breakColor: Color(tc.acc2),
                sessions: sessions,
                width: s.rulerWidth)),
          ])),
        ])),
      ),

      // ── 任务抽屉 overlay ──────────────────────────────────────────────
      if (_drawerOpen) ...[
        Positioned.fill(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _drawerOpen = false),
          child: Container(color: Colors.black.withOpacity(0.38)))),
        Positioned(
          left: 0, right: 0, bottom: 0,
          top: MediaQuery.of(context).size.height * 0.25,
          child: _TaskDrawer(
            tasks: availTasks, engine: engine,
            tc: tc, accent: accent, appState: appState,
            onClose: () => setState(() => _drawerOpen = false))),
      ],
    ]);
  }

  void _showSettingsSheet(BuildContext context, AppState appState,
      ThemeConfig tc, PomSettings s, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(
                color: Color(tc.brd),
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(L.get('screens.settings.pomSettings'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: Color(tc.tx))),
          const SizedBox(height: 16),
          _SettingRow(label: L.get('screens.settings.focusDuration'), value: L.get('time.minuteValue', {'mins': s.focusMins}), tc: tc,
              onTap: () {}),
          _SettingRow(label: L.get('screens.settings.shortBreak'), value: L.get('time.minuteValue', {'mins': s.breakMins}), tc: tc,
              onTap: () {}),
          _SettingRow(label: L.get('screens.settings.longBreakInterval'), value: L.get('screens.pomodoro.roundCount', {'count': s.longBreakInterval}), tc: tc,
              onTap: () {}),
          const SizedBox(height: 12),
          // 进度条开关
          Row(children: [
            Icon(Icons.linear_scale_rounded, size: 16, color: Color(tc.ts)),
            const SizedBox(width: 8),
            Text(L.get('screens.settings.showProgress'), style: TextStyle(fontSize: 13, color: Color(tc.tx))),
            const Spacer(),
            AppSwitch(value: s.showProgress, tc: tc,
                onChanged: (v) => appState.updatePomSettings(showProgress: v)),
          ]),

        ])));
  }

  String _modeLabel(PomMode m, bool running) => switch (m) {
    PomMode.focus      => running ? L.get('screens.pomodoro.modeFocus') : L.get('screens.pomodoro.modeReady'),
    PomMode.shortBreak => L.get('screens.pomodoro.modeBreak'),
    PomMode.longBreak  => L.get('screens.pomodoro.modeLongBreak'),
  };

  String _nextLabel(PomMode m, PomEngine e, PomSettings s) {
    switch (m) {
      case PomMode.focus:
        final rounds = s.longBreakInterval - e.focusRoundsSinceLongBreak;
        return rounds <= 1 
            ? L.get('screens.pomodoro.nextLongBreak', {'mins': s.longBreakMins}) 
            : L.get('screens.pomodoro.nextBreak', {'mins': s.breakMins});
      case PomMode.shortBreak:
        return L.get('screens.pomodoro.nextFocus', {'mins': s.focusMins});
      case PomMode.longBreak:
        return L.get('screens.pomodoro.nextFocus', {'mins': s.focusMins});
    }
  }

  String _fmtSecs(int s) {
    if (s < 60) return '${s}${L.get('time.second')}';
    if (s < 3600) return '${s ~/ 60}${L.get('time.minuteShort')}';
    return '${s ~/ 3600}${L.get('time.hour')}${s % 3600 ~/ 60 > 0 ? '${s % 3600 ~/ 60}${L.get('time.minuteShort')}' : ''}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 背景脉冲圆圈
// ─────────────────────────────────────────────────────────────────────────────
class _PulsePainter extends CustomPainter {
  final Color color;
  final double progress;
  const _PulsePainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final r = size.width * 0.38;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r * 1.15,
        Paint()..color = color.withOpacity(color.opacity * 0.5)
          ..style = PaintingStyle.fill);
  }
  @override bool shouldRepaint(_PulsePainter o) =>
      o.color != color || o.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Big play/pause button
// ─────────────────────────────────────────────────────────────────────────────
class _BigPlayBtn extends StatefulWidget {
  final bool running, hasStarted;
  final Color color;
  final VoidCallback onTap;
  const _BigPlayBtn({required this.running, required this.hasStarted,
      required this.color, required this.onTap});
  @override State<_BigPlayBtn> createState() => _BigPlayBtnState();
}
class _BigPlayBtnState extends State<_BigPlayBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _sc;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100));
    _sc = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeIn));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final label = widget.running 
        ? L.get('screens.common.pause') 
        : widget.hasStarted ? L.get('screens.common.continue') : L.get('screens.common.start');
    final icon  = widget.running ? Icons.pause_rounded : Icons.play_arrow_rounded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) { _ac.reverse(); widget.onTap(); },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _sc,
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.running
                ? widget.color.withOpacity(0.12)
                : widget.color,
            border: widget.running
                ? Border.all(color: widget.color, width: 2) : null,
            boxShadow: widget.running ? null : [
              BoxShadow(color: widget.color.withOpacity(0.4),
                  blurRadius: 20, offset: const Offset(0, 4)),
            ]),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 32,
                color: widget.running ? widget.color : Colors.white),
            Text(label, style: TextStyle(
                fontSize: 10,
                color: widget.running ? widget.color : Colors.white,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Control icon button
// ─────────────────────────────────────────────────────────────────────────────
class _CtrlBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final ThemeConfig tc;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.size,
      required this.color, required this.tc, required this.onTap});
  @override State<_CtrlBtn> createState() => _CtrlBtnState();
}
class _CtrlBtnState extends State<_CtrlBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80),
        lowerBound: 0.88, upperBound: 1.0)..value = 1.0;
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.reverse(),
      onTapUp: (_) { _ac.forward(); widget.onTap(); },
      onTapCancel: () => _ac.forward(),
      child: ScaleTransition(
        scale: _ac,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(widget.tc.card)),
          child: Icon(widget.icon, size: widget.size, color: widget.color))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task drawer
// ─────────────────────────────────────────────────────────────────────────────
class _TaskDrawer extends StatelessWidget {
  final List<TaskModel> tasks;
  final PomEngine engine;
  final ThemeConfig tc;
  final Color accent;
  final AppState appState;
  final VoidCallback onClose;
  const _TaskDrawer({required this.tasks, required this.engine,
      required this.tc, required this.accent, required this.appState,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: appState.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(
            color: const Color(0x28000000), blurRadius: 24,
            offset: const Offset(0, -6))]),
      child: Column(children: [
        // Handle + title
        const SizedBox(height: 10),
        Row(children: [
          const SizedBox(width: 16),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: Color(tc.brd),
              borderRadius: BorderRadius.circular(2))),
          const Spacer(),
          Text(L.get('screens.pomodoro.selectTaskToBind'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(tc.ts))),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Icon(Icons.close_rounded, size: 18, color: Color(tc.tm)))),
        ]),
        const SizedBox(height: 6),
        Divider(color: Color(tc.brd), height: 1),
        const SizedBox(height: 6),
        // None option
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _TaskOption(
            label: L.get('screens.pomodoro.noTaskBound'),
            sublabel: L.get('screens.pomodoro.freeFocusMode'),
            selected: engine.selTaskId == null,
            color: Color(tc.ts), accent: accent, tc: tc,
            onTap: () {
              CrashLogger.tap('PomodoroScreen', 'selectTask null');
              appState.pomSelectTask(null);
              onClose();
            })),
        const SizedBox(height: 4),
        // Task list — Expanded so it fills remaining overlay height
        Expanded(child: tasks.isEmpty
          ? Center(child: Text(L.get('screens.pomodoro.noTasksToday'),
              style: TextStyle(fontSize: 13, color: Color(tc.tm))))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
              itemCount: tasks.length,
              itemBuilder: (_, idx) {
                final t = tasks[idx];
                final tagColor = t.tags.isNotEmpty
                    ? appState.tagColor(t.tags.first) : Color(tc.ts);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _TaskOption(
                    label: t.text,
                    sublabel: t.tags.isNotEmpty ? t.tags.first : '',
                    selected: engine.selTaskId == t.id,
                    color: tagColor, accent: accent, tc: tc,
                    onTap: () {
                      CrashLogger.tap('PomodoroScreen', 'selectTask ${t.id}');
                      appState.pomSelectTask(t.id);
                      onClose();
                    }));
              })),
      ]),
    );
  }
}

class _TaskOption extends StatelessWidget {
  final String label, sublabel;
  final bool selected;
  final Color color, accent;
  final ThemeConfig tc;
  final VoidCallback onTap;
  const _TaskOption({required this.label, required this.sublabel,
      required this.selected, required this.color, required this.accent,
      required this.tc, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? accent.withOpacity(0.10)
            : Color(tc.bg).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: accent.withOpacity(0.4))
            : Border.all(color: Colors.transparent)),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? accent : color.withOpacity(0.5))),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Color(tc.tx) : Color(tc.ts))),
          if (sublabel.isNotEmpty)
            Text(sublabel, style: TextStyle(fontSize: 9.5, color: color)),
        ])),
        if (selected)
          Icon(Icons.check_circle_rounded, size: 16, color: accent),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings row in bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final String label, value;
  final ThemeConfig tc;
  final VoidCallback onTap;
  const _SettingRow({required this.label, required this.value,
      required this.tc, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 13, color: Color(tc.ts))),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w600, color: Color(tc.tx))),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// 双轨时长快切组件
// 一行显示「🍅 25′ | ☕ 5′」，点击任意一侧展开悬浮选择器
// 极紧凑，高度约 34px，运行时隐藏
// ─────────────────────────────────────────────────────────────────────────────
class _DualTimerTicker extends StatefulWidget {
  final int focusMins;
  final int breakMins;
  final Color accent;
  final Color accent2;
  final ThemeConfig tc;
  final void Function(int) onFocusTap;
  final void Function(int) onBreakTap;

  const _DualTimerTicker({
    required this.focusMins,
    required this.breakMins,
    required this.accent,
    required this.accent2,
    required this.tc,
    required this.onFocusTap,
    required this.onBreakTap,
  });

  @override
  State<_DualTimerTicker> createState() => _DualTimerTickerState();
}

class _DualTimerTickerState extends State<_DualTimerTicker>
    with SingleTickerProviderStateMixin {
  // null = 收起，'focus' or 'break' = 展开哪侧
  String? _open;
  late AnimationController _anim;
  late Animation<double> _fade;

  static const _focusOpts = [15, 25, 45, 90];
  static const _breakOpts  = [3, 5, 10, 15];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 180));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _toggle(String side) {
    setState(() {
      if (_open == side) {
        _open = null;
        _anim.reverse();
      } else {
        _open = side;
        _anim.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final accent  = widget.accent;
    final accent2 = widget.accent2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 主行：🍅 25′  |  ☕ 5′ ────────────────────────────────
        Container(
          height: 34,
          decoration: BoxDecoration(
            color: Color(tc.card).withOpacity(0.7),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Color(tc.brd).withOpacity(0.5)),
          ),
          child: Row(children: [
            // Focus side
            Expanded(child: GestureDetector(
              onTap: () => _toggle('focus'),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _open == 'focus'
                      ? accent.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🍅', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: _open == 'focus' ? 16 : 14,
                        fontWeight: FontWeight.w800,
                        color: _open == 'focus' ? accent : Color(tc.tx),
                        fontFamily: 'serif',
                      ),
                      child: Text('${widget.focusMins}′'),
                    ),
                    const SizedBox(width: 3),
                    AnimatedRotation(
                      turns: _open == 'focus' ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: _open == 'focus'
                              ? accent : Color(tc.tm)),
                    ),
                  ],
                ),
              ),
            )),

            // Divider
            Container(width: 1, height: 16,
                color: Color(tc.brd).withOpacity(0.6)),

            // Break side
            Expanded(child: GestureDetector(
              onTap: () => _toggle('break'),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _open == 'break'
                      ? accent2.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('☕', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: _open == 'break' ? 16 : 14,
                        fontWeight: FontWeight.w800,
                        color: _open == 'break' ? accent2 : Color(tc.tx),
                        fontFamily: 'serif',
                      ),
                      child: Text('${widget.breakMins}′'),
                    ),
                    const SizedBox(width: 3),
                    AnimatedRotation(
                      turns: _open == 'break' ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: _open == 'break'
                              ? accent2 : Color(tc.tm)),
                    ),
                  ],
                ),
              ),
            )),
          ]),
        ),

        // ── 展开选择器（FadeTransition + SizeTransition）─────────────
        FadeTransition(
          opacity: _fade,
          child: SizeTransition(
            sizeFactor: _fade,
            axisAlignment: -1,
            child: _open != null ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _PickerRow(
                options: _open == 'focus' ? _focusOpts : _breakOpts,
                current: _open == 'focus'
                    ? widget.focusMins : widget.breakMins,
                accent: _open == 'focus' ? accent : accent2,
                tc: tc,
                onTap: (mins) {
                  if (_open == 'focus') widget.onFocusTap(mins);
                  else widget.onBreakTap(mins);
                  setState(() { _open = null; });
                  _anim.reverse();
                },
              ),
            ) : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// ── 选项行（展开后显示）──────────────────────────────────────────────────────
class _PickerRow extends StatelessWidget {
  final List<int> options;
  final int current;
  final Color accent;
  final ThemeConfig tc;
  final void Function(int) onTap;

  const _PickerRow({
    required this.options,
    required this.current,
    required this.accent,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((mins) {
        final sel = current == mins;
        return Expanded(child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onTap(mins); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 36,
            decoration: BoxDecoration(
              color: sel ? accent.withOpacity(0.15) : Color(tc.card).withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? accent : Color(tc.brd).withOpacity(0.4),
                width: sel ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$mins',
                  style: TextStyle(
                    fontSize: sel ? 15 : 13,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel ? accent : Color(tc.ts),
                    fontFamily: 'serif',
                  )),
                Text('min',
                  style: TextStyle(
                    fontSize: 8,
                    color: sel ? accent.withOpacity(0.7) : Color(tc.tm),
                  )),
              ],
            ),
          ),
        ));
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 心流状态指数组件 — 仅在专注运行时显示，每 tick 由外层 ListenableBuilder 驱动
//
// 五维算法（0-100）：
//   A 连续专注占比    sessionFocusSecs / totalSecs       权重 35%
//   B 无暂停加成      max(0, 1 - pauseCount * 0.25)      权重 25%
//   C 进度深度        progress (0→1)                     权重 20%
//   D 历史质量基准    avgCompositeScore/100 (近14天)      权重 10%
//   E 无娱乐干扰加成  max(0, 1 - distractionCount * 0.3) 权重 10%
//
// 阶段：预热(0-34) → 进入(35-59) → 专注(60-79) → 深度心流(80-100)
// ─────────────────────────────────────────────────────────────────────────────
class _FlowIndexBar extends StatefulWidget {
  final PomEngine engine;
  final ThemeConfig tc;
  final Color accent;
  const _FlowIndexBar({required this.engine, required this.tc, required this.accent});
  @override State<_FlowIndexBar> createState() => _FlowIndexBarState();
}

class _FlowIndexBarState extends State<_FlowIndexBar>
    with SingleTickerProviderStateMixin {
  double _historyBaseline = 0.5;
  bool _baselineLoaded = false;
  late AnimationController _animCtrl;
  double _prevIndex = 0;
  double _animTarget = 0;
  
  late Map<UIField, String> _ui;

  @override
  void initState() {
    super.initState();
    _refreshUI();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _loadBaseline();
  }

  void _refreshUI() {
    _ui = DisplayAdapter.getDisplayData(PomodoroPageState(false));
  }

  Future<void> _loadBaseline() async {
    final avg = await FocusQualityService.avgCompositeScore(days: 14);
    if (mounted) setState(() {
      _historyBaseline = avg > 0 ? (avg / 100).clamp(0.0, 1.0) : 0.5;
      _baselineLoaded = true;
      _refreshUI();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  double _calcIndex() {
    final e = widget.engine;
    if (e.totalSecs <= 0) return 0;
    final a = (e.sessionFocusSecs / e.totalSecs).clamp(0.0, 1.0);
    final b = (1.0 - e.pauseCount * 0.25).clamp(0.0, 1.0);
    final c = e.progress.clamp(0.0, 1.0);
    final d = _historyBaseline;
    final f = (1.0 - DistractionDetector.distractionCount * 0.30).clamp(0.0, 1.0);
    return (a * 0.35 + b * 0.25 + c * 0.20 + d * 0.10 + f * 0.10).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final idx   = _calcIndex();
    final score = (idx * 100).round();
    _refreshUI();

    if ((idx - _animTarget).abs() > 0.008) {
      final begin = _prevIndex;
      _animCtrl.stop();
      _animCtrl.value = 0;
      _animCtrl.duration = Duration(milliseconds: idx > _prevIndex ? 800 : 1200);
      _animTarget = idx;
      // drive animation externally via TweenAnimationBuilder inside
    }
    _prevIndex = idx;

    final tc     = widget.tc;
    final accent = widget.accent;

    // Phase colours: grey → blue → accent → gold
    final flowColor = score >= 80
        ? const Color(0xFFFFB300)
        : score >= 60
            ? accent
            : score >= 35
                ? const Color(0xFF3a90c0)
                : Color(tc.ts);

    final phase = score >= 80 ? _ui[UIField.flowStateDeep]!
        : score >= 60 ? _ui[UIField.flowStateFocused]!
        : score >= 35 ? _ui[UIField.flowStateEntering]!
        : _ui[UIField.flowStateWarmingUp]!;

    final e = widget.engine;

    return Column(mainAxisSize: MainAxisSize.min, children: [

      // ── Score + label row ──────────────────────────────────────────
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Big animated score
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: idx * 100),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (_, val, __) => Text('${val.round()}',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900,
                  color: flowColor, height: 1.0)),
        ),
        const SizedBox(width: 5),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text(_ui[UIField.flowIndex]!,
              style: TextStyle(fontSize: 9, color: Color(tc.ts))),
          Text(phase, style: TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.w600, color: flowColor)),
        ]),
        const Spacer(),
        // Interrupt badges
        if (e.pauseCount > 0)
          _FlowBadge('⏸ ${e.pauseCount}', const Color(0xFFe8982a), tc),
        if (DistractionDetector.distractionCount > 0) ...[
          const SizedBox(width: 4),
          _FlowBadge('📱 ${DistractionDetector.distractionCount}',
              const Color(0xFFc04040), tc),
        ],
      ]),

      const SizedBox(height: 7),

      // ── Segmented meter bar ────────────────────────────────────────
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: idx),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (_, v, __) => _SegmentedMeter(value: v, tc: tc, accent: accent),
      ),

      const SizedBox(height: 5),

      // ── 5-dim sub-scores ──────────────────────────────────────────
      if (_baselineLoaded)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _FlowSub(_ui[UIField.flowMetricContinuous]!, (e.sessionFocusSecs /
              (e.totalSecs > 0 ? e.totalSecs : 1)).clamp(0.0, 1.0), tc),
          const SizedBox(width: 6),
          _FlowSub(_ui[UIField.flowMetricFocus]!, (1.0 - e.pauseCount * 0.25).clamp(0.0, 1.0), tc),
          const SizedBox(width: 6),
          _FlowSub(_ui[UIField.flowMetricDepth]!, e.progress.clamp(0.0, 1.0), tc),
          const SizedBox(width: 6),
          _FlowSub(_ui[UIField.flowMetricNoDistraction]!, (1.0 - DistractionDetector.distractionCount * 0.30)
              .clamp(0.0, 1.0), tc),
        ]),
    ]);
  }
}

// ── Segmented meter: four zone blocks with smooth fill ───────────────────────
class _SegmentedMeter extends StatelessWidget {
  final double value; // 0-1
  final ThemeConfig tc;
  final Color accent;
  const _SegmentedMeter({required this.value, required this.tc, required this.accent});

  @override
  Widget build(BuildContext context) {
    // Four equal zones: 0-35 / 35-60 / 60-80 / 80-100
    const thresholds = [0.0, 0.35, 0.60, 0.80, 1.0];
    final zoneColors = [
      Color(tc.brd),               // grey  — 预热
      const Color(0xFF3a90c0),      // blue  — 进入
      accent,                       // theme — 专注
      const Color(0xFFFFB300),      // gold  — 深度
    ];

    return Row(children: List.generate(4, (i) {
      final zStart = thresholds[i];
      final zEnd   = thresholds[i + 1];
      final zWidth = zEnd - zStart;
      // How much of this zone is filled (0-1 within zone)
      final fill = value <= zStart ? 0.0
          : value >= zEnd ? 1.0
          : (value - zStart) / zWidth;
      final isActive = value > zStart;

      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < 3 ? 2 : 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            // Track
            Container(
                height: 5,
                color: Color(tc.brd).withOpacity(0.30)),
            // Fill
            FractionallySizedBox(
              widthFactor: fill,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: isActive
                      ? zoneColors[i].withOpacity(0.80)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: fill >= 1.0 ? [BoxShadow(
                      color: zoneColors[i].withOpacity(0.45),
                      blurRadius: 4)] : null,
                ),
              ),
            ),
          ]),
        ),
      ));
    }));
  }
}

class _FlowBadge extends StatelessWidget {
  final String text;
  final Color color;
  final ThemeConfig tc;
  const _FlowBadge(this.text, this.color, this.tc);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.30))),
    child: Text(text, style: TextStyle(
        fontSize: 9, color: color, fontWeight: FontWeight.w600)),
  );
}

class _FlowSub extends StatelessWidget {
  final String label;
  final double value;
  final ThemeConfig tc;
  const _FlowSub(this.label, this.value, this.tc);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label ', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
      Text('${(value * 100).round()}%',
          style: TextStyle(fontSize: 8.5, color: Color(tc.ts),
              fontWeight: FontWeight.w600)),
    ],
  );
}
