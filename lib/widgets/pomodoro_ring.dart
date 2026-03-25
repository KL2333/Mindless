// lib/widgets/pomodoro_ring.dart
// Inspired by Tomato (github.com/nsh07/Tomato):
// • Focus phase  → clean circular arc with leading dot glow
// • Break phase  → wavy/sinusoidal arc track (CircularWavyProgressIndicator analogue)
// • Color animates smoothly between modes
import 'dart:math';
import 'package:flutter/material.dart';

class PomodoroRing extends StatefulWidget {
  final double progress;     // 0..1
  final String timeStr;
  final Color ringColor;
  final bool running;
  final bool isBreak;        // true → wavy track
  final Color textColor;
  final VoidCallback? onTimeTap;
  final bool showProgress;

  const PomodoroRing({
    super.key,
    required this.progress,
    required this.timeStr,
    required this.ringColor,
    required this.textColor,
    this.running = false,
    this.isBreak = false,
    this.showProgress = true,
    this.onTimeTap,
  });

  @override
  State<PomodoroRing> createState() => _PomodoroRingState();
}

class _PomodoroRingState extends State<PomodoroRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.018)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    if (widget.running) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PomodoroRing old) {
    super.didUpdateWidget(old);
    if (widget.running && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.running && _pulse.isAnimating) {
      _pulse.animateTo(0, duration: const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _scaleAnim.value,
        child: SizedBox(
          width: 224, height: 224,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, prog, __) => CustomPaint(
              painter: _RingPainter(
                progress: prog,
                ringColor: widget.ringColor,
                isBreak: widget.isBreak,
                running: widget.running,
              ),
              child: Center(
                child: GestureDetector(
                  onTap: widget.onTimeTap,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w700,
                        color: widget.textColor,
                        letterSpacing: -2,
                        fontFamily: 'serif',
                      ),
                      child: Text(widget.timeStr),
                    ),
                    if (widget.onTimeTap != null)
                      AnimatedOpacity(
                        opacity: widget.running ? 0.4 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(Icons.nightlight_round, size: 11,
                          color: widget.ringColor),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final bool isBreak;
  final bool running;

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.isBreak,
    required this.running,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    const sw = 14.0;
    final trackColor = ringColor.withOpacity(0.13);

    // ── Background track ────────────────────────────────────
    if (isBreak) {
      // Wavy dotted track for break mode
      _drawWavyTrack(canvas, center, radius, trackColor, sw);
    } else {
      canvas.drawCircle(center, radius, Paint()
        ..color = trackColor
        ..strokeWidth = sw
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    if (progress <= 0) return;

    // ── Outer glow ──────────────────────────────────────────
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, 2 * pi * progress, false,
      Paint()
        ..color = ringColor.withOpacity(0.15)
        ..strokeWidth = sw + 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── Main arc ────────────────────────────────────────────
    if (isBreak) {
      _drawWavyArc(canvas, center, radius, ringColor, sw, progress);
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * progress, false,
        Paint()
          ..color = ringColor
          ..strokeWidth = sw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Leading dot ─────────────────────────────────────────
    final angle = -pi / 2 + 2 * pi * progress;
    final dx = center.dx + radius * cos(angle);
    final dy = center.dy + radius * sin(angle);
    // Glow halo
    canvas.drawCircle(Offset(dx, dy), 11,
      Paint()
        ..color = ringColor.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    // Solid dot
    canvas.drawCircle(Offset(dx, dy), 6.5, Paint()..color = ringColor);
    // White center
    canvas.drawCircle(Offset(dx, dy), 3, Paint()..color = Colors.white.withOpacity(0.90));
  }

  /// Draws a wavy sinusoidal track around the full circle.
  void _drawWavyTrack(Canvas canvas, Offset center, double radius,
      Color color, double strokeWidth) {
    const steps = 240;
    const wavelength = 20.0; // degrees per wave
    const amplitude = 3.5;
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final baseAngle = -pi / 2 + 2 * pi * t;
      final wave = sin(t * 2 * pi * (360 / wavelength)) * amplitude;
      final r = radius + wave;
      final x = center.dx + r * cos(baseAngle);
      final y = center.dy + r * sin(baseAngle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..color = color
      ..strokeWidth = strokeWidth * 0.55
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
  }

  /// Draws a wavy arc up to [progress] (0..1).
  void _drawWavyArc(Canvas canvas, Offset center, double radius,
      Color color, double strokeWidth, double progress) {
    const steps = 160;
    const wavelength = 20.0;
    const amplitude = 3.5;
    final path = Path();
    final count = (steps * progress).round();
    for (int i = 0; i <= count; i++) {
      final t = i / steps;
      final baseAngle = -pi / 2 + 2 * pi * t;
      final wave = sin(t * 2 * pi * (360 / wavelength)) * amplitude;
      final r = radius + wave;
      final x = center.dx + r * cos(baseAngle);
      final y = center.dy + r * sin(baseAngle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.isBreak != isBreak;
}
