// lib/screens/pomodoro_ambient.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/pom_engine.dart';
import '../services/focus_quality_service.dart';
import '../beta/beta_flags.dart';

class PomodoroAmbientScreen extends StatefulWidget {
  const PomodoroAmbientScreen({super.key});
  @override
  State<PomodoroAmbientScreen> createState() => _PomodoroAmbientScreenState();
}

class _PomodoroAmbientScreenState extends State<PomodoroAmbientScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  double? _originalBrightness;
  // Cache engine ref so dispose() never calls context.read on a dead element
  late PomEngine _engine;

  // Burn-in prevention: drift offset, 1px per minute
  double _driftX = 0, _driftY = 0;
  Timer? _driftTimer;
  static const _driftPx = 30.0; // max drift radius

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyDimBrightness();
    _acquireScreenOn();
    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _startDrift();
    // Cache engine BEFORE any async work — context is valid here
    _engine = context.read<AppState>().engine;
    _engine.phaseJustCompleted.addListener(_onPhase);
  }

  static const _windowCh = MethodChannel('com.lsz.app/keepalive');
  static const _alarmCh  = MethodChannel('com.lsz.app/pom_alarm');

  Future<void> _acquireScreenOn() async {
    try { await _windowCh.invokeMethod('acquire'); } catch (_) {}
  }

  Future<void> _releaseScreenOn() async {
    // Only release if pom is no longer running (don't release if timer still active)
    try { await _windowCh.invokeMethod('release'); } catch (_) {}
  }

  void _startDrift() {
    int tick = 0;
    _driftTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      tick++;
      // Lissajous: x and y drift independently on different periods
      setState(() {
        _driftX = _driftPx * sin(tick * 0.37); // ~170s period
        _driftY = _driftPx * sin(tick * 0.23); // ~273s period
      });
    });
  }

  Future<void> _applyDimBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      // Use extremely low brightness for AOD mode
      await ScreenBrightness().setScreenBrightness(0.01);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        // Restore to original or a sensible default
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
      }
      // Always call reset to release the plugin's override
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
  }

  @override
  void dispose() {
    // Use cached _engine — context.read is NOT safe in dispose()
    _engine.phaseJustCompleted.removeListener(_onPhase);
    _restoreBrightness();
    _releaseScreenOn();
    _driftTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _onPhase() async {
    final state = context.read<AppState>();
    final mode  = state.engine.phaseJustCompleted.value;
    if (mode == null || !mounted) return;

    final pom = state.settings.pom;
    final isFocus = mode == PomMode.focus;

    // 1. Restore brightness to normal so user can see the alert
    await _restoreBrightness();
    // Re-apply a slightly higher brightness than 0.01 so the dialog is visible
    try { await ScreenBrightness().setScreenBrightness(0.3); } catch (_) {}

    // 2. Ring alarm via native channel
    try {
      await _alarmCh.invokeMethod('ring', {
        'sound': pom.alarmSound,
        'vibrate': pom.alarmVibrate,
      });
    } catch (_) {}

    // 3. Restore system UI (exit immersive mode temporarily)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 4. Show fullscreen alert dialog
    if (!mounted) return;
    final tc  = state.themeConfig;
    final acc = Color(tc.acc);
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
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.85, end: 1.0),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOut,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: acc.withOpacity(0.20),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: acc.withOpacity(0.55), width: 2.5),
                            boxShadow: [BoxShadow(
                                color: acc.withOpacity(0.30),
                                blurRadius: 28, spreadRadius: 4)],
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
                      Text(
                        isFocus ? '专注完成！' : '休息结束！',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isFocus
                            ? '本轮 ${pom.focusMins} 分钟已完成，好好休息一下'
                            : '休息时间结束，准备好开始下一轮专注了吗？',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15,
                            color: Colors.white.withOpacity(0.75)),
                      ),
                      if (isFocus && state.settings.focusQualityEnabled) ...[
                        const SizedBox(height: 32),
                        Text('这轮专注感觉怎么样？',
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (i) {
                            final score = i + 1;
                            const emojis = ['😩','😕','😐','😊','🔥'];
                            const labels = ['很差','较差','一般','不错','极佳'];
                            final sel = ratingSelected == score;
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
                                  color: sel
                                      ? acc.withOpacity(0.28)
                                      : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: sel ? acc
                                          : Colors.white.withOpacity(0.25),
                                      width: 1.5),
                                ),
                                child: Column(children: [
                                  Text(emojis[i],
                                      style: const TextStyle(fontSize: 24)),
                                  const SizedBox(height: 4),
                                  Text(labels[i], style: TextStyle(
                                      fontSize: 9.5,
                                      color: sel ? acc
                                          : Colors.white.withOpacity(0.65),
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.normal)),
                                ]),
                              ),
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 48),
                      Text('轻触任意处继续',
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
    // Dialog closed: stop alarm, re-apply extreme dim brightness, re-enter immersive
    try { await _alarmCh.invokeMethod('stop'); } catch (_) {}
    if (mounted) {
      await _applyDimBrightness();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _exit() async {
    HapticFeedback.lightImpact();
    // Restore brightness BEFORE popping
    await _restoreBrightness();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Also listen to PomEngine directly so the clock updates every second
    final pom = context.read<AppState>().engine;
    return ListenableBuilder(
      listenable: pom,
      builder: (context, _) {
    final m = pom.secsLeft ~/ 60;
    final s = pom.secsLeft % 60;
    final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final isFocus = pom.mode == PomMode.focus;
    final baseColor = isFocus
        ? const Color(0xFFE07040)   // warm orange for focus
        : const Color(0xFF4A90C0);  // cool blue for break

    return GestureDetector(
      onTap: _exit,
      child: Scaffold(
        // Force pure black background for AOD mode
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, __) {
            // Adjust glow and text opacity for extreme dark mode
            final glowIntensity = 0.45 + _glowCtrl.value * 0.20;
            final ringColor = baseColor.withOpacity(glowIntensity);
            final textColor = Colors.white.withOpacity(0.60 + _glowCtrl.value * 0.15);

            // Check ambient fx beta flag
            final ambientFxOn = betaAmbientFx(state.settings);

            return Stack(children: [
              // ── Ambient special effects (β) ──────────────────────────
              if (ambientFxOn)
                Positioned.fill(child: CustomPaint(
                  painter: _AmbientFxPainter(
                    progress: _glowCtrl.value,
                    isFocus: isFocus,
                    baseColor: baseColor),
                )),
              // Full-screen tap area (pure black)
              Positioned.fill(child: Container(color: Colors.black)),

              // Center content with burn-in drift
              AnimatedPositioned(
                duration: const Duration(seconds: 60),
                curve: Curves.linear,
                left: MediaQuery.of(context).size.width / 2 - 110 + _driftX,
                top: MediaQuery.of(context).size.height / 2 - 150 + _driftY,
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phase label
                    Text(
                      pom.mode == PomMode.focus
                          ? '专注'
                          : pom.mode == PomMode.longBreak ? '长休息' : '休息',
                      style: TextStyle(
                        fontSize: 14,
                        color: ringColor.withOpacity(0.5),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glowing ring (slightly dimmer)
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: _AmbientRingPainter(
                        progress: pom.progress,
                        color: ringColor,
                        glowIntensity: glowIntensity * 0.7,
                      ),
                      child: SizedBox(
                        width: 220, height: 220,
                        child: Center(
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w200,
                              color: textColor,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(
                                  color: ringColor.withOpacity(glowIntensity * 0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Cycle indicator dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        state.settings.pom.longBreakInterval,
                        (i) => Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < pom.focusRoundsSinceLongBreak
                                ? ringColor.withOpacity(0.7)
                                : Colors.white.withOpacity(0.05),
                            boxShadow: i < pom.focusRoundsSinceLongBreak
                                ? [BoxShadow(color: ringColor.withOpacity(0.4), blurRadius: 4)]
                                : null,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Hint text (very dim)
                    Text(
                      '轻触任意处退出',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.12),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
      }, // ListenableBuilder builder
    ); // ListenableBuilder
  }
}

class _AmbientRingPainter extends CustomPainter {
  final double progress, glowIntensity;
  final Color color;
  _AmbientRingPainter({
    required this.progress,
    required this.color,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2 - 12;
    const startAngle = -pi / 2;

    // Track (very dim)
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = color.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (progress <= 0) return;

    // Outer glow layers
    for (final pair in [
      (color.withOpacity(0.05 * glowIntensity), 18.0),
      (color.withOpacity(0.10 * glowIntensity), 10.0),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, progress * 2 * pi, false,
        Paint()
          ..color = pair.$1
          ..style = PaintingStyle.stroke
          ..strokeWidth = pair.$2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Main arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, progress * 2 * pi, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Leading dot glow
    final angle = startAngle + progress * 2 * pi;
    final dotX = cx + r * cos(angle);
    final dotY = cy + r * sin(angle);
    canvas.drawCircle(
      Offset(dotX, dotY), 7,
      Paint()..color = color.withOpacity(0.3 * glowIntensity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(Offset(dotX, dotY), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AmbientRingPainter o) =>
      o.progress != progress || o.glowIntensity != glowIntensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// β 息屏特效 Painter — 烛光粒子 + 流星 + 光晕呼吸
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientFxPainter extends CustomPainter {
  final double progress;   // 0.0 → 1.0 looping
  final bool isFocus;
  final Color baseColor;

  static final _rng = Random(7);
  // Candle embers — 40 particles
  static final _embers = List.generate(40, (i) => (
    x:     _rng.nextDouble(),
    y:     _rng.nextDouble(),
    size:  1.0 + _rng.nextDouble() * 3.0,
    speed: 0.12 + _rng.nextDouble() * 0.28,
    phase: _rng.nextDouble(),
    wobble: (_rng.nextDouble() - 0.5) * 0.06,
  ));
  // Shooting stars — 5 objects
  static final _stars = List.generate(5, (i) => (
    startX: _rng.nextDouble(),
    startY: _rng.nextDouble() * 0.5,
    angle:  0.3 + _rng.nextDouble() * 0.5,
    speed:  0.35 + _rng.nextDouble() * 0.4,
    phase:  _rng.nextDouble(),
    len:    0.06 + _rng.nextDouble() * 0.10,
  ));

  _AmbientFxPainter({required this.progress,
      required this.isFocus, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    // ── Subtle ambient glow at bottom ────────────────────────────────────────
    final glowColor = isFocus
        ? const Color(0xFFE07040)
        : const Color(0xFF4A90C0);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.2),
        radius: 0.8,
        colors: [
          glowColor.withOpacity(0.10 + 0.05 * (0.5 + 0.5 * sin(progress * 2 * pi))),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // ── Candle embers (focus) / Snowflake motes (break) ──────────────────────
    for (final e in _embers) {
      final t = (progress * e.speed + e.phase) % 1.0;
      final x = (e.x + e.wobble * sin(t * 2 * pi)) * size.width;
      final y = size.height - t * (size.height + 20) - 10;
      if (y < -10 || y > size.height + 10) continue;
      final alpha = sin(t * pi).clamp(0.0, 1.0);
      final emberColor = isFocus
          ? Color.lerp(glowColor, const Color(0xFFFFDD88), alpha)!
              .withOpacity(0.55 * alpha)
          : Colors.white.withOpacity(0.30 * alpha);
      canvas.drawCircle(Offset(x, y), e.size * (0.5 + alpha * 0.5),
          Paint()
            ..color = emberColor
            ..maskFilter = alpha > 0.3
                ? const MaskFilter.blur(BlurStyle.normal, 3) : null);
    }

    // ── Shooting stars ────────────────────────────────────────────────────────
    for (final star in _stars) {
      final t = (progress * star.speed + star.phase) % 1.0;
      if (t > 0.6) continue; // Only visible 60% of cycle
      final alpha = sin((t / 0.6) * pi).clamp(0.0, 1.0);
      final sx = (star.startX + cos(star.angle) * t * 0.6) * size.width;
      final sy = (star.startY + sin(star.angle) * t * 0.6) * size.height;
      final ex = sx - cos(star.angle) * star.len * size.width;
      final ey = sy - sin(star.angle) * star.len * size.height;
      final starPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9 * alpha),
            Colors.white.withOpacity(0),
          ],
        ).createShader(Rect.fromPoints(Offset(sx, sy), Offset(ex, ey)))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), starPaint);
      // Star head dot
      canvas.drawCircle(Offset(sx, sy), 2.0,
          Paint()..color = Colors.white.withOpacity(0.9 * alpha));
    }
  }

  double sin(double x) => x < 3.14159 ? x * (1 - x / 3.14159) * 1.273 : (x - 3.14159) * (1 - (x - 3.14159) / 3.14159) * -1.273;
  double cos(double x) => sin(x + 1.5708);
  static const double pi = 3.14159265;

  @override
  bool shouldRepaint(_AmbientFxPainter o) => o.progress != progress;
}
