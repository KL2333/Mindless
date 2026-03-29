// lib/widgets/time_ruler.dart — DiscRuler v5
//
// 设计概念：
//   透过一个竖向"玻璃视窗"（圆角矩形孔洞），观察一个旋转的扁圆柱体的侧面。
//   圆柱侧面印有时间刻度，随时间连续旋转——就像老式钟鼓上的刻度带。
//   玻璃视窗有折射高光、边框、阴影，营造真实厚度感。
//   当前时刻的刻度线（红色）始终停在视窗中央。

import 'package:flutter/material.dart';

class TimeRuler extends StatefulWidget {
  final int    focusMins;
  final int    breakMins;
  final bool   pomRunning;
  final bool   isFocusMode;
  final Color  accentColor;
  final Color  trackColor;
  final Color  lineColor;
  final Color  textColor;
  final Color  breakColor;
  final List<(double, int, bool)> sessions;
  final double width;

  const TimeRuler({
    super.key,
    required this.focusMins,
    required this.breakMins,
    required this.pomRunning,
    required this.isFocusMode,
    required this.accentColor,
    this.trackColor = const Color(0xFF1A1A1A),
    this.lineColor  = const Color(0xFF888888),
    this.textColor  = const Color(0xFFAAAAAA),
    this.breakColor = const Color(0xFF5580AA),
    this.sessions   = const [],
    this.width      = 32,
  });

  @override
  State<TimeRuler> createState() => _TimeRulerState();
}

class _TimeRulerState extends State<TimeRuler>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 每秒转动一格
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _nowFrac() {
    final now = DateTime.now();
    // 总时间轴：0 ~ 24h，映射到 0.0 ~ 1.0（圆柱一整圈）
    return (now.hour + now.minute / 60.0 + now.second / 3600.0) / 24.0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _DiscPainter(
          nowFrac:     _nowFrac(),
          focusMins:   widget.focusMins,
          breakMins:   widget.breakMins,
          pomRunning:  widget.pomRunning,
          isFocusMode: widget.isFocusMode,
          accentColor: widget.accentColor,
          trackColor:  widget.trackColor,
          lineColor:   widget.lineColor,
          textColor:   widget.textColor,
          breakColor:  widget.breakColor,
          sessions:    widget.sessions,
        ),
        size: Size(widget.width, double.infinity),
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  final double nowFrac;           // 0.0..1.0，当前时刻在24h圆盘上的位置
  final int    focusMins, breakMins;
  final bool   pomRunning, isFocusMode;
  final Color  accentColor, trackColor, lineColor, textColor, breakColor;
  final List<(double, int, bool)> sessions;

  const _DiscPainter({
    required this.nowFrac,
    required this.focusMins,
    required this.breakMins,
    required this.pomRunning,
    required this.isFocusMode,
    required this.accentColor,
    required this.trackColor,
    required this.lineColor,
    required this.textColor,
    required this.breakColor,
    required this.sessions,
  });

  // 把 hourFrac（0..1 in 24h）转换为视窗内的 y 坐标
  // 视窗高度 h，中央是当前时刻（nowFrac）
  // 可见范围：nowFrac ± windowHalf（= ±3h / 24h）
  double _toY(double hFrac, double h) {
    const windowHalf = 3.0 / 24.0; // ±3小时可见
    var diff = hFrac - nowFrac;
    // 处理跨零点回绕
    if (diff > 0.5)  diff -= 1.0;
    if (diff < -0.5) diff += 1.0;
    // diff 在 -windowHalf..+windowHalf 内才可见
    return h / 2.0 + diff / windowHalf * (h / 2.0);
  }

  bool _inView(double hFrac) {
    const windowHalf = 3.0 / 24.0;
    var diff = hFrac - nowFrac;
    if (diff > 0.5)  diff -= 1.0;
    if (diff < -0.5) diff += 1.0;
    return diff.abs() <= windowHalf;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 视窗裁切区域（圆角矩形）─────────────────────────────────────────────
    final viewRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h), const Radius.circular(8));

    // ── 圆柱侧面背景 ─────────────────────────────────────────────────────────
    // 用竖向渐变模拟圆柱体侧面的明暗（中间亮，两侧暗）
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          trackColor.withOpacity(0.95),
          Color.lerp(trackColor, Colors.white, 0.08)!,
          Color.lerp(trackColor, Colors.white, 0.13)!,
          Color.lerp(trackColor, Colors.white, 0.08)!,
          trackColor.withOpacity(0.95),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.save();
    canvas.clipRRect(viewRRect);
    canvas.drawRRect(viewRRect, bgPaint);

    // ── 过去专注时段色块 ───────────────────────────────────────────────────
    for (final s in sessions) {
      final sf = s.$1 / 24.0;
      final ef = (s.$1 + s.$2 / 60.0) / 24.0;
      if (!_inView(sf) && !_inView(ef)) continue;
      final sy = _toY(sf, h).clamp(0.0, h);
      final ey = _toY(ef, h).clamp(0.0, h);
      if (ey <= sy) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.18, sy, w * 0.64, ey - sy),
          const Radius.circular(2)),
        Paint()..color = (s.$3 ? accentColor : breakColor).withOpacity(0.55));
    }

    // ── 预计专注色块 ───────────────────────────────────────────────────────
    if (pomRunning) {
      final durH = (isFocusMode ? focusMins : breakMins) / 60.0;
      final ef = nowFrac + durH / 24.0;
      final sy = h / 2.0;  // nowFrac 始终在中央
      final ey = _toY(ef, h).clamp(0.0, h);
      if (ey > sy + 2) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, sy, w * 0.76, ey - sy),
            const Radius.circular(2)),
          Paint()..color = (isFocusMode ? accentColor : breakColor).withOpacity(0.16));
      }
    }

    // ── 圆盘刻度线 ─────────────────────────────────────────────────────────
    // 圆盘每5分钟一小格，每小时一大格，每6小时一特大格
    // 通过视差投影模拟刻度印在圆柱弧面上
    final tickP = Paint()..strokeCap = StrokeCap.round;

    // 渲染 ±3小时内的所有刻度（5分钟精度 = 36个/小时 × 6小时 = 216条）
    const windowHalf = 3.0 / 24.0;
    final startH = (nowFrac - windowHalf) * 24.0;
    final endH   = (nowFrac + windowHalf) * 24.0;

    // 每5分钟
    final startMin = (startH * 12).floor();  // 5分钟步进 = 12/h
    final endMin   = (endH * 12).ceil();

    for (int m = startMin; m <= endMin; m++) {
      final hFrac = m / (24.0 * 12);
      final y = _toY(hFrac, h);
      if (y < -2 || y > h + 2) continue;

      final totalMins = m * 5;  // 实际分钟
      final isHour   = totalMins % 60 == 0;
      final is6h     = totalMins % 360 == 0;
      final is30m    = totalMins % 30 == 0;

      // 透视感：刻度线长度由中央向两端变短（模拟圆柱弧面）
      final distFromCenter = (y - h / 2).abs() / (h / 2);
      final perspScale = 1.0 - distFromCenter * 0.3;  // 边缘缩短30%

      double lineLen;
      double opacity;
      double strokeW;

      if (is6h) {
        lineLen = w * 0.72 * perspScale;
        opacity = 0.9;
        strokeW = 1.4;
      } else if (isHour) {
        lineLen = w * 0.52 * perspScale;
        opacity = 0.65;
        strokeW = 1.0;
      } else if (is30m) {
        lineLen = w * 0.35 * perspScale;
        opacity = 0.45;
        strokeW = 0.8;
      } else {
        lineLen = w * 0.22 * perspScale;
        opacity = 0.25;
        strokeW = 0.6;
      }

      // 刻度颜色：中央附近更亮
      final brightness = 1.0 - distFromCenter * 0.5;
      tickP.color = Color.lerp(lineColor.withOpacity(0),
          lineColor.withOpacity(opacity), brightness)!;
      tickP.strokeWidth = strokeW;

      canvas.drawLine(
        Offset(w / 2 - lineLen / 2, y),
        Offset(w / 2 + lineLen / 2, y),
        tickP);

      // 时间标签（整点 & 离中央较近时）
      if (isHour && distFromCenter < 0.75) {
        final realH = (m ~/ 12) % 24;
        final lbl = '${realH.toString().padLeft(2, '0')}';
        final fs = is6h ? 8.0 : 6.5;
        final fw = is6h ? FontWeight.w800 : FontWeight.w500;
        final tp = TextPainter(
          text: TextSpan(text: lbl, style: TextStyle(
              color: textColor.withOpacity(brightness * (is6h ? 0.95 : 0.6)),
              fontSize: fs * perspScale,
              fontWeight: fw,
              fontFamily: 'monospace')),
          textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, Offset(w / 2 - tp.width / 2, y - tp.height / 2));
      }
    }

    // ── 当前时刻红线（中央固定）────────────────────────────────────────────
    final cy = h / 2.0;

    // 外发光
    canvas.drawLine(
      Offset(w * 0.05, cy), Offset(w * 0.95, cy),
      Paint()
        ..color = const Color(0xFFFF3333).withOpacity(0.30)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // 主线
    canvas.drawLine(
      Offset(0, cy), Offset(w, cy),
      Paint()
        ..color = const Color(0xFFFF4444)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round);
    // 中心点
    canvas.drawCircle(Offset(w / 2, cy), 4.5,
        Paint()..color = const Color(0xFFFF3333));
    canvas.drawCircle(Offset(w / 2, cy), 2.2,
        Paint()..color = Colors.white.withOpacity(0.92));

    canvas.restore(); // end clip

    // ── 玻璃视窗效果（在剪切外渲染，叠加在上面）─────────────────────────────

    // 上下渐变蒙版（圆柱边缘的明暗衰减）
    final fadeH = h * 0.22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, fadeH), const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [trackColor, trackColor.withOpacity(0)],
        ).createShader(Rect.fromLTWH(0, 0, w, fadeH)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, h - fadeH, w, fadeH), const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [trackColor, trackColor.withOpacity(0)],
        ).createShader(Rect.fromLTWH(0, h - fadeH, w, fadeH)));

    // 玻璃边框（高光 + 暗边）
    canvas.drawRRect(
      viewRRect,
      Paint()
        ..color = lineColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);

    // 左侧折射高光线（模拟玻璃厚度）
    final hlPath = Path()
      ..moveTo(w * 0.12, h * 0.08)
      ..quadraticBezierTo(w * 0.08, h * 0.5, w * 0.12, h * 0.92);
    canvas.drawPath(hlPath,
        Paint()
          ..color = Colors.white.withOpacity(0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);

    // 右侧次级高光
    final hlPath2 = Path()
      ..moveTo(w * 0.82, h * 0.12)
      ..quadraticBezierTo(w * 0.88, h * 0.5, w * 0.82, h * 0.88);
    canvas.drawPath(hlPath2,
        Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_DiscPainter o) =>
      o.nowFrac != nowFrac ||
      o.pomRunning != pomRunning ||
      o.sessions.length != sessions.length ||
      o.accentColor != accentColor;
}
