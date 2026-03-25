// lib/services/focus_quality_service.dart
// 专注质量评分 — 主观评分 × 客观效率 综合建立洞察
// 每轮番茄钟结束后触发，存储在本地并汇入统计

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FocusQualityEntry {
  final String date;           // yyyy-MM-dd
  final int hour;              // 完成时的小时
  final int sessionMins;       // 本次专注实际分钟
  final int? subjectiveScore;  // 用户主观评分 1-5，null=未评分
  final double objectiveScore; // 客观效率 0.0-1.0（focusSecs/totalSecs）
  final String? taskId;        // 绑定的任务ID
  final String? noiseLevel;    // 环境声等级 label
  final double? flowIndex;     // 心流指数均值 0.0-1.0（本轮专注期间）

  const FocusQualityEntry({
    required this.date,
    required this.hour,
    required this.sessionMins,
    this.subjectiveScore,
    required this.objectiveScore,
    this.taskId,
    this.noiseLevel,
    this.flowIndex,
  });

  /// 综合质量分 0-100
  int get compositeScore {
    final obj = objectiveScore.clamp(0.0, 1.0);
    if (subjectiveScore == null) return (obj * 100).round();
    final sub = (subjectiveScore! - 1) / 4.0; // 1-5 → 0-1
    return ((obj * 0.5 + sub * 0.5) * 100).round();
  }

  Map<String, dynamic> toJson() => {
    'date': date, 'hour': hour, 'sessionMins': sessionMins,
    'subjectiveScore': subjectiveScore, 'objectiveScore': objectiveScore,
    'taskId': taskId, 'noiseLevel': noiseLevel, 'flowIndex': flowIndex,
  };

  factory FocusQualityEntry.fromJson(Map<String, dynamic> j) => FocusQualityEntry(
    date: j['date'] as String,
    hour: (j['hour'] as num).toInt(),
    sessionMins: (j['sessionMins'] as num).toInt(),
    subjectiveScore: j['subjectiveScore'] as int?,
    objectiveScore: (j['objectiveScore'] as num).toDouble(),
    taskId: j['taskId'] as String?,
    noiseLevel: j['noiseLevel'] as String?,
    flowIndex: j['flowIndex'] != null ? (j['flowIndex'] as num).toDouble() : null,
  );
}

class FocusQualityService {
  static const _prefKey = 'lsz_focus_quality_v1';
  static final List<FocusQualityEntry> _cache = [];
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _cache.addAll(list.map((e) => FocusQualityEntry.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    _loaded = true;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_cache.map((e) => e.toJson()).toList());
    await prefs.setString(_prefKey, json);
  }

  /// Add an entry (called when a focus session ends)
  static Future<void> addEntry(FocusQualityEntry entry) async {
    await load();
    _cache.add(entry);
    // Keep last 500 entries
    if (_cache.length > 500) _cache.removeRange(0, _cache.length - 500);
    await _save();
  }

  /// Update subjective score for the latest entry (called after user rates)
  static Future<void> rateLastSession(int score) async {
    await load();
    if (_cache.isEmpty) return;
    final last = _cache.last;
    _cache[_cache.length - 1] = FocusQualityEntry(
      date: last.date, hour: last.hour, sessionMins: last.sessionMins,
      subjectiveScore: score.clamp(1, 5),
      objectiveScore: last.objectiveScore,
      taskId: last.taskId, noiseLevel: last.noiseLevel,
    );
    await _save();
  }

  /// Get entries for the last N days
  static Future<List<FocusQualityEntry>> getRecent({int days = 30}) async {
    await load();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _cache.where((e) {
      try {
        return DateTime.parse(e.date).isAfter(cutoff);
      } catch (_) { return false; }
    }).toList();
  }

  /// Average composite score for recent entries
  static Future<double> avgCompositeScore({int days = 7}) async {
    final entries = await getRecent(days: days);
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.compositeScore).reduce((a, b) => a + b) / entries.length;
  }

  /// Best hour based on composite score
  static Future<int?> bestHourByQuality({int days = 30}) async {
    final entries = await getRecent(days: days);
    if (entries.isEmpty) return null;
    final hourScores = <int, List<int>>{};
    for (final e in entries) {
      hourScores.putIfAbsent(e.hour, () => []).add(e.compositeScore);
    }
    final avgByHour = hourScores.map((h, scores) =>
      MapEntry(h, scores.reduce((a, b) => a + b) / scores.length));
    if (avgByHour.isEmpty) return null;
    return avgByHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Average flow index for recent entries (entries that have flowIndex)
  static Future<double?> avgFlowIndex({int days = 14}) async {
    final entries = await getRecent(days: days);
    final withFlow = entries.where((e) => e.flowIndex != null).toList();
    if (withFlow.isEmpty) return null;
    return withFlow.map((e) => e.flowIndex!).reduce((a, b) => a + b)
        / withFlow.length;
  }

  /// Flow index trend: returns list of (date, avgFlow) for sparkline
  /// Groups by date, takes avg flow per day, last N days with data
  static Future<List<({String date, double flow})>> flowTrend({int days = 14}) async {
    final entries = await getRecent(days: days);
    final byDate = <String, List<double>>{};
    for (final e in entries) {
      if (e.flowIndex != null) {
        byDate.putIfAbsent(e.date, () => []).add(e.flowIndex!);
      }
    }
    final sorted = byDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return (date: e.key, flow: avg);
    }).toList();
  }

  /// Flow insight for smart plan integration
  static Future<String?> buildFlowInsight() async {
    final trend = await flowTrend(days: 14);
    if (trend.length < 3) return null;

    final avg = trend.map((t) => t.flow).reduce((a, b) => a + b) / trend.length;
    final avgScore = (avg * 100).round();

    // Detect rising or falling trend (compare first half vs second half)
    final mid = trend.length ~/ 2;
    final firstHalf = trend.take(mid).map((t) => t.flow).reduce((a, b) => a + b) / mid;
    final secondHalf = trend.skip(mid).map((t) => t.flow).reduce((a, b) => a + b) / (trend.length - mid);
    final delta = ((secondHalf - firstHalf) * 100).round();

    if (avgScore >= 75) {
      if (delta >= 5) return '心流指数上升趋势 +$delta，近两周深度专注能力持续增强 🔥';
      return '心流指数稳定在 $avgScore 分，你已建立了可靠的深度专注习惯 ✨';
    } else if (avgScore >= 55) {
      if (delta <= -8) return '心流指数近期下滑 $delta 分，注意休息和减少干扰源';
      return '心流指数 $avgScore 分，还有提升空间 — 尝试减少专注期间的暂停次数';
    } else {
      return '心流指数偏低（$avgScore 分），建议从较短的专注时长开始积累进入状态的节奏';
    }
  }

  /// Build cross-insight text (for smart plan integration)
  static Future<String?> buildInsight() async {
    final entries = await getRecent(days: 14);
    if (entries.length < 3) return null;

    final rated = entries.where((e) => e.subjectiveScore != null).toList();
    if (rated.isEmpty) return null;

    final avgSubj = rated.map((e) => e.subjectiveScore!).reduce((a, b) => a + b)
        / rated.length;
    final avgObj = entries.map((e) => e.objectiveScore).reduce((a, b) => a + b)
        / entries.length;

    final subjPct = (avgSubj / 5 * 100).round();
    final objPct  = (avgObj * 100).round();

    if ((subjPct - objPct).abs() > 25) {
      if (subjPct > objPct) {
        return '你对专注感觉不错（主观 $subjPct 分），但实际专注效率 $objPct 分偏低，可能有隐性分心';
      } else {
        return '你低估了自己的专注效果！主观感受 $subjPct 分，实际效率达 $objPct 分';
      }
    }
    return '近两周专注质量稳定：主观 $subjPct 分 · 客观 $objPct 分';
  }
}
