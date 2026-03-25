import '../services/i18n_manager.dart';

/// 核心展示协议 (Display Protocol)
/// 定义 UI 上所有合法的翻译展示位置 (Slots)
enum UIField {
  // Stats Screen
  statsTitle,
  vitalityAnalysis,
  completionRate,
  tagCompletion,
  totalCompletion,
  focusTime,
  quantity,
  showTime,
  byRank,
  byAlpha,
  statsTotal,
  completionRateLabel,
  focusRateLabel,
  statsToday,
  statsWeek,
  statsMonth,
  statsYear,
  calendarTab,
  weekCalTab,
  monthCalTab,
  yearCalTab,
  byRankLabel,
  byAlphaLabel,
  statsNewActiveTags,
  
  // Smart Plan / Today
  today,
  tomorrow,
  smartPlanTitle,
  smartPlanMetricTodayDone,
  smartPlanMetricLoad,
  smartPlanMetricTrend,
  smartPlanMetricFlow,
  smartPlanMetricHabit,
  smartPlanMetricReminder,
  smartPlanPsychologyAnalysis,
  smartPlanScreenUsageDistribution,
  smartPlanImprovementAdvice,
  smartPlanInsightOverview,
  smartPlanFindings,
  smartPlanEfficiencyIndex,
  smartPlanProcrastinationIndex,
  smartPlanBlockDistribution,
  smartPlanDisposableTime,
  smartPlanLoadingUsage,
  smartPlanScreenCross,
  smartPlanFlowAnalysis,
  smartPlanTotalItems,
  smartPlanMetricOverload,
  smartPlanMetricModerate,
  smartPlanMetricTrendUp,
  smartPlanMetricTrendDown,
  smartPlanGreetingNight,
  smartPlanScheduleBtn,
  smartPlanViewFullAnalysis,
  smartPlanViewDetail,
  
  // Share Card
  shareCardPeriod,
  shareCardToday,
  shareCardFullVersion,
  shareCardGenerating,
  shareCardSaveShare,
  shareCardRenderFailed,
  shareCardShareFailed,
  shareCardTodayTasks,
  shareCardTasksOverview,
  shareCardDoneCount,
  shareCardPendingCount,
  shareCardVitality,
  shareCardDoneTime,
  shareCardTagDistribution,
  shareCardDeviation,
  shareCardIgnoreStats,
  shareCardHabitTracking,
  shareCardPomAnalysis,
  shareCardAiSummary,
  
  // Pomodoro
  pomodoro,
  focusComplete,
  breakComplete,
  environmentNoise,
  qualityQuestion,
  focusTimes,
  totalTime,
  avgQuality,
  recentTrend,
  maxDelay,
  maxEarly,
  flowStateDeep,
  flowStateFocused,
  flowStateEntering,
  flowStateWarmingUp,
  flowIndex,
  flowMetricContinuous,
  flowMetricFocus,
  flowMetricDepth,
  flowMetricNoDistraction,
  
  // Common
  ok,
  cancel,
  save,
  delete,
  error,
}

/// 密封页面状态类 (Sealed States)
/// 强制编译器检查是否处理了所有页面/主题逻辑
sealed class PageState {}
class StatsPageState extends PageState {
  final String period; // today, week, month, year
  StatsPageState(this.period);
}
class SmartPlanPageState extends PageState {}
class ShareCardPageState extends PageState {
  final String period;
  ShareCardPageState(this.period);
}
class PomodoroPageState extends PageState {
  final bool isBreaking;
  PomodoroPageState(this.isBreaking);
}

/// Headless UI 适配器 (Display Adapter)
/// 业务逻辑变量与 UI 展示字段的物理脱钩层
class DisplayAdapter {
  static I18nManager get i18n => I18nManager.instance;

  /// 核心映射逻辑：将业务状态“翻译”成展示内容
  static Map<UIField, String> getDisplayData(PageState state) {
    final Map<UIField, String> data = {};

    switch (state) {
      case StatsPageState s:
        data[UIField.statsTitle] = i18n.get('screens.stats.title');
        data[UIField.vitalityAnalysis] = i18n.get('screens.stats.vitalityAnalysis');
        data[UIField.completionRate] = i18n.get('screens.stats.completionRate');
        data[UIField.tagCompletion] = i18n.get('screens.stats.tagCompletion');
        data[UIField.totalCompletion] = i18n.get('screens.stats.totalCompletion');
        data[UIField.focusTime] = i18n.get('screens.stats.focusTime');
        data[UIField.quantity] = i18n.get('screens.stats.quantity');
        data[UIField.showTime] = i18n.get('screens.stats.time');
        data[UIField.byRank] = i18n.get('screens.stats.byRank');
        data[UIField.byAlpha] = i18n.get('screens.stats.byAlpha');
        data[UIField.statsTotal] = i18n.get('screens.stats.total');
        data[UIField.completionRateLabel] = i18n.get('screens.stats.completionRateLabel');
        data[UIField.focusRateLabel] = i18n.get('screens.stats.focusRateLabel');
        data[UIField.statsToday] = i18n.get('screens.stats.today');
        data[UIField.statsWeek] = i18n.get('screens.stats.week');
        data[UIField.statsMonth] = i18n.get('screens.stats.month');
        data[UIField.statsYear] = i18n.get('screens.stats.year');
        data[UIField.calendarTab] = i18n.get('screens.stats.calendar');
        data[UIField.weekCalTab] = i18n.get('screens.stats.weekCal');
        data[UIField.monthCalTab] = i18n.get('screens.stats.monthCal');
        data[UIField.yearCalTab] = i18n.get('screens.stats.yearCal');
        data[UIField.statsNewActiveTags] = i18n.get('screens.statsNew.activeTags');
        break;

      case SmartPlanPageState _:
        data[UIField.smartPlanTitle] = i18n.get('screens.today.smartPlan.title');
        data[UIField.smartPlanMetricTodayDone] = i18n.get('screens.today.smartPlan.metricTodayDone');
        data[UIField.smartPlanMetricLoad] = i18n.get('screens.today.smartPlan.metricLoad');
        data[UIField.smartPlanMetricTrend] = i18n.get('screens.today.smartPlan.metricTrend');
        data[UIField.smartPlanMetricFlow] = i18n.get('screens.today.smartPlan.metricFlow');
        data[UIField.smartPlanMetricHabit] = i18n.get('screens.today.smartPlan.metricHabit');
        data[UIField.smartPlanMetricReminder] = i18n.get('screens.today.smartPlan.metricReminder');
        data[UIField.smartPlanPsychologyAnalysis] = i18n.get('screens.today.smartPlan.psychologyAnalysis');
        data[UIField.smartPlanScreenUsageDistribution] = i18n.get('screens.today.smartPlan.screenUsageDistribution');
        data[UIField.smartPlanImprovementAdvice] = i18n.get('screens.today.smartPlan.improvementAdvice');
        data[UIField.smartPlanInsightOverview] = i18n.get('screens.today.smartPlan.insightOverview');
        data[UIField.smartPlanEfficiencyIndex] = i18n.get('screens.today.smartPlan.efficiencyIndex');
        data[UIField.smartPlanProcrastinationIndex] = i18n.get('screens.today.smartPlan.procrastinationIndex');
        data[UIField.smartPlanBlockDistribution] = i18n.get('screens.today.smartPlan.blockDistribution');
        data[UIField.smartPlanDisposableTime] = i18n.get('screens.today.smartPlan.disposableTime');
        data[UIField.smartPlanLoadingUsage] = i18n.get('screens.today.smartPlan.loadingUsage');
        data[UIField.smartPlanScreenCross] = i18n.get('screens.today.smartPlan.screenCross');
        data[UIField.smartPlanFlowAnalysis] = i18n.get('screens.today.smartPlan.flowAnalysis');
        data[UIField.smartPlanMetricOverload] = i18n.get('screens.today.smartPlan.metricOverload');
        data[UIField.smartPlanMetricModerate] = i18n.get('screens.today.smartPlan.metricModerate');
        data[UIField.smartPlanMetricTrendUp] = i18n.get('screens.today.smartPlan.metricTrendUp');
        data[UIField.smartPlanMetricTrendDown] = i18n.get('screens.today.smartPlan.metricTrendDown');
        data[UIField.smartPlanGreetingNight] = i18n.get('screens.today.smartPlan.greetings.night');
        data[UIField.smartPlanScheduleBtn] = i18n.get('screens.today.smartPlan.scheduleBtn');
        data[UIField.smartPlanViewFullAnalysis] = i18n.get('screens.today.smartPlan.viewFullAnalysis');
        data[UIField.smartPlanViewDetail] = i18n.get('screens.today.smartPlan.viewDetail');
        break;

      case ShareCardPageState s:
        data[UIField.shareCardToday] = i18n.get('widgets.shareCard.shareToday');
        data[UIField.shareCardFullVersion] = i18n.get('widgets.shareCard.fullVersion');
        data[UIField.shareCardGenerating] = i18n.get('widgets.shareCard.generating');
        data[UIField.shareCardSaveShare] = i18n.get('widgets.shareCard.saveShare');
        data[UIField.shareCardTodayTasks] = i18n.get('widgets.shareCard.todayTasks');
        data[UIField.shareCardTasksOverview] = i18n.get('widgets.shareCard.tasksOverview');
        data[UIField.shareCardVitality] = i18n.get('widgets.shareCard.vitality');
        data[UIField.shareCardDoneTime] = i18n.get('widgets.shareCard.doneTime');
        data[UIField.shareCardTagDistribution] = i18n.get('widgets.shareCard.tagDistribution');
        data[UIField.shareCardDeviation] = i18n.get('widgets.shareCard.deviation');
        data[UIField.shareCardIgnoreStats] = i18n.get('widgets.shareCard.ignoreStats');
        data[UIField.shareCardHabitTracking] = i18n.get('widgets.shareCard.habitTracking');
        data[UIField.shareCardPomAnalysis] = i18n.get('widgets.shareCard.pomAnalysis');
        data[UIField.shareCardAiSummary] = i18n.get('widgets.shareCard.aiSummary');
        break;

      case PomodoroPageState p:
        data[UIField.pomodoro] = i18n.get('screens.pomodoro.title');
        data[UIField.focusComplete] = i18n.get('screens.pomodoro.focusComplete');
        data[UIField.breakComplete] = i18n.get('screens.pomodoro.breakComplete');
        data[UIField.qualityQuestion] = i18n.get('screens.pomodoro.qualityQuestion');
        data[UIField.focusTimes] = i18n.get('screens.pomHistory.focusTimes');
        data[UIField.totalTime] = i18n.get('screens.pomHistory.totalTime');
        data[UIField.avgQuality] = i18n.get('screens.pomHistory.avgQuality');
        data[UIField.recentTrend] = i18n.get('screens.pomHistory.recentTrend');
        data[UIField.maxDelay] = i18n.get('screens.pomHistory.maxDelay');
        data[UIField.maxEarly] = i18n.get('screens.pomHistory.maxEarly');
        data[UIField.flowStateDeep] = i18n.get('screens.pomodoro.flowStateDeep');
        data[UIField.flowStateFocused] = i18n.get('screens.pomodoro.flowStateFocused');
        data[UIField.flowStateEntering] = i18n.get('screens.pomodoro.flowStateEntering');
        data[UIField.flowStateWarmingUp] = i18n.get('screens.pomodoro.flowStateWarmingUp');
        data[UIField.flowIndex] = i18n.get('screens.pomodoro.flowIndex');
        data[UIField.flowMetricContinuous] = i18n.get('screens.pomodoro.flowMetricContinuous');
        data[UIField.flowMetricFocus] = i18n.get('screens.pomodoro.flowMetricFocus');
        data[UIField.flowMetricDepth] = i18n.get('screens.pomodoro.flowMetricDepth');
        data[UIField.flowMetricNoDistraction] = i18n.get('screens.pomodoro.flowMetricNoDistraction');
        break;
    }

    // 强制审计：严禁漏填或非法内容泄露到 UI
    _validate(data);
    return data;
  }

  /// 审计拦截器 (Registry Audit)
  static void _validate(Map<UIField, String> data) {
    // 获取当前状态对应的所有预期字段（基于 switch case 的反向检查）
    // 在复杂生产环境下可以维护一个 PageState -> List<UIField> 的映射表
    // 这里采用更直观的逐项检查
    
    for (var entry in data.entries) {
      final field = entry.key;
      final content = entry.value;

      // 1. 检查是否存在漏填或空值
      if (content.isEmpty) {
        _reportError(field, "内容为空！");
      }

      // 2. 检查是否包含中间变量特征（防止 Leak）
      if (content.contains('.') || (content.startsWith('[') && content.endsWith(']'))) {
        _reportError(field, "检测到原始变量键名泄露 -> '$content'");
      }
      
      // 3. 检查是否包含未处理的插值占位符 (e.g. {{count}})
      if (content.contains('{{') && content.contains('}}')) {
        _reportError(field, "检测到未处理的插值占位符 -> '$content'");
      }
    }
  }

  static void _reportError(UIField field, String msg) {
    final errorMsg = "🛑 [I18n Registry Audit] 字段 ${field.name} $msg";
    
    // 开发环境下直接抛出异常，强制修复
    assert(() {
      throw Exception(errorMsg);
    }());
    
    // 生产环境下记录日志并回退到体面的提示，而不是空白
    print(errorMsg);
  }
}

/// 集中的本地化/翻译访问门面
/// 兼容旧代码，但推荐逐步迁移到 DisplayAdapter
class L {
  static I18nManager get i18n => I18nManager.instance;

  /// 初始化i18n系统（在main()中调用）
  static Future<void> init(String? initialLang) async {
    await i18n.init(initialLang);
  }

  /// 动态设置语言
  static void setLanguage(String lang) {
    i18n.setLanguage(lang);
  }

  /// 通用get方法（支持参数插值）
  static String get(String key, [Map<String, dynamic>? params]) {
    return i18n.get(key, params);
  }

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                      TODAY SCREEN                         ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get today => i18n.get('screens.today.title');
  static String get tomorrow => i18n.get('screens.today.tomorrow');
  static String get addHint => i18n.get('screens.today.addHint');
  static String get addTomorrow => i18n.get('screens.today.addTomorrow');
  static String get todayShare => i18n.get('screens.today.share');
  static String get unassigned => i18n.get('screens.today.unassigned');
  static String get overdue => i18n.get('screens.today.overdue');
  static String get overdueFree => i18n.get('screens.today.overdueFree');
  static String get unassignedHint => i18n.get('screens.today.unassignedHint');
  static String get cancelAssign => i18n.get('screens.today.cancelAssign');
  static String get selectingHint => i18n.get('screens.today.selectingHint');
  static String get smartPlan => i18n.get('screens.today.smartPlan.title');
  static String overdueItems(int count) => i18n.get('screens.today.overdueItems', {'count': count.toString()});
  static String get overdueHint => i18n.get('screens.today.overdueHint');
  static String overdueSince(String date) => i18n.get('screens.today.overdueSince', {'date': date});
  static String get dropHere => i18n.get('screens.today.dropHere');
  static String get dragOrAdd => i18n.get('screens.today.dragOrAdd');
  static String targetPool(String emoji, String name) => i18n.get('screens.today.targetPool', {'emoji': emoji, 'name': name});

  // Smart Plan
  static String get smartPlanTitle => i18n.get('screens.today.smartPlan.title');
  static String smartPlanItemsToSchedule(int count) => i18n.get('screens.today.smartPlan.itemsToSchedule', {'count': count.toString()});
  static String get smartPlanViewDetail => i18n.get('screens.today.smartPlan.viewDetail');
  static String get smartPlanScheduleBtn => i18n.get('screens.today.smartPlan.scheduleBtn');
  static String smartPlanAllScheduled(int count) => i18n.get('screens.today.smartPlan.allScheduled', {'count': count.toString()});
  static String smartPlanScheduleAll(int count) => i18n.get('screens.today.smartPlan.scheduleAll', {'count': count.toString()});
  static String get smartPlanMetricTodayDone => i18n.get('screens.today.smartPlan.metricTodayDone');
  static String get smartPlanMetricLoad => i18n.get('screens.today.smartPlan.metricLoad');
  static String get smartPlanMetricOverload => i18n.get('screens.today.smartPlan.metricOverload');
  static String get smartPlanMetricModerate => i18n.get('screens.today.smartPlan.metricModerate');
  static String get smartPlanMetricTrend => i18n.get('screens.today.smartPlan.metricTrend');
  static String get smartPlanMetricTrendUp => i18n.get('screens.today.smartPlan.metricTrendUp');
  static String get smartPlanMetricTrendDown => i18n.get('screens.today.smartPlan.metricTrendDown');
  static String get smartPlanMetricToSchedule => i18n.get('screens.today.smartPlan.metricToSchedule');
  static String get smartPlanMetricOptimizable => i18n.get('screens.today.smartPlan.metricOptimizable');
  static String get smartPlanMetricHabit => i18n.get('screens.today.smartPlan.metricHabit');
  static String get smartPlanMetricReminder => i18n.get('screens.today.smartPlan.metricReminder');
  static String get smartPlanMetricFlow => i18n.get('screens.today.smartPlan.metricFlow');
  static String get smartPlanMetricFlowUp => i18n.get('screens.today.smartPlan.metricFlowUp');
  static String get smartPlanMetricFlowLow => i18n.get('screens.today.smartPlan.metricFlowLow');
  static String get smartPlanMetricFlowStable => i18n.get('screens.today.smartPlan.metricFlowStable');
  static String get smartPlanViewFullAnalysis => i18n.get('screens.today.smartPlan.viewFullAnalysis');
  static String get smartPlanDetailTitle => i18n.get('screens.today.smartPlan.detailTitle');
  static String get smartPlanClickRobot => i18n.get('screens.today.smartPlan.clickRobot');
  static String get smartPlanGiveAdvice => i18n.get('screens.today.smartPlan.giveAdvice');
  static String get smartPlanOneClickPlan => i18n.get('screens.today.smartPlan.oneClickPlan');
  static String smartPlanScheduledMsg(int count) => i18n.get('screens.today.smartPlan.scheduledMsg', {'count': count.toString()});
  static String get smartPlanEfficiencyIndex => i18n.get('screens.today.smartPlan.efficiencyIndex');
  static String get smartPlanProcrastinationIndex => i18n.get('screens.today.smartPlan.procrastinationIndex');
  static String get smartPlanBlockDistribution => i18n.get('screens.today.smartPlan.blockDistribution');
  static String get smartPlanDisposableTime => i18n.get('screens.today.smartPlan.disposableTime');
  static String smartPlanDisposableTimeDesc(double hours) => i18n.get('screens.today.smartPlan.disposableTimeDesc', {'hours': hours.toStringAsFixed(1)});
  static String get smartPlanDisposableTimeAdjust => i18n.get('screens.today.smartPlan.disposableTimeAdjust');
  static String get smartPlanInsightTask => i18n.get('screens.today.smartPlan.insightTask');
  static String get smartPlanInsightCross => i18n.get('screens.today.smartPlan.insightCross');
  static String get smartPlanLoadingUsage => i18n.get('screens.today.smartPlan.loadingUsage');
  static String get smartPlanScreenCross => i18n.get('screens.today.smartPlan.screenCross');
  static String smartPlanFindings(int count) => i18n.get('screens.today.smartPlan.findings', {'count': count.toString()});
  static String get smartPlanScreenUsageDistribution => i18n.get('screens.today.smartPlan.screenUsageDistribution');
  static String get smartPlanScreenTaskInsight => i18n.get('screens.today.smartPlan.screenTaskInsight');
  static String get smartPlanDisclaimer => i18n.get('screens.today.smartPlan.disclaimer');
  static String get smartPlanImprovementAdvice => i18n.get('screens.today.smartPlan.improvementAdvice');
  static String get smartPlanPsychologyAnalysis => i18n.get('screens.today.smartPlan.psychologyAnalysis');
  static String get smartPlanTaskEfficiencyInsight => i18n.get('screens.today.smartPlan.taskEfficiencyInsight');
  static String get smartPlanInsightOverview => i18n.get('screens.today.smartPlan.insightOverview');
  static String get smartPlanHighConfidence => i18n.get('screens.today.smartPlan.highConfidence');
  static String get smartPlanMedConfidence => i18n.get('screens.today.smartPlan.medConfidence');
  static String get smartPlanLowConfidence => i18n.get('screens.today.smartPlan.lowConfidence');
  static String get smartPlanSourceDistribution => i18n.get('screens.today.smartPlan.sourceDistribution');
  static String get smartPlanSourceTask => i18n.get('screens.today.smartPlan.sourceTask');
  static String get smartPlanSourceCrossTask => i18n.get('screens.today.smartPlan.sourceCrossTask');
  static String get smartPlanSourceTrend => i18n.get('screens.today.smartPlan.sourceTrend');
  static String get smartPlanSourceScreen => i18n.get('screens.today.smartPlan.sourceScreen');
  static String get smartPlanSourceScreenTask => i18n.get('screens.today.smartPlan.sourceScreenTask');
  static String get smartPlanFlowAnalysis => i18n.get('screens.today.smartPlan.flowAnalysis');
  static String get smartPlanFlowLast14Days => i18n.get('screens.today.smartPlan.flowLast14Days');
  static String smartPlanUpdatedHours(String hours) => i18n.get('screens.today.smartPlan.updatedHours', {'hours': hours});
  static String get smartPlanApplyAISuggestion => i18n.get('screens.today.smartPlan.applyAISuggestion');
  static String get smartPlanTaskScheduleAdvice => i18n.get('screens.today.smartPlan.taskScheduleAdvice');
  static String smartPlanTotalItems(int count) => i18n.get('screens.today.smartPlan.totalItems', {'count': count.toString()});
  
  // Quadrant
  static String get quadQ1Name => i18n.get('screens.quadrant.q1_name');
  static String get quadQ1Sub => i18n.get('screens.quadrant.q1_sub');
  static String get quadQ2Name => i18n.get('screens.quadrant.q2_name');
  static String get quadQ2Sub => i18n.get('screens.quadrant.q2_sub');
  static String get quadQ3Name => i18n.get('screens.quadrant.q3_name');
  static String get quadQ3Sub => i18n.get('screens.quadrant.q3_sub');
  static String get quadQ4Name => i18n.get('screens.quadrant.q4_name');
  static String get quadQ4Sub => i18n.get('screens.quadrant.q4_sub');
  static String get quadUnassigned => i18n.get('screens.quadrant.unassigned');
  static String get quadDragToQuad => i18n.get('screens.quadrant.dragToQuad');
  static String get quadNoUnassigned => i18n.get('screens.quadrant.noUnassigned');
  static String get quadAllAssigned => i18n.get('screens.quadrant.allAssigned');
  static String get quadDropBack => i18n.get('screens.quadrant.dropBack');
  static String get quadIgnore => i18n.get('screens.quadrant.ignore');
  static String get quadDropToHide => i18n.get('screens.quadrant.dropToHide');
  static String get quadDrop => i18n.get('screens.quadrant.drop');
  static String quadDoneToday(int count) => i18n.get('screens.quadrant.doneToday', {'count': count.toString()});

  // Share Card
  static String shareCardPeriod(String period) => i18n.get('widgets.shareCard.sharePeriod', {'period': period});
  static String get shareCardToday => i18n.get('widgets.shareCard.shareToday');
  static String get shareCardFullVersion => i18n.get('widgets.shareCard.fullVersion');
  static String get shareCardGenerating => i18n.get('widgets.shareCard.generating');
  static String get shareCardSaveShare => i18n.get('widgets.shareCard.saveShare');
  static String get shareCardRenderFailed => i18n.get('widgets.shareCard.renderFailed');
  static String get shareCardShareFailed => i18n.get('widgets.shareCard.shareFailed');
  static String shareCardError(String error) => i18n.get('widgets.shareCard.screenshotError', {'error': error});
  static String get shareCardTodayTasks => i18n.get('widgets.shareCard.todayTasks');
  static String get shareCardTargetDayTasks => i18n.get('widgets.shareCard.targetDayTasks');
  static String shareCardPeriodOverview(String period) => i18n.get('widgets.shareCard.periodOverview', {'period': period});
  static String get shareCardTasksOverview => i18n.get('widgets.shareCard.tasksOverview');
  static String shareCardDoneCount(int count) => i18n.get('widgets.shareCard.doneCount', {'count': count.toString()});
  static String shareCardPendingCount(int count) => i18n.get('widgets.shareCard.pendingCount', {'count': count.toString()});
  static String get shareCardNoTasks => i18n.get('widgets.shareCard.noTasks');
  static String get shareCardStatsGlobal => i18n.get('widgets.shareCard.statsGlobal');
  static String get shareCardHistoryTasks => i18n.get('widgets.shareCard.historyTasks');
  static String get shareCardTagTotal => i18n.get('widgets.shareCard.tagTotal');
  static String shareCardCompletionStats(String period) => i18n.get('widgets.shareCard.completionStats', {'period': period});
  static String get shareCardDone => i18n.get('widgets.shareCard.done');
  static String get shareCardNotDone => i18n.get('widgets.shareCard.notDone');
  static String get shareCardVitality => i18n.get('widgets.shareCard.vitality');
  static String get shareCardDoneTime => i18n.get('widgets.shareCard.doneTime');
  static String get shareCardTagDistribution => i18n.get('widgets.shareCard.tagDistribution');
  static String get shareCardTargetDayTag => i18n.get('widgets.shareCard.targetDayTag');
  static String get shareCardTodayTag => i18n.get('widgets.shareCard.todayTag');
  static String get shareCardDeviation => i18n.get('widgets.shareCard.deviation');
  static String get shareCardOnTime => i18n.get('widgets.shareCard.onTime');
  static String shareCardDelayed(String count) => i18n.get('widgets.shareCard.delayed', {'count': count});
  static String shareCardAhead(String count) => i18n.get('widgets.shareCard.ahead', {'count': count});
  static String get shareCardPlanVsActual => i18n.get('widgets.shareCard.planVsActual');
  static String get shareCardIgnoreStats => i18n.get('widgets.shareCard.ignoreStats');
  static String shareCardTotalIgnored(int count) => i18n.get('widgets.shareCard.totalIgnored', {'count': count.toString()});
  static String get shareCardTotalIgnoredLabel => i18n.get('widgets.shareCard.totalIgnoredLabel');
  static String shareCardPeriodIgnored(String period, int count) => i18n.get('widgets.shareCard.periodIgnored', {'period': period, 'count': count.toString()});
  static String get shareCardHabitTracking => i18n.get('widgets.shareCard.habitTracking');
  static String shareCardStreakDays(int count) => i18n.get('widgets.shareCard.streakDays', {'count': count.toString()});
  static String shareCardMonthlyCount(int count) => i18n.get('widgets.shareCard.monthlyCount', {'count': count.toString()});
  static String get shareCardPomAnalysis => i18n.get('widgets.shareCard.pomAnalysis');
  static String shareCardPomCount(int count) => i18n.get('widgets.shareCard.pomCount', {'count': count.toString()});
  static String get shareCardPeriodSummary => i18n.get('widgets.shareCard.periodSummary');
  static String get shareCardVitalityInsight => i18n.get('widgets.shareCard.vitalityInsight');
  static String get shareCardTimeEfficiency => i18n.get('widgets.shareCard.timeEfficiency');
  static String get shareCardOverallGrade => i18n.get('widgets.shareCard.overallGrade');
  static String get shareCardAiSummary => i18n.get('widgets.shareCard.aiSummary');
  static String shareCardTagline(String date) => i18n.get('widgets.shareCard.tagline', {'date': date});
  static String smartPlanMetricToScheduleValue(int count) => i18n.get('screens.today.smartPlan.metricToScheduleValue', {'count': count.toString()});
  static String smartPlanMetricCurrentHours(String hours) => i18n.get('screens.today.smartPlan.metricCurrentHours', {'hours': hours});
  static String get smartPlanFestivalDragonBoat => i18n.get('screens.today.smartPlan.festivalDragonBoat');
  static String get smartPlanFestivalNewYear => i18n.get('screens.today.smartPlan.festivalNewYear');
  static String get smartPlanFestivalMidAutumn => i18n.get('screens.today.smartPlan.festivalMidAutumn');
  static String get smartPlanFestivalWaterDay => i18n.get('screens.today.smartPlan.festivalWaterDay');
  static String smartPlanFestivalDefault(String emoji, String name, String tagline) => i18n.get('screens.today.smartPlan.festivalDefault', {'emoji': emoji, 'name': name, 'tagline': tagline});
  static String get smartPlanConfHigh => i18n.get('screens.today.smartPlan.confHigh');
  static String get smartPlanConfMed => i18n.get('screens.today.smartPlan.confMed');
  static String get smartPlanConfLow => i18n.get('screens.today.smartPlan.confLow');
  static String get smartPlanConfLabel => i18n.get('screens.today.smartPlan.confLabel');
  static String get smartPlanScreenTimeDistribution => i18n.get('screens.today.smartPlan.screenTimeDistribution');
  static String get smartPlanEfficiency => i18n.get('screens.today.smartPlan.efficiency');
  static String get smartPlanWorkStudy => i18n.get('screens.today.smartPlan.workStudy');
  static String get smartPlanEntertainment => i18n.get('screens.today.smartPlan.entertainment');
  static String get smartPlanFocus => i18n.get('screens.today.smartPlan.focus');
  static String smartPlanFocusValue(String hours) => i18n.get('screens.today.smartPlan.focusValue', {'hours': hours});
  static String get smartPlanNoData => i18n.get('screens.today.smartPlan.noData');
  static String get smartPlanMorning => i18n.get('screens.today.smartPlan.morning');
  static String get smartPlanAfternoon => i18n.get('screens.today.smartPlan.afternoon');
  static String get smartPlanEvening => i18n.get('screens.today.smartPlan.evening');

  static List<String> get smartPlanSoups => List<String>.from(i18n.getRaw('screens.today.smartPlan.soups') ?? []);
  static List<String> get smartPlanAdvice => List<String>.from(i18n.getRaw('screens.today.smartPlan.advice') ?? []);

  static String smartPlanGreetingAllDone(int count, int mins) => i18n.get('screens.today.smartPlan.greetings.allDone', {'count': count.toString(), 'mins': mins.toString()});
  static String smartPlanGreetingStreak(int days) => i18n.get('screens.today.smartPlan.greetings.streak', {'days': days.toString()});
  static String smartPlanGreetingMorning(int count) => i18n.get('screens.today.smartPlan.greetings.morning', {'count': count.toString()});
  static String smartPlanGreetingAfternoon(int done, int total) => i18n.get('screens.today.smartPlan.greetings.afternoon', {'done': done.toString(), 'total': total.toString()});
  static String smartPlanGreetingEvening(int count) => i18n.get('screens.today.smartPlan.greetings.evening', {'count': count.toString()});
  static String get smartPlanGreetingNight => i18n.get('screens.today.smartPlan.greetings.night');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                      STATS SCREEN                        ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get stats => i18n.get('screens.stats.title');
  static String get statsToday => i18n.get('screens.stats.today');
  static String get statsWeek => i18n.get('screens.stats.week');
  static String get statsMonth => i18n.get('screens.stats.month');
  static String get statsYear => i18n.get('screens.stats.year');
  
  static String statsPeriodDone(String period) => 
    i18n.get('screens.stats.periodDone', {'period': period});
  static String statsPeriodNew(String period) => 
    i18n.get('screens.stats.periodNew', {'period': period});
  static String get statsActiveTags => i18n.get('screens.stats.activeTags');

  static String statsDateFormat(int year, int month, int day) => 
    i18n.get('screens.stats.dateFormat', {'year': year, 'month': month, 'day': day});
  static String statsWeekFormat(int year, int week) => 
    i18n.get('screens.stats.weekFormat', {'year': year, 'week': week});
  static String statsMonthFormat(int year, int month) => 
    i18n.get('screens.stats.monthFormat', {'year': year, 'month': month});
  static String statsYearFormat(int year) => 
    i18n.get('screens.stats.yearFormat', {'year': year});
  static String statsDayOfYear(int day, int week) => 
    i18n.get('screens.stats.dayOfYear', {'day': day, 'week': week});

  static String get calendarTab => i18n.get('screens.stats.calendar');
  static String get weekCalTab => i18n.get('screens.stats.weekCal');
  static String get monthCalTab => i18n.get('screens.stats.monthCal');
  static String get yearCalTab => i18n.get('screens.stats.yearCal');
  static String get vitalityAnalysis => i18n.get('screens.stats.vitalityAnalysis');
  static String get statsCompletionRateByBlock => i18n.get('screens.stats.completionRateByBlock');
  static String statsInsightLowestRate(String emoji, String blockName) => 
    i18n.get('screens.stats.insightLowestRate', {'emoji': emoji, 'blockName': blockName});
  static String statsInsightBestVitality(String blockName, int count) => 
    i18n.get('screens.stats.insightBestVitality', {'blockName': blockName, 'count': count});

  static String get completionRate => i18n.get('screens.stats.completionRate');
  static String get tagCompletion => i18n.get('screens.stats.tagCompletion');
  static String get statsByCount => i18n.get('screens.stats.byCount');
  static String get statsByTime => i18n.get('screens.stats.byTime');
  static String statsPeriod(String period) => i18n.get('screens.stats.period', {'period': period});

  static String get totalCompletion => i18n.get('screens.stats.totalCompletion');
  static String get statsFocusTime => i18n.get('screens.stats.focusTime');
  static String get statsFocusTimeStats => i18n.get('screens.stats.focusTimeStats');
  static String get statsDetails => i18n.get('screens.stats.details');
  static String get statsNoTasksOnDate => i18n.get('screens.stats.noTasksOnDate');
  static String get statsAddTaskOnDate => i18n.get('screens.stats.addTaskOnDate');
  static String get statsLogSomething => i18n.get('screens.stats.logSomething');
  static String get statsMarkAsDone => i18n.get('screens.stats.markAsDone');
  static String get statsTotalCompletionRank => i18n.get('screens.stats.totalCompletionRank');
  static String get statsPomodoroStats => i18n.get('screens.stats.pomodoroStats');
  static String statsPeriodFocus(String period) => i18n.get('screens.stats.periodFocus', {'period': period});
  static String get statsFocusedTasks => i18n.get('screens.stats.focusedTasks');
  static String get statsTotalFocus => i18n.get('screens.stats.totalFocus');
  static String get statsDailyFocusDuration => i18n.get('screens.stats.dailyFocusDuration');
  static String get statsCompletionTimeline => i18n.get('screens.stats.completionTimeline');
  static String statsTotalItems(int count) => i18n.get('screens.stats.totalItems', {'count': count});
  static String statsPeakTime(int hour, String block) => i18n.get('screens.stats.peakTime', {'hour': hour, 'block': block});

  static String get statsDeviationAnalysis => i18n.get('screens.stats.deviationAnalysis');
  static String get statsViewDetails => i18n.get('screens.stats.viewDetails');
  static String get statsDeviationDetails => i18n.get('screens.stats.deviationDetails');
  static String get statsDeviationTrend => i18n.get('screens.stats.deviationTrend');
  static String get statsSummaryMetrics => i18n.get('screens.stats.summaryMetrics');
  static String get statsOnTime => i18n.get('screens.stats.onTime');
  static String statsItemCount(int count) => i18n.get('screens.stats.itemCount', {'count': count});
  static String get statsDelayed => i18n.get('screens.stats.delayed');
  static String get statsAhead => i18n.get('screens.stats.ahead');
  static String get statsAvgDeviation => i18n.get('screens.stats.avgDeviation');
  static String get statsMaxDelay => i18n.get('screens.stats.maxDelay');
  static String get statsMaxAhead => i18n.get('screens.stats.maxAhead');
  static String get statsDeviationDistribution => i18n.get('screens.stats.deviationDistribution');
  static String get statsAhead6 => i18n.get('screens.stats.ahead6');
  static String get statsOnTime0 => i18n.get('screens.stats.onTime0');
  static String get statsDelayed6 => i18n.get('screens.stats.delayed6');
  static String get statsBlockPlanVsActual => i18n.get('screens.stats.blockPlanVsActual');
  static String get statsActualVsPlan => i18n.get('screens.stats.actualVsPlan');
  static String get statsDailyDeviationSource => i18n.get('screens.stats.dailyDeviationSource');
  static String get statsTagDeviationOverTime => i18n.get('screens.stats.tagDeviationOverTime');
  static String get statsTagDeviationSummary => i18n.get('screens.stats.tagDeviationSummary');
  static String statsAvgDelayValue(String value) => i18n.get('screens.stats.avgDelayValue', {'value': value});
  static String statsAvgAheadValue(String value) => i18n.get('screens.stats.avgAheadValue', {'value': value});
  static String statsItemsAnalysed(int count) => i18n.get('screens.stats.itemsAnalysed', {'count': count});
  static String get statsAvgDelay => i18n.get('screens.stats.avgDelay');
  static String get statsAvgAhead => i18n.get('screens.stats.avgAhead');
  static String get statsCompletionTimelineDetails => i18n.get('screens.stats.completionTimelineDetails');
  static String get statsTotalDone => i18n.get('screens.stats.totalDone');
  static String get statsMorningDone => i18n.get('screens.stats.morningDone');
  static String get statsAfternoonDone => i18n.get('screens.stats.afternoonDone');
  static String get statsNightDone => i18n.get('screens.stats.nightDone');
  static String statsDailyCompletionCount(String period) => i18n.get('screens.stats.dailyCompletionCount', {'period': period});
  static String get statsHourlyCompletionDetails => i18n.get('screens.stats.hourlyCompletionDetails');
  static String get statsFocusStatsDetails => i18n.get('screens.stats.focusStatsDetails');
  static String statsDailyFocusDurationPeriod(String period) => i18n.get('screens.stats.dailyFocusDurationPeriod', {'period': period});
  static String get statsMinutes => i18n.get('screens.stats.minutes');
  static String get statsTagDailyFocusCompare => i18n.get('screens.stats.tagDailyFocusCompare');
  static String get statsTagFocusDetails => i18n.get('screens.stats.tagFocusDetails');
  static String statsTotalFocusTime(String value) => i18n.get('screens.stats.totalFocusTime', {'value': value});
  static String timeDay(int count) => i18n.get('time.day', {'count': count});

  static String get quantity => i18n.get('screens.stats.quantity');
  static String get showTime => i18n.get('screens.stats.time');
  static String get byRank => i18n.get('screens.stats.byRank');
  static String get byAlpha => i18n.get('screens.stats.byAlpha');
  static String get statsTotal => i18n.get('screens.stats.total');
  static String get completionRateLabel => i18n.get('screens.stats.completionRateLabel');
  static String get focusRateLabel => i18n.get('screens.stats.focusRateLabel');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                  STATS NEW SCREEN                        ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get statsNewTitle => i18n.get('screens.statsNew.title');
  static String get statsNewDay => i18n.get('screens.statsNew.day');
  static String get statsNewWeek => i18n.get('screens.statsNew.week');
  static String get statsNewMonth => i18n.get('screens.statsNew.month');
  static String get statsNewYear => i18n.get('screens.statsNew.year');
  static String get statsNewCompleted => i18n.get('screens.statsNew.completed');
  static String get statsNewTasks => i18n.get('screens.statsNew.newTasks');
  static String get statsNewActiveTags => i18n.get('screens.statsNew.activeTags');
  static String get statsNewFocus => i18n.get('screens.statsNew.focusLabel');
  static String get statsNewAccumulate => i18n.get('screens.statsNew.accumulateFocus');
  static String get statsNewTagRanking => i18n.get('screens.statsNew.tagRanking');
  static String get statsNewTimeDistribution => i18n.get('screens.statsNew.timeDistribution');
  static String get statsNewVitality => i18n.get('screens.statsNew.vitality');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                   QUADRANT SCREEN                        ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get quadrant => i18n.get('screens.quadrant.title');
  static String get importantUrgent => i18n.get('screens.quadrant.important_urgent');
  static String get importantUrgentAction => i18n.get('screens.quadrant.important_urgent_action');
  static String get importantNotUrgent => i18n.get('screens.quadrant.important_notUrgent');
  static String get importantNotUrgentAction => i18n.get('screens.quadrant.important_notUrgent_action');
  static String get notImportantUrgent => i18n.get('screens.quadrant.notImportant_urgent');
  static String get notImportantUrgentAction => i18n.get('screens.quadrant.notImportant_urgent_action');
  static String get notImportantNotUrgent => i18n.get('screens.quadrant.notImportant_notUrgent');
  static String get notImportantNotUrgentAction => i18n.get('screens.quadrant.notImportant_notUrgent_action');
  static String get unclassified => i18n.get('screens.quadrant.unclassified');
  static String get returnBtn => i18n.get('screens.quadrant.returnBtn');
  static String get allClassified => i18n.get('screens.quadrant.allClassified');
  static String get hideBtn => i18n.get('screens.quadrant.hideBtn');
  static String get ignore => i18n.get('screens.quadrant.ignore');
  static String get longPressDrag => i18n.get('screens.quadrant.longPressDrag');
  static String get putIn => i18n.get('screens.quadrant.putIn');
  static String get noUnclassified => i18n.get('screens.quadrant.noUnclassified');
  static String get todayCompleted => i18n.get('screens.quadrant.todayCompleted');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                    SEARCH SCREEN                         ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get searchHint => i18n.get('screens.search.hint');
  static String get searchEmptyHint => i18n.get('screens.search.emptyHint');
  static String searchNoResults(String query) => 
    i18n.get('screens.search.noResults', {'query': query});
  static String searchResultCount(int count) =>
    i18n.get('screens.search.resultCount', {'count': count.toString()});
  static String get searchToday => i18n.get('screens.search.today');
  static String get searchTomorrow => i18n.get('screens.search.tomorrow');
  static String get searchTasksCount => i18n.get('screens.search.tasksCount');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                  POMODORO SCREEN                         ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get pomodoro => i18n.get('screens.pomodoro.title');
  static String get focusComplete => i18n.get('screens.pomodoro.focusComplete');
  static String get breakComplete => i18n.get('screens.pomodoro.breakComplete');
  static String pomFocusMsg(int mins) => 
    i18n.get('screens.pomodoro.focusMsg', {'mins': mins.toString()});
  static String get pomBreakMsg => i18n.get('screens.pomodoro.breakMsg');
  static String pomNoise(String assessment) =>
    i18n.get('screens.pomodoro.environmentNoise', {'assessment': assessment});
  static String get qualityQuestion => i18n.get('screens.pomodoro.qualityQuestion');
  static String get pomQuality1 => i18n.get('screens.pomodoro.quality1');
  static String get pomQuality2 => i18n.get('screens.pomodoro.quality2');
  static String get pomQuality3 => i18n.get('screens.pomodoro.quality3');
  static String get pomQuality4 => i18n.get('screens.pomodoro.quality4');
  static String get pomQuality5 => i18n.get('screens.pomodoro.quality5');
  static String pomRoundCount(int count) =>
    i18n.get('screens.pomodoro.roundCount', {'count': count.toString()});

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║              POMODORO HISTORY SCREEN                     ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get pomHistory => i18n.get('screens.pomHistory.title');
  static String get focusTimes => i18n.get('screens.pomHistory.focusTimes');
  static String get totalTime => i18n.get('screens.pomHistory.totalTime');
  static String get avgQuality => i18n.get('screens.pomHistory.avgQuality');
  static String pomRated(int count) =>
    i18n.get('screens.pomHistory.rated', {'count': count.toString()});
  static String get recentTrend => i18n.get('screens.pomHistory.recentTrend');
  static String pomRecent(int count) =>
    i18n.get('screens.pomHistory.recent', {'count': count.toString()});
  static String get maxDelay => i18n.get('screens.pomHistory.maxDelay');
  static String get maxEarly => i18n.get('screens.pomHistory.maxEarly');
  static String get pomSample => i18n.get('screens.pomHistory.sample');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                  SETTINGS SCREEN                         ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get settings => i18n.get('screens.settings.title');
  static String get appearance => i18n.get('screens.settings.appearance');
  static String get themeColors => i18n.get('screens.settings.themeColors');
  static String get themeColor => i18n.get('screens.settings.themeColor');
  static String get visualCenter => i18n.get('screens.settings.visualCenter');
  static String get visualCenterTitle => i18n.get('screens.settings.visualCenterTitle');
  static String get visualCenterSubtitle => i18n.get('screens.settings.visualCenterSubtitle');
  static String get personalization => i18n.get('screens.settings.personalization');
  static String get seasonalTheme => i18n.get('screens.settings.seasonalTheme');
  static String get currentRecommend => i18n.get('screens.settings.currentRecommend');
  static String get shareReport => i18n.get('screens.settings.shareReport');
  static String get shareCaption => i18n.get('screens.settings.shareCaption');
  static String get clockStyle => i18n.get('screens.settings.clockStyle');
  static String get clockStyleDateDesc => i18n.get('screens.settings.clockStyleDateDesc');
  static String get clockStyleSunArcDesc => i18n.get('screens.settings.clockStyleSunArcDesc');
  static String get clockStyleTimelineLabel => i18n.get('screens.settings.clockStyleTimelineLabel');
  static String get clockStyleTimelineDesc => i18n.get('screens.settings.clockStyleTimelineDesc');
  static String get showTopClock => i18n.get('screens.settings.showTopClock');
  static String get styleSelection => i18n.get('screens.settings.styleSelection');
  static String get clockStyleHint => i18n.get('screens.settings.clockStyleHint');
  static String get dateTime => i18n.get('screens.settings.dateTime');
  static String get sunArc => i18n.get('screens.settings.sunArc');
  static String get timeScale => i18n.get('screens.settings.timeScale');
  static String get language => i18n.get('screens.settings.language');
  static String get languageTitle => i18n.get('screens.settings.languageTitle');
  static String get chinese => i18n.get('screens.settings.chinese');
  static String get english => i18n.get('screens.settings.english');
  static String get taskStats => i18n.get('screens.settings.taskStats');
  static String get defaultStatsView => i18n.get('screens.settings.defaultStatsView');
  static String get tagManagement => i18n.get('screens.settings.tagManagement');
  static String get tagSystem => i18n.get('screens.settings.tagSystem');
  static String get tagSystemSubtitle => i18n.get('screens.settings.tagSystemSubtitle');
  static String get statsView => i18n.get('screens.settings.statsView');
  static String get statsViewSubtitle => i18n.get('screens.settings.statsViewSubtitle');
  static String get taskManagement => i18n.get('screens.settings.taskManagement');
  static String settingTagCount(int count) =>
    i18n.get('screens.settings.tagCount', {'count': count.toString()});
  static String get tagFilter => i18n.get('screens.settings.tagFilter');
  static String get filterAll => i18n.get('screens.settings.all');
  static String get filterWhitelist => i18n.get('screens.settings.whitelist');
  static String get filterBlacklist => i18n.get('screens.settings.blacklist');
  static String get heatmapThreshold => i18n.get('screens.settings.heatmapThreshold');
  static String get heatmapThresholdDesc => i18n.get('screens.settings.heatmapThresholdDesc');
  static String get yellowStart => i18n.get('screens.settings.yellowStart');
  static String get greenStart => i18n.get('screens.settings.greenStart');
  static String get goldStart => i18n.get('screens.settings.goldStart');
  static String heatmapLegend(int yellow, int green, int gold) =>
    i18n.get('screens.settings.heatmapLegend', {'yellow': yellow, 'green': green, 'gold': gold});
  static String get pomSettings => i18n.get('screens.settings.pomSettings');
  static String get pomSubtitle => i18n.get('screens.settings.pomSubtitle');
  static String get pomParams => i18n.get('screens.settings.pomParams');
  static String get focusDuration => i18n.get('screens.settings.focusDuration');
  static String get shortBreak => i18n.get('screens.settings.shortBreak');
  static String get longBreak => i18n.get('screens.settings.longBreak');
  static String get longBreakInterval => i18n.get('screens.settings.longBreakInterval');
  static String get trackFocusTime => i18n.get('screens.settings.trackFocusTime');
  static String get phaseEndReminder => i18n.get('screens.settings.phaseEndReminder');
  static String get alarmSound => i18n.get('screens.settings.alarmSound');
  static String get alarmSoundDesc => i18n.get('screens.settings.alarmSoundDesc');
  static String get vibrateReminder => i18n.get('screens.settings.vibrateReminder');
  static String get vibrateReminderDesc => i18n.get('screens.settings.vibrateReminderDesc');
  static String get rulerPositionSize => i18n.get('screens.settings.rulerPositionSize');
  static String get reset => i18n.get('screens.settings.reset');
  static String get topPosition => i18n.get('screens.settings.topPosition');
  static String get displayHeight => i18n.get('screens.settings.displayHeight');
  static String get leftOffset => i18n.get('screens.settings.leftOffset');
  static String get width => i18n.get('screens.settings.width');
  static String get rulerPreviewHint => i18n.get('screens.settings.rulerPreviewHint');
  static String pomDisplay(int focus, int breakTime) =>
    i18n.get('screens.settings.pomDisplay', {'focus': focus.toString(), 'break': breakTime.toString()});
  static String get showPomTab => i18n.get('screens.settings.showPomTab');
  static String get semester => i18n.get('screens.settings.semester');
  static String get semesterSettings => i18n.get('screens.settings.semesterSettings');
  static String get semesterSubtitle => i18n.get('screens.settings.semesterSubtitle');
  static String get notConfigured => i18n.get('screens.settings.notConfigured');
  static String semesterCount(int count) =>
    i18n.get('screens.settings.semesterCount', {'count': count.toString()});
  static String get appSettings => i18n.get('screens.settings.about');
  static String get aboutGroup => i18n.get('screens.settings.aboutGroup');
  static String get aboutSubtitle => i18n.get('screens.settings.aboutSubtitle');
  static String get appName => i18n.get('screens.settings.appName');
  static String get appNameHint => i18n.get('screens.settings.appNameHint');
  static String get defaultAppName => i18n.get('screens.settings.defaultAppName');
  static String get dataOverview => i18n.get('screens.settings.dataOverview');
  static String dataRecordCount(int count) =>
    i18n.get('screens.settings.recordCount', {'count': count.toString()});
  static String get betaFeatures => i18n.get('screens.settings.betaFeatures');
  static String get betaFeaturesDesc => i18n.get('screens.settings.betaFeaturesDesc');
  static String get general => i18n.get('screens.settings.general');
  static String get generalSubtitle => i18n.get('screens.settings.generalSubtitle');
  static String get dataSafety => i18n.get('screens.settings.dataSafety');
  static String get dataSafetySubtitle => i18n.get('screens.settings.dataSafetySubtitle');
  static String get lab => i18n.get('screens.settings.lab');
  static String get labSubtitle => i18n.get('screens.settings.labSubtitle');
  static String get diagnostics => i18n.get('screens.settings.diagnostics');
  static String get crashLogs => i18n.get('screens.settings.crashLogs');
  static String get crashLogsDesc => i18n.get('screens.settings.crashLogsDesc');
  static String get aboutApp => i18n.get('screens.settings.aboutApp');
  static String get dynamicColor => i18n.get('screens.settings.dynamicColor');
  static String get wallpaperTheme => i18n.get('screens.settings.wallpaperTheme');
  static String get dynamicEnabled => i18n.get('screens.settings.dynamicEnabled');
  static String get builtInPalette => i18n.get('screens.settings.builtInPalette');
  static String get followSystem => i18n.get('screens.settings.followSystem');
  static String get darkThemeAuto => i18n.get('screens.settings.darkThemeAuto');
  static String get darkTheme => i18n.get('screens.settings.darkTheme');
  static String get darkThemeDefaultName => i18n.get('screens.settings.darkThemeDefaultName');
  static String get wallpaperNotEnabled => i18n.get('screens.settings.wallpaperNotEnabled');
  static String get wallpaperEnableHint => i18n.get('screens.settings.wallpaperEnableHint');
  static String get goToSettings => i18n.get('screens.settings.goToSettings');
  static String get specialThemes => i18n.get('screens.settings.specialThemes');
  static String get blackHoleThemeDesc => i18n.get('screens.settings.blackHoleThemeDesc');
  static String get gargantuaWarningTitle => i18n.get('screens.settings.gargantua.warningTitle');
  static String get gargantuaWarningContent => i18n.get('screens.settings.gargantua.warningContent');
  static String get gargantuaAboutTitle => i18n.get('screens.settings.gargantua.aboutTitle');
  static String get gargantuaAboutContent => i18n.get('screens.settings.gargantua.aboutContent');
  static String get simulationParams => i18n.get('screens.settings.simulationParams');
  static String get accretionDisk => i18n.get('screens.settings.accretionDisk');
  static String get animateSimulation => i18n.get('screens.settings.animateSimulation');
  static String get advancedParams => i18n.get('screens.settings.advancedParams');
  static String get rotationSpeed => i18n.get('screens.settings.rotationSpeed');
  static String get maxIterations => i18n.get('screens.settings.maxIterations');
  static String get blackHoleSettingsHint => i18n.get('screens.settings.blackHoleSettingsHint');

  static String get defaultCalViewDay => i18n.get('screens.settings.defaultCalViewLabels.day');
  static String get defaultCalViewWeek => i18n.get('screens.settings.defaultCalViewLabels.week');
  static String get defaultCalViewMonth => i18n.get('screens.settings.defaultCalViewLabels.month');
  static String get defaultCalViewYear => i18n.get('screens.settings.defaultCalViewLabels.year');

  static String get saved => i18n.get('screens.settings.saved');
  static String get newTagHint => i18n.get('screens.settings.newTagHint');
  static String tagAdded(String tag) => i18n.get('screens.settings.tagAdded', {'tag': tag});
  static String get filterMode => i18n.get('screens.settings.filterMode');
  static String get whitelistDesc => i18n.get('screens.settings.whitelistDesc');
  static String get blacklistDesc => i18n.get('screens.settings.blacklistDesc');
  static String get savedGroups => i18n.get('screens.settings.savedGroups');
  static String get showSemesterWeek => i18n.get('screens.settings.showSemesterWeek');
  static String semesterNum(String num) => i18n.get('screens.settings.semesterNum', {'num': num});
  static String get week => i18n.get('screens.settings.week');
  static String get semesterStartDate => i18n.get('screens.settings.semesterStartDate');
  static String get selectDate => i18n.get('common.selectDate');
  static String get weekCountHint => i18n.get('screens.settings.weekCountHint');
  static String get addSemester => i18n.get('screens.settings.addSemester');
  static String get firstUse => i18n.get('screens.settings.firstUse');
  static String get totalTasks => i18n.get('screens.settings.totalTasks');
  static String get completedTasks => i18n.get('screens.settings.completedTasks');
  static String get betaSmartPlan => i18n.get('screens.settings.beta.smartPlan');
  static String get betaSmartPlanDesc => i18n.get('screens.settings.beta.smartPlanDesc');
  static String get betaUsageStats => i18n.get('screens.settings.beta.usageStats');
  static String get betaUsageStatsDesc => i18n.get('screens.settings.beta.usageStatsDesc');
  static String get betaTaskGravity => i18n.get('screens.settings.beta.taskGravity');
  static String get betaTaskGravityDesc => i18n.get('screens.settings.beta.taskGravityDesc');
  static String get betaFocusEnhance => i18n.get('screens.settings.beta.focusEnhance');
  static String get betaDeepFocusAnalysis => i18n.get('screens.settings.beta.deepFocusAnalysis');
  static String get betaDeepFocusAnalysisDesc => i18n.get('screens.settings.beta.deepFocusAnalysisDesc');
  static String get betaAmbientFx => i18n.get('screens.settings.beta.ambientFx');
  static String get betaAmbientFxDesc => i18n.get('screens.settings.beta.ambientFxDesc');
  static String get betaPersistNotif => i18n.get('screens.settings.beta.persistNotif');
  static String get betaPersistNotifDesc => i18n.get('screens.settings.beta.persistNotifDesc');
  static String get betaWeatherEffects => i18n.get('screens.settings.beta.weatherEffects');
  static String get betaWeather => i18n.get('screens.settings.beta.weather');
  static String get betaWeatherDesc => i18n.get('screens.settings.beta.weatherDesc');
  static String get betaFestivalAutoTheme => i18n.get('screens.settings.beta.festivalAutoTheme');
  static String get betaFestivalAutoThemeDesc => i18n.get('screens.settings.beta.festivalAutoThemeDesc');
  static String get betaFocusQualityAndEnv => i18n.get('screens.settings.beta.focusQualityAndEnv');
  static String get betaFocusQuality => i18n.get('screens.settings.beta.focusQuality');
  static String get betaFocusQualityDesc => i18n.get('screens.settings.beta.focusQualityDesc');
  static String get betaNoisePom => i18n.get('screens.settings.beta.noisePom');
  static String get betaNoisePomDesc => i18n.get('screens.settings.beta.noisePomDesc');
  static String get betaDistractionAlert => i18n.get('screens.settings.beta.distractionAlert');
  static String get betaDistractionAlertDesc => i18n.get('screens.settings.beta.distractionAlertDesc');
  static String get betaAnimationsEnhanced => i18n.get('screens.settings.beta.animationsEnhanced');
  static String get betaAnimationsEnhancedDesc => i18n.get('screens.settings.beta.animationsEnhancedDesc');
  static String get betaDangerZone => i18n.get('screens.settings.beta.dangerZone');
  static String get betaDangerZoneDesc => i18n.get('screens.settings.beta.dangerZoneDesc');

  static String get dynamicThemeDesc => i18n.get('screens.settings.dynamicThemeDesc');
  static String get seasonalThemeSubtitle => i18n.get('screens.settings.seasonalThemeSubtitle');
  static String get festivalCalendar => i18n.get('screens.settings.festivalCalendar');
  static String get festivalCalendarSubtitle => i18n.get('screens.settings.festivalCalendarSubtitle');
  static String get wallpaperAndTransparency => i18n.get('screens.settings.wallpaperAndTransparency');
  static String get liquidGlass => i18n.get('screens.settings.liquidGlass');
  static String get componentDisplay => i18n.get('screens.settings.componentDisplay');
  static String get topClock => i18n.get('screens.settings.topClock');
  static String get enabled => i18n.get('screens.settings.enabled');
  static String get disabled => i18n.get('screens.settings.disabled');
  static String get wallpaperSettings => i18n.get('screens.settings.wallpaperSettings');
  static String get customImageSet => i18n.get('screens.settings.customImageSet');
  static String get builtInWallpaper => i18n.get('screens.settings.builtInWallpaper');
  static String get globalOpacityTitle => i18n.get('screens.settings.globalOpacityTitle');
  static String get glassTransparency => i18n.get('screens.settings.glassTransparency');
  static String get glassTransparencyDesc => i18n.get('screens.settings.glassTransparencyDesc');
  static String get topBarOffset => i18n.get('screens.settings.topBarOffset');
  static String get topBarOffsetDesc => i18n.get('screens.settings.topBarOffsetDesc');
  static String get editTags => i18n.get('screens.settings.editTags');
  static String get editTagsSubtitle => i18n.get('screens.settings.editTagsSubtitle');
  static String get statsFilter => i18n.get('screens.settings.statsFilter');
  static String get filterModeSubtitleAll => i18n.get('screens.settings.filterModeSubtitleAll');
  static String get filterModeSubtitleList => i18n.get('screens.settings.filterModeSubtitleList');
  static String get heatmapThresholdSubtitle => i18n.get('screens.settings.heatmapThresholdSubtitle');
  static String get basicInfo => i18n.get('screens.settings.basicInfo');
  static String get shareAndExport => i18n.get('screens.settings.shareAndExport');
  static String get shareAndReport => i18n.get('screens.settings.shareAndReport');
  static String get shareAndReportSubtitle => i18n.get('screens.settings.shareAndReportSubtitle');
  static String get overview => i18n.get('screens.settings.overview');
  static String get overviewSubtitle => i18n.get('screens.settings.overviewSubtitle');
  static String get troubleshooting => i18n.get('screens.settings.troubleshooting');
  static String get crashLog => i18n.get('screens.settings.crashLog');
  static String get crashLogSubtitle => i18n.get('screens.settings.crashLogSubtitle');
  static String get seasonalThemeTitle => i18n.get('screens.settings.seasonalThemeTitle');
  static String get applyTheme => i18n.get('screens.settings.applyTheme');
  static String get learnMoreFestival => i18n.get('screens.settings.learnMoreFestival');
  static String get themeGroupSeasons => i18n.get('screens.settings.themeGroups.seasons');
  static String get themeGroupTraditional => i18n.get('screens.settings.themeGroups.traditional');
  static String get themeGroupWorld => i18n.get('screens.settings.themeGroups.world');
  static String get themeGroupClassic => i18n.get('screens.settings.themeGroups.classic');
  static String get themeGroupSpecial => i18n.get('screens.settings.themeGroups.special');

  static String get todayLabel => i18n.get('time.today');
  static String get applyThemeBtn => i18n.get('screens.settings.applyTheme');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                  TIME BLOCKS & LABELS                    ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get morning => i18n.get('time.morning');
  static String get afternoon => i18n.get('time.afternoon');
  static String get evening => i18n.get('time.evening');
  static String get timeUnassigned => i18n.get('time.unassigned');
  static String get morningEmoji => i18n.get('time.morning_emoji');
  static String get afternoonEmoji => i18n.get('time.afternoon_emoji');
  static String get eveningEmoji => i18n.get('time.evening_emoji');
  static String get unassignedEmoji => i18n.get('time.unassigned_emoji');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                   TIME UNITS                             ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get second => i18n.get('time.second');
  static String get minute => i18n.get('time.minute');
  static String get hour => i18n.get('time.hour');
  static String get minuteShort => i18n.get('time.minuteShort');

  static String get mondayShort => i18n.get('time.monday_short');
  static String get tuesdayShort => i18n.get('time.tuesday_short');
  static String get wednesdayShort => i18n.get('time.wednesday_short');
  static String get thursdayShort => i18n.get('time.thursday_short');
  static String get fridayShort => i18n.get('time.friday_short');
  static String get saturdayShort => i18n.get('time.saturday_short');
  static String get sundayShort => i18n.get('time.sunday_short');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                   CALENDAR LABELS                        ║
  // ╚═══════════════════════════════════════════════════════════╝
  // 中文: 一二三四五六日, 英文: Mon Tue Wed ...
  static List<String> get weekDays {
    if (i18n.currentLanguage == 'zh') {
      return ['一', '二', '三', '四', '五', '六', '日'];
    } else {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
  }

  // 中文: 1月2月....12月, 英文: Jan Feb ... Dec
  static List<String> get months {
    if (i18n.currentLanguage == 'zh') {
      return ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    } else {
      return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    }
  }
  static String get legendFew => i18n.get('calendar.legend_few');
  static String get legendMedium => i18n.get('calendar.legend_medium');
  static String get legendMany => i18n.get('calendar.legend_many');
  static String get legendGold => i18n.get('calendar.legend_gold');
  static String get legendFuture => i18n.get('calendar.legend_future');
  static String calGoldMedals(int count) =>
    i18n.get('calendar.goldMedals', {'count': count.toString()});

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                   TASK TILE LABELS                       ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get taskQuality => i18n.get('taskTile.taskQuality');
  static String get taskQuality1 => i18n.get('taskTile.quality_1');
  static String get taskQuality2 => i18n.get('taskTile.quality_2');
  static String get taskQuality3 => i18n.get('taskTile.quality_3');
  static String get taskQuality4 => i18n.get('taskTile.quality_4');
  static String get taskQuality5 => i18n.get('taskTile.quality_5');
  static String get submitRating => i18n.get('taskTile.submitRating');
  static String get skipRating => i18n.get('taskTile.skipRating');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                   THEMES                                 ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get themeBlackHole => i18n.get('themes.black_hole');
  static String get themeDark => i18n.get('themes.dark');
  static String get themeLight => i18n.get('themes.light');
  static String get themeSakura => i18n.get('themes.sakura');
  static String get themeOcean => i18n.get('themes.ocean');
  static String get themeForest => i18n.get('themes.forest');
  static String get themeSunset => i18n.get('themes.sunset');
  static String get themeLavander => i18n.get('themes.lavander');

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                   SHARE LABELS                           ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String sharePeriodSummary(String period) =>
    i18n.get('share.periodSummary', {'period': period});
  static String get shareTodaySummary => i18n.get('share.todaySummary');
  static String get shareFullVersion => i18n.get('share.fullVersion');
  static String get shareScreenshotFailed => i18n.get('share.screenshotFailed');
  static String get shareShareFailed => i18n.get('share.shareFailed');
  static String shareError(String error) =>
    i18n.get('share.error', {'error': error});

  // Share Card Specific
  static String get shareCardLast7Days => i18n.get('widgets.shareCard.last7Days');
  static String get shareCardCurrentPeriod => i18n.get('widgets.shareCard.currentPeriod');
  static String get shareCardActiveDays => i18n.get('widgets.shareCard.activeDays');
  static String shareCardDaysCount(int count) => i18n.get('widgets.shareCard.daysCount', {'count': count.toString()});
  static String get shareCardTasksTotal => i18n.get('widgets.shareCard.tasksTotal');
  static String get shareCardNoTasksPeriod => i18n.get('widgets.shareCard.noTasksPeriod');
  static String get shareCardOverdueNotDone => i18n.get('widgets.shareCard.overdueNotDone');
  static String get shareCardOverdueBefore => i18n.get('widgets.shareCard.overdueBefore');
  static String get shareCardDailyTaskDetails => i18n.get('widgets.shareCard.dailyTaskDetails');
  static String get shareCardItemsUnit => i18n.get('widgets.shareCard.itemsUnit');
  static String shareCardPeriodSummaryWithDate(String period, String date) => 
    i18n.get('widgets.shareCard.periodSummaryWithDate', {'period': period, 'date': date});
  static String shareCardSummaryWithDate(String date) => 
    i18n.get('widgets.shareCard.summaryWithDate', {'date': date});

  // ═══════════════════════════════════════════════════════════════
  // ╔═══════════════════════════════════════════════════════════╗
  // ║                   COMMON BUTTONS                         ║
  // ╚═══════════════════════════════════════════════════════════╝
  static String get ok => i18n.get('screens.common.ok');
  static String get cancel => i18n.get('screens.common.cancel');
  static String get skip => i18n.get('screens.common.skip');
  static String get submit => i18n.get('screens.common.submit');
  static String get copy => i18n.get('screens.common.copy');
  static String get delete => i18n.get('screens.common.delete');
  static String get edit => i18n.get('screens.common.edit');
  static String get add => i18n.get('screens.common.add');
  static String get close => i18n.get('screens.common.close');
  static String get back => i18n.get('screens.common.back');
  static String get open => i18n.get('screens.common.open');
  static String get save => i18n.get('screens.common.save');
  static String get share => i18n.get('screens.common.share');
  static String get download => i18n.get('screens.common.download');
  static String get upload => i18n.get('screens.common.upload');
  static String get error => i18n.get('screens.common.error');
  static String get success => i18n.get('screens.common.success');
  static String get loading => i18n.get('screens.common.loading');
  static String get empty => i18n.get('screens.common.empty');
  static String get tryAgain => i18n.get('screens.common.tryAgain');

  // ╔════════════════════════════════════════════════════════════════╗
  // ║                   向后兼容别名                                  ║
  // ║  保留旧的变量名以确保现有代码继续工作                             ║
  // ╚════════════════════════════════════════════════════════════════╝
  static String get todayTitle => today;
  static String get quadrantTitle => quadrant;
  static String get statsTitle => stats;
  static String get pomodoroTitle => pomodoro;
  static String get settingsTitle => settings;

  // 时段名称别名
  static String get morn => morning;
  static String get noon => afternoon;
  static String get eve => evening;

  // 按钮别名
  static String get okBtn => ok;
  static String get cancelBtn => cancel;
  static String get skipBtn => skip;
  static String get shareBtn => share;
  static String get deleteBtn => delete;
  static String get addBtn => add;
}
