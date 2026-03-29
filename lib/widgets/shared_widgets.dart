// lib/widgets/shared_widgets.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// 光学级玻璃拟态容器 (Optical Liquid Glass)
/// 特点：极高透明度、精细虹彩边框、光学厚度感、支持 RepaintBoundary 性能优化
class OpticalGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final double opacity;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final bool useBlur;
  final double blurSigma;
  final bool iridescent; // 是否开启虹彩边缘效果

  const OpticalGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 32,
    this.borderWidth = 1.2,
    this.opacity = 0.02,
    this.borderColor,
    this.padding,
    this.width,
    this.height,
    this.useBlur = true,
    this.blurSigma = 40.0,
    this.iridescent = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: iridescent 
          ? null // 使用 CustomPainter 绘制虹彩边框
          : Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.15),
              width: borderWidth,
            ),
      ),
      child: child,
    );

    if (iridescent) {
      content = CustomPaint(
        painter: _IridescentBorderPainter(
          radius: borderRadius,
          strokeWidth: borderWidth,
          baseColor: borderColor ?? Colors.white.withOpacity(0.25),
        ),
        child: content,
      );
    }

    if (useBlur) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    return RepaintBoundary(child: content);
  }
}

class _IridescentBorderPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Color baseColor;

  _IridescentBorderPainter({
    required this.radius,
    required this.strokeWidth,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    
    // 虹彩渐变：模拟光学折射
    final gradient = SweepGradient(
      center: Alignment.center,
      colors: [
        baseColor.withOpacity(0.1),
        baseColor.withOpacity(0.4),
        baseColor.withOpacity(0.1),
        baseColor.withOpacity(0.6),
        baseColor.withOpacity(0.2),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 碎裂冰块效果 (Ice Crack) 用于中断警告
class IceCrackPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0 碎裂程度
  final Color color;

  IceCrackPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color.withOpacity(0.3 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rand = math.Random(42); // 固定种子保证裂纹稳定
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0) * (3.14159 / 180.0);
      final startX = centerX + math.cos(angle) * 20;
      final startY = centerY + math.sin(angle) * 20;
      
      var currX = startX;
      var currY = startY;
      
      for (int j = 0; j < 5; j++) {
        final nextX = currX + (rand.nextDouble() - 0.5) * 40 * progress + math.cos(angle) * 30 * progress;
        final nextY = currY + (rand.nextDouble() - 0.5) * 40 * progress + math.sin(angle) * 30 * progress;
        canvas.drawLine(Offset(currX, currY), Offset(nextX, nextY), paint);
        currX = nextX;
        currY = nextY;
      }
    }
  }

  @override
  bool shouldRepaint(IceCrackPainter oldDelegate) => oldDelegate.progress != progress;
}

/// 动态环境光球 (Animated Glass Orb)
class GlassOrb extends StatelessWidget {
  final Color color;
  final double size;
  final Alignment alignment;
  final double blurSigma;

  const GlassOrb({
    super.key,
    required this.color,
    this.size = 300,
    this.alignment = Alignment.center,
    this.blurSigma = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: blurSigma,
                spreadRadius: size * 0.1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated toggle switch matching app theme
class AppSwitch extends StatelessWidget {
  final bool value;
  final ThemeConfig tc;
  final ValueChanged<bool> onChanged;

  const AppSwitch({
    super.key,
    required this.value,
    required this.tc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: value ? Color(tc.acc) : Color(tc.brd),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃分段选择器 (Liquid Segmented Control)
/// 视觉：Apple 风格双态胶囊 + Liquid Glass 质感
/// 动效：物理揭晓式切换 (与 Dock 栏一致)
class LiquidSegmentedControl extends StatefulWidget {
  final List<String> labels;
  final int currentIndex;
  final ValueChanged<int> onValueChanged;
  final ThemeConfig tc;
  final double width;
  final double height;

  const LiquidSegmentedControl({
    super.key,
    required this.labels,
    required this.currentIndex,
    required this.onValueChanged,
    required this.tc,
    this.width = 220,
    this.height = 36,
  });

  @override
  State<LiquidSegmentedControl> createState() => _LiquidSegmentedControlState();
}

class _LiquidSegmentedControlState extends State<LiquidSegmentedControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _offset = 0.0;

  @override
  void initState() {
    super.initState();
    _offset = widget.currentIndex.toDouble();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() {
      setState(() {
        _offset = _anim.value;
      });
    });
  }

  @override
  void didUpdateWidget(LiquidSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _ctrl.stop();
      _anim = Tween<double>(
        begin: _offset,
        end: widget.currentIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth = widget.width.isFinite ? widget.width : constraints.maxWidth;
        final segmentWidth = actualWidth / widget.labels.length;
        final maxRange = actualWidth - segmentWidth;
        final indicatorLeft = _offset * (maxRange / (widget.labels.length - 1));

        return OpticalGlassContainer(
          width: actualWidth,
          height: widget.height,
          borderRadius: widget.height / 2,
          padding: const EdgeInsets.all(2),
          opacity: 0.05,
          borderColor: Color(widget.tc.brd).withOpacity(0.2),
          iridescent: false,
          useBlur: true,
          blurSigma: 10,
          child: Stack(
            children: [
              // ── 底层文字 (Inactive) ──
              ClipPath(
                clipper: _SegmentClipper(
                  left: indicatorLeft,
                  width: segmentWidth,
                  inverse: true,
                ),
                child: Row(
                  children: List.generate(widget.labels.length, (i) {
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onValueChanged(i),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            widget.labels[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(widget.tc.ts),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ── 滑块指示器 (Indicator) ──
              Positioned(
                left: indicatorLeft,
                top: 0,
                bottom: 0,
                child: Container(
                  width: segmentWidth,
                  decoration: BoxDecoration(
                    color: Color(widget.tc.na).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 顶层文字 (Active - Physical Reveal) ──
              ClipPath(
                clipper: _SegmentClipper(
                  left: indicatorLeft,
                  width: segmentWidth,
                  inverse: false,
                ),
                child: Row(
                  children: List.generate(widget.labels.length, (i) {
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onValueChanged(i),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            widget.labels[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(widget.tc.nt),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class _SegmentClipper extends CustomClipper<Path> {
  final double left;
  final double width;
  final bool inverse;

  _SegmentClipper({
    required this.left,
    required this.width,
    required this.inverse,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    if (inverse) {
      // 剪掉指示器所在区域，显示底层
      path.addRect(Rect.fromLTWH(0, 0, left, size.height));
      path.addRect(Rect.fromLTWH(left + width, 0, size.width - (left + width), size.height));
    } else {
      // 仅保留指示器所在区域，显示顶层
      path.addRect(Rect.fromLTWH(left, 0, width, size.height));
    }
    return path;
  }

  @override
  bool shouldReclip(_SegmentClipper old) =>
      old.left != left || old.width != width || old.inverse != inverse;
}
