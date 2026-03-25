// lib/widgets/deviation_chart.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

// Each time-slot is numbered across calendar days:
// day 0 morning=0, day 0 afternoon=1, day 0 evening=2,
// day 1 morning=3, day 1 afternoon=4, day 1 evening=5, ...
// Deviation = actual_slot - planned_slot  (positive = later than planned)

int _blockIdx(String blk) {
  switch (blk) {
    case 'morning':   return 0;
    case 'afternoon': return 1;
    case 'evening':   return 2;
    default:          return 1; // unassigned → neutral mid
  }
}

/// Absolute slot number for a given (date string, timeBlock)
int _absSlot(String dateStr, String blk) {
  // Use day-of-year × 3 + blockIdx as a comparable integer
  final d = DateTime.parse('${dateStr}T12:00:00');
  final epoch = DateTime(d.year, 1, 1);
  final dayNum = d.difference(epoch).inDays;
  return dayNum * 3 + _blockIdx(blk);
}

class DeviationChart extends StatelessWidget {
  final List<String> days;
  final AppState state;
  final String title;

  const DeviationChart({
    super.key,
    required this.days,
    required this.state,
    required this.title,
  });

  /// For a completed task, compute deviation in block-slots.
  /// Returns null if task doesn't have enough info.
  double? _taskDeviation(TaskModel t) {
    if (!t.done || t.doneAt == null) return null;
    if (t.originalTimeBlock == 'unassigned') return null;

    final plannedSlot = _absSlot(t.originalDate, t.originalTimeBlock);

    // Actual completion slot
    String actualBlk;
    if (t.doneTimeBlock != null) {
      actualBlk = t.doneTimeBlock!;
    } else if (t.doneHour != null) {
      actualBlk = AppState.hourToTimeBlock(t.doneHour!, 0);
    } else {
      return null;
    }
    final actualSlot = _absSlot(t.doneAt!, actualBlk);
    return (actualSlot - plannedSlot).toDouble();
  }

  /// Returns map: doneAt date → average deviation for that day.
  /// Also tracks global max/min individual task deviations.
  Map<String, double> _buildDailyDeviations() {
    final Map<String, List<double>> buckets = {};
    for (final t in state.tasks) {
      final dev = _taskDeviation(t);
      if (dev == null) continue;
      if (!days.contains(t.doneAt)) continue;
      // Attribute to originalDate (planning day), not completion day
      final key = days.contains(t.originalDate) ? t.originalDate : t.doneAt!;
      buckets.putIfAbsent(key, () => []).add(dev);
    }
    final result = <String, double>{};
    for (final entry in buckets.entries) {
      result[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
    }
    return result;
  }

  /// All individual task deviations in the period (for global max/min).
  List<double> _allTaskDeviations() {
    final all = <double>[];
    for (final t in state.tasks) {
      final dev = _taskDeviation(t);
      if (dev == null) continue;
      if (!days.contains(t.doneAt)) continue;
      all.add(dev);
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final tc = state.themeConfig;
    final dailyMap = _buildDailyDeviations();

    // Build ordered data points aligned to the days list
    final data = <MapEntry<String, double>>[];
    for (final day in days) {
      if (dailyMap.containsKey(day)) {
        data.add(MapEntry(day, dailyMap[day]!));
      }
    }

    if (data.isEmpty) return const SizedBox.shrink();

    final maxAbs = data.map((e) => e.value.abs()).reduce(max).clamp(1.0, 999.0);
    final allDevs = _allTaskDeviations();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Text('📐 $title',
            style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
          const Spacer(),
          _legendDot(const Color(0xFF4A9068), '准时'),
          const SizedBox(width: 6),
          _legendDot(const Color(0xFFE07040), '推迟'),
          const SizedBox(width: 6),
          _legendDot(const Color(0xFF5060D0), '提前'),
        ]),
        const SizedBox(height: 4),
        Text('横轴：日期  纵轴：平均偏差（时段数，跨日计算）',
          style: TextStyle(fontSize: 9, color: Color(tc.tm))),
        const SizedBox(height: 10),

        // Chart
        SizedBox(
          height: 110,
          child: CustomPaint(
            painter: _LinePainter(
              data: data,
              maxAbs: maxAbs,
              accent: Color(tc.acc),
              gridColor: Color(tc.brd),
            ),
            size: const Size(double.infinity, 110),
          ),
        ),

        const SizedBox(height: 6),
        // X-axis date labels (first, middle, last)
        _buildDateLabels(data, tc),
        const SizedBox(height: 10),
        _buildSummary(data, allDevs, tc),
      ]),
    );
  }

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500)),
  ]);

  Widget _buildDateLabels(List<MapEntry<String, double>> data, ThemeConfig tc) {
    if (data.isEmpty) return const SizedBox.shrink();
    final first = data.first.key;
    final last  = data.last.key;
    final mid   = data.length > 2 ? data[data.length ~/ 2].key : null;

    String fmt(String d) {
      final dt = DateTime.parse('${d}T12:00:00');
      return '${dt.month}/${dt.day}';
    }

    return Row(children: [
      Text(fmt(first), style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
      if (mid != null) ...[
        const Spacer(),
        Text(fmt(mid), style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
      ],
      const Spacer(),
      Text(fmt(last), style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
    ]);
  }

  Widget _buildSummary(List<MapEntry<String, double>> data, List<double> allDevs, ThemeConfig tc) {
    final avg = data.map((e) => e.value).reduce((a, b) => a + b) / data.length;
    // Global max/min across ALL individual tasks in period (not per-day averages)
    final globalMax = allDevs.isEmpty ? 0.0 : allDevs.reduce(max);
    final globalMin = allDevs.isEmpty ? 0.0 : allDevs.reduce(min);

    String trend;
    Color trendColor;
    if (avg.abs() < 0.4) {
      trend = '整体规划准确，平均偏差 ${avg.abs().toStringAsFixed(1)} 时段 ✓';
      trendColor = const Color(0xFF4A9068);
    } else if (avg > 0) {
      final slots = avg.round();
      final d = slots ~/ 3, r = slots % 3;
      final bn = ['上午','下午','晚上'][r];
      trend = '倾向于比规划晚完成，平均推迟约${d > 0 ? ' $d 天' : ''}${r > 0 ? ' $bn' : ''}（${avg.toStringAsFixed(1)} 时段）';
      trendColor = const Color(0xFFE07040);
    } else {
      final slots = avg.abs().round();
      final d = slots ~/ 3, r = slots % 3;
      final bn = ['上午','下午','晚上'][r];
      trend = '倾向于比规划早完成，平均提前约${d > 0 ? ' $d 天' : ''}${r > 0 ? ' $bn' : ''}（${avg.abs().toStringAsFixed(1)} 时段）';
      trendColor = const Color(0xFF5060D0);
    }

    String fmtSlots(double v) {
      final s = v.round().abs();
      final d = s ~/ 3, r = s % 3;
      final bn = ['上午','下午','晚上'][r];
      return '${d > 0 ? '$d天' : ''}${r > 0 ? bn : ''}（${v.abs().toStringAsFixed(1)} 时段）';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: trendColor.withOpacity(0.09), borderRadius: BorderRadius.circular(8)),
        child: Text(trend, style: TextStyle(fontSize: 10.5, color: trendColor, fontWeight: FontWeight.w500)),
      ),
      const SizedBox(height: 5),
      Text(
        '最大推迟 ${fmtSlots(globalMax)} · 最大提前 ${fmtSlots(globalMin)} · 样本 ${allDevs.length} 条',
        style: TextStyle(fontSize: 9, color: Color(tc.tm)),
      ),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double maxAbs;
  final Color accent, gridColor;

  _LinePainter({
    required this.data,
    required this.maxAbs,
    required this.accent,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padX = 10.0, padTop = 8.0, padBot = 8.0;
    final W = size.width - 2 * padX;
    final H = size.height - padTop - padBot;
    final midY = padTop + H / 2;
    final yScale = (H / 2) / maxAbs.clamp(1.0, 999.0);

    // ── Grid lines ─────────────────────────────────────────
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.6;
    // Zero line (bold)
    canvas.drawLine(Offset(padX, midY), Offset(padX + W, midY),
      Paint()..color = gridColor..strokeWidth = 1.2);
    // ±3 slot lines (= 1 day)
    for (final offset in [-3.0, 3.0, -6.0, 6.0]) {
      final y = midY - offset * yScale;
      if (y >= padTop && y <= padTop + H) {
        canvas.drawLine(Offset(padX, y), Offset(padX + W, y), gridPaint);
      }
    }

    // Y-axis labels: 0, ±3, ±6
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String text, double y) {
      tp.text = TextSpan(text: text,
        style: TextStyle(fontSize: 7, color: gridColor));
      tp.layout();
      if (y >= padTop - 2 && y <= padTop + H + 2) {
        tp.paint(canvas, Offset(0, y - tp.height / 2));
      }
    }
    drawLabel('0', midY);
    if (3 * yScale < H / 2) {
      drawLabel('+3', midY - 3 * yScale);
      drawLabel('-3',  midY + 3 * yScale);
    }
    if (6 * yScale < H / 2) {
      drawLabel('+6', midY - 6 * yScale);
      drawLabel('-6',  midY + 6 * yScale);
    }

    // ── Compute points ──────────────────────────────────────
    final pts = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = padX + (data.length == 1 ? W / 2 : i * W / (data.length - 1));
      final y = (midY - data[i].value * yScale).clamp(padTop, padTop + H);
      pts.add(Offset(x, y));
    }

    // ── Area fill ───────────────────────────────────────────
    if (pts.length > 1) {
      final areaPath = _smooth(pts);
      areaPath.lineTo(pts.last.dx, midY);
      areaPath.lineTo(pts.first.dx, midY);
      areaPath.close();
      canvas.drawPath(areaPath, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [accent.withOpacity(0.18), accent.withOpacity(0.03)],
        ).createShader(Rect.fromLTWH(padX, padTop, W, H))
        ..style = PaintingStyle.fill);

      // ── Stroke ──────────────────────────────────────────
      canvas.drawPath(_smooth(pts), Paint()
        ..color = accent..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }

    // ── Dots ────────────────────────────────────────────────
    for (int i = 0; i < pts.length; i++) {
      final pt = pts[i];
      final dev = data[i].value;
      final dotColor = dev.abs() < 0.5
          ? const Color(0xFF4A9068)
          : dev > 0
              ? const Color(0xFFE07040)
              : const Color(0xFF5060D0);

      // Larger dot for big deviations
      final r = (2.5 + (dev.abs() / maxAbs).clamp(0.0, 1.0) * 2.5).clamp(2.5, 5.0);
      canvas.drawCircle(pt, r, Paint()..color = dotColor);
      canvas.drawCircle(pt, r - 1.5, Paint()..color = Colors.white.withOpacity(0.6));
    }
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1], p1 = pts[i];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_LinePainter o) =>
      o.data != data || o.maxAbs != maxAbs;
}
