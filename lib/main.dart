// lib/main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'widgets/liquid_glass_refractor.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'models/models.dart';
import 'providers/app_state.dart';
import 'services/pom_engine.dart';
import 'theme/app_theme.dart';
import 'l10n/l10n.dart';
import 'screens/today_screen.dart';
import 'screens/search_screen.dart';
import 'services/festival_calendar.dart';
import 'screens/quadrant_screen.dart';
import 'screens/stats_screen_new.dart';
import 'screens/pomodoro_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'services/distraction_detector.dart';
import 'widgets/sun_arc_clock.dart';
import 'widgets/timeline_clock.dart';
import 'widgets/date_clock.dart';
import 'services/crash_logger.dart';
import 'services/weather_service.dart';
import 'widgets/global_wallpaper_layer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // CrashLogger 最早初始化，拦截后续所有异常
  await CrashLogger.init();
  CrashLogger.action('App', 'main() — App starting');

  // ✅ 初始化国际化系统
  await L.init('zh');
  CrashLogger.info('App', 'i18n system initialized');

  // 允许竖屏+横屏，不强制锁定方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await NotificationService.init();
  CrashLogger.info('App', 'NotificationService initialized');
  // Init distraction detector with the notification plugin
  DistractionDetector.init(NotificationService.plugin);

  runApp(ChangeNotifierProvider(
    create: (_) => AppState()..load(),
    child: const LiuShuiZhangApp(),
  ));
}

class LiuShuiZhangApp extends StatelessWidget {
  const LiuShuiZhangApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // ✅ 改进：使用新的i18n系统
    L.setLanguage(state.settings.lang);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final s = state.settings;
        final systemBrightness = MediaQuery.platformBrightnessOf(context);
        final isDark = s.followSystemTheme && systemBrightness == Brightness.dark;

        // Pick which named theme config to use for our custom widgets
        final activeThemeName = isDark ? s.darkTheme : s.theme;

        ThemeData lightTheme;
        ThemeData? darkThemeData;

        if (s.dynamicColor && lightDynamic != null) {
          lightTheme  = _buildDynamicTheme(lightDynamic, Brightness.light);
          darkThemeData = darkDynamic != null
              ? _buildDynamicTheme(darkDynamic, Brightness.dark)
              : _buildDynamicTheme(lightDynamic, Brightness.dark);
          final dynScheme = isDark && darkDynamic != null ? darkDynamic : lightDynamic;
          final dynTc = _schemeToThemeConfig(dynScheme, isDark);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.setDynamicThemeConfig(dynTc);
            state.setResolvedThemeName(activeThemeName);
          });
        } else {
          lightTheme = AppTheme.themeData(activeThemeName);
          darkThemeData = s.followSystemTheme
              ? AppTheme.themeData(s.darkTheme)
              : null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.setDynamicThemeConfig(null);
            state.setResolvedThemeName(activeThemeName);
          });
        }

        return MaterialApp(
          title: 'Mindless',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkThemeData,
          themeMode: s.followSystemTheme ? ThemeMode.system : ThemeMode.light,
          builder: (context, child) =>
              GlobalWallpaperLayer(child: child ?? const SizedBox.shrink()),
          home: const MainShell(),
        );
      },
    );
  }

  ThemeData _buildDynamicTheme(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg   = isDark ? const Color(0xFF181E1B) : scheme.surface;
    final card = isDark ? const Color(0xFF232B27) : scheme.surfaceContainerHighest;
    final tx   = scheme.onSurface;
    final ts   = scheme.onSurface.withOpacity(0.60);
    final brd  = scheme.outlineVariant;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(brightness: brightness),
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      fontFamily: 'serif',
      appBarTheme: AppBarTheme(backgroundColor: bg, elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(fontFamily: 'serif', color: tx,
              fontSize: 20, fontWeight: FontWeight.w700)),
      cardTheme: CardThemeData(color: card, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          hintStyle: TextStyle(color: ts, fontSize: 14)),
      dividerTheme: DividerThemeData(color: brd, space: 1, thickness: 1),
    );
  }

  /// Convert a Material You ColorScheme into our ThemeConfig so custom widgets
  /// use the correct palette when dynamic color is active.
  ThemeConfig _schemeToThemeConfig(ColorScheme sc, bool isDark) {
    int c(Color col) => col.value;
    final bg   = isDark ? const Color(0xFF181E1B) : sc.surface;
    final card = isDark ? const Color(0xFF232B27) : sc.surfaceContainerHighest;
    final nb   = isDark ? const Color(0xFF1E2822) : sc.surfaceContainerHigh;
    final cb   = isDark ? const Color(0xFF252F2A) : sc.surfaceContainerLow;
    final brd  = isDark ? const Color(0xFF2A3630) : sc.outlineVariant;
    return ThemeConfig(
      name: 'dynamic',
      bg: c(bg), card: c(card),
      tx: c(sc.onSurface),
      ts: c(sc.onSurface.withOpacity(0.60)),
      tm: c(sc.onSurface.withOpacity(0.40)),
      acc: c(sc.primary), acc2: c(sc.secondary),
      nb: c(nb), na: c(sc.primary), nt: c(sc.onPrimary),
      brd: c(brd), pb: c(cb), cb: c(cb),
      ct: c(sc.onSurface.withOpacity(0.55)),
      tagColors: [
        c(sc.primary), c(sc.secondary), c(sc.tertiary),
        c(sc.primaryContainer), c(sc.secondaryContainer), c(sc.tertiaryContainer),
        c(sc.primary.withOpacity(0.7)), c(sc.secondary.withOpacity(0.7)),
      ],
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _tab = 0;
  int _prevTab = 0;
  bool _notifRequested = false;
  Timer? _rolloverTimer;
  String _lastAppDate = '';
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lastAppDate = AppState.appDateKey(DateTime.now());
    _rolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final newDate = AppState.appDateKey(DateTime.now());
      if (newDate != _lastAppDate) {
        _lastAppDate = newDate;
        if (mounted) context.read<AppState>().refreshUi();
      }
    });
    // Register global pomodoro tab switch callback
    AppState.switchToPomodoroTab = () {
      if (!mounted) return;
      final state = context.read<AppState>();
      final pomIdx = state.settings.showPomodoro ? 3 : -1;
      if (pomIdx >= 0) _switchTab(pomIdx);
    };
    // Catch up pomodoro timer after screen-on / app resume
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (mounted) context.read<AppState>().pomCatchUp();
      },
    );
    // Start weather service (starts API polling + respects pinned setting)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<AppState>().settings;
      // 内嵌和风天气凭据，city为空时不拉取但常驻效果仍有效
      // betaWeather=false 时关闭粒子叠加层；city有值时始终尝试获取实时天气
      WeatherService.start(
        s.weatherApiKey,
        s.weatherCity.isNotEmpty ? s.weatherCity : '北京',
        s.pinnedWeatherEffect,
        jwtSecret: s.weatherJwtSecret,
        jwtKid:    s.weatherJwtKid,
        jwtSub:    s.weatherJwtSub,
        apiHost:   s.weatherApiHost,
        onUpdate: (_) { if (mounted) setState(() {}); },
      );
      // One-time noise consent dialog (shown once after update)
      final appState = context.read<AppState>();
      if (!appState.settings.noiseConsentShown) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) _showNoiseConsentDialog(context);
        });
      }
    });
  }

  void _showNoiseConsentDialog(BuildContext ctx) {
    final state = context.read<AppState>();
    final tc = state.themeConfig;
    final acc = Color(tc.acc);
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Color(tc.card),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎙', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text('番茄钟环境声分析',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: Color(tc.tx))),
          const SizedBox(height: 10),
          Text(
            '流水账可以在番茄钟专注期间自动采集环境分贝数据，'
            '分析噪音环境对专注效率的影响。\n\n'
            '数据仅存储在本机，不会上传。'
            '需要麦克风权限（仅采集分贝，不录制或存储语音内容）。\n\n'
            '是否允许番茄钟自动环境声采样？',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(tc.ts), height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  state.markNoiseConsentShown(false);
                  Navigator.pop(dCtx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Color(tc.brd).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('不允许', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(tc.tm))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  state.markNoiseConsentShown(true);
                  Navigator.pop(dCtx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: acc,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: acc.withOpacity(0.35),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Text('允许', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _rolloverTimer?.cancel();
    _lifecycleListener?.dispose();
    AppState.switchToPomodoroTab = null;
    WeatherService.stop();
    super.dispose();
  }

  void _switchTab(int idx) {
    CrashLogger.tap('NavTab', 'tab $idx (from $_tab)');
    if (idx == _tab) return;
    HapticFeedback.selectionClick();
    setState(() { _prevTab = _tab; _tab = idx; });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_notifRequested) {
      _notifRequested = true;
      Future.delayed(const Duration(seconds: 2),
          () => NotificationService.requestPermission());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final showPom = state.settings.showPomodoro;

    final screens = [
      const TodayScreen(),
      const QuadrantScreen(),
      const StatsScreenNew(),   // β Bento UI 升为默认美术
      if (showPom) const PomodoroScreen(),
    ];
    final effectiveTab = _tab.clamp(0, screens.length - 1);
    final pending = state.pendingCount;
    final total = state.tasks.length;

    // Pomodoro tab index (3 if shown, -1 if hidden)
    final pomTabIdx = showPom ? 3 : -1;
    final pomRunning = state.engine.running;
    final showBanner = pomRunning && effectiveTab != pomTabIdx && showPom;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // ── Landscape layout ────────────────────────────────────────────────────
    if (isLandscape) {
      final hasWall = state.showsGlobalWallpaper;
      return Scaffold(
        backgroundColor: hasWall ? Colors.transparent : Color(tc.bg),
        body: SafeArea(
          child: Row(children: [
            // Left rail nav
            _buildRailNav(tc, showPom, effectiveTab),
            // Main content column
            Expanded(child: Column(children: [
              // ── Slim top bar (replaces full AppBar in landscape) ──────
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                color: hasWall ? state.chromeBarColor(tc) : Color(tc.bg),
                child: Row(children: [
                  Text(state.settings.appName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        fontFamily: 'serif', color: Color(tc.tx))),
                  const SizedBox(width: 10),
                  if (total > 0) ...[
                    Text('$pending', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(tc.acc))),
                    Text(' / $total', style: TextStyle(
                        fontSize: 13, color: Color(tc.tx))),
                    const SizedBox(width: 8),
                    if (total > 0)
                      SizedBox(width: 80,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0,
                              end: total > 0 ? (total - pending) / total : 0.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => LinearProgressIndicator(
                            value: v,
                            backgroundColor: Color(tc.pb),
                            color: Color(tc.acc),
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(2)))),
                  ],
                  const Spacer(),
                  if (showBanner)
                    Expanded(
                      child: _PomBanner(
                          pom: state.engine, tc: tc,
                          onTap: () => _switchTab(pomTabIdx))),
                  if (!showBanner) const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Navigator.push(context, PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 340),
                      pageBuilder: (_, __, ___) => ChangeNotifierProvider.value(
                        value: context.read<AppState>(),
                        child: const SettingsScreen()),
                      transitionsBuilder: (_, anim, __, child) {
                        final cv = CurvedAnimation(parent: anim,
                            curve: Curves.easeInOutCubic);
                        return FadeTransition(opacity: cv,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero).animate(cv),
                            child: child));
                      })),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Icon(Icons.settings_outlined,
                          size: 18, color: Color(tc.ts)))),
                  // Search button (landscape)
                  GestureDetector(
                    onTap: () => showGlobalSearch(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Icon(Icons.search_rounded,
                          size: 18, color: Color(tc.ts)))),
                ])),
              // Thin progress line
              if (total > 0)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0,
                      end: total > 0 ? (total - pending) / total : 0.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v, backgroundColor: Colors.transparent,
                    color: Color(tc.acc).withOpacity(0.4),
                    minHeight: 1.5)),
              // Screen content
              Expanded(child: _TabBody(
                index: effectiveTab,
                prevIndex: _prevTab,
                children: screens,
              )),
            ])),
          ]),
        ),
      );
    }

    // ── Portrait layout (original) ──────────────────────────────────────────
    // ── 自动节日主题：节日当天且开关开启时，自动切换主题 ─────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.settings.autoFestivalTheme) {
        final todayFestival = getTodayFestival();
        if (todayFestival != null &&
            state.settings.theme != todayFestival.id) {
          state.setTheme(todayFestival.id);
        }
      }
    });

    final hasWall = state.showsGlobalWallpaper;

    // ── 玻璃效果：壁纸由 MaterialApp.builder 里 [GlobalWallpaperLayer] 全局铺设。
    //   无壁纸：Scaffold 实色背景。
    //   有壁纸：Scaffold 透明；卡片等仍用 AppState.cardColor（globalOpacity）；
    //   顶栏/底栏用 chromeBarColor / chromeNavBarColor（globalOpacity × topChromeOpacity）。

    final uiContent = Scaffold(
      backgroundColor: hasWall ? Colors.transparent : Color(tc.bg),
      extendBody: true, // Allow content to bleed under bottom bar
      extendBodyBehindAppBar: true, // Allow content to bleed under top bar
      appBar: _buildAppBar(state, tc, pending, total),
      body: Column(
        children: [
          // Banner needs a bit of spacing if appbar is floating
          const SizedBox(height: 10),
          // ── In-app pomodoro banner ─────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: showBanner
                ? _PomBanner(
                    pom: state.engine,
                    tc: tc,
                    onTap: () => _switchTab(pomTabIdx),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _TabBody(
              index: effectiveTab,
              prevIndex: _prevTab,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(tc, showPom, effectiveTab),
    );

    return uiContent;
  }

  Widget _clockWidget(String style) {
    switch (style) {
      case 'timeline': return const TimelineClock();
      case 'date':     return const DateClock();
      default:         return const SunArcClock();
    }
  }

  PreferredSizeWidget _buildAppBar(AppState state, ThemeConfig tc, int pending, int total) {
    final pct = total > 0 ? (total - pending) / total : 0.0;
    final clockStyle = state.settings.clockStyle;
    final showClock = state.settings.showTopClock;
    final topPad = MediaQuery.of(context).padding.top;

    // Adaptive height based on clock visibility
    final barHeight = showClock ? 78.0 : 46.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(topPad + barHeight + 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: LiquidGlassRefractor(
          borderRadius: 45.0, // 严格遵循边缘曲率参数
          baseColor: state.chromeBarColor(tc),
          intensity: state.settings.glassEffectIntensity,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clock widget (swappable) - only if enabled
                if (showClock)
                  GestureDetector(
                    onTap: () {
                      const styles = ['date', 'sunArc', 'timeline'];
                      final cur = styles.indexOf(clockStyle);
                      state.setClockStyle(styles[(cur + 1) % styles.length]);
                    },
                    child: _clockWidget(clockStyle),
                  ),
                // App name + counters + settings button
                Padding(
                  padding: EdgeInsets.fromLTRB(16, showClock ? 0 : 6, 10, showClock ? 6 : 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: Text(state.settings.appName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'serif'),
                      overflow: TextOverflow.ellipsis)),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '$pending', style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700, color: Color(tc.acc))),
                      TextSpan(text: ' / $total', style: TextStyle(fontSize: 13, color: Color(tc.tx))),
                    ])),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: Icon(Icons.search_rounded, color: Color(tc.ts), size: 19),
                      padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
                      onPressed: () => showGlobalSearch(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: Color(tc.ts), size: 19),
                      padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
                      onPressed: () => Navigator.push(context, PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 340),
                        pageBuilder: (_, __, ___) => ChangeNotifierProvider.value(
                          value: context.read<AppState>(), child: const SettingsScreen()),
                        transitionsBuilder: (_, anim, __, child) {
                          final c = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
                          return FadeTransition(opacity: c,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(c),
                              child: child));
                        },
                      )),
                    ),
                  ]),
                ),
                // Progress bar
                if (total > 0)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 500), curve: Curves.easeOut,
                    builder: (_, v, __) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: LinearProgressIndicator(value: v, backgroundColor: Color(tc.pb).withOpacity(0.3),
                        color: Color(tc.acc), minHeight: 2,
                        borderRadius: BorderRadius.circular(1)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(ThemeConfig tc, bool showPom, int effectiveTab) {
    final state = context.watch<AppState>();
    final pomRunning = state.engine.running;
    final isFocusMode = pomRunning && state.engine.mode == PomMode.focus;
    final isBreakMode = pomRunning && state.engine.mode != PomMode.focus;
    final capColor = isFocusMode ? Color(tc.acc)
        : isBreakMode ? Color(tc.acc2)
        : Color(tc.na);
    final capTextColor = isFocusMode || isBreakMode ? Color(tc.nt) : Color(tc.nt);

    IconData getIcon(IconData normal, IconData special) {
      return state.settings.theme == 'black_hole' ? special : normal;
    }

    final items = [
      (
        icon: getIcon(Icons.today_outlined, Icons.explore_outlined),
        active: getIcon(Icons.today, Icons.explore),
        label: L.today
      ),
      (
        icon: getIcon(Icons.grid_view_outlined, Icons.radar_outlined),
        active: getIcon(Icons.grid_view, Icons.radar),
        label: L.quadrant
      ),
      (
        icon: getIcon(Icons.bar_chart_outlined, Icons.auto_awesome_outlined),
        active: getIcon(Icons.bar_chart, Icons.auto_awesome),
        label: L.stats
      ),
      if (showPom)
        (
          icon: getIcon(Icons.timer_outlined, Icons.bolt_outlined),
          active: getIcon(Icons.timer, Icons.bolt),
          label: L.pomodoro
        ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Floating above bottom edge
        child: LiquidGlassRefractor(
          borderRadius: 45.0, // 严格遵循边缘曲率参数
          baseColor: state.chromeNavBarColor(tc),
          intensity: state.settings.glassEffectIntensity,
          child: SizedBox(
            height: 64,
            child: Row(children: items.asMap().entries.map((e) {
              final i = e.key; final item = e.value; final active = effectiveTab == i;
              return Expanded(child: GestureDetector(
                onTap: () => _switchTab(i),
                behavior: HitTestBehavior.opaque,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: active ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  builder: (_, v, __) {
                    final pillColor = active && pomRunning ? capColor : Color(tc.na);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        decoration: BoxDecoration(
                          color: active ? pillColor.withOpacity(v) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(active ? item.active : item.icon, size: 22,
                            color: Color.lerp(Color(tc.ts), active && pomRunning ? capTextColor : Color(tc.nt), v)!),
                          // Label slides in when active
                          ClipRect(
                            child: AnimatedAlign(
                              alignment: Alignment.centerLeft,
                              widthFactor: active ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6, right: 4),
                                child: Text(item.label, style: TextStyle(
                                  fontSize: 12,
                                  color: Color.lerp(Color(tc.ts), active && pomRunning ? capTextColor : Color(tc.nt), v),
                                  fontWeight: FontWeight.w700),
                                  maxLines: 1, softWrap: false),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ));
            }).toList()),
          ),
        ),
      ),
    );
  }

  // ── Landscape side rail navigation ──────────────────────────────────────
  Widget _buildRailNav(ThemeConfig tc, bool showPom, int effectiveTab) {
    final state = context.watch<AppState>();
    final pomRunning = state.engine.running;
    final isFocusMode = pomRunning && state.engine.mode == PomMode.focus;
    final isBreakMode = pomRunning && state.engine.mode != PomMode.focus;
    final capColor = isFocusMode ? Color(tc.acc)
        : isBreakMode ? Color(tc.acc2) : Color(tc.na);

    IconData getIcon(IconData normal, IconData special) {
      return state.settings.theme == 'black_hole' ? special : normal;
    }

    final items = [
      (
        icon: getIcon(Icons.today_outlined, Icons.explore_outlined),
        active: getIcon(Icons.today, Icons.explore),
        label: L.today
      ),
      (
        icon: getIcon(Icons.grid_view_outlined, Icons.radar_outlined),
        active: getIcon(Icons.grid_view, Icons.radar),
        label: L.quadrant
      ),
      (
        icon: getIcon(Icons.bar_chart_outlined, Icons.auto_awesome_outlined),
        active: getIcon(Icons.bar_chart, Icons.auto_awesome),
        label: L.stats
      ),
      if (showPom)
        (
          icon: getIcon(Icons.timer_outlined, Icons.bolt_outlined),
          active: getIcon(Icons.timer, Icons.bolt),
          label: L.pomodoro
        ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          width: 64,
          decoration: BoxDecoration(
            color: state.chromeRailNavColor(tc),
            border: Border(right: BorderSide(
              color: pomRunning ? capColor.withOpacity(0.3) : Color(tc.brd).withOpacity(0.4),
              width: 1)),
            boxShadow: [BoxShadow(
              color: capColor.withOpacity(pomRunning ? 0.18 : 0.06),
              blurRadius: pomRunning ? 18 : 8)],
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            ...items.asMap().entries.map((e) {
              final i = e.key; final item = e.value;
              final active = effectiveTab == i;
              return GestureDetector(
                onTap: () => _switchTab(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 52, height: 52,
                  margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? (pomRunning ? capColor : Color(tc.na)).withOpacity(0.85)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(active ? item.active : item.icon, size: 22,
                      color: active ? Color(tc.nt) : Color(tc.ts)),
                    const SizedBox(height: 2),
                    Text(item.label, style: TextStyle(
                      fontSize: 9,
                      color: active ? Color(tc.nt) : Color(tc.ts),
                      fontWeight: active ? FontWeight.w700 : FontWeight.normal),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }
}

// ── In-app Pomodoro Banner ────────────────────────────────────────────────────
// Shows at the top of the body when a pomodoro is running and the user is on
// another tab. Ticks every second. Tapping navigates to the pomodoro tab.
class _PomBanner extends StatefulWidget {
  final PomEngine pom;
  final ThemeConfig tc;
  final VoidCallback onTap;
  const _PomBanner({required this.pom, required this.tc, required this.onTap});

  @override
  State<_PomBanner> createState() => _PomBannerState();
}

class _PomBannerState extends State<_PomBanner> {
  Timer? _ticker;
  int _secsLeft = 0;

  @override
  void initState() {
    super.initState();
    _secsLeft = widget.pom.secsLeft;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secsLeft = widget.pom.secsLeft;
      });
    });
  }

  @override
  void didUpdateWidget(_PomBanner old) {
    super.didUpdateWidget(old);
    _secsLeft = widget.pom.secsLeft;
  }

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  String get _timeStr {
    final m = _secsLeft ~/ 60;
    final s = _secsLeft % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  String get _phaseLabel {
    switch (widget.pom.mode) {
      case PomMode.focus:      return '🍅 专注中';
      case PomMode.shortBreak: return '☕ 短休息';
      case PomMode.longBreak:  return '🛋 长休息';
    }
  }

  Color get _accentColor {
    final tc = widget.tc;
    return widget.pom.mode == PomMode.focus
        ? Color(tc.acc)
        : Color(tc.acc2);
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final accent = _accentColor;
    final progress = widget.pom.progress;
    final isFocus = widget.pom.mode == PomMode.focus;

    // 任务名（从 AppState 查）
    final taskId = widget.pom.selTaskId;
    final String? taskName = taskId != null
        ? context.read<AppState>().tasks
            .where((t) => t.id == taskId)
            .map((t) => t.text)
            .firstOrNull
        : null;
    final hasTask = taskName != null && taskName.isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
        height: 48,
        decoration: BoxDecoration(
          color: Color(tc.nb),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
          boxShadow: [BoxShadow(
            color: accent.withOpacity(0.20),
            blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(children: [
          // 进度条（左侧竖条）
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.linear,
            width: 4,
            height: 48,
            color: accent,
          ),
          const SizedBox(width: 10),
          // 状态图标
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.12)),
            child: Icon(
              isFocus ? Icons.timer_rounded : Icons.coffee_rounded,
              size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          // 主信息列
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(_phaseLabel.replaceAll(RegExp(r'^[^ ]+ '), ''),
                  style: TextStyle(fontSize: 10,
                    color: Color(tc.ts), fontWeight: FontWeight.w500)),
                if (hasTask) ...[
                  Text(' · ', style: TextStyle(fontSize: 9, color: Color(tc.tm))),
                  Flexible(child: Text(
                    taskName.length > 12 ? '${taskName.substring(0,12)}…' : taskName,
                    style: TextStyle(fontSize: 10, color: Color(tc.ts)),
                    overflow: TextOverflow.ellipsis)),
                ],
              ]),
              // 进度条（横向）
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Color(tc.brd),
                  color: accent,
                  minHeight: 3)),
            ],
          )),
          const SizedBox(width: 8),
          // 时间
          Text(_timeStr, style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800,
            color: Color(tc.tx),
            fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 10),
          Icon(Icons.keyboard_arrow_right_rounded, size: 18,
              color: Color(tc.tm)),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

// ── Tab body: IndexedStack + fade so widgets are NEVER destroyed ──────────────
// Using AnimatedSwitcher with KeyedSubtree was destroying PomodoroScreen on
// every tab switch, causing its AnimationControllers and onPomPhaseDone
// callback to be disposed mid-session → crash when the timer fired.
// IndexedStack keeps all screens mounted; only their opacity/offstage changes.
class _TabBody extends StatefulWidget {
  final int index;
  final int prevIndex;
  final List<Widget> children;
  const _TabBody({required this.index, required this.prevIndex,
      required this.children});
  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  int _displayIndex = 0;

  @override
  void initState() {
    super.initState();
    _displayIndex = widget.index;
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 180));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_TabBody old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      _ctrl.reverse().then((_) {
        if (mounted) setState(() => _displayIndex = widget.index);
        _ctrl.forward();
      });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: IndexedStack(
        index: _displayIndex,
        children: widget.children,
      ),
    );
  }
}
