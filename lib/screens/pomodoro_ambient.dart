// lib/screens/pomodoro_ambient.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/shared_widgets.dart';
import '../services/pom_engine.dart';
import '../services/focus_quality_service.dart';
import '../services/distraction_detector.dart';
import '../services/environment_sound_service.dart';
import '../services/phone_flip_service.dart';
import '../beta/beta_flags.dart';

class PomodoroAmbientScreen extends StatefulWidget {
  const PomodoroAmbientScreen({super.key});
  @override
  State<PomodoroAmbientScreen> createState() => _PomodoroAmbientScreenState();
}

class _PomodoroAmbientScreenState extends State<PomodoroAmbientScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  double? _originalBrightness;
  // Cache engine ref so dispose() never calls context.read on a dead element
  late PomEngine _engine;
  StreamSubscription<PhoneFlipEvent>? _flipSub;
  bool _pickupDialogOpen = false;

  // Burn-in prevention: drift offset, 1px per minute
  double _driftX = 0, _driftY = 0;
  Timer? _driftTimer;
  static const _driftPx = 30.0; // max drift radius

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyDimBrightness();
    _acquireScreenOn();
    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _startDrift();
    _engine = context.read<AppState>().engine;
    _engine.phaseJustCompleted.addListener(_onPhase);
    _engine.addListener(_syncFlipMonitoring);
    _syncFlipMonitoring();
  }

  static const _windowCh = MethodChannel('com.lsz.app/keepalive');
  static const _alarmCh  = MethodChannel('com.lsz.app/pom_alarm');

  Future<void> _acquireScreenOn() async {
    try { await _windowCh.invokeMethod('acquire'); } catch (_) {}
  }

  Future<void> _releaseScreenOn() async {
    // Only release if pom is no longer running (don't release if timer still active)
    try { await _windowCh.invokeMethod('release'); } catch (_) {}
  }

  void _startDrift() {
    int tick = 0;
    _driftTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      tick++;
      // Lissajous: x and y drift independently on different periods
      setState(() {
        _driftX = _driftPx * sin(tick * 0.37); // ~170s period
        _driftY = _driftPx * sin(tick * 0.23); // ~273s period
      });
    });
  }

  Future<void> _applyDimBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      // Use extremely low brightness for AOD mode
      await ScreenBrightness().setScreenBrightness(0.01);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        // Restore to original or a sensible default
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
      }
      // Always call reset to release the plugin's override
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
  }

  PomDisciplineMode get _disciplineMode =>
      pomDisciplineModeFromKey(context.read<AppState>().settings.pom.disciplineMode);

  bool get _halfStrictFocusRunning =>
      _disciplineMode == PomDisciplineMode.semiStrict &&
      _engine.running &&
      _engine.mode == PomMode.focus;

  bool get _ambientLocked =>
      _engine.running &&
      _engine.mode == PomMode.focus &&
      _disciplineMode != PomDisciplineMode.normal;

  void _syncFlipMonitoring() {
    if (!mounted) return;
    if (_halfStrictFocusRunning && !_pickupDialogOpen) {
      _flipSub ??= PhoneFlipService.events().listen((event) {
        if (event.type == PhoneFlipEventType.pickedUp) {
          _handlePickupInterrupt();
        }
      });
      return;
    }
    _flipSub?.cancel();
    _flipSub = null;
  }

  Future<void> _resumeAfterFlip() async {
    final state = context.read<AppState>();
    state.pomStart();
    if (state.settings.distractionAlertEnabled) {
      DistractionDetector.startMonitoring();
    }
    if (state.settings.noisePomEnabled) {
      EnvironmentSoundService.startSessionSampling();
    }
    await _applyDimBrightness();
    await _acquireScreenOn();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _syncFlipMonitoring();
  }

  Future<void> _cancelFocusSession() async {
    final state = context.read<AppState>();
    state.pomReset();
    await _restoreBrightness();
    await _releaseScreenOn();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handlePickupInterrupt() async {
    if (!mounted || _pickupDialogOpen || !_halfStrictFocusRunning) return;
    _pickupDialogOpen = true;
    _flipSub?.cancel();
    _flipSub = null;
    final state = context.read<AppState>();
    state.engine.pause();
    DistractionDetector.stopMonitoring();
    EnvironmentSoundService.stopSessionSampling();
    await _restoreBrightness();
    try { await ScreenBrightness().setScreenBrightness(0.3); } catch (_) {}
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    var countdown = 10;
    var resumed = false;
    StateSetter? updateDialog;
    BuildContext? dialogContext;
    Timer? countdownTimer;
    Timer? vibrationTimer;
    StreamSubscription<PhoneFlipEvent>? sub;

    final alreadyFaceDown = await PhoneFlipService.isFaceDown();
    if (alreadyFaceDown) {
      _pickupDialogOpen = false;
      await _resumeAfterFlip();
      return;
    }

    // 启动中断时的“急促呼吸震动”
    if (state.settings.pom.alarmVibrate) {
      vibrationTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
        HapticFeedback.lightImpact();
      });
    }

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown--;
      if (countdown <= 0) {
        timer.cancel();
        if (dialogContext != null && mounted) {
          Navigator.of(dialogContext!, rootNavigator: true).pop();
        }
        return;
      }
      updateDialog?.call(() {});
    });

    sub = PhoneFlipService.events().listen((event) {
      if (event.type == PhoneFlipEventType.faceDown) {
        resumed = true;
        countdownTimer?.cancel();
        if (dialogContext != null && mounted) {
          Navigator.of(dialogContext!, rootNavigator: true).pop();
        }
      }
    });

    final tc = state.themeConfig;
    final acc = const Color(0xFFFF5252); // 玫瑰红 (Warning)
    final acc2 = const Color(0xFFD32F2F);
    
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.96),
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (ctx, anim, __) => StatefulBuilder(
        builder: (ctx, setSt) {
          dialogContext = ctx;
          updateDialog = setSt;
          return WillPopScope(
            onWillPop: () async => false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  children: [
                    // A. 背景：超级模糊层 + 噪点 + 冰块碎裂效果
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          child: CustomPaint(
                            painter: _IceCrackBackgroundPainter(
                              progress: 1.0 - (countdown / 10.0),
                              color: acc.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // B. 动态环境光球
                    GlassOrb(color: acc.withOpacity(0.12), alignment: const Alignment(-1.2, -0.8), size: 350),
                    GlassOrb(color: acc2.withOpacity(0.08), alignment: const Alignment(1.3, 0.7), size: 450),

                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            
                            // C. 核心状态容器：Liquid Glass + 弹射缩放动画
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) => Transform.scale(
                                scale: 0.85 + (0.15 * value),
                                child: Opacity(opacity: value.clamp(0, 1), child: child),
                              ),
                              child: OpticalGlassContainer(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                                borderColor: acc.withOpacity(0.3),
                                child: Column(
                                  children: [
                                    // 动态图标 + 倒计时
                                    _buildDisciplineIcon('📴', countdown, acc),
                                    
                                    const SizedBox(height: 40),
                                    
                                    // 标题
                                    Text(
                                      '已检测到拿起手机',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 28, 
                                        fontWeight: FontWeight.w200, 
                                        color: acc.withOpacity(0.9),
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // 描述
                                    Text(
                                      '请在 $countdown 秒内重新翻转手机，否则本轮专注将被取消',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16, 
                                        color: Colors.white.withOpacity(0.4),
                                        height: 1.6,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),

                                    // 液体注满动画 (Liquid Filling)
                                    const SizedBox(height: 40),
                                    _buildLiquidProgress(countdown / 10.0, acc),
                                  ],
                                ),
                              ),
                            ),
                            
                            const Spacer(),

                            // D. 底部优雅提示
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1200),
                              curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: child,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '轻触任意位置立即取消本轮专注',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: Colors.white.withOpacity(0.25),
                                      letterSpacing: 3.0,
                                      fontWeight: FontWeight.w200,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Icon(Icons.close_rounded, size: 24, color: Colors.white.withOpacity(0.3)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    vibrationTimer?.cancel();
    await sub.cancel();
    countdownTimer.cancel();
    _pickupDialogOpen = false;

    if (!mounted) return;
    if (resumed) {
      await _resumeAfterFlip();
      return;
    }
    await _cancelFocusSession();
  }

  @override
  void dispose() {
    _engine.phaseJustCompleted.removeListener(_onPhase);
    _engine.removeListener(_syncFlipMonitoring);
    _flipSub?.cancel();
    _restoreBrightness();
    _releaseScreenOn();
    _driftTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _onPhase() async {
    final state = context.read<AppState>();
    final mode  = state.engine.phaseJustCompleted.value;
    if (mode == null || !mounted) return;

    final pom = state.settings.pom;
    final isFocus = mode == PomMode.focus;

    // 1. Restore brightness to normal so user can see the alert
    await _restoreBrightness();
    // Re-apply a slightly higher brightness than 0.01 so the dialog is visible
    try { await ScreenBrightness().setScreenBrightness(0.3); } catch (_) {}

    // 2. Ring alarm via native channel
    try {
      await _alarmCh.invokeMethod('ring', {
        'sound': pom.alarmSound,
        'vibrate': pom.alarmVibrate,
        'persistent': pom.persistentVibrate,
      });
    } catch (_) {}

    // 3. Restore system UI (exit immersive mode temporarily)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 4. Show fullscreen alert dialog
    if (!mounted) return;
    final tc  = state.themeConfig;
    
    // 环境色适配：琥珀金 (Focus) / 冰川蓝 (Break)
    final acc = isFocus ? const Color(0xFFFFB300) : const Color(0xFF4FC3F7);
    final acc2 = isFocus ? const Color(0xFFE65100) : const Color(0xFF0277BD);
    
    int? ratingSelected;
    Timer? vibrationTimer;

    // 启动“呼吸式震动”
    if (pom.alarmVibrate && pom.persistentVibrate) {
      vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        HapticFeedback.vibrate();
      });
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.96),
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (ctx, anim, _) => StatefulBuilder(
        builder: (ctx, setSt) => WillPopScope(
          onWillPop: () async => false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.mediumImpact();
              if (ratingSelected != null) {
                FocusQualityService.rateLastSession(ratingSelected!);
              }
              Navigator.of(ctx).pop();
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  // A. 背景：超级模糊层 + 噪点纹理
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        child: CustomPaint(painter: _NoisePainter()),
                      ),
                    ),
                  ),
                  
                  // B. 动态环境光球
                  GlassOrb(color: acc.withOpacity(0.12), alignment: const Alignment(-1.2, -0.8), size: 350),
                  GlassOrb(color: acc2.withOpacity(0.08), alignment: const Alignment(1.3, 0.7), size: 450),

                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          
                          // C. 核心状态容器：Liquid Glass
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) => Transform.scale(
                              scale: 0.85 + (0.15 * value),
                              child: Opacity(opacity: value.clamp(0, 1), child: child),
                            ),
                            child: OpticalGlassContainer(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                              borderColor: acc.withOpacity(0.3),
                              child: Column(
                                children: [
                                  // 动态图标
                                  _buildPhaseIcon(isFocus, acc),
                                  
                                  const SizedBox(height: 40),
                                  
                                  // 标题与文字 (琥珀金/冰川蓝)
                                  Text(
                                    isFocus ? '专注完成！' : '休息结束！',
                                    style: TextStyle(
                                      fontSize: 32, 
                                      fontWeight: FontWeight.w200, 
                                      color: acc.withOpacity(0.9),
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // 描述
                                  Text(
                                    isFocus
                                        ? '本轮 ${pom.focusMins} 分钟已完成，好好休息一下'
                                        : '休息时间结束，准备好开始下一轮专注了吗？',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16, 
                                      color: Colors.white.withOpacity(0.4),
                                      height: 1.6,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const Spacer(),

                          // D. 评分交互区
                          if (isFocus && state.settings.focusQualityEnabled) ...[
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: child,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '这轮专注感觉怎么样？',
                                    style: TextStyle(
                                      fontSize: 15, 
                                      fontWeight: FontWeight.w300, 
                                      color: Colors.white.withOpacity(0.6),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: List.generate(5, (i) {
                                      final score = i + 1;
                                      const emojis = ['😩','😕','😐','😊','🔥'];
                                      final sel = ratingSelected == score;
                                      return GestureDetector(
                                        onTap: () {
                                          setSt(() => ratingSelected = score);
                                          HapticFeedback.lightImpact();
                                        },
                                        child: AnimatedScale(
                                          duration: const Duration(milliseconds: 300),
                                          scale: sel ? 1.3 : 1.0,
                                          curve: Curves.elasticOut,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 400),
                                            width: 56, height: 64,
                                            decoration: BoxDecoration(
                                              color: sel ? acc.withOpacity(0.2) : Colors.white.withOpacity(0.03),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: sel ? acc.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                                                width: sel ? 1.5 : 0.8,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(emojis[i], style: const TextStyle(fontSize: 28)),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const Spacer(flex: 2),
                          
                          // E. 底部提示
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1200),
                            curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: child,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.white.withOpacity(0.3)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '轻触任意处继续',
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: Colors.white.withOpacity(0.25),
                                    letterSpacing: 4.0,
                                    fontWeight: FontWeight.w200,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    vibrationTimer?.cancel();
    // Dialog closed: stop alarm, re-apply extreme dim brightness, re-enter immersive
    try { await _alarmCh.invokeMethod('stop'); } catch (_) {}
    if (mounted) {
      await _applyDimBrightness();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _exit() async {
    HapticFeedback.lightImpact();
    // Restore brightness BEFORE popping
    await _restoreBrightness();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildDisciplineIcon(String icon, int countdown, Color core) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 背景扩散圆
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, value, child) => Container(
            width: 116 * value, height: 116 * value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: core.withOpacity(0.1 * (1.5 - value)),
            ),
          ),
        ),
        Container(
          width: 116, height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [core.withOpacity(0.3), core.withOpacity(0.05)],
            ),
            border: Border.all(color: core.withOpacity(0.4), width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 46)),
              Positioned(
                right: 10, top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: core.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$countdown',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseIcon(bool isFocus, Color acc) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 背景扩散圆
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, value, child) => Container(
            width: 100 * value, height: 100 * value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: acc.withOpacity(0.1 * (1.5 - value)),
            ),
          ),
        ),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [acc.withOpacity(0.3), acc.withOpacity(0.05)],
            ),
            border: Border.all(color: acc.withOpacity(0.4), width: 1.5),
          ),
          child: Center(
            child: Text(
              isFocus ? '✨' : '☕',
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
      ],
    );
  }

  /// 专注干扰警告 (针对娱乐 App 拦截)
  Widget _buildDistractionAlert({
    required String appName,
    required Color accent,
    required VoidCallback onDismiss,
  }) {
    return OpticalGlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDistractionIcon(accent),
          const SizedBox(height: 32),
          Text(
            '正在检测到干扰',
            style: const TextStyle(
              fontSize: 26, 
              fontWeight: FontWeight.w900, 
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '你正在使用 $appName，这会中断你的专注。请立即返回专注！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16, 
              color: Colors.white.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onDismiss,
            child: OpticalGlassContainer(
              borderRadius: 20,
              opacity: 0.1,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              borderColor: accent.withOpacity(0.3),
              child: Text(
                '我知道了',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistractionIcon(Color core) {
    return Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
          builder: (context, value, child) => Container(
            width: 100 * value, height: 100 * value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: core.withOpacity(0.15 * (1.5 - value)),
            ),
          ),
        ),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [core.withOpacity(0.4), core.withOpacity(0.1)],
            ),
            border: Border.all(color: core.withOpacity(0.5), width: 2),
          ),
          child: Center(
            child: Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pom = context.read<AppState>().engine;
    return ListenableBuilder(
      listenable: pom,
      builder: (context, _) {
    final m = pom.secsLeft ~/ 60;
    final s = pom.secsLeft % 60;
    final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final isFocus = pom.mode == PomMode.focus;
    final disciplineMode = pomDisciplineModeFromKey(state.settings.pom.disciplineMode);
    final rawBase = isFocus
        ? const Color(0xFFE07040)
        : const Color(0xFF4A90C0);
    final baseColor = switch (disciplineMode) {
      PomDisciplineMode.strict => Color.lerp(rawBase, const Color(0xFFFF8A65), 0.18)!,
      PomDisciplineMode.semiStrict => Color.lerp(rawBase, const Color(0xFFA884FF), 0.16)!,
      PomDisciplineMode.normal => rawBase,
    };

    return GestureDetector(
      onTap: _ambientLocked ? null : _exit,
      child: Scaffold(
        // Force pure black background for AOD mode
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, __) {
            // Adjust glow and text opacity for extreme dark mode
            final glowIntensity = 0.45 + _glowCtrl.value * 0.20;
            final ringColor = baseColor.withOpacity(glowIntensity);
            final textColor = Colors.white.withOpacity(0.60 + _glowCtrl.value * 0.15);

            // Check ambient fx beta flag
            final ambientFxOn = betaAmbientFx(state.settings);

            return Stack(children: [
              // ── Ambient special effects (β) ──────────────────────────
              if (ambientFxOn)
                Positioned.fill(child: CustomPaint(
                  painter: _AmbientFxPainter(
                    progress: _glowCtrl.value,
                    isFocus: isFocus,
                    baseColor: baseColor),
                )),
              // Full-screen tap area (pure black)
              Positioned.fill(child: Container(color: Colors.black)),

              // Center content with burn-in drift
              AnimatedPositioned(
                duration: const Duration(seconds: 60),
                curve: Curves.linear,
                left: MediaQuery.of(context).size.width / 2 - 110 + _driftX,
                top: MediaQuery.of(context).size.height / 2 - 150 + _driftY,
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phase label
                    Text(
                      pom.mode == PomMode.focus
                          ? '专注'
                          : pom.mode == PomMode.longBreak ? '长休息' : '休息',
                      style: TextStyle(
                        fontSize: 14,
                        color: ringColor.withOpacity(0.5),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glowing ring (slightly dimmer)
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: _AmbientRingPainter(
                        progress: pom.progress,
                        color: ringColor,
                        glowIntensity: glowIntensity * 0.7,
                      ),
                      child: SizedBox(
                        width: 220, height: 220,
                        child: Center(
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w200,
                              color: textColor,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(
                                  color: ringColor.withOpacity(glowIntensity * 0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Cycle indicator dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        state.settings.pom.longBreakInterval,
                        (i) => Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < pom.focusRoundsSinceLongBreak
                                ? ringColor.withOpacity(0.7)
                                : Colors.white.withOpacity(0.05),
                            boxShadow: i < pom.focusRoundsSinceLongBreak
                                ? [BoxShadow(color: ringColor.withOpacity(0.4), blurRadius: 4)]
                                : null,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Hint text (very dim)
                    Text(
                      _ambientLocked ? '翻回正面可打断本轮专注' : '轻触任意处退出',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.12),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
      }, // ListenableBuilder builder
    ); // ListenableBuilder
  }
}

class _AmbientDisciplineHero extends StatelessWidget {
  final String icon;
  final int countdown;
  final Color accent;
  final Color accent2;
  final String title;
  final String subtitle;

  const _AmbientDisciplineHero({
    required this.icon,
    required this.countdown,
    required this.accent,
    required this.accent2,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final core = Color.lerp(accent, accent2, 0.45)!;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // 背景扩散圆
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Container(
                width: 116 * value, height: 116 * value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: core.withOpacity(0.1 * (1.5 - value)),
                ),
              ),
            ),
            Container(
              width: 116, height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [core.withOpacity(0.3), core.withOpacity(0.05)],
                ),
                border: Border.all(color: core.withOpacity(0.4), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 46)),
                  Positioned(
                    right: 10, top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: core.withOpacity(0.4)),
                      ),
                      child: Text(
                        '$countdown',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: Colors.white.withOpacity(0.78),
          ),
        ),
      ],
    );
  }
}

class _AmbientRingPainter extends CustomPainter {
  final double progress, glowIntensity;
  final Color color;
  _AmbientRingPainter({
    required this.progress,
    required this.color,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2 - 12;
    const startAngle = -pi / 2;

    // Track (very dim)
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = color.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (progress <= 0) return;

    // Outer glow layers
    for (final pair in [
      (color.withOpacity(0.05 * glowIntensity), 18.0),
      (color.withOpacity(0.10 * glowIntensity), 10.0),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, progress * 2 * pi, false,
        Paint()
          ..color = pair.$1
          ..style = PaintingStyle.stroke
          ..strokeWidth = pair.$2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Main arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, progress * 2 * pi, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Leading dot glow
    final angle = startAngle + progress * 2 * pi;
    final dotX = cx + r * cos(angle);
    final dotY = cy + r * sin(angle);
    canvas.drawCircle(
      Offset(dotX, dotY), 7,
      Paint()..color = color.withOpacity(0.3 * glowIntensity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(Offset(dotX, dotY), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AmbientRingPainter o) =>
      o.progress != progress || o.glowIntensity != glowIntensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// β 息屏特效 Painter — 烛光粒子 + 流星 + 光晕呼吸
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientFxPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0 looping
  final bool isFocus;
  final Color baseColor;

  static final _rng = Random(7);
  // Candle embers — 40 particles
  static final _embers = List.generate(40, (i) => (
    x: _rng.nextDouble(),
    y: _rng.nextDouble(),
    size: 1.0 + _rng.nextDouble() * 3.0,
    speed: 0.12 + _rng.nextDouble() * 0.28,
    phase: _rng.nextDouble(),
    wobble: (_rng.nextDouble() - 0.5) * 0.06,
  ));
  // Shooting stars — 5 objects
  static final _stars = List.generate(5, (i) => (
    startX: _rng.nextDouble(),
    startY: _rng.nextDouble() * 0.5,
    angle: 0.3 + _rng.nextDouble() * 0.5,
    speed: 0.35 + _rng.nextDouble() * 0.4,
    phase: _rng.nextDouble(),
    len: 0.06 + _rng.nextDouble() * 0.10,
  ));

  _AmbientFxPainter({
    required this.progress,
    required this.isFocus,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Subtle ambient glow at bottom ────────────────────────────────────────
    final glowColor = isFocus ? const Color(0xFFE07040) : const Color(0xFF4A90C0);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.2),
        radius: 0.8,
        colors: [
          glowColor.withOpacity(0.10 + 0.05 * (0.5 + 0.5 * sin(progress * 2 * pi))),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // ── Candle embers (focus) / Snowflake motes (break) ──────────────────────
    for (final e in _embers) {
      final t = (progress * e.speed + e.phase) % 1.0;
      final x = (e.x + e.wobble * sin(t * 2 * pi)) * size.width;
      final y = size.height - t * (size.height + 20) - 10;
      if (y < -10 || y > size.height + 10) continue;
      final alpha = sin(t * pi).clamp(0.0, 1.0);
      final emberColor = isFocus
          ? Color.lerp(glowColor, const Color(0xFFFFDD88), alpha)!
              .withOpacity(0.55 * alpha)
          : Colors.white.withOpacity(0.30 * alpha);
      canvas.drawCircle(
          Offset(x, y),
          e.size * (0.5 + alpha * 0.5),
          Paint()
            ..color = emberColor
            ..maskFilter = alpha > 0.3 ? const MaskFilter.blur(BlurStyle.normal, 3) : null);
    }

    // ── Shooting stars ────────────────────────────────────────────────────────
    for (final star in _stars) {
      final t = (progress * star.speed + star.phase) % 1.0;
      if (t > 0.6) continue; // Only visible 60% of cycle
      final alpha = sin((t / 0.6) * pi).clamp(0.0, 1.0);
      final sx = (star.startX + cos(star.angle) * t * 0.6) * size.width;
      final sy = (star.startY + sin(star.angle) * t * 0.6) * size.height;
      final ex = sx - cos(star.angle) * star.len * size.width;
      final ey = sy - sin(star.angle) * star.len * size.height;
      final starPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9 * alpha),
            Colors.white.withOpacity(0),
          ],
        ).createShader(Rect.fromPoints(Offset(sx, sy), Offset(ex, ey)))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), starPaint);
      // Star head dot
      canvas.drawCircle(Offset(sx, sy), 2.0, Paint()..color = Colors.white.withOpacity(0.9 * alpha));
    }
  }

  @override
  bool shouldRepaint(_AmbientFxPainter o) => o.progress != progress;
}

class _IceCrackBackgroundPainter extends CustomPainter {
  final double progress;
  final Color color;
  _IceCrackBackgroundPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final painter = IceCrackPainter(progress: progress, color: color);
    painter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 噪点纹理绘制
class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.015);
    final rand = Random();
    for (int i = 0; i < 1000; i++) {
      canvas.drawCircle(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
        0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

Widget _buildLiquidProgress(double progress, Color color) {
  return Container(
    height: 6,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(3),
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: progress.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.4), color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 1),
          ],
        ),
      ),
    ),
  );
}
