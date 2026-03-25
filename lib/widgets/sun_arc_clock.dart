// lib/widgets/sun_arc_clock.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class SunArcClock extends StatefulWidget {
  const SunArcClock({super.key});
  @override
  State<SunArcClock> createState() => _SunArcClockState();
}

class _SunArcClockState extends State<SunArcClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  // 25-hour float: 0:00–4:59 → 24.0–28.99, 5:00 → 5.0
  double get _tf {
    final h = _now.hour + _now.minute / 60.0 + _now.second / 3600.0;
    return h < 5.0 ? h + 24.0 : h;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);
  static Color _lerpC(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

  // ── Colour ─────────────────────────────────────────────────
  //  8 h  amber-gold   #FFB340
  // 12 h  pale gold    #FFE566
  // 18 h  deep orange  #FF7A20
  // 22 h  near-black   #120400   (warm shadow, visible via text shadow)
  // 25 h  vivid red    #FF2020
  static const _amber  = Color(0xFFFFB340);
  static const _gold   = Color(0xFFFFE566);
  static const _orange = Color(0xFFFF7A20);
  static const _dark   = Color(0xFF1A0600);
  static const _red    = Color(0xFFFF2020);

  Color _color(double tf) {
    if (tf < 5.0)   return _amber.withOpacity(0.45); // should not normally hit
    if (tf < 8.0)   return _lerpC(_amber.withOpacity(0.5), _amber, (tf - 5) / 3);
    if (tf <= 12.0) return _lerpC(_amber, _gold,   (tf - 8)  / 4);
    if (tf <= 18.0) return _lerpC(_gold,  _orange, (tf - 12) / 6);
    if (tf <= 22.0) return _lerpC(_orange,_dark,   (tf - 18) / 4);
    if (tf <= 25.0) return _lerpC(_dark,  _red,    (tf - 22) / 3);
    // 25–29 underground: red → dim amber
    return _lerpC(_red, _amber.withOpacity(0.5), (tf - 25) / 4);
  }

  // ── Font size ───────────────────────────────────────────────
  double _fs(double tf) {
    const base = 11.5, max = 21.0;
    if (tf < 18.0)  return base;
    if (tf <= 25.0) return _lerp(base, max, (tf - 18) / 7);
    return _lerp(max, base, (tf - 25) / 4);
  }

  // ── Arc position (returns xFrac 0-1, yFrac 0-1 where 0=top) ─
  (double xFrac, double yFrac) _pos(double tf) {
    if (tf >= 8.0 && tf <= 18.0) {
      final p = (tf - 8.0) / 10.0;
      final dy = p - 0.5;
      return (p, 4 * dy * dy); // parabola: 0 at noon, 1 at edges
    }
    if (tf < 8.0) {
      // 5–8: pre-dawn creep in from left bottom
      final p = ((tf - 5.0) / 3.0).clamp(0.0, 1.0);
      return (p * 0.04, 1.0);
    }
    if (tf <= 25.0) {
      // 18–25: fixed right edge
      return (1.0, 1.0);
    }
    // 25–29: underground drift right→left
    final p = ((tf - 25.0) / 4.0).clamp(0.0, 1.0);
    return (1.0 - p, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final tf = _tf;
    final col = _color(tf);
    final fs  = _fs(tf);
    final (xFrac, yFrac) = _pos(tf);
    final isDaytime = tf >= 8.0 && tf <= 18.0;
    final label = AppState.fmt25h(_now.hour, _now.minute);

    return LayoutBuilder(builder: (_, bc) {
      const H = 48.0;
      const padX = 24.0;
      final W = bc.maxWidth;

      const arcTop = 7.0;
      const arcBot = H - 7.0;
      final sunX = padX + xFrac * (W - 2 * padX);
      final sunY = arcTop + yFrac * (arcBot - arcTop);

      // Text width estimate for centering
      final tw = fs * label.length * 0.62;
      final tx = (sunX - tw / 2).clamp(4.0, W - tw - 4.0);
      final ty = (sunY - fs * 0.85).clamp(0.0, H - fs * 1.4);

      return SizedBox(
        width: W,
        height: H,
        child: Stack(clipBehavior: Clip.none, children: [
          // Faint arc line (daytime only)
          if (isDaytime)
            CustomPaint(
              painter: _ArcLine(col, W, padX, arcTop, arcBot),
              size: Size(W, H),
            ),
          // Time label
          Positioned(
            left: tx,
            top: ty,
            child: Text(label,
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w700,
                color: col,
                letterSpacing: 0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ]),
      );
    });
  }
}

// Brushstroke-like arc — one quadratic bezier, low opacity
class _ArcLine extends CustomPainter {
  final Color color;
  final double width, padX, topY, botY;
  _ArcLine(this.color, this.width, this.padX, this.topY, this.botY);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(padX, botY)
      ..quadraticBezierTo(size.width / 2, topY, size.width - padX, botY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArcLine o) =>
      o.color != color || o.width != width;
}
