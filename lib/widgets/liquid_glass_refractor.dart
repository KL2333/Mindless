import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// 严格遵循物理模拟参数的 Liquid Glass 渲染组件
class LiquidGlassRefractor extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final Color baseColor;
  final double intensity; // 通透感强度 (0.0 - 1.0, 越低越通透)

  const LiquidGlassRefractor({
    super.key,
    required this.child,
    this.borderRadius = 45.0,
    required this.baseColor,
    this.intensity = 0.3,
  });

  @override
  State<LiquidGlassRefractor> createState() => _LiquidGlassRefractorState();
}

class _LiquidGlassRefractorState extends State<LiquidGlassRefractor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 0.5Hz 频率
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 动态计算模糊度和透明度
    // intensity 越低，sigma 越小，opacity 越低
    final double sigma = 1.0 + (widget.intensity * 14.0); // 1.0 到 15.0
    final double baseOpacity = 0.01 + (widget.intensity * 0.09); // 0.01 到 0.10
    final double gradientOpacity = 0.02 + (widget.intensity * 0.08); // 0.02 到 0.10

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 1. 底层阴影 (Depth/Shadow Layer)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08 + (widget.intensity * 0.04)),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          
          // 2. 中层折射体 (Refraction/Glass Layer)
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // 计算动态中心点位移 (周期性正弦位移)
                  final offset = sin(_controller.value * pi);
                  final center = Alignment(offset * 0.1, offset * 0.1);
                  
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      // 饱和度过滤: 极低 Alpha 值
                      color: widget.baseColor.withOpacity(baseOpacity),
                      // 非匀质背景: SweepGradient 叠加
                      gradient: SweepGradient(
                        center: center,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          widget.baseColor.withOpacity(gradientOpacity),
                          Colors.white.withOpacity(baseOpacity),
                          widget.baseColor.withOpacity(gradientOpacity),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                    child: child,
                  );
                },
                child: widget.child,
              ),
            ),
          ),

          // 3. 顶层高光与内部反射 (Highlight & Internal Reflection Layer)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlassEffectPainter(
                  borderRadius: widget.borderRadius,
                  intensity: widget.intensity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassEffectPainter extends CustomPainter {
  final double borderRadius;
  final double intensity;
  final Paint _borderPaint;
  final Paint _reflectionPaint;

  _GlassEffectPainter({required this.borderRadius, required this.intensity})
      : _borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 + (intensity * 1.5), // 动态边缘宽度 (0.5 到 2.0)
        _reflectionPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 + (intensity * 1.2) // 动态内部反射宽度 (0.8 到 2.0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. 边框干涉 (Edge Interference) - 135度渐变 (动态对比度)
    _borderPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.1 + (intensity * 0.5)), // 动态起点亮度 (0.1 到 0.6)
        Colors.white.withOpacity(0.02 + (intensity * 0.08)), // 动态终点亮度 (0.02 到 0.1)
      ],
      stops: const [0.0, 1.0],
    ).createShader(rect);
    canvas.drawRRect(rrect, _borderPaint);

    // 2. 内部反射 (Internal Reflection)
    // 在容器内边缘 2px 处模拟全反射
    final reflectionPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        rect.deflate(2.0),
        Radius.circular(max(0, borderRadius - 2.0)),
      ));
    
    // 顶部 Y 轴负方向偏移 Offset(0, 2)
    canvas.save();
    canvas.translate(0, 2);
    _reflectionPaint.color = Colors.white.withOpacity(0.1 + (intensity * 0.3)); // 动态反射亮度 (0.1 到 0.4)
    // 只画顶部的反射弧
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.35));
    canvas.drawPath(reflectionPath, _reflectionPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
