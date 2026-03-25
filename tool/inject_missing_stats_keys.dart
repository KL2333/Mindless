import 'dart:convert';
import 'dart:io';

void main() async {
  final Map<String, Map<String, String>> newTranslations = {
    'screens.stats.periodDone': {'zh': '{{period}}完成', 'en': 'Done in {{period}}'},
    'screens.stats.periodNew': {'zh': '{{period}}新增', 'en': 'New in {{period}}'},
    'screens.stats.activeTags': {'zh': '活跃标签', 'en': 'Active Tags'},
    'screens.stats.dateFormat': {'zh': '{{year}}年{{month}}月{{day}}日', 'en': '{{year}}-{{month}}-{{day}}'},
    'screens.stats.weekFormat': {'zh': '{{year}}年 第{{week}}周', 'en': '{{year}} Week {{week}}'},
    'screens.stats.monthFormat': {'zh': '{{year}}年{{month}}月', 'en': '{{year}}-{{month}}'},
    'screens.stats.yearFormat': {'zh': '{{year}}年', 'en': '{{year}}'},
    'screens.stats.dayOfYear': {'zh': '第{{day}}天 (第{{week}}周)', 'en': 'Day {{day}} (Week {{week}})'},
    'screens.stats.completionRateByBlock': {'zh': '各时段完成率', 'en': 'Completion by Block'},
    'screens.stats.insightLowestRate': {'zh': '{{emoji}}{{blockName}}的完成率最低，建议适当调整该时段的任务量。', 'en': '{{emoji}}{{blockName}} has the lowest completion rate. Consider adjusting workload.'},
    'screens.stats.insightBestVitality': {'zh': '你在{{blockName}}最有活力，共完成了{{count}}个任务。', 'en': 'You are most productive in {{blockName}}, with {{count}} tasks done.'},
    'screens.stats.byCount': {'zh': '按数量', 'en': 'By Count'},
    'screens.stats.byTime': {'zh': '按用时', 'en': 'By Time'},
    'screens.stats.period': {'zh': '{{period}}', 'en': '{{period}}'},
    'screens.stats.focusTimeStats': {'zh': '专注用时统计', 'en': 'Focus Time Stats'},
    'screens.stats.details': {'zh': '详情', 'en': 'Details'},
    'screens.stats.noTasksOnDate': {'zh': '该日期没有任务记录', 'en': 'No tasks on this date'},
    'screens.stats.addTaskOnDate': {'zh': '在当前日期记录任务', 'en': 'Add task on this date'},
    'screens.stats.logSomething': {'zh': '想记点什么...', 'en': 'Log something...'},
    'screens.stats.markAsDone': {'zh': '标记为已完成', 'en': 'Mark as done'},
    'screens.stats.totalCompletionRank': {'zh': '累计完成排名', 'en': 'Total Completion Rank'},
    'screens.stats.pomodoroStats': {'zh': '番茄钟统计', 'en': 'Pomodoro Stats'},
    'screens.stats.periodFocus': {'zh': '{{period}}专注', 'en': 'Focus in {{period}}'},
    'screens.stats.focusedTasks': {'zh': '专注任务数', 'en': 'Focused Tasks'},
    'screens.stats.totalFocus': {'zh': '累计总专注', 'en': 'Total Focus'},
    'screens.stats.dailyFocusDuration': {'zh': '每日专注时长分布', 'en': 'Daily Focus Duration'},
    'screens.stats.completionTimeline': {'zh': '任务完成时间分布', 'en': 'Completion Timeline'},
    'screens.stats.totalItems': {'zh': '共计 {{count}} 项', 'en': '{{count}} items total'},
    'screens.stats.peakTime': {'zh': '峰值在 {{hour}} 点 ({{block}})', 'en': 'Peak at {{hour}}:00 ({{block}})'},
    'screens.stats.deviationAnalysis': {'zh': '预估偏差分析', 'en': 'Deviation Analysis'},
    'screens.stats.viewDetails': {'zh': '查看明细', 'en': 'View Details'},
    'screens.stats.deviationDetails': {'zh': '预估偏差详情', 'en': 'Deviation Details'},
    'screens.stats.deviationTrend': {'zh': '预估偏差趋势', 'en': 'Deviation Trend'},
    'screens.stats.summaryMetrics': {'zh': '汇总指标', 'en': 'Summary Metrics'},
    'screens.stats.onTime': {'zh': '准时', 'en': 'On Time'},
    'screens.stats.itemCount': {'zh': '{{count}}项', 'en': '{{count}} items'},
    'screens.stats.delayed': {'zh': '延后', 'en': 'Delayed'},
    'screens.stats.ahead': {'zh': '提前', 'en': 'Ahead'},
    'screens.stats.avgDeviation': {'zh': '平均偏差', 'en': 'Avg Deviation'},
    'screens.stats.maxDelay': {'zh': '最大延后', 'en': 'Max Delay'},
    'screens.stats.maxAhead': {'zh': '最大提前', 'en': 'Max Ahead'},
    'screens.stats.deviationDistribution': {'zh': '偏差分布 (时段)', 'en': 'Deviation Distribution'},
    'screens.stats.ahead6': {'zh': '提前6时段', 'en': 'Ahead 6'},
    'screens.stats.onTime0': {'zh': '准时', 'en': 'On Time'},
    'screens.stats.delayed6': {'zh': '延后6时段', 'en': 'Late 6'},
    'screens.stats.blockPlanVsActual': {'zh': '各时段计划 vs 实际', 'en': 'Plan vs Actual by Block'},
    'screens.stats.actualVsPlan': {'zh': '实际 / 计划', 'en': 'Actual / Plan'},
    'screens.stats.dailyDeviationSource': {'zh': '每日偏差数据源', 'en': 'Daily Deviation Source'},
    'screens.stats.tagDeviationOverTime': {'zh': '各标签偏差随时间变化', 'en': 'Tag Deviation Trend'},
    'screens.stats.tagDeviationSummary': {'zh': '各标签当前平均偏差', 'en': 'Tag Deviation Summary'},
    'screens.stats.avgDelayValue': {'zh': '延后{{value}}', 'en': 'Late {{value}}'},
    'screens.stats.avgAheadValue': {'zh': '提前{{value}}', 'en': 'Ahead {{value}}'},
    'screens.stats.itemsAnalysed': {'zh': '分析了{{count}}项任务', 'en': 'Analysed {{count}} items'},
    'screens.stats.avgDelay': {'zh': '平均延后', 'en': 'Avg Delay'},
    'screens.stats.avgAhead': {'zh': '平均提前', 'en': 'Avg Ahead'},
    'screens.stats.completionTimelineDetails': {'zh': '任务完成分布详情', 'en': 'Completion Distribution'},
    'screens.stats.totalDone': {'zh': '累计完成', 'en': 'Total Done'},
    'screens.stats.morningDone': {'zh': '上午完成', 'en': 'Morning Done'},
    'screens.stats.afternoonDone': {'zh': '下午完成', 'en': 'Afternoon Done'},
    'screens.stats.nightDone': {'zh': '夜晚完成', 'en': 'Night Done'},
    'screens.stats.dailyCompletionCount': {'zh': '{{period}}每日完成数', 'en': 'Daily Completion in {{period}}'},
    'screens.stats.hourlyCompletionDetails': {'zh': '各小时明细', 'en': 'Hourly Details'},
    'screens.stats.focusStatsDetails': {'zh': '专注统计详情', 'en': 'Focus Stats Details'},
    'screens.stats.dailyFocusDurationPeriod': {'zh': '{{period}}每日专注时长', 'en': 'Daily Focus in {{period}}'},
    'screens.stats.minutes': {'zh': '分钟', 'en': 'Minutes'},
    'screens.stats.tagDailyFocusCompare': {'zh': '各标签日专注对比', 'en': 'Tag Focus Comparison'},
    'screens.stats.tagFocusDetails': {'zh': '各标签专注明细', 'en': 'Tag Focus Details'},
    'screens.stats.totalFocusTime': {'zh': '累计专注: {{value}}', 'en': 'Total: {{value}}'},
    'time.day': {'zh': '{{count}}天', 'en': '{{count}}d'},
  };

  await _inject('assets/i18n/zh.json', newTranslations, 'zh');
  await _inject('assets/i18n/en.json', newTranslations, 'en');
}

Future<void> _inject(String path, Map<String, Map<String, String>> translations, String lang) async {
  final file = File(path);
  final jsonStr = await file.readAsString();
  final Map<String, dynamic> data = jsonDecode(jsonStr);

  translations.forEach((key, values) {
    final value = values[lang] ?? values['en']!;
    _setNestedValue(data, key, value);
  });

  final encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(data));
  print('✅ Injected ${translations.length} keys into $path');
}

void _setNestedValue(Map<String, dynamic> data, String path, String value) {
  final keys = path.split('.');
  Map<String, dynamic> current = data;
  for (int i = 0; i < keys.length - 1; i++) {
    final key = keys[i];
    if (!current.containsKey(key)) {
      current[key] = <String, dynamic>{};
    }
    current = current[key];
  }
  current[keys.last] = value;
}
