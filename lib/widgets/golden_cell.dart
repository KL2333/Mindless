// lib/widgets/golden_cell.dart
import 'dart:math';
import 'package:flutter/material.dart';

class GoldenCalendarCell extends StatefulWidget {
  final int day;
  final bool isSelected;
  final VoidCallback onTap;

  const GoldenCalendarCell({
    super.key, required this.day, required this.isSelected, required this.onTap,
  });

  @override
  State<GoldenCalendarCell> createState() => _GoldenCalendarCellState();
}

class _GoldenCalendarCellState extends State<GoldenCalendarCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        // Rainbow border gradient (rotating)
        final borderColors = List.generate(7, (i) =>
          HSLColor.fromAHSL(1, (t * 360 + i * 51.4) % 360, 1.0, 0.55).toColor());

        // Gold shimmer gradient (sweeping left→right)
        final shimmerPos = -1.5 + t * 4.0;
        final shimmer = LinearGradient(
          begin: Alignment(shimmerPos, -0.5),
          end: Alignment(shimmerPos + 1.2, 0.5),
          colors: const [
            Color(0xFF8B6914), Color(0xFFB8860B), Color(0xFFDAA520),
            Color(0xFFFFD700), Color(0xFFFFF8DC), Color(0xFFFFD700),
            Color(0xFFDAA520), Color(0xFFB8860B), Color(0xFF8B6914),
          ],
          stops: const [0, .1, .25, .4, .5, .6, .75, .9, 1],
        );

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: SweepGradient(
                colors: [...borderColors, borderColors.first],
                transform: GradientRotation(t * 2 * pi),
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: widget.isSelected
                  ? [BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)]
                  : [BoxShadow(color: Colors.amber.withOpacity(0.25), blurRadius: 5)],
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                gradient: shimmer,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Text(
                  '${widget.day}',
                  style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x88000000), blurRadius: 3)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Mini golden cell for year view
class GoldenMiniCell extends StatefulWidget {
  final VoidCallback onTap;
  final String tooltip;
  const GoldenMiniCell({super.key, required this.onTap, required this.tooltip});
  @override
  State<GoldenMiniCell> createState() => _GoldenMiniCellState();
}

class _GoldenMiniCellState extends State<GoldenMiniCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final shimmerPos = -1.5 + t * 4.0;
        return GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: widget.tooltip,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(shimmerPos, -0.5), end: Alignment(shimmerPos + 1.2, 0.5),
                  colors: const [Color(0xFF8B6914), Color(0xFFDAA520), Color(0xFFFFF8DC), Color(0xFFDAA520), Color(0xFF8B6914)],
                ),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: HSLColor.fromAHSL(1, (t * 360) % 360, 1, 0.55).toColor(),
                  width: 0.8,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
