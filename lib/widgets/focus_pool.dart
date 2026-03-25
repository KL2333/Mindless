// lib/widgets/focus_pool.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class FocusPoolWidget extends StatefulWidget {
  const FocusPoolWidget({super.key});
  @override
  State<FocusPoolWidget> createState() => _FocusPoolWidgetState();
}

class _FocusPoolWidgetState extends State<FocusPoolWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _waveCtrl.dispose(); super.dispose(); }

  void _showEditDialog(BuildContext context, AppState state) {
    double val = state.settings.disposableHours;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: const Text('今日可支配时间'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${val.toStringAsFixed(1)} 小时', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Slider(value: val, min: 1, max: 16, divisions: 30,
            onChanged: (v) => setSt(() => val = (v * 2).round() / 2)),
          Text('范围：1–16小时，以0.5小时为步进', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () {
            state.setDisposableHours(val);
            Navigator.pop(ctx);
          }, child: const Text('确定')),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final today = state.todayKey;
    final todayFocusSecs = state.tasks
        .where((t) => t.doneAt == today)
        .fold(0, (s, t) => s + t.focusSecs);
    final disposableSecs = (state.settings.disposableHours * 3600).round();
    final pct = disposableSecs > 0 ? (todayFocusSecs / disposableSecs).clamp(0.0, 1.0) : 0.0;
    final focusMins = todayFocusSecs ~/ 60;
    final focusH = focusMins ~/ 60;
    final focusM = focusMins % 60;
    final focusLabel = focusH > 0 ? '${focusH}h${focusM > 0 ? '${focusM}m' : ''}' : '${focusMins}m';
    final pctLabel = '${(pct * 100).round()}%';

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showEditDialog(context, state);
      },
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Color(tc.card),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
        ),
        clipBehavior: Clip.hardEdge,
        child: AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) {
            return CustomPaint(
              painter: _PoolPainter(
                fillPct: pct,
                wavePhase: _waveCtrl.value * 2 * pi,
                fillColor: Color(tc.acc),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('今日专注',
                      style: TextStyle(fontSize: 9.5, letterSpacing: 0.8, fontWeight: FontWeight.w600,
                        color: pct > 0.25 ? Colors.white.withOpacity(0.85) : Color(tc.ts))),
                    const SizedBox(height: 2),
                    Text(focusLabel,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: pct > 0.25 ? Colors.white : Color(tc.tx),
                        shadows: pct > 0.25 ? const [Shadow(color: Color(0x55000000), blurRadius: 6)] : null)),
                  ]),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(pctLabel,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: pct > 0.25 ? Colors.white : Color(tc.acc),
                        shadows: pct > 0.25 ? const [Shadow(color: Color(0x55000000), blurRadius: 6)] : null)),
                    Text('可支配 ${state.settings.disposableHours.toStringAsFixed(1)}h',
                      style: TextStyle(fontSize: 9.5,
                        color: pct > 0.25 ? Colors.white.withOpacity(0.75) : Color(tc.ts))),
                    Text('长按修改',
                      style: TextStyle(fontSize: 8.5,
                        color: pct > 0.25 ? Colors.white.withOpacity(0.5) : Color(tc.tm))),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PoolPainter extends CustomPainter {
  final double fillPct, wavePhase;
  final Color fillColor;
  _PoolPainter({required this.fillPct, required this.wavePhase, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      Paint()..color = fillColor.withOpacity(0.08),
    );
    if (fillPct <= 0) return;

    final waterRight = size.width * fillPct;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(0, size.height);

    // Wavy right edge
    const steps = 60;
    for (int i = steps; i >= 0; i--) {
      final y = size.height * i / steps;
      final wave1 = 5.0 * sin(y / size.height * 2 * pi + wavePhase);
      final wave2 = 3.0 * sin(y / size.height * 3 * pi - wavePhase * 1.3);
      path.lineTo(waterRight + wave1 + wave2, y);
    }
    path.close();

    // Fill gradient left → right
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [fillColor.withOpacity(0.85), fillColor.withOpacity(0.65)],
      ).createShader(Rect.fromLTWH(0, 0, waterRight, size.height));
    canvas.drawPath(path, paint);

    // Gloss stripe near top
    if (fillPct > 0.05) {
      final gloss = Paint()..color = Colors.white.withOpacity(0.14);
      final glossPath = Path()
        ..moveTo(0, 0)
        ..lineTo(waterRight.clamp(0, size.width), 0)
        ..lineTo(waterRight.clamp(0, size.width), 10)
        ..lineTo(0, 14)
        ..close();
      canvas.drawPath(glossPath, gloss);
    }
  }

  @override
  bool shouldRepaint(_PoolPainter o) => o.fillPct != fillPct || o.wavePhase != wavePhase;
}
