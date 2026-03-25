import '../services/i18n_manager.dart';

/// 国际化便利类，提供快速访问和IDE智能提示
/// ✅ 支持旧getters (向后兼容)
/// ✅ 支持新路径访问: L.get('screens.today.title')
/// ✅ 支持参数插值: L.get('greeting', {'name': 'Alice'})
class L {
  // ────────────────────────────────────────────────────────
  // 静态访问函数 (支持嵌套路径和参数)
  // ────────────────────────────────────────────────────────
  
  static String get(String key, [Map<String, dynamic>? params]) {
    return i18n.get(key, params);
  }

  // ────────────────────────────────────────────────────────
  // 屏幕标签 (IDE 智能提示)
  // ────────────────────────────────────────────────────────
  
  static String get today => i18n.get('screens.today.title');
  static String get quadrant => i18n.get('screens.quadrant.title');
  static String get stats => i18n.get('screens.stats.title');
  static String get pomodoro => i18n.get('screens.pomodoro.title');
  static String get settings => i18n.get('screens.settings.title');
  
  // ────────────────────────────────────────────────────────
  // 时间相关 (IDE 智能提示)
  // ────────────────────────────────────────────────────────
  
  static String get morning => i18n.get('time.morning');
  static String get afternoon => i18n.get('time.afternoon');
  static String get evening => i18n.get('time.evening');
  static String get dayToday => i18n.get('common.dayToday');
  static String get dayTomorrow => i18n.get('common.dayTomorrow');
  
  // ────────────────────────────────────────────────────────
  // 任务相关
  // ────────────────────────────────────────────────────────
  
  static String get addHint => i18n.get('screens.today.addHint');
  static String get addTomorrow => i18n.get('screens.today.addTomorrow');
  static String get unassigned => i18n.get('screens.today.unassigned');
  static String get overdue => i18n.get('screens.today.overdue');
  static String get ignore => i18n.get('common.ignore');
  static String get todayNoTasks => i18n.get('screens.today.noTasks');
  
  // ────────────────────────────────────────────────────────
  // 时段块定义
  // ────────────────────────────────────────────────────────
  
  static Map<String, Map<String, dynamic>> get blocks => {
    'morning': {
      'name': i18n.get('blocks.morning.name'),
      'emoji': i18n.get('blocks.morning.emoji'),
      'color': i18n.get('blocks.morning.color') as int? ?? 0xFFe8982a,
    },
    'afternoon': {
      'name': i18n.get('blocks.afternoon.name'),
      'emoji': i18n.get('blocks.afternoon.emoji'),
      'color': i18n.get('blocks.afternoon.color') as int? ?? 0xFF3a90c0,
    },
    'evening': {
      'name': i18n.get('blocks.evening.name'),
      'emoji': i18n.get('blocks.evening.emoji'),
      'color': i18n.get('blocks.evening.color') as int? ?? 0xFF7a5ab8,
    },
  };
  
  // ────────────────────────────────────────────────────────
  // 番茄钟相关
  // ────────────────────────────────────────────────────────
  
  static String get focus => i18n.get('screens.pomodoro.focus');
  static String get shortBreak => i18n.get('screens.pomodoro.shortBreak');
  static String get longBreak => i18n.get('screens.pomodoro.longBreak');
  static String get cycle => i18n.get('screens.pomodoro.cycle');
  static String get cycleUnit => i18n.get('screens.pomodoro.cycleUnit');
  static String get bindTask => i18n.get('screens.pomodoro.bindTask');
  static String get autoNext => i18n.get('screens.pomodoro.autoNext');
  static String get noTask => i18n.get('screens.pomodoro.noTask');
  static String get skip => i18n.get('screens.pomodoro.skip');
  static String get pause => i18n.get('screens.pomodoro.pause');
  static String get resume => i18n.get('screens.pomodoro.resume');
  static String get start => i18n.get('screens.pomodoro.start');
  static String get reset => i18n.get('screens.pomodoro.reset');
  static String get nextPhase => i18n.get('screens.pomodoro.nextPhase');
  static String get currentPhase => i18n.get('screens.pomodoro.currentPhase');
  
  // ────────────────────────────────────────────────────────
  // 统计相关
  // ────────────────────────────────────────────────────────
  
  static String get vitalityTitle => i18n.get('screens.stats.vitalityTitle');
  static String get deviationTitle => i18n.get('screens.stats.deviationTitle');
  static String get deviationDesc => i18n.get('screens.stats.deviationDesc');
  static String get countLabel => i18n.get('screens.stats.countLabel');
  static String get timeLabel => i18n.get('screens.stats.timeLabel');
  static String get rankLabel => i18n.get('screens.stats.rankLabel');
  static String get alphaLabel => i18n.get('screens.stats.alphaLabel');
  
  // ────────────────────────────────────────────────────────
  // 今日专注
  // ────────────────────────────────────────────────────────
  
  static String get todayFocus => i18n.get('screens.today.todayFocus');
  static String get disposable => i18n.get('screens.settings.disposable');
  static String get longPresEdit => i18n.get('screens.settings.longPresEdit');
  
  // ────────────────────────────────────────────────────────
  // 通用操作
  // ────────────────────────────────────────────────────────
  
  static String get save => i18n.get('common.save');
  static String get cancel => i18n.get('common.cancel');
  static String get reset2 => i18n.get('screens.pomodoro.reset');
  
  // ────────────────────────────────────────────────────────
  // 设置相关
  // ────────────────────────────────────────────────────────
  
  static String get appNameLbl => i18n.get('screens.settings.appNameLbl');
  static String get appearance => i18n.get('screens.settings.appearance');
  static String get clockStyle => i18n.get('screens.settings.clockStyle');
  static String get defaultView => i18n.get('screens.settings.defaultView');
  static String get language => i18n.get('screens.settings.language');
  static String get colorThresh => i18n.get('screens.settings.colorThresh');
  static String get pomSettings => i18n.get('screens.settings.pomSettings');
  static String get semSettings => i18n.get('screens.settings.semSettings');
  static String get tagFilter => i18n.get('screens.settings.tagFilter');
  static String get tagMgmt => i18n.get('screens.settings.tagMgmt');
  static String get dataOverview => i18n.get('screens.settings.dataOverview');
  static String get about => i18n.get('screens.settings.about');
  static String get showPomodoro => i18n.get('screens.settings.showPomodoro');
  static String get dynamicColor => i18n.get('screens.settings.dynamicColor');
  static String get installDate => i18n.get('screens.settings.installDate');
  static String get total => i18n.get('screens.settings.total');
  static String get completed => i18n.get('screens.settings.completed');
  static String get rate => i18n.get('screens.settings.rate');
  
  // ────────────────────────────────────────────────────────
  // i18n系统控制
  // ────────────────────────────────────────────────────────
  
  /// 初始化i18n系统
  static Future<void> init(String lang) => i18n.init(lang);
  
  /// 设置当前语言
  static void setLanguage(String lang) => i18n.setLanguage(lang);
  
  /// 获取当前语言 (向后兼容)
  static String get lang => i18n.currentLanguage;
}
