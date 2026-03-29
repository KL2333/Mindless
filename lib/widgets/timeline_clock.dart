// lib/widgets/timeline_clock.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class TimelineClock extends StatefulWidget {
  const TimelineClock({super.key});
  @override
  State<TimelineClock> createState() => _TimelineClockState();
}

class _TimelineClockState extends State<TimelineClock>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  DateTime _now = DateTime.now();
  late AnimationController _introCtrl;
  late Animation<double> _introAnim;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 30000));
    _introAnim = CurvedAnimation(parent: _introCtrl, curve: Curves.easeInOut);
    _introCtrl.forward();
    _shown = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
      if (!_shown && _introCtrl.isCompleted) _shown = true;
    });
  }

  @override
  void dispose() { _timer.cancel(); _introCtrl.dispose(); super.dispose(); }

  // 1am = 0.0, next 1am = 1.0  (uses 25h logic: <5 = +24)
  double get _progress {
    double tf = _now.hour + _now.minute / 60.0 + _now.second / 3600.0;
    if (tf < 1.0) tf += 24.0;
    return ((tf - 1.0) / 24.0).clamp(0.0, 1.0);
  }

  static const _ticks = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28];

  @override
  Widget build(BuildContext context) {
    final prog = _introCtrl.isCompleted ? _progress : _introAnim.value * _progress;
    final timeStr = AppState.fmt25h(_now.hour, _now.minute);

    return AnimatedBuilder(
      animation: _introAnim,
      builder: (_, __) {
        final p = _introCtrl.isCompleted ? _progress : _introAnim.value * _progress;
        return LayoutBuilder(builder: (_, bc) {
          final W = bc.maxWidth;
          return SizedBox(
            width: W, height: 48,
            child: CustomPaint(
              painter: _TimelinePainter(p, _ticks, _introCtrl.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(timeStr,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFFFFD76E),
                        letterSpacing: 0.8,
                        fontFeatures: [FontFeature.tabularFigures()],
                      )),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final double progress;
  final List<int> ticks;
  final double introFade;

  _TimelinePainter(this.progress, this.ticks, this.introFade);

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    const padX = 12.0;
    const trackY = 38.0;
    const trackH = 3.0;
    final trackW = W - 2 * padX;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08 * introFade)
      ..style = PaintingStyle.fill;
    final filledPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFFB340).withOpacity(0.7),
          const Color(0xFFFFD76E).withOpacity(0.9),
        ],
      ).createShader(Rect.fromLTWH(padX, 0, trackW * progress, trackH))
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = const Color(0xFFFFD76E)
      ..style = PaintingStyle.fill;

    // Background track
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padX, trackY, trackW, trackH),
      const Radius.circular(2));
    canvas.drawRRect(trackRect, bgPaint);

    // Filled portion
    if (progress > 0) {
      final filledRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(padX, trackY, trackW * progress, trackH),
        const Radius.circular(2));
      canvas.drawRRect(filledRect, filledPaint);
    }

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.25 * introFade)
      ..strokeWidth = 1.0;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (final h in ticks) {
      final frac = ((h - 1) / 24.0).clamp(0.0, 1.0);
      final x = padX + trackW * frac;
      canvas.drawLine(Offset(x, trackY - 5), Offset(x, trackY), tickPaint);

      // Label every 3h
      if (h % 3 == 1) {
        final label = h >= 25 ? '${h}h' : '${h}:00';
        tp.text = TextSpan(text: label,
          style: TextStyle(fontSize: 7, color: Colors.white.withOpacity(0.35 * introFade)));
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, trackY - 14));
      }
    }

    // Moving dot
    final dotX = padX + trackW * progress;
    canvas.drawCircle(Offset(dotX, trackY + trackH / 2), 5.5, dotPaint);
    // Inner glow
    canvas.drawCircle(Offset(dotX, trackY + trackH / 2), 3.0,
      Paint()..color = Colors.white.withOpacity(0.8 * introFade));
  }

  @override
  bool shouldRepaint(_TimelinePainter o) => o.progress != progress || o.introFade != introFade;
}
