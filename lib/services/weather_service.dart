// lib/services/weather_service.dart  v3
// 和风天气（QWeather）适配版
// 支持 JWT（Ed25519）认证 + API Key 认证
// JWT token 生成在 Kotlin 侧完成（避免引入 dart 加密库）
// Flutter 侧负责：组装参数 → 调 Native → 解析 icon 码 → 映射 WeatherType

import 'dart:async';
import 'dart:math' show pi, max, sin, cos, Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 和风天气图标码 → WeatherType 映射
// 参考：https://dev.qweather.com/docs/resource/icons/
// ─────────────────────────────────────────────────────────────────────────────

enum WeatherType {
  none,          // 未获取
  clear,         // 晴（100/150）
  sunnyCloudy,   // 晴间多云（102/152）
  partlyCloudy,  // 多云（101/151）
  overcast,      // 阴（104/154）
  drizzle,       // 小雨/毛毛雨（300/301/309）
  lightRain,     // 中雨（302/305/306）
  heavyRain,     // 大雨/暴雨（303/304/307/308/310-313）
  thunderstorm,  // 雷阵雨（302含雷/303-304含雷/400系列雷）
  hail,          // 冰雹（304/362/363/374/375）
  sleet,         // 雨夹雪（405/406/407）
  lightSnow,     // 小雪（400/401）
  heavySnow,     // 大雪/暴雪（402/403）
  blizzard,      // 暴风雪（404）
  fog,           // 雾（500/501/509/510/514/515）
  haze,          // 霾（502/503/504）
  sand,          // 扬沙（505/506）
  dustStorm,     // 沙尘暴（507/508）
}

class WeatherMeta {
  final String key;
  final String emoji;
  final String label;
  final Color  tint;
  const WeatherMeta({required this.key, required this.emoji,
      required this.label, required this.tint});
}

const Map<WeatherType, WeatherMeta> kWeatherMeta = {
  WeatherType.none:         WeatherMeta(key:'none',        emoji:'🌡',  label:'未设置',   tint: Color(0xFF87CEEB)),
  WeatherType.clear:        WeatherMeta(key:'clear',       emoji:'☀️',  label:'晴',       tint: Color(0xFFFDB813)),
  WeatherType.sunnyCloudy:  WeatherMeta(key:'sunnyCloudy', emoji:'🌤',  label:'晴间多云', tint: Color(0xFFE8C46A)),
  WeatherType.partlyCloudy: WeatherMeta(key:'partlyCloudy',emoji:'⛅',  label:'多云',     tint: Color(0xFF90AABF)),
  WeatherType.overcast:     WeatherMeta(key:'overcast',    emoji:'☁️',  label:'阴',       tint: Color(0xFF6E7F8D)),
  WeatherType.drizzle:      WeatherMeta(key:'drizzle',     emoji:'🌦',  label:'小雨',     tint: Color(0xFF6A92B0)),
  WeatherType.lightRain:    WeatherMeta(key:'lightRain',   emoji:'🌧',  label:'中雨',     tint: Color(0xFF4E7A9E)),
  WeatherType.heavyRain:    WeatherMeta(key:'heavyRain',   emoji:'🌧',  label:'大雨/暴雨',tint: Color(0xFF2C5F8A)),
  WeatherType.thunderstorm: WeatherMeta(key:'thunderstorm',emoji:'⛈',  label:'雷阵雨',   tint: Color(0xFF2D3E50)),
  WeatherType.hail:         WeatherMeta(key:'hail',        emoji:'🌨',  label:'冰雹',     tint: Color(0xFF5B7FA6)),
  WeatherType.sleet:        WeatherMeta(key:'sleet',       emoji:'🌨',  label:'雨夹雪',   tint: Color(0xFF7A9EB5)),
  WeatherType.lightSnow:    WeatherMeta(key:'lightSnow',   emoji:'🌨',  label:'小雪',     tint: Color(0xFFBDD5E8)),
  WeatherType.heavySnow:    WeatherMeta(key:'heavySnow',   emoji:'❄️',  label:'大雪/暴雪',tint: Color(0xFFCCE4F5)),
  WeatherType.blizzard:     WeatherMeta(key:'blizzard',    emoji:'🌬',  label:'暴风雪',   tint: Color(0xFF8AAFC7)),
  WeatherType.fog:          WeatherMeta(key:'fog',         emoji:'🌫',  label:'雾',       tint: Color(0xFFBEC8D0)),
  WeatherType.haze:         WeatherMeta(key:'haze',        emoji:'🌫',  label:'霾',       tint: Color(0xFFB8A87A)),
  WeatherType.sand:         WeatherMeta(key:'sand',        emoji:'🌪',  label:'扬沙',     tint: Color(0xFFD4A850)),
  WeatherType.dustStorm:    WeatherMeta(key:'dustStorm',   emoji:'🌪',  label:'沙尘暴',   tint: Color(0xFFB8862A)),
};

WeatherType weatherTypeFromKey(String key) =>
    kWeatherMeta.entries.firstWhere(
      (e) => e.value.key == key,
      orElse: () => const MapEntry(WeatherType.none,
          WeatherMeta(key:'none',emoji:'',label:'',tint:Color(0))),
    ).key;

/// 和风天气图标码 → WeatherType
WeatherType fromQWeatherIcon(int icon) {
  // 晴
  if (icon == 100 || icon == 150) return WeatherType.clear;
  // 晴间多云
  if (icon == 102 || icon == 152) return WeatherType.sunnyCloudy;
  // 多云
  if (icon == 101 || icon == 103 || icon == 151 || icon == 153)
    return WeatherType.partlyCloudy;
  // 阴
  if (icon == 104 || icon == 154) return WeatherType.overcast;
  // 小雨/毛毛雨
  if (icon == 300 || icon == 301 || icon == 309 || icon == 399)
    return WeatherType.drizzle;
  // 雷阵雨
  if (icon == 302 || icon == 303 || icon == 304)
    return WeatherType.thunderstorm;
  // 中雨
  if (icon == 305 || icon == 306) return WeatherType.lightRain;
  // 大雨/暴雨
  if (icon >= 307 && icon <= 313) return WeatherType.heavyRain;
  // 冰雹
  if (icon == 362 || icon == 363 || icon == 374 || icon == 375)
    return WeatherType.hail;
  // 雨夹雪
  if (icon == 405 || icon == 406 || icon == 407) return WeatherType.sleet;
  // 小雪
  if (icon == 400 || icon == 401) return WeatherType.lightSnow;
  // 大雪/暴雪
  if (icon == 402 || icon == 403) return WeatherType.heavySnow;
  // 暴风雪
  if (icon == 404) return WeatherType.blizzard;
  // 雾
  if (icon == 500 || icon == 501 || icon == 509 ||
      icon == 510 || icon == 514 || icon == 515) return WeatherType.fog;
  // 霾
  if (icon == 502 || icon == 503 || icon == 504) return WeatherType.haze;
  // 扬沙
  if (icon == 505 || icon == 506) return WeatherType.sand;
  // 沙尘暴
  if (icon == 507 || icon == 508) return WeatherType.dustStorm;
  // 300-399 其余雨
  if (icon >= 300 && icon < 400) return WeatherType.lightRain;
  // 400-499 其余雪
  if (icon >= 400 && icon < 500) return WeatherType.lightSnow;
  return WeatherType.none;
}

// ─────────────────────────────────────────────────────────────────────────────
// WeatherData
// ─────────────────────────────────────────────────────────────────────────────

class WeatherData {
  final WeatherType type;
  final double tempC;
  final String desc;
  final int    iconCode; // 原始图标码
  final DateTime fetchedAt;

  const WeatherData({required this.type, required this.tempC,
      required this.desc, this.iconCode = 100, required this.fetchedAt});

  factory WeatherData.empty() => WeatherData(
      type: WeatherType.none, tempC: 0, desc: '未获取',
      fetchedAt: DateTime(2000));

  bool get isStale => DateTime.now().difference(fetchedAt).inMinutes > 30;
  WeatherMeta get meta => kWeatherMeta[type]!;
}

// ─────────────────────────────────────────────────────────────────────────────
// WeatherService
// ─────────────────────────────────────────────────────────────────────────────

class WeatherService {
  static const _ch = MethodChannel('com.lsz.app/weather');

  // ── 内嵌和风天气凭据（Builtin QWeather credentials）─────────────────────
  // ⚠️  私钥内嵌于 APK，仅供个人使用，请勿公开发布
  // 用户在设置中填写自己的凭据后，将优先使用用户的凭据
  // ── GitHub Open Source Version: No built-in credentials ───────────────────
  // Users must provide their own credentials in Settings > Lab > Weather.
  static const _kBuiltinApiHost  = '';
  static const _kBuiltinSub      = '';  // Project ID
  static const _kBuiltinKid      = '';  // Credential ID
  static const _kBuiltinSecret   = '';  // Ed25519 Private Key PEM
  // ──────────────────────────────────────────────────────────────────────────

  static WeatherData? _cached;
  static Timer? _timer;
  static WeatherType _pinned = WeatherType.none;
  static void Function(WeatherData)? _onUpdate;

  // Config — 用户设置优先，为空时回退到内嵌凭据
  static String _apiKey    = '';
  static String _city      = '';
  static String _apiHost   = '';  // 和风天气用户专属 API Host
  static String _jwtSecret = '';  // Ed25519 私钥 PEM
  static String _jwtKid    = '';  // 凭据 ID
  static String _jwtSub    = '';  // 项目 ID

  // ── 运行时决策：使用哪套凭据 ──────────────────────────────────────────
  static String get _effectiveApiHost  =>
      _apiHost.isNotEmpty   ? _apiHost   : _kBuiltinApiHost;
  static String get _effectiveSecret   =>
      _jwtSecret.isNotEmpty ? _jwtSecret : _kBuiltinSecret;
  static String get _effectiveKid      =>
      _jwtKid.isNotEmpty    ? _jwtKid    : _kBuiltinKid;
  static String get _effectiveSub      =>
      _jwtSub.isNotEmpty    ? _jwtSub    : _kBuiltinSub;
  static bool   get _hasCredentials    =>
      _effectiveSecret.isNotEmpty || _apiKey.isNotEmpty;

  static WeatherType get effectiveType {
    if (_pinned != WeatherType.none) return _pinned;
    return _cached?.type ?? WeatherType.none;
  }
  static WeatherData get current => _cached ?? WeatherData.empty();

  /// 启动天气服务
  /// [apiKey]   — 和风天气 API Key（与 jwtSecret 二选一）
  /// [city]     — 城市名（中文或英文）
  /// [pinned]   — 常驻特效 key
  /// [apiHost]  — 用户专属 API Host，留空使用免费版 devapi.qweather.com
  /// [jwtSecret]— Ed25519 私钥 PEM 字符串（优先于 apiKey）
  /// [jwtKid]   — 凭据 ID
  /// [jwtSub]   — 项目 ID
  static void start(
    String apiKey,
    String city,
    String pinned, {
    required void Function(WeatherData) onUpdate,
    String jwtSecret = '',
    String jwtKid    = '',
    String jwtSub    = '',
    String apiHost   = '',
  }) {
    _pinned    = weatherTypeFromKey(pinned);
    _apiKey    = apiKey;
    _city      = city;
    _apiHost   = apiHost;
    _jwtSecret = jwtSecret;
    _jwtKid    = jwtKid;
    _jwtSub    = jwtSub;
    _onUpdate  = onUpdate;
    // (JWT token is generated fresh on each request by the native layer)

    // 只要城市不为空就启动（内嵌凭据保证始终可用）
    if (city.isNotEmpty) {
      _fetch();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(minutes: 30), (_) => _fetch());
    }
    onUpdate(_cached ?? WeatherData.empty());
  }

  static void setPinned(String key) {
    _pinned = weatherTypeFromKey(key);
    _onUpdate?.call(_cached ?? WeatherData.empty());
  }

  static void stop() {
    _timer?.cancel(); _timer = null; _onUpdate = null;
  }

  static Future<void> _fetch() async {
    if (_city.isEmpty) return;
    try {
      // JWT token 由 Kotlin 侧生成（传私钥+kid+sub）
      // 直接传给 native，native 负责构建 JWT 并请求
      // 优先使用用户凭据，否则回退到内嵌凭据
      final result = await _ch.invokeMethod<Map>('fetchWeather', {
        'apiKey':    _apiKey,           // API Key 方式（留空=使用JWT）
        'city':      _city,
        'apiHost':   _effectiveApiHost, // 用户Host或内嵌Host
        'jwtSecret': _effectiveSecret,  // 用户私钥或内嵌私钥
        'jwtKid':    _effectiveKid,     // 用户kid或内嵌kid
        'jwtSub':    _effectiveSub,     // 用户sub或内嵌sub
      });
      if (result == null) return;

      final iconCode = (result['iconCode'] ?? 100) as int;
      final temp     = (result['temp']     ?? 20.0) as double;
      final desc     = (result['desc']     ?? '')   as String;
      final type = fromQWeatherIcon(iconCode);

      _cached = WeatherData(
          type: type, tempC: temp, desc: desc,
          iconCode: iconCode, fetchedAt: DateTime.now());
      _onUpdate?.call(_cached!);
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GlobalWeatherOverlay
// ─────────────────────────────────────────────────────────────────────────────

class GlobalWeatherOverlay extends StatefulWidget {
  final WeatherType type;
  final double intensity;
  const GlobalWeatherOverlay({super.key, required this.type,
      this.intensity = 0.65});
  @override
  State<GlobalWeatherOverlay> createState() => _GlobalWeatherOverlayState();
}

class _GlobalWeatherOverlayState extends State<GlobalWeatherOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _cycleSec = <WeatherType, double>{
    WeatherType.drizzle: 4.0, WeatherType.lightRain: 3.0,
    WeatherType.heavyRain: 2.2, WeatherType.thunderstorm: 2.0,
    WeatherType.hail: 2.5, WeatherType.sleet: 3.5,
    WeatherType.lightSnow: 6.0, WeatherType.heavySnow: 4.5,
    WeatherType.blizzard: 2.5, WeatherType.fog: 10.0,
    WeatherType.haze: 12.0, WeatherType.sand: 5.0,
    WeatherType.dustStorm: 3.0, WeatherType.partlyCloudy: 14.0,
    WeatherType.overcast: 16.0, WeatherType.sunnyCloudy: 14.0,
    WeatherType.clear: 20.0,
  };

  double get _cycle => _cycleSec[widget.type] ?? 5.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: Duration(milliseconds: (_cycle * 1000).round()))..repeat();
  }

  @override
  void didUpdateWidget(GlobalWeatherOverlay old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) {
      _ctrl.duration = Duration(milliseconds: (_cycle * 1000).round());
      _ctrl.repeat();
    }
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.type == WeatherType.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: WeatherPainter(type: widget.type,
              progress: _ctrl.value, intensity: widget.intensity),
          size: Size.infinite),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WeatherPainter — 17 种粒子特效
// ─────────────────────────────────────────────────────────────────────────────

class WeatherPainter extends CustomPainter {
  final WeatherType type;
  final double progress;
  final double intensity;

  static final _rng = Random(12345);
  static final List<_P> _pts = List.generate(120, (i) => _P(
    x: _rng.nextDouble(), y: _rng.nextDouble(),
    size: 0.8 + _rng.nextDouble() * 3.5,
    speed: 0.25 + _rng.nextDouble() * 0.75,
    phase: _rng.nextDouble(),
    drift: _rng.nextDouble() - 0.5,
    angle: _rng.nextDouble() * pi * 2,
  ));

  const WeatherPainter({required this.type, required this.progress,
      required this.intensity});

  @override
  void paint(Canvas canvas, Size s) {
    switch (type) {
      case WeatherType.drizzle:      _rain(canvas, s, count: 30, heavy: false, opacity: 0.30);
      case WeatherType.lightRain:    _rain(canvas, s, count: 55, heavy: false, opacity: 0.42);
      case WeatherType.heavyRain:    _rain(canvas, s, count: 90, heavy: true,  opacity: 0.55);
      case WeatherType.thunderstorm: _rain(canvas, s, count: 100, heavy: true, opacity: 0.60); _lightning(canvas, s);
      case WeatherType.hail:         _hail(canvas, s);
      case WeatherType.sleet:        _rain(canvas, s, count: 40, heavy: false, opacity: 0.35); _snow(canvas, s, count: 30, opacity: 0.50);
      case WeatherType.lightSnow:    _snow(canvas, s, count: 45, opacity: 0.70);
      case WeatherType.heavySnow:    _snow(canvas, s, count: 80, opacity: 0.80);
      case WeatherType.blizzard:     _blizzard(canvas, s);
      case WeatherType.fog:          _fog(canvas, s, color: const Color(0xFFD0D8DD), opacity: 0.55);
      case WeatherType.haze:         _fog(canvas, s, color: const Color(0xFFD4BE82), opacity: 0.50); _hazeParticles(canvas, s);
      case WeatherType.sand:         _sandStream(canvas, s, opacity: 0.50);
      case WeatherType.dustStorm:    _sandStream(canvas, s, opacity: 0.72); _dustVortex(canvas, s);
      case WeatherType.sunnyCloudy:  _clouds(canvas, s, count: 2, opacity: 0.22); _sunRays(canvas, s, opacity: 0.18);
      case WeatherType.partlyCloudy: _clouds(canvas, s, count: 3, opacity: 0.28);
      case WeatherType.overcast:     _clouds(canvas, s, count: 5, opacity: 0.35);
      case WeatherType.clear:        _sunRays(canvas, s, opacity: 0.20);
      default: break;
    }
  }

  void _rain(Canvas canvas, Size s, {required int count, required bool heavy, required double opacity}) {
    final paint = Paint()
      ..color = const Color(0xFF8BC4E8).withOpacity(opacity * intensity)
      ..strokeWidth = heavy ? 1.6 : 0.9
      ..strokeCap = StrokeCap.round;
    final len = heavy ? 22.0 : 14.0;
    final slant = heavy ? -0.22 : -0.10;
    for (int i = 0; i < count; i++) {
      final p = _pts[i % _pts.length];
      final t = ((progress * p.speed + p.phase) % 1.0);
      final x = p.x * s.width;
      final y = t * (s.height + len + 20) - len;
      canvas.drawLine(Offset(x + slant * len / 2, y - len / 2),
          Offset(x - slant * len / 2, y + len / 2), paint);
    }
  }

  void _lightning(Canvas canvas, Size s) {
    final phase = (progress * 7) % 1.0;
    if (phase > 0.10) return;
    final bright = (1.0 - phase / 0.10).clamp(0.0, 1.0);
    final idx = (progress * 31).floor() % 3;
    final bx = [0.25, 0.55, 0.78][idx] * s.width;
    final paint = Paint()
      ..color = const Color(0xFFFFF8C0).withOpacity(bright * 0.85 * intensity)
      ..strokeWidth = 2.0 ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(bx, 0);
    path.lineTo(bx - 18, s.height * 0.35);
    path.lineTo(bx + 10, s.height * 0.38);
    path.lineTo(bx - 22, s.height * 0.70);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFFFF8C0).withOpacity(bright * 0.15 * intensity)
      ..strokeWidth = 14 ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  }

  void _hail(Canvas canvas, Size s) {
    final p1 = Paint()..color = const Color(0xFFD0EEFF).withOpacity(0.80 * intensity);
    final p2 = Paint()..color = const Color(0xFF90CCF0).withOpacity(0.60 * intensity)
        ..style = PaintingStyle.stroke ..strokeWidth = 0.8;
    for (int i = 0; i < 40; i++) {
      final p = _pts[i % _pts.length];
      final t = ((progress * p.speed * 1.3 + p.phase) % 1.0);
      final x = (p.x + p.drift * 0.04 * t) * s.width;
      final y = t * (s.height + 20) - 10;
      canvas.drawCircle(Offset(x, y), p.size * 1.2, p1);
      canvas.drawCircle(Offset(x, y), p.size * 1.2, p2);
    }
  }

  void _snow(Canvas canvas, Size s, {required int count, required double opacity}) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity * intensity);
    for (int i = 0; i < count; i++) {
      final p = _pts[i % _pts.length];
      final t = ((progress * p.speed * 0.5 + p.phase) % 1.0);
      final sway = sin(t * pi * 4 + p.angle) * 18 * p.drift.abs();
      canvas.drawCircle(Offset(p.x * s.width + sway, t * (s.height + 20) - 10),
          p.size * 0.9, paint);
    }
  }

  void _blizzard(Canvas canvas, Size s) {
    final sp = Paint()..color = Colors.white.withOpacity(0.35 * intensity)
        ..strokeWidth = 1.0 ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 50; i++) {
      final p = _pts[i];
      final t = ((progress * p.speed * 2 + p.phase) % 1.0);
      final x = (p.x - t * 0.8 + p.drift * 0.1) * s.width;
      final y = (p.y * 0.8 + 0.1) * s.height + sin(t * pi * 3) * 20;
      canvas.drawLine(Offset(x, y), Offset(x + 30 * p.speed, y + 6), sp);
    }
    _snow(canvas, s, count: 60, opacity: 0.80);
  }

  void _fog(Canvas canvas, Size s, {required Color color, required double opacity}) {
    for (int i = 0; i < 8; i++) {
      final p = _pts[i];
      final drift = (progress * 0.03 * p.speed + p.phase * 0.15) % 1.5 - 0.25;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset((p.x + drift) * s.width,
              (0.08 + p.y * 0.78) * s.height),
              width: s.width * (0.55 + p.size * 0.08), height: 55 + p.size * 8),
          const Radius.circular(28)),
        Paint()..color = color.withOpacity(opacity * intensity * (0.6 + p.speed * 0.4))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35));
    }
  }

  void _hazeParticles(Canvas canvas, Size s) {
    for (int i = 0; i < 20; i++) {
      final p = _pts[i + 8];
      final t = ((progress * p.speed * 0.3 + p.phase) % 1.0);
      canvas.drawCircle(
        Offset((p.x + t * 0.4 * p.drift) * s.width,
            (0.15 + p.y * 0.70) * s.height),
        p.size * 14,
        Paint()..color = const Color(0xFFD4A830).withOpacity(0.06 * intensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }
  }

  void _sandStream(Canvas canvas, Size s, {required double opacity}) {
    for (int i = 0; i < 8; i++) {
      final p = _pts[i + 20];
      final drift = (progress * 0.18 * p.speed + p.phase) % 1.6 - 0.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset((p.x + drift) * s.width,
              (0.30 + p.y * 0.55) * s.height),
              width: s.width * 0.65, height: 28 + p.size * 4),
          const Radius.circular(14)),
        Paint()..color = const Color(0xFFD4924A)
            .withOpacity(opacity * intensity * (0.4 + p.speed * 0.35))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
    }
    final pp = Paint()..color = const Color(0xFFDFAA5A).withOpacity(0.18 * intensity);
    for (int i = 0; i < 50; i++) {
      final p = _pts[i + 30];
      final t = ((progress * p.speed * 1.5 + p.phase) % 1.0);
      canvas.drawCircle(
        Offset(((p.x - t * 0.4 + 0.4) % 1.0) * s.width,
            (0.2 + p.y * 0.65) * s.height + sin(t * pi * 2) * 8),
        p.size * 1.5, pp);
    }
  }

  void _dustVortex(Canvas canvas, Size s) {
    for (int i = 0; i < 3; i++) {
      final p = _pts[i + 80];
      canvas.drawCircle(
        Offset(p.x * s.width, (0.4 + p.y * 0.4) * s.height),
        60 + p.size * 20,
        Paint()..color = const Color(0xFFB87A2A).withOpacity(0.12 * intensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    }
  }

  void _clouds(Canvas canvas, Size s, {required int count, required double opacity}) {
    for (int i = 0; i < count; i++) {
      final p = _pts[i + 90];
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(((p.x + progress * 0.06 * p.speed) % 1.3 - 0.15) * s.width,
              (0.02 + p.y * 0.22) * s.height),
          width: s.width * 0.52, height: 70),
        Paint()..color = Colors.white.withOpacity(opacity * intensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }
  }

  void _sunRays(Canvas canvas, Size s, {required double opacity}) {
    final cx = s.width * 0.80; final cy = s.height * 0.08;
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * pi * 2 + progress * 0.15;
      final r1 = 30.0; final r2 = 80 + sin(progress * pi * 2 + i) * 15;
      canvas.drawLine(
        Offset(cx + cos(angle) * r1, cy + sin(angle) * r1),
        Offset(cx + cos(angle) * r2, cy + sin(angle) * r2),
        Paint()..color = const Color(0xFFFFC840)
            .withOpacity(opacity * intensity * 0.6)
            ..strokeWidth = 2.5 ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(Offset(cx, cy), 28, Paint()
      ..color = const Color(0xFFFFC840).withOpacity(opacity * intensity * 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
  }

  @override
  bool shouldRepaint(WeatherPainter o) =>
      o.progress != progress || o.type != type;
}

class _P {
  final double x, y, size, speed, phase, drift, angle;
  const _P({required this.x, required this.y, required this.size,
      required this.speed, required this.phase, required this.drift,
      required this.angle});
}

// ─────────────────────────────────────────────────────────────────────────────
// WeatherChip
// ─────────────────────────────────────────────────────────────────────────────

class WeatherChip extends StatelessWidget {
  final WeatherData weather;
  final Color textColor;
  const WeatherChip({super.key, required this.weather, required this.textColor});

  @override
  Widget build(BuildContext context) {
    if (weather.type == WeatherType.none) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(weather.meta.emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 3),
      Text('${weather.tempC.round()}°',
          style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
    ]);
  }
}
