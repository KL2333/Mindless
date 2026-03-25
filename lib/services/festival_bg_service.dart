// lib/services/festival_bg_service.dart
// 节日全局扁平化背景层
// 每个节日一套独特的 CustomPainter，始终在所有界面背景浮现（极低透明度）
// 设计原则：扁平、极简、辨识度高、不干扰内容阅读（整体透明度 ≤ 12%）

import 'dart:math';
import 'package:flutter/material.dart';
import 'festival_calendar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 入口 Widget — 自动根据今日节日展示对应背景
// ─────────────────────────────────────────────────────────────────────────────

class FestivalBgOverlay extends StatefulWidget {
  final String? forceFestivalId; // null = 自动检测今日节日
  const FestivalBgOverlay({super.key, this.forceFestivalId});

  @override
  State<FestivalBgOverlay> createState() => _FestivalBgOverlayState();
}

class _FestivalBgOverlayState extends State<FestivalBgOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final festivalId = widget.forceFestivalId
        ?? getTodayFestival()?.id;
    if (festivalId == null) return const SizedBox.shrink();

    final painter = _painterFor(festivalId);
    if (painter == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: painter(progress: _ctrl.value),
          size: Size.infinite,
        ),
      ),
    );
  }

  _FestivalPainterFactory? _painterFor(String id) {
    switch (id) {
      case 'dragon_boat':      return ({required double progress}) => _DragonBoatPainter(progress: progress);
      case 'world_water_day':   return ({required double progress}) => _WaterDayPainter(progress: progress);
      case 'lunar_new_year':   return ({required double progress}) => _LunarNewYearPainter(progress: progress);
      case 'mid_autumn':       return ({required double progress}) => _MidAutumnPainter(progress: progress);
      default: return null;
    }
  }
}

typedef _FestivalPainterFactory = CustomPainter Function({required double progress});

// ─────────────────────────────────────────────────────────────────────────────
// 端午节背景（不依赖图片资源）
// 主视觉：荷叶 + 水波 + 极简龙舟剪影（右下角）
// ─────────────────────────────────────────────────────────────────────────────

class _DragonBoatPainter extends CustomPainter {
  final double progress;
  static const _opMain = 0.075; // overall opacity ceiling

  const _DragonBoatPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;

    // Palette from festival_calendar.dart (themeReason)
    const lotusGreen = Color(0xFF2A9C72);
    const lotusLight = Color(0xFF5DC49A);
    const deepWater  = Color(0xFF1A5C3A);

    // ── Soft water ripples ────────────────────────────────────────────────
    final rippleCenter = Offset(w * 0.76, h * 0.72);
    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3.0) % 1.0;
      final r = w * (0.10 + t * 0.12);
      final alpha = (1.0 - t) * _opMain * 0.75;
      canvas.drawCircle(
        rippleCenter,
        r,
        Paint()
          ..color = lotusLight.withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // ── Lotus leaves (flat circles with notch) ────────────────────────────
    void leaf(Offset c, double r, double notchAngle, Color col, double op) {
      final path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
      // notch (a small triangle cut)
      final notch = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * 1.2 * cos(notchAngle - 0.22), c.dy + r * 1.2 * sin(notchAngle - 0.22))
        ..lineTo(c.dx + r * 1.2 * cos(notchAngle + 0.22), c.dy + r * 1.2 * sin(notchAngle + 0.22))
        ..close();
      final combined = Path.combine(PathOperation.difference, path, notch);
      canvas.drawPath(combined, Paint()..color = col.withOpacity(op));
      canvas.drawPath(
        combined,
        Paint()
          ..color = deepWater.withOpacity(op * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    leaf(Offset(w * 0.18, h * 0.78), w * 0.10, -0.6, lotusGreen, _opMain);
    leaf(Offset(w * 0.30, h * 0.70), w * 0.075, 1.9, lotusLight, _opMain * 0.85);
    leaf(Offset(w * 0.10, h * 0.63), w * 0.06, 0.9, lotusLight, _opMain * 0.70);

    // ── Minimal dragon boat silhouette (bottom-right) ─────────────────────
    final boatBaseY = h * 0.84;
    final boatX = w * 0.62;
    final boatW = w * 0.28;
    final boatH = w * 0.05;
    final sway = sin(progress * pi * 2) * (w * 0.004);

    final boatPath = Path()
      ..moveTo(boatX, boatBaseY + sway)
      ..quadraticBezierTo(boatX + boatW * 0.18, boatBaseY + boatH * 0.85 + sway,
          boatX + boatW * 0.5, boatBaseY + boatH * 0.9 + sway)
      ..quadraticBezierTo(boatX + boatW * 0.82, boatBaseY + boatH * 0.85 + sway,
          boatX + boatW, boatBaseY + sway)
      ..quadraticBezierTo(boatX + boatW * 0.78, boatBaseY - boatH * 0.55 + sway,
          boatX + boatW * 0.5, boatBaseY - boatH * 0.6 + sway)
      ..quadraticBezierTo(boatX + boatW * 0.22, boatBaseY - boatH * 0.55 + sway,
          boatX, boatBaseY + sway)
      ..close();

    canvas.drawPath(
      boatPath,
      Paint()..color = deepWater.withOpacity(_opMain * 0.85),
    );

    // Dragon head hint (a small curve at front)
    final head = Path()
      ..moveTo(boatX + boatW * 0.92, boatBaseY - boatH * 0.55 + sway)
      ..quadraticBezierTo(
        boatX + boatW * 1.02,
        boatBaseY - boatH * 0.95 + sway,
        boatX + boatW * 0.98,
        boatBaseY - boatH * 0.20 + sway,
      );
    canvas.drawPath(
      head,
      Paint()
        ..color = deepWater.withOpacity(_opMain * 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DragonBoatPainter o) => o.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 世界水日背景
// 主视觉：一滴纯净的水，居于画面右下角偏中，扁平风格
// 辅助：若干细微气泡从底部缓缓飘起，极淡水波纹向外扩散
// ─────────────────────────────────────────────────────────────────────────────

class _WaterDayPainter extends CustomPainter {
  final double progress;
  static const _mainOpacity = 0.09;  // 主水滴整体透明度
  static const _auxOpacity  = 0.045; // 气泡/波纹透明度

  static final _rng = Random(42);
  static final _bubbles = List.generate(18, (i) => (
    x: 0.08 + _rng.nextDouble() * 0.84,
    size: 2.0 + _rng.nextDouble() * 5.0,
    speed: 0.08 + _rng.nextDouble() * 0.12,
    phase: _rng.nextDouble(),
    drift: (_rng.nextDouble() - 0.5) * 0.03,
  ));

  const _WaterDayPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width * 0.72;
    final cy = s.height * 0.58;

    // ── 水波纹（3圈，向外扩散）─────────────────────────────────────────────
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3.0) % 1.0;
      final r = s.width * 0.12 * (0.4 + phase * 0.8);
      final alpha = (1.0 - phase) * _auxOpacity;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = const Color(0xFF0E86B4).withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // ── 主水滴（扁平化，单色填充 + 高光） ─────────────────────────────────
    _drawWaterDrop(canvas, cx, cy,
        width: s.width * 0.16, height: s.width * 0.22);

    // ── 小气泡（从底部缓缓飘起）───────────────────────────────────────────
    for (final b in _bubbles) {
      final t = ((progress * b.speed + b.phase) % 1.0);
      final bx = (b.x + b.drift * sin(t * pi * 2)) * s.width;
      final by = s.height * (1.0 - t * 1.1) + 20;
      if (by < -20 || by > s.height + 20) continue;
      final alpha = sin(t * pi).clamp(0.0, 1.0) * _auxOpacity;
      canvas.drawCircle(
        Offset(bx, by),
        b.size,
        Paint()
          ..color = const Color(0xFF38C4C8).withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  void _drawWaterDrop(Canvas canvas, double cx, double cy,
      {required double width, required double height}) {
    // 水滴形状：底部半圆 + 顶部尖锐收口
    final halfW = width / 2;
    final bodyH = height * 0.62; // 圆弧部分高度
    final tipH  = height * 0.38; // 尖头高度

    final path = Path();
    // 底部圆弧中心
    final circleCy = cy + tipH * 0.5;
    // 两侧与圆弧相切的起点
    path.moveTo(cx, cy - tipH); // 顶端尖点
    path.cubicTo(
      cx + halfW * 0.6, cy - tipH * 0.2,
      cx + halfW,       circleCy - bodyH * 0.1,
      cx + halfW,       circleCy,
    );
    // 底部圆弧（下半圆）
    path.arcToPoint(
      Offset(cx - halfW, circleCy),
      radius: Radius.circular(halfW),
      clockwise: false,
    );
    path.cubicTo(
      cx - halfW,       circleCy - bodyH * 0.1,
      cx - halfW * 0.6, cy - tipH * 0.2,
      cx,               cy - tipH,
    );
    path.close();

    // 主体填充 — 深海蓝
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF0E86B4).withOpacity(_mainOpacity),
    );

    // 轮廓线
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0E86B4).withOpacity(_mainOpacity * 1.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // 高光（左上角小椭圆，增加立体感）
    final hlCx = cx - halfW * 0.28;
    final hlCy = cy - tipH * 0.25;
    canvas.save();
    canvas.translate(hlCx, hlCy);
    canvas.rotate(-0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: halfW * 0.45,
        height: halfW * 0.22,
      ),
      Paint()..color = Colors.white.withOpacity(_mainOpacity * 1.4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WaterDayPainter o) => o.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 农历新年背景
// 主视觉：一只大灯笼，居于画面右侧，扁平红色
// 辅助：若干细小烟花/星点从底部飘散，极淡云纹
// ─────────────────────────────────────────────────────────────────────────────

class _LunarNewYearPainter extends CustomPainter {
  final double progress;
  static const _op = 0.09;
  static final _rng = Random(88);
  static final _sparks = List.generate(24, (i) => (
    angle: _rng.nextDouble() * pi * 2,
    r: 0.05 + _rng.nextDouble() * 0.12,
    speed: 0.06 + _rng.nextDouble() * 0.10,
    phase: _rng.nextDouble(),
    size: 1.5 + _rng.nextDouble() * 3.0,
  ));

  const _LunarNewYearPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size s) {
    final lx = s.width * 0.78;
    final ly = s.height * 0.30;

    // ── 灯笼主体 ─────────────────────────────────────────────────────────
    _drawLantern(canvas, lx, ly,
        rx: s.width * 0.065, ry: s.width * 0.095);

    // ── 烟花粒子（从灯笼位置向四周发散）──────────────────────────────────
    final now = progress;
    for (final sp in _sparks) {
      final t = ((now * sp.speed + sp.phase) % 1.0);
      final dist = sp.r * s.width * t;
      final px = lx + cos(sp.angle) * dist;
      final py = ly + sin(sp.angle) * dist;
      final alpha = (1.0 - t) * _op * 0.6;
      canvas.drawCircle(
        Offset(px, py), sp.size * (1.0 - t * 0.5),
        Paint()..color = const Color(0xFFEE8820).withOpacity(alpha),
      );
    }

    // ── 极淡福字轮廓（右上角）────────────────────────────────────────────
    // 用几何图形代替文字渲染（菱形）
    final fp = Paint()
      ..color = const Color(0xFFCC2020).withOpacity(_op * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final fx = s.width * 0.88, fy = s.height * 0.08, fr = s.width * 0.025;
    final fpath = Path()
      ..moveTo(fx, fy - fr)
      ..lineTo(fx + fr, fy)
      ..lineTo(fx, fy + fr)
      ..lineTo(fx - fr, fy)
      ..close();
    canvas.drawPath(fpath, fp);
  }

  void _drawLantern(Canvas canvas, double cx, double cy,
      {required double rx, required double ry}) {
    // 椭圆形灯笼主体
    final bodyRect = Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 2, height: ry * 2);

    // 主体填充
    canvas.drawOval(
      bodyRect,
      Paint()..color = const Color(0xFFCC2020).withOpacity(_op),
    );
    canvas.drawOval(
      bodyRect,
      Paint()
        ..color = const Color(0xFFCC2020).withOpacity(_op * 1.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // 灯笼横纹（3条）
    for (int i = 0; i < 3; i++) {
      final frac = (i + 1) / 4.0;
      final y = cy - ry + ry * 2 * frac;
      // 用椭圆段近似横纹
      canvas.drawLine(
        Offset(cx - rx * _chordWidth(frac), y),
        Offset(cx + rx * _chordWidth(frac), y),
        Paint()
          ..color = const Color(0xFFEE8820).withOpacity(_op * 0.8)
          ..strokeWidth = 0.6,
      );
    }

    // 顶部/底部装饰条
    final capPaint = Paint()
      ..color = const Color(0xFFEE8820).withOpacity(_op * 1.2)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(cx - rx * 0.5, cy - ry), Offset(cx + rx * 0.5, cy - ry), capPaint);
    canvas.drawLine(
      Offset(cx - rx * 0.5, cy + ry), Offset(cx + rx * 0.5, cy + ry), capPaint);

    // 顶部细绳
    canvas.drawLine(
      Offset(cx, cy - ry),
      Offset(cx, cy - ry - rx * 0.6),
      Paint()
        ..color = const Color(0xFFCC2020).withOpacity(_op)
        ..strokeWidth = 0.8,
    );

    // 底部流苏（3条短线）
    for (int i = -1; i <= 1; i++) {
      final fx = cx + i * rx * 0.3;
      final swayLen = rx * 0.5 * (1 + 0.2 * sin(progress * pi * 2 + i * 0.8));
      canvas.drawLine(
        Offset(fx, cy + ry),
        Offset(fx + i * rx * 0.05, cy + ry + swayLen),
        Paint()
          ..color = const Color(0xFFEE8820).withOpacity(_op * 0.9)
          ..strokeWidth = 0.7,
      );
    }
  }

  double _chordWidth(double frac) {
    // 椭圆在 y=frac*2ry 处的 x/rx 比例
    final y = frac * 2 - 1; // -1 to 1
    return sqrt((1 - y * y).clamp(0.0, 1.0));
  }

  @override
  bool shouldRepaint(_LunarNewYearPainter o) => o.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 中秋节背景
// 主视觉：一轮圆月，居于画面右上，金色扁平光晕
// 辅助：几颗星点，淡淡云层从左飘过
// ─────────────────────────────────────────────────────────────────────────────

class _MidAutumnPainter extends CustomPainter {
  final double progress;
  static const _op = 0.09;

  static final _rng = Random(15);
  static final _stars = List.generate(14, (i) => (
    x: _rng.nextDouble(),
    y: _rng.nextDouble() * 0.5,
    size: 0.8 + _rng.nextDouble() * 1.8,
    twinkle: _rng.nextDouble(),
  ));

  const _MidAutumnPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size s) {
    final mx = s.width * 0.76;
    final my = s.height * 0.18;
    final mr = s.width * 0.085;

    // ── 月亮光晕（多圈渐变光）────────────────────────────────────────────
    for (int i = 3; i >= 1; i--) {
      canvas.drawCircle(
        Offset(mx, my),
        mr * (1.0 + i * 0.45),
        Paint()
          ..color = const Color(0xFFE8C060)
              .withOpacity(_op * (0.20 / i)),
      );
    }

    // ── 月亮主体 ─────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(mx, my),
      mr,
      Paint()..color = const Color(0xFFE8C060).withOpacity(_op * 1.2),
    );
    // 月面纹理：2个淡圆（月海）
    canvas.drawCircle(
      Offset(mx - mr * 0.28, my + mr * 0.20),
      mr * 0.20,
      Paint()..color = const Color(0xFFD0A040).withOpacity(_op * 0.6),
    );
    canvas.drawCircle(
      Offset(mx + mr * 0.18, my - mr * 0.15),
      mr * 0.13,
      Paint()..color = const Color(0xFFD0A040).withOpacity(_op * 0.5),
    );

    // ── 星点（轻微闪烁）──────────────────────────────────────────────────
    for (final st in _stars) {
      final twinkle = 0.6 + 0.4 * sin(progress * pi * 2 + st.twinkle * pi * 4);
      canvas.drawCircle(
        Offset(st.x * s.width, st.y * s.height),
        st.size * twinkle,
        Paint()
          ..color = const Color(0xFFE8C060).withOpacity(_op * 0.7 * twinkle),
      );
    }

    // ── 云层（从左向右缓缓飘移）──────────────────────────────────────────
    final cloudOffset = (progress * 0.15 * s.width) % (s.width * 1.5) - s.width * 0.3;
    _drawCloud(canvas, cloudOffset + s.width * 0.1, s.height * 0.12,
        s.width * 0.22, _op * 0.4);
    _drawCloud(canvas, cloudOffset + s.width * 0.55, s.height * 0.22,
        s.width * 0.18, _op * 0.3);
  }

  void _drawCloud(Canvas canvas, double cx, double cy, double w, double op) {
    final h = w * 0.35;
    final p = Paint()..color = const Color(0xFFE8C060).withOpacity(op);
    // 三个圆叠成云朵
    canvas.drawOval(Rect.fromCenter(
        center: Offset(cx, cy), width: w, height: h), p);
    canvas.drawCircle(Offset(cx - w * 0.22, cy - h * 0.25), h * 0.65, p);
    canvas.drawCircle(Offset(cx + w * 0.18, cy - h * 0.20), h * 0.55, p);
    canvas.drawCircle(Offset(cx - w * 0.42, cy + h * 0.05), h * 0.40, p);
  }

  @override
  bool shouldRepaint(_MidAutumnPainter o) => o.progress != progress;
}
