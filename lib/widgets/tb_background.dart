
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class TBBackground extends StatelessWidget {
  const TBBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<AppState>().themeConfig;
    return CustomPaint(
      painter: _TBBackgroundPainter(
        color: Color(tc.acc).withOpacity(0.06),
        seed: 10, // Fixed seed for consistent pattern
      ),
      size: Size.infinite,
    );
  }
}

class _TBBackgroundPainter extends CustomPainter {
  final Color color;
  final int seed;
  final int microbeCount;
  
  // Cache the generated microbes to avoid recalculating on every paint
  late final List<(_Microbe, Paint)> _microbes;

  _TBBackgroundPainter({
    required this.color,
    this.seed = 0,
    this.microbeCount = 36,
  }) {
    _microbes = _generateMicrobes();
  }

  List<(_Microbe, Paint)> _generateMicrobes() {
    final random = Random(seed);
    final List<(_Microbe, Paint)> microbes = [];
    for (int i = 0; i < microbeCount; i++) {
      final microbe = _Microbe(
        x: random.nextDouble(),
        y: random.nextDouble(),
        rotation: random.nextDouble() * pi,
        scale: random.nextDouble() * 0.5 + 0.5,
      );
      final paint = Paint()
        ..color = color.withOpacity(color.opacity * (random.nextDouble() * 0.5 + 0.3))
        ..style = PaintingStyle.fill;
      microbes.add((microbe, paint));
    }
    return microbes;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final microbeData in _microbes) {
      final microbe = microbeData.$1;
      final paint = microbeData.$2;
      
      canvas.save();
      
      // Translate to the microbe's position
      canvas.translate(microbe.x * size.width, microbe.y * size.height);
      
      // Rotate the canvas
      canvas.rotate(microbe.rotation);
      
      // Define the rod shape (a rounded rectangle)
      final RRect rod = RRect.fromLTRBR(
        -15 * microbe.scale, -3 * microbe.scale,
        15 * microbe.scale, 3 * microbe.scale,
        Radius.circular(3 * microbe.scale),
      );
      
      canvas.drawRRect(rod, paint);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TBBackgroundPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class _Microbe {
  final double x;
  final double y;
  final double rotation;
  final double scale;

  _Microbe({
    required this.x,
    required this.y,
    required this.rotation,
    required this.scale,
  });
}
