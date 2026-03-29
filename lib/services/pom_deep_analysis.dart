// lib/services/pom_deep_analysis.dart
// 番茄钟深度分析 — 基于 crash log 和任务 focusSecs 数据
// 分析：打断分布、完成率热力、最佳专注时长建议、最佳时段

import '../providers/app_state.dart' show AppState;

// ── 输出数据结构 ──────────────────────────────────────────────────────────────

class DeepFocusReport {
  /// 每小时（0-23）的平均专注分钟数
  final List<double> hourlyFocusMins;

  /// 每小时打断次数（来自 pause 间隔分析）
  /// 近似：每个任务的 focusSecs 与 doneHour 差值推算
  final List<double> hourlyInterruptScore;

  /// 最高效时段 (hour 0-23)
  final int bestHour;

  /// 近7天每日完成率 (0.0-1.0)
  final List<double> weeklyCompletionRate;

  /// 近7天每日专注时长 (hours)
  final List<double> weeklyFocusHours;

  /// 平均专注时长建议（分钟）
  final int suggestedFocusMins;

  /// 置信度（样本数量）
  final int sampleCount;

  /// 峰值时段标签
  final String peakLabel;

  /// 连续性分析
  final String continuityInsight;

  /// 专注时长分布（bucket 5min步进，0-60min）
  final List<int> focusDurationBuckets; // 12 buckets: [0-5, 5-10, ..., 55-60+]

  const DeepFocusReport({
    required this.hourlyFocusMins,
    required this.hourlyInterruptScore,
    required this.bestHour,
    required this.weeklyCompletionRate,
    required this.weeklyFocusHours,
    required this.suggestedFocusMins,
    required this.sampleCount,
    required this.peakLabel,
    required this.continuityInsight,
    required this.focusDurationBuckets,
  });

  static DeepFocusReport empty() => DeepFocusReport(
    hourlyFocusMins: List.filled(24, 0),
    hourlyInterruptScore: List.filled(24, 0),
    bestHour: 9,
    weeklyCompletionRate: List.filled(7, 0),
    weeklyFocusHours: List.filled(7, 0),
    suggestedFocusMins: 25,
    sampleCount: 0,
    peakLabel: '暂无数据',
    continuityInsight: '完成更多番茄钟后可看到分析',
    focusDurationBuckets: List.filled(12, 0),
  );
}

// ── Analysis engine ───────────────────────────────────────────────────────────
class PomDeepAnalysis {
  static DeepFocusReport analyze(AppState state) {
    final now = DateTime.now();
    final today = state.todayKey;

    // Collect tasks with focus data, past 30 days
    final focusTasks = state.tasks.where((t) =>
        t.done && t.focusSecs > 60 && t.doneAt != null &&
        t.doneHour != null).toList();

    if (focusTasks.length < 3) return DeepFocusReport.empty();

    // ── 1. Hourly focus distribution ────────────────────────────────────────
    final hourlyMins = List<double>.filled(24, 0);
    final hourlyCount = List<int>.filled(24, 0);
    for (final t in focusTasks) {
      final h = t.doneHour!.clamp(0, 23);
      hourlyMins[h] += t.focusSecs / 60.0;
      hourlyCount[h]++;
    }
    // Normalize to average per session
    for (int h = 0; h < 24; h++) {
      if (hourlyCount[h] > 0) hourlyMins[h] /= hourlyCount[h];
    }

    // ── 2. Interrupt score heuristic ─────────────────────────────────────────
    // Interrupt score ∝ 1 - (actualFocusSecs / expectedSecs)
    // Expected = planMins * 60 (25min default). Higher = more interrupted.
    final hourlyInterrupt = List<double>.filled(24, 0);
    final hourlyInterruptCount = List<int>.filled(24, 0);
    for (final t in focusTasks) {
      final h = t.doneHour!.clamp(0, 23);
      // Focus efficiency: actual / expected (cap at 1)
      final expectedSecs = 25 * 60; // default 25min session
      final efficiency = (t.focusSecs / expectedSecs).clamp(0.0, 1.0);
      hourlyInterrupt[h] += (1.0 - efficiency); // higher = more interrupted
      hourlyInterruptCount[h]++;
    }
    for (int h = 0; h < 24; h++) {
      if (hourlyInterruptCount[h] > 0) {
        hourlyInterrupt[h] /= hourlyInterruptCount[h];
      }
    }

    // ── 3. Best hour = highest focus, lowest interrupt ───────────────────────
    int bestHour = 9;
    double bestScore = -1;
    for (int h = 6; h < 24; h++) { // 6am to midnight
      if (hourlyCount[h] == 0) continue;
      final score = hourlyMins[h] * (1 - hourlyInterrupt[h] * 0.5);
      if (score > bestScore) { bestScore = score; bestHour = h; }
    }

    // ── 4. Weekly completion & focus ─────────────────────────────────────────
    final weekDates = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    });
    final weeklyCompletion = <double>[];
    final weeklyFocus = <double>[];
    for (final d in weekDates) {
      final dayTasks = state.tasks.where((t) => t.createdAt == d || t.rescheduledTo == d);
      final total = dayTasks.length;
      final done  = dayTasks.where((t) => t.done && t.doneAt == d).length;
      weeklyCompletion.add(total > 0 ? done / total : 0.0);
      final focusSecs = dayTasks.fold(0, (s, t) => s + t.focusSecs)
          + (state.settings.unboundFocusByDate[d] ?? 0);
      weeklyFocus.add(focusSecs / 3600.0);
    }

    // ── 5. Suggested focus duration ──────────────────────────────────────────
    // Median completed focus session duration
    final completedSecs = focusTasks
        .where((t) => t.focusSecs >= 10 * 60)
        .map((t) => t.focusSecs)
        .toList()..sort();
    int suggestedMins = 25;
    if (completedSecs.isNotEmpty) {
      final median = completedSecs[completedSecs.length ~/ 2];
      // Round to nearest 5min between 15-50
      suggestedMins = ((median / 60 / 5).round() * 5).clamp(15, 50);
    }

    // ── 6. Focus duration distribution (buckets of 5min) ─────────────────────
    final buckets = List<int>.filled(12, 0);
    for (final t in focusTasks) {
      final mins = (t.focusSecs / 60).round();
      final bucket = (mins ~/ 5).clamp(0, 11);
      buckets[bucket]++;
    }

    // ── 7. Peak label ─────────────────────────────────────────────────────────
    final peakLabel = '${_hourLabel(bestHour)} 最高效 · '
        '平均 ${hourlyMins[bestHour].round()} 分/轮';

    // ── 8. Continuity insight ─────────────────────────────────────────────────
    final streak = _calcStreak(weekDates, weeklyFocus);
    String continuityInsight;
    if (streak >= 7) {
      continuityInsight = '🔥 连续 $streak 天保持专注，势头极佳！';
    } else if (streak >= 3) {
      continuityInsight = '✨ 已连续 $streak 天专注，继续保持';
    } else if (weeklyFocus.any((h) => h > 0.5)) {
      continuityInsight = '📈 本周有 ${weeklyFocus.where((h) => h > 0.5).length} 天有效专注';
    } else {
      continuityInsight = '💡 建议每天至少完成 1 个番茄钟';
    }

    return DeepFocusReport(
      hourlyFocusMins:     hourlyMins,
      hourlyInterruptScore: hourlyInterrupt,
      bestHour:             bestHour,
      weeklyCompletionRate: weeklyCompletion,
      weeklyFocusHours:     weeklyFocus,
      suggestedFocusMins:   suggestedMins,
      sampleCount:          focusTasks.length,
      peakLabel:            peakLabel,
      continuityInsight:    continuityInsight,
      focusDurationBuckets: buckets,
    );
  }

  static String _hourLabel(int h) {
    if (h < 6)  return '凌晨';
    if (h < 12) return '上午 ${h}时';
    if (h == 12) return '正午';
    if (h < 18) return '下午 ${h - 12}时';
    return '晚上 ${h - 12}时';
  }

  static int _calcStreak(List<String> dates, List<double> focus) {
    int streak = 0;
    for (int i = dates.length - 1; i >= 0; i--) {
      if (focus[i] > 0.1) streak++;
      else break;
    }
    return streak;
  }
}

