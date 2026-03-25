import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/crash_logger.dart';

class BlackHoleShaderWidget extends StatefulWidget {
  const BlackHoleShaderWidget({super.key});

  @override
  State<BlackHoleShaderWidget> createState() => _BlackHoleShaderWidgetState();
}

class _BlackHoleShaderWidgetState extends State<BlackHoleShaderWidget> with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  ui.Image? _bgImage;
  late Ticker _ticker;
  double _elapsedTime = 0.0;
  double _cameraOffsetX = 0.0;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _loadAssets();
    _ticker = createTicker((elapsed) {
      if (mounted) {
        final state = context.read<AppState>();
        final s = state.settings.blackHole;
        setState(() {
          _elapsedTime = elapsed.inMilliseconds / 1000.0;
          if (s.animate) {
            _cameraOffsetX += s.speed;
          }
        });
      }
    });
  }

  Future<void> _loadAssets() async {
    try {
      final data = await rootBundle.load('assets/black_hole_bg.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _bgImage = frame.image;
        });
      }
    } catch (e) {
      CrashLogger.error('Shader', 'Failed to load bg image: $e');
    }
  }

  Future<void> _loadShader() async {
    try {
      CrashLogger.info('Shader', 'Loading black_hole.frag...');
      final program = await ui.FragmentProgram.fromAsset('shaders/black_hole.frag');
      if (mounted) {
        setState(() {
          _program = program;
          _ticker.start();
        });
        CrashLogger.info('Shader', 'black_hole.frag loaded successfully');
      }
    } catch (e, stack) {
      CrashLogger.error('Shader', 'Failed to load shader: $e');
      debugPrint('Failed to load shader: $e\n$stack');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null || _bgImage == null) {
      return Container(color: Colors.black);
    }

    final state = context.watch<AppState>();
    final s = state.settings.blackHole;

    return CustomPaint(
      painter: BlackHolePainter(
        shader: _program!.fragmentShader(),
        bgImage: _bgImage!,
        time: _elapsedTime,
        cameraOffsetX: _cameraOffsetX,
        accretionDisk: s.accretionDisk,
        maxIterations: s.maxIterations,
      ),
      size: Size.infinite,
    );
  }
}

class BlackHolePainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image bgImage;
  final double time;
  final double cameraOffsetX;
  final bool accretionDisk;
  final int maxIterations;

  BlackHolePainter({
    required this.shader,
    required this.bgImage,
    required this.time,
    required this.cameraOffsetX,
    required this.accretionDisk,
    required this.maxIterations,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1:1 Implementation of uniforms from chrismatgit/black-hole-simulation
    shader.setFloat(0, accretionDisk ? 1.0 : 0.0); // uAccretionDisk
    shader.setFloat(1, size.width); // uResolution.x
    shader.setFloat(2, size.height); // uResolution.y
    shader.setFloat(3, cameraOffsetX); // uCameraTranslate.x
    // 原作者摄像机默认 Y 偏移是 0.05，我们保持这个偏移以确保视角一致
    shader.setFloat(4, 0.0); // uCameraTranslate.y
    shader.setFloat(5, 0.0); // uCameraTranslate.z
    shader.setFloat(6, 75.0); // uPov
    shader.setFloat(7, maxIterations.toDouble()); // uMaxIterations
    shader.setFloat(8, 2.5 / maxIterations.toDouble()); // uStepSize
    shader.setFloat(9, time); // uTime

    shader.setImageSampler(0, bgImage);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant BlackHolePainter oldDelegate) {
    return oldDelegate.time != time ||
           oldDelegate.cameraOffsetX != cameraOffsetX ||
           oldDelegate.accretionDisk != accretionDisk ||
           oldDelegate.maxIterations != maxIterations;
  }
}
