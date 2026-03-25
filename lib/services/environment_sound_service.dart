// lib/services/environment_sound_service.dart  v3
// 环境声评估服务
//
// 三种使用场景：
//   1. 单次分析（统计页按钮）  → assessOnce30s()，30s实时采样，存入历史（source='manual'）
//   2. 番茄钟抽样              → startSessionSampling() / stopAndRecord()
//      结果存入历史（source='pomodoro'），供番茄钟深度分析调取
//   3. 智能建议联动            → NoiseHistoryStore.buildInsight()，仅使用 source='pomodoro' 数据

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
enum NoiseLevel {
  silent,    // < 30 dB
  quiet,     // 30-45 dB
  moderate,  // 45-60 dB
  loud,      // 60-75 dB
  veryLoud,  // > 75 dB
}

extension NoiseLevelX on NoiseLevel {
  String get label {
    switch (this) {
      case NoiseLevel.silent:   return '极安静';
      case NoiseLevel.quiet:    return '安静';
      case NoiseLevel.moderate: return '适中';
      case NoiseLevel.loud:     return '嘈杂';
      case NoiseLevel.veryLoud: return '非常嘈杂';
    }
  }
  String get emoji {
    switch (this) {
      case NoiseLevel.silent:   return '🤫';
      case NoiseLevel.quiet:    return '🔕';
      case NoiseLevel.moderate: return '🔉';
      case NoiseLevel.loud:     return '🔊';
      case NoiseLevel.veryLoud: return '📢';
    }
  }
  double get score {
    switch (this) {
      case NoiseLevel.silent:   return 1.0;
      case NoiseLevel.quiet:    return 0.85;
      case NoiseLevel.moderate: return 0.65;
      case NoiseLevel.loud:     return 0.40;
      case NoiseLevel.veryLoud: return 0.15;
    }
  }
  int get colorHex {
    switch (this) {
      case NoiseLevel.silent:   return 0xFF4A9068;
      case NoiseLevel.quiet:    return 0xFF3a90c0;
      case NoiseLevel.moderate: return 0xFFe8c84a;
      case NoiseLevel.loud:     return 0xFFe8982a;
      case NoiseLevel.veryLoud: return 0xFFc04040;
    }
  }

  static NoiseLevel fromDb(double db) {
    if (db < 30) return NoiseLevel.silent;
    if (db < 45) return NoiseLevel.quiet;
    if (db < 60) return NoiseLevel.moderate;
    if (db < 75) return NoiseLevel.loud;
    return NoiseLevel.veryLoud;
  }

  static NoiseLevel fromIndex(int i) =>
      NoiseLevel.values[i.clamp(0, NoiseLevel.values.length - 1)];
}

// ─────────────────────────────────────────────────────────────────────────────
class NoiseSample {
  final DateTime time;
  final double dbLevel;
  final NoiseLevel level;

  const NoiseSample({
    required this.time, required this.dbLevel, required this.level,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'dbLevel': dbLevel,
    'level': level.index,
  };

  factory NoiseSample.fromJson(Map<String, dynamic> j) => NoiseSample(
    time: DateTime.parse(j['time'] as String),
    dbLevel: (j['dbLevel'] as num).toDouble(),
    level: NoiseLevelX.fromIndex(j['level'] as int),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Session 报告
//   source: 'manual' = 统计页手动测量  |  'pomodoro' = 番茄钟自动抽样
// ─────────────────────────────────────────────────────────────────────────────
class SessionNoiseReport {
  final List<NoiseSample> samples;
  final double avgDb;
  final NoiseLevel dominantLevel;
  final String assessment;
  final DateTime sessionStart;
  final String source; // 'manual' | 'pomodoro'

  const SessionNoiseReport({
    required this.samples,
    required this.avgDb,
    required this.dominantLevel,
    required this.assessment,
    required this.sessionStart,
    this.source = 'pomodoro',
  });

  static final empty = SessionNoiseReport(
    samples: const [],
    avgDb: 0,
    dominantLevel: NoiseLevel.quiet,
    assessment: '暂无数据',
    sessionStart: DateTime(2000),
    source: 'pomodoro',
  );

  bool get hasData => samples.isNotEmpty;
  bool get isManual => source == 'manual';

  Map<String, dynamic> toJson() => {
    'samples': samples.map((s) => s.toJson()).toList(),
    'avgDb': avgDb,
    'dominantLevel': dominantLevel.index,
    'assessment': assessment,
    'sessionStart': sessionStart.toIso8601String(),
    'source': source,
  };

  factory SessionNoiseReport.fromJson(Map<String, dynamic> j) {
    final samples = (j['samples'] as List? ?? [])
        .map((e) => NoiseSample.fromJson(e as Map<String, dynamic>))
        .toList();
    return SessionNoiseReport(
      samples: samples,
      avgDb: (j['avgDb'] as num? ?? 0).toDouble(),
      dominantLevel: NoiseLevelX.fromIndex(j['dominantLevel'] as int? ?? 1),
      assessment: (j['assessment'] as String?) ?? '暂无数据',
      sessionStart: DateTime.tryParse(j['sessionStart'] as String? ?? '') ??
          DateTime(2000),
      source: (j['source'] as String?) ?? 'pomodoro',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class NoiseHistoryStore {
  static const _prefKey = 'lsz_noise_history_v1';
  static final List<SessionNoiseReport> _cache = [];
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _cache.addAll(list.map((e) =>
            SessionNoiseReport.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    _loaded = true;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cache.length > 200) _cache.removeRange(0, _cache.length - 200);
    await prefs.setString(_prefKey,
        jsonEncode(_cache.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(SessionNoiseReport report) async {
    await load();
    if (!report.hasData) return;
    _cache.add(report);
    await _save();
  }

  /// Recent sessions filtered by source ('manual', 'pomodoro', or null=all)
  static Future<List<SessionNoiseReport>> recent({
    int days = 14,
    String? source,
  }) async {
    await load();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _cache.where((r) {
      if (!r.hasData) return false;
      if (!r.sessionStart.isAfter(cutoff)) return false;
      if (source != null && r.source != source) return false;
      return true;
    }).toList();
  }

  /// All sessions (newest first), optionally filtered by source
  static Future<List<SessionNoiseReport>> allSorted({String? source}) async {
    await load();
    final filtered = source == null
        ? List<SessionNoiseReport>.from(_cache)
        : _cache.where((r) => r.source == source).toList();
    return filtered.reversed.toList();
  }

  static List<SessionNoiseReport> get all => List.unmodifiable(_cache);

  // ── Smart plan insight — ONLY uses pomodoro source ─────────────────────
  static Future<String?> buildInsight() async {
    final sessions = await recent(days: 30, source: 'pomodoro');
    if (sessions.length < 3) return null;

    final levelCount = <NoiseLevel, int>{};
    for (final s in sessions) {
      levelCount[s.dominantLevel] = (levelCount[s.dominantLevel] ?? 0) + 1;
    }
    final dominant = levelCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final avgDb = sessions.map((s) => s.avgDb).reduce((a, b) => a + b) /
        sessions.length;
    final noisyCount = sessions
        .where((s) =>
            s.dominantLevel == NoiseLevel.loud ||
            s.dominantLevel == NoiseLevel.veryLoud)
        .length;

    if (noisyCount > sessions.length * 0.5) {
      return '近${sessions.length}次番茄钟有 $noisyCount 次环境嘈杂（avg ${avgDb.round()}dB），'
          '建议换安静场所或佩戴耳机';
    }
    if (dominant == NoiseLevel.silent || dominant == NoiseLevel.quiet) {
      return '你的专注环境整体安静（avg ${avgDb.round()}dB），保持这种良好习惯 🤫';
    }
    return '专注环境平均噪音 ${avgDb.round()}dB（${dominant.label}），'
        '偶尔嘈杂，建议在最安静的时段安排核心任务';
  }

  static Future<List<double>> hourlyNoiseScore({int days = 30}) async {
    final sessions = await recent(days: days, source: 'pomodoro');
    final hourScores = List<List<double>>.generate(24, (_) => []);
    for (final s in sessions) {
      for (final sample in s.samples) {
        final h = sample.time.hour.clamp(0, 23);
        hourScores[h].add(sample.level.score);
      }
    }
    return List.generate(24, (h) {
      if (hourScores[h].isEmpty) return 0.0;
      return hourScores[h].reduce((a, b) => a + b) / hourScores[h].length;
    });
  }

  static Future<double> overallScore({int days = 30}) async {
    final sessions = await recent(days: days, source: 'pomodoro');
    if (sessions.isEmpty) return 0;
    final scores = sessions.map((s) => s.dominantLevel.score).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class EnvironmentSoundService {
  static const _ch         = MethodChannel('com.lsz.app/audio_noise');
  static const _streamCh   = EventChannel('com.lsz.app/audio_noise_stream');

  static final List<NoiseSample> _sessionSamples = [];
  static Timer? _samplingTimer;
  static DateTime? _sessionStart;
  static bool _enabled = false;

  // Live dB stream — backed by the native EventChannel
  // Each subscription creates a new 30s recording session.
  static Stream<double> get liveDbStream =>
      _streamCh.receiveBroadcastStream().map((v) => (v as num).toDouble());

  static bool _measuring30s = false;

  static bool get isEnabled => _enabled;
  static void setEnabled(bool v) => _enabled = v;

  // ── 30s single measurement ────────────────────────────────────────────
  /// UI layer should subscribe to [liveDbStream] for per-second updates.
  /// Call [buildReportFromReadings] once all readings are collected.
  ///
  /// Usage pattern in UI:
  ///   1. Subscribe to liveDbStream → update live meter
  ///   2. After stream ends (or 30 readings) → call buildReportFromReadings()
  static Future<SessionNoiseReport?> buildReportFromReadings(
      List<double> readings, DateTime startTime) async {
    if (readings.isEmpty) return null;
    final avgDb = readings.reduce((a, b) => a + b) / readings.length;
    final samples = List.generate(readings.length, (i) => NoiseSample(
      time: startTime.add(Duration(seconds: i + 1)),
      dbLevel: readings[i],
      level: NoiseLevelX.fromDb(readings[i]),
    ));
    final counts = <NoiseLevel, int>{};
    for (final s in samples) counts[s.level] = (counts[s.level] ?? 0) + 1;
    final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final report = SessionNoiseReport(
      samples: samples,
      avgDb: avgDb,
      dominantLevel: dominant,
      assessment: _buildAssessment(avgDb, dominant),
      sessionStart: startTime,
      source: 'manual',
    );
    await NoiseHistoryStore.add(report);
    return report;
  }

  // Keep old name for backward compat — delegates to new API
  static Future<SessionNoiseReport?> assessOnce30s() async {
    // Not used directly anymore; UI drives via liveDbStream + buildReportFromReadings
    return null;
  }

  // Legacy quick snapshot (1.5s) for pomodoro background sampling
  static Future<NoiseSample?> assessOnce({bool persist = false}) async {
    try {
      final result = await _ch.invokeMethod<double>('measureDb');
      if (result == null) return null;
      return NoiseSample(
        time: DateTime.now(),
        dbLevel: result,
        level: NoiseLevelX.fromDb(result),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Session sampling (Pomodoro background) ──────────────────────────────
  // Each "sample" is a single 1.5s snapshot taken periodically during a session.
  static void startSessionSampling() {
    if (!_enabled) return;
    _sessionSamples.clear();
    _sessionStart = DateTime.now();
    _samplingTimer?.cancel();
    Future.delayed(const Duration(seconds: 30), _takeSample);
    _samplingTimer = Timer.periodic(
        const Duration(minutes: 5), (_) => _takeSample());
  }

  static Future<void> _takeSample() async {
    final s = await assessOnce(persist: false);
    if (s != null) _sessionSamples.add(s);
  }

  static Future<SessionNoiseReport> stopAndRecord() async {
    _samplingTimer?.cancel();
    _samplingTimer = null;
    if (_sessionSamples.isEmpty) {
      _sessionStart = null;
      return SessionNoiseReport.empty;
    }
    final avgDb = _sessionSamples.map((s) => s.dbLevel).reduce((a, b) => a + b)
        / _sessionSamples.length;
    final counts = <NoiseLevel, int>{};
    for (final s in _sessionSamples) counts[s.level] = (counts[s.level] ?? 0) + 1;
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final report = SessionNoiseReport(
      samples: List.from(_sessionSamples),
      avgDb: avgDb,
      dominantLevel: dominant,
      assessment: _buildAssessment(avgDb, dominant),
      sessionStart: _sessionStart ?? DateTime.now(),
      source: 'pomodoro',
    );
    _sessionSamples.clear();
    _sessionStart = null;
    await NoiseHistoryStore.add(report);
    return report;
  }

  // Backward compat
  static SessionNoiseReport stopSessionSampling() {
    _samplingTimer?.cancel();
    _samplingTimer = null;
    if (_sessionSamples.isEmpty) return SessionNoiseReport.empty;
    final avgDb = _sessionSamples.map((s) => s.dbLevel).reduce((a, b) => a + b)
        / _sessionSamples.length;
    final counts = <NoiseLevel, int>{};
    for (final s in _sessionSamples) counts[s.level] = (counts[s.level] ?? 0) + 1;
    final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final samples = List<NoiseSample>.from(_sessionSamples);
    _sessionSamples.clear();
    _sessionStart = null;
    return SessionNoiseReport(
      samples: samples,
      avgDb: avgDb,
      dominantLevel: dominant,
      assessment: _buildAssessment(avgDb, dominant),
      sessionStart: DateTime.now(),
      source: 'pomodoro',
    );
  }

  static String levelLabel(NoiseLevel level) => level.label;
  static String levelEmoji(NoiseLevel level) => level.emoji;
  static double levelToScore(NoiseLevel level) => level.score;

  static String _buildAssessment(double avgDb, NoiseLevel level) {
    final db = avgDb.round().toString();
    switch (level) {
      case NoiseLevel.silent:
        return L.get('screens.statsNew.noise.assess.silent', {'db': db});
      case NoiseLevel.quiet:
        return L.get('screens.statsNew.noise.assess.quiet', {'db': db});
      case NoiseLevel.moderate:
        return L.get('screens.statsNew.noise.assess.moderate', {'db': db});
      case NoiseLevel.loud:
        return L.get('screens.statsNew.noise.assess.loud', {'db': db});
      case NoiseLevel.veryLoud:
        return L.get('screens.statsNew.noise.assess.veryLoud', {'db': db});
    }
  }
}
