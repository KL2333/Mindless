// lib/models/models.dart

class TaskModel {
  final int id;
  String text;
  List<String> tags;
  bool done;
  String createdAt;        // may be updated by reschedule
  String originalDate;     // locked at creation, never changes
  String originalTimeBlock;// locked at creation, never changes
  String? doneAt;
  int focusSecs;
  int? quadrant;
  bool ignored;
  String timeBlock;        // pool assignment, may change
  int? doneHour;
  String? doneTimeBlock;   // actual completion time-block (overrides doneHour for vitality)
  String? rescheduledTo;    // date task was rescheduled to (createdAt stays unchanged)

  TaskModel({
    required this.id, required this.text, required this.tags,
    required this.done, required this.createdAt,
    String? originalDate, String? originalTimeBlock,
    this.doneAt, this.focusSecs = 0, this.quadrant,
    this.ignored = false, required this.timeBlock,
    this.doneHour, this.doneTimeBlock, this.rescheduledTo,
  }) : originalDate = originalDate ?? createdAt,
       originalTimeBlock = originalTimeBlock ?? timeBlock;

  factory TaskModel.fromJson(Map<String, dynamic> j) => TaskModel(
    id: j['id'] as int, text: j['text'] as String,
    tags: List<String>.from(j['tags'] ?? []),
    done: j['done'] as bool, createdAt: j['createdAt'] as String,
    originalDate: j['originalDate'] as String? ?? j['createdAt'] as String,
    originalTimeBlock: j['originalTimeBlock'] as String? ?? (j['timeBlock'] ?? 'unassigned') as String,
    doneAt: j['doneAt'] as String?, focusSecs: (j['focusSecs'] ?? 0) as int,
    quadrant: j['quadrant'] as int?, ignored: (j['ignored'] ?? false) as bool,
    timeBlock: (j['timeBlock'] ?? 'unassigned') as String,
    doneHour: j['doneHour'] as int?, doneTimeBlock: j['doneTimeBlock'] as String?,
    rescheduledTo: j['rescheduledTo'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'text': text, 'tags': tags, 'done': done, 'createdAt': createdAt,
    'originalDate': originalDate, 'originalTimeBlock': originalTimeBlock,
    'doneAt': doneAt, 'focusSecs': focusSecs, 'quadrant': quadrant,
    'ignored': ignored, 'timeBlock': timeBlock,
    'doneHour': doneHour, 'doneTimeBlock': doneTimeBlock,
    'rescheduledTo': rescheduledTo,
  };

  TaskModel copyWith({
    String? text, List<String>? tags, bool? done, String? createdAt,
    String? doneAt, int? focusSecs, int? quadrant, bool? ignored,
    String? timeBlock, int? doneHour, String? doneTimeBlock, String? rescheduledTo,
    bool clearQuadrant = false, bool clearDoneAt = false, bool clearDoneTimeBlock = false,
    bool clearRescheduledTo = false,
  }) => TaskModel(
    id: id, text: text ?? this.text, tags: tags ?? this.tags,
    done: done ?? this.done, createdAt: createdAt ?? this.createdAt,
    originalDate: originalDate, originalTimeBlock: originalTimeBlock,
    doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
    focusSecs: focusSecs ?? this.focusSecs,
    quadrant: clearQuadrant ? null : (quadrant ?? this.quadrant),
    ignored: ignored ?? this.ignored, timeBlock: timeBlock ?? this.timeBlock,
    doneHour: doneHour ?? this.doneHour,
    doneTimeBlock: clearDoneTimeBlock ? null : (doneTimeBlock ?? this.doneTimeBlock),
    rescheduledTo: clearRescheduledTo ? null : (rescheduledTo ?? this.rescheduledTo),
  );
}

class SemesterInfo {
  final int num; final String start; final int? weekCount;
  const SemesterInfo({required this.num, required this.start, this.weekCount});
  factory SemesterInfo.fromJson(Map<String, dynamic> j) => SemesterInfo(
    num: j['num'] as int, start: j['start'] as String, weekCount: j['weekCount'] as int?);
  Map<String, dynamic> toJson() => {'num': num, 'start': start, 'weekCount': weekCount};
}

class PomSettings {
  int focusMins, breakMins, longBreakMins, longBreakInterval;
  bool autoNext, trackTime, showProgress;
  String disciplineMode;
  // Time ruler display settings
  bool showRuler;          // show/hide the disc ruler
  double rulerTopFrac;     // top position as fraction of screen height (0.05-0.60)
  double rulerHeightFrac;  // height as fraction of screen height (0.15-0.80)
  double rulerLeft;        // left offset in pixels (0-80)
  double rulerWidth;       // width in pixels (16-60)
  // Alarm settings — triggered at phase end (focus→break, break→focus)
  bool alarmSound;         // play system alarm sound on phase end
  bool alarmVibrate;       // vibrate on phase end
  bool persistentVibrate;  // keep vibrating until dismissed

  PomSettings({
    this.focusMins = 25, this.breakMins = 5,
    this.longBreakMins = 15, this.longBreakInterval = 4,
    this.autoNext = false, this.trackTime = true, this.showProgress = true,
    this.disciplineMode = 'normal',
    this.showRuler = false,
    this.rulerTopFrac = 0.120,
    this.rulerHeightFrac = 0.600,
    this.rulerLeft = 6.0,
    this.rulerWidth = 34.0,
    this.alarmSound = true,
    this.alarmVibrate = true,
    this.persistentVibrate = true,
  });
  factory PomSettings.fromJson(Map<String, dynamic> j) => PomSettings(
    focusMins: (j['focusMins'] ?? 25) as int, breakMins: (j['breakMins'] ?? 5) as int,
    longBreakMins: (j['longBreakMins'] ?? 15) as int,
    longBreakInterval: (j['longBreakInterval'] ?? 4) as int,
    autoNext: (j['autoNext'] ?? false) as bool, trackTime: (j['trackTime'] ?? true) as bool,
    showProgress: (j['showProgress'] ?? true) as bool,
    disciplineMode: (j['disciplineMode'] ?? 'normal') as String,
    showRuler: (j['showRuler'] ?? false) as bool,
    rulerTopFrac: (j['rulerTopFrac'] ?? 0.120) as double,
    rulerHeightFrac: (j['rulerHeightFrac'] ?? 0.600) as double,
    rulerLeft: (j['rulerLeft'] ?? 6.0) as double,
    rulerWidth: (j['rulerWidth'] ?? 34.0) as double,
    alarmSound: (j['alarmSound'] ?? true) as bool,
    alarmVibrate: (j['alarmVibrate'] ?? true) as bool,
    persistentVibrate: (j['persistentVibrate'] ?? true) as bool,
  );
  Map<String, dynamic> toJson() => {
    'focusMins': focusMins, 'breakMins': breakMins,
    'longBreakMins': longBreakMins, 'longBreakInterval': longBreakInterval,
    'autoNext': autoNext, 'trackTime': trackTime, 'showProgress': showProgress,
    'disciplineMode': disciplineMode,
    'showRuler': showRuler,
    'rulerTopFrac': rulerTopFrac, 'rulerHeightFrac': rulerHeightFrac,
    'rulerLeft': rulerLeft, 'rulerWidth': rulerWidth,
    'alarmSound': alarmSound, 'alarmVibrate': alarmVibrate,
    'persistentVibrate': persistentVibrate,
  };
}

class BlackHoleSettings {
  bool accretionDisk;
  bool animate;
  double speed;
  int maxIterations;

  BlackHoleSettings({
    this.accretionDisk = true,
    this.animate = true,
    this.speed = 0.01,
    this.maxIterations = 64,
  });

  factory BlackHoleSettings.fromJson(Map<String, dynamic>? j) => BlackHoleSettings(
    accretionDisk: (j?['accretionDisk'] ?? true) as bool,
    animate: (j?['animate'] ?? true) as bool,
    speed: (j?['speed'] ?? 0.01) as double,
    maxIterations: (j?['maxIterations'] ?? 64) as int,
  );

  Map<String, dynamic> toJson() => {
    'accretionDisk': accretionDisk,
    'animate': animate,
    'speed': speed,
    'maxIterations': maxIterations,
  };
}

class FilterGroup {
  final String name; final String mode; final List<String> tags;
  const FilterGroup({required this.name, required this.mode, this.tags = const []});
  factory FilterGroup.fromJson(Map<String, dynamic> j) => FilterGroup(
    name: j['name'] as String, mode: (j['mode'] ?? 'all') as String,
    tags: List<String>.from(j['tags'] ?? []));
  Map<String, dynamic> toJson() => {'name': name, 'mode': mode, 'tags': tags};
}

class AppSettings {
  String theme, tagFilterMode, lang, clockStyle, defaultCalView, appName;
  bool showSem, showPomodoro, dynamicColor, showTopClock;
  bool followSystemTheme;  // auto switch light/dark when system changes
  double topBarOffset; // 顶栏间距偏移值
  double glassEffectIntensity; // 玻璃通透感强度 (0.0 - 1.0, 越低越通透)
  String darkTheme;        // which theme to use in dark mode (default: 'dark')
  int tagRowCount;
  Map<String, int> unboundFocusByDate; // date → unbound focus seconds
  List<SemesterInfo> sems;
  PomSettings pom;
  BlackHoleSettings blackHole;
  List<int> colorThresholds;
  List<String> tagWhitelist, tagBlacklist;
  String? installDate, activeGroup;
  List<FilterGroup> filterGroups;
  double disposableHours;

  // ── About Screen Customization ──────────────────────────────────────────
  String aboutShortText;   // "流水不争先..."
  String aboutFooterText;  // "愿你的时间 终有回响"
  String? currentAboutPreset; // Theme-based preset key

  // ── Appearance overrides ────────────────────────────────────────────────────
  int? customBgColor;      // null = use theme default; 0xFFRRGGBB override
  double globalOpacity;    // 0.5 ~ 1.0, default 1.0 (full)
  /// 顶部栏（AppBar、底栏等）相对 [globalOpacity] 的额外系数；仅在有自定义背景图时生效。
  double topChromeOpacity;
  String? customBgImagePath; // 自定义背景图片路径（null=不使用图片）

  // ── β runtime flags (only meaningful when kBetaFeatures = true) ───────────
  bool betaSmartPlan;
  bool betaUsageStats;
  bool betaTaskGravity;
  bool betaStatsNewUI;
  // New β features
  bool betaDeepFocusAnalysis; // 番茄钟深度分析
  bool betaAmbientFx;         // 息屏特效
  bool betaWeather;           // 天气背景特效
  bool betaPersistNotif;      // 常驻通知栏控制（暂停/继续按钮）
  String weatherApiKey;       // OpenWeatherMap API Key
  String weatherCity;         // 用户设置的城市
  String pinnedWeatherEffect;  // 常驻天气特效：none=跟随API, 其余=强制指定
  String weatherJwtSecret;     // JWT Ed25519 私钥 PEM
  String weatherJwtKid;        // 和风天气 凭据ID (kid)
  String weatherJwtSub;        // 和风天气 项目ID (sub)
  String weatherApiHost;       // 和风天气 API Host（留空=免费版 devapi）
  // New β features (v043)
  bool noiseMonitorEnabled;   // 统计页「单次环境声分析」功能开关（独立）
  bool noisePomEnabled;       // 番茄钟运行时自动环境声抽样开关
  bool noiseConsentShown;     // 是否已向用户展示过番茄钟环境声授权弹窗
  bool distractionAlertEnabled; // 娱乐App干扰提醒
  bool focusQualityEnabled;   // 专注质量评分
  bool animationsEnhanced;    // 动画升级开关
  bool autoFestivalTheme;     // 节日当天自动切换对应主题
  // package → category ('social'|'video'|'game'|'custom'|'work'|'other')
  // user overrides; merged with built-in defaults in native code
  Map<String, String> userAppCategories;

  AppSettings({
    this.theme = 'warm', this.showSem = false,
    List<SemesterInfo>? sems, PomSettings? pom, List<int>? colorThresholds,
    this.tagFilterMode = 'all',
    List<String>? tagWhitelist, List<String>? tagBlacklist,
    this.installDate, List<FilterGroup>? filterGroups, this.activeGroup,
    this.appName = '流水账', this.showPomodoro = true, this.tagRowCount = 3,
    this.clockStyle = 'date', this.defaultCalView = 'week',
    this.lang = 'zh', this.dynamicColor = false,
    this.showTopClock = false,
    this.topBarOffset = -40.0,
    this.glassEffectIntensity = 0.0,
    this.followSystemTheme = false, this.darkTheme = 'dark',
    this.disposableHours = 6.0,
    Map<String, int>? unboundFocusByDate,
    this.customBgColor,
    this.globalOpacity = 1.0,
    this.topChromeOpacity = 1.0,
    this.customBgImagePath,
    this.betaSmartPlan = true,
    this.betaUsageStats = true,
    this.betaTaskGravity = true,
    this.betaStatsNewUI = false,
    this.betaDeepFocusAnalysis = false,
    this.betaAmbientFx = false,
    this.betaWeather = false,
    this.betaPersistNotif = false,
    this.weatherApiKey = '',
    this.weatherCity = '',
    this.pinnedWeatherEffect = 'none',
    this.weatherJwtSecret = '',
    this.weatherJwtKid = '',
    this.weatherJwtSub = '',
    this.weatherApiHost = '',
    this.noiseMonitorEnabled = false,
    this.noisePomEnabled = false,
    this.noiseConsentShown = false,
    this.distractionAlertEnabled = true,
    this.focusQualityEnabled = true,
    this.animationsEnhanced = true,
    this.autoFestivalTheme = true,
    BlackHoleSettings? blackHole,
    Map<String, String>? userAppCategories,
    this.aboutShortText = '流水不争先，争的是滔滔不绝',
    this.aboutFooterText = '无脑 无用',
    this.currentAboutPreset,
  }) : sems = sems ?? [], pom = pom ?? PomSettings(),
       blackHole = blackHole ?? BlackHoleSettings(),
       colorThresholds = colorThresholds ?? [3, 6, 10],
       tagWhitelist = tagWhitelist ?? [], tagBlacklist = tagBlacklist ?? [],
       filterGroups = filterGroups ?? [],
       unboundFocusByDate = unboundFocusByDate ?? {},
       userAppCategories = userAppCategories ?? {};

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    theme: (j['theme'] ?? 'warm') as String, showSem: (j['showSem'] ?? false) as bool,
    sems: (j['sems'] as List<dynamic>? ?? []).map((e) => SemesterInfo.fromJson(e as Map<String, dynamic>)).toList(),
    pom: j['pom'] != null ? PomSettings.fromJson(j['pom'] as Map<String, dynamic>) : PomSettings(),
    colorThresholds: j['colorThresholds'] != null ? List<int>.from(j['colorThresholds']) : [3, 6, 10],
    tagFilterMode: (j['tagFilterMode'] ?? 'all') as String,
    tagWhitelist: List<String>.from(j['tagWhitelist'] ?? []),
    tagBlacklist: List<String>.from(j['tagBlacklist'] ?? []),
    installDate: j['installDate'] as String?,
    filterGroups: (j['filterGroups'] as List<dynamic>? ?? []).map((e) => FilterGroup.fromJson(e as Map<String, dynamic>)).toList(),
    activeGroup: j['activeGroup'] as String?,
    appName: (j['appName'] ?? '流水账') as String,
    showPomodoro: (j['showPomodoro'] ?? true) as bool,
    tagRowCount: (j['tagRowCount'] ?? 3) as int,
    unboundFocusByDate: (j['unboundFocusByDate'] as Map<String,dynamic>? ?? {}).map((k,v) => MapEntry(k, (v as num).toInt())),
    clockStyle: (j['clockStyle'] ?? 'date') as String,
    defaultCalView: (j['defaultCalView'] ?? 'week') as String,
    lang: (j['lang'] ?? 'zh') as String,
    dynamicColor: (j['dynamicColor'] ?? false) as bool,
    showTopClock: (j['showTopClock'] ?? false) as bool,
    topBarOffset: (j['topBarOffset'] ?? -40.0) as double,
    glassEffectIntensity: (j['glassEffectIntensity'] ?? 0.0) as double,
    followSystemTheme: (j['followSystemTheme'] ?? false) as bool,
    darkTheme: (j['darkTheme'] ?? 'dark') as String,
    disposableHours: (j['disposableHours'] ?? 6.0) as double,
    customBgColor: j['customBgColor'] != null ? (j['customBgColor'] as num).toInt() : null,
    globalOpacity: (j['globalOpacity'] ?? 1.0) as double,
    topChromeOpacity: (j['topChromeOpacity'] ?? 1.0) as double,
    customBgImagePath: j['customBgImagePath'] as String?,
    betaSmartPlan: (j['betaSmartPlan'] ?? true) as bool,
    betaUsageStats: (j['betaUsageStats'] ?? true) as bool,
    betaTaskGravity: (j['betaTaskGravity'] ?? true) as bool,
    betaStatsNewUI: (j['betaStatsNewUI'] ?? false) as bool,
    betaDeepFocusAnalysis: (j['betaDeepFocusAnalysis'] ?? false) as bool,
    betaAmbientFx: (j['betaAmbientFx'] ?? false) as bool,
    betaWeather: (j['betaWeather'] ?? false) as bool,
    betaPersistNotif: (j['betaPersistNotif'] ?? false) as bool,
    weatherApiKey: (j['weatherApiKey'] ?? '') as String,
    weatherCity: (j['weatherCity'] ?? '') as String,
    pinnedWeatherEffect: (j['pinnedWeatherEffect'] ?? 'none') as String,
    weatherJwtSecret: (j['weatherJwtSecret'] ?? '') as String,
    weatherJwtKid: (j['weatherJwtKid'] ?? '') as String,
    weatherJwtSub: (j['weatherJwtSub'] ?? '') as String,
    weatherApiHost: (j['weatherApiHost'] ?? '') as String,
    noiseMonitorEnabled: (j['noiseMonitorEnabled'] ?? false) as bool,
    noisePomEnabled: (j['noisePomEnabled'] ?? false) as bool,
    noiseConsentShown: (j['noiseConsentShown'] ?? false) as bool,
    distractionAlertEnabled: (j['distractionAlertEnabled'] ?? true) as bool,
    focusQualityEnabled: (j['focusQualityEnabled'] ?? true) as bool,
    animationsEnhanced: (j['animationsEnhanced'] ?? true) as bool,
    autoFestivalTheme: (j['autoFestivalTheme'] ?? true) as bool,
    blackHole: BlackHoleSettings.fromJson(j['blackHole'] as Map<String, dynamic>?),
    userAppCategories: (j['userAppCategories'] as Map<String,dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v as String)),
    aboutShortText: j['aboutShortText'] as String? ?? '流水不争先，争的是滔滔不绝',
    aboutFooterText: j['aboutFooterText'] as String? ?? '无脑 无用',
    currentAboutPreset: j['currentAboutPreset'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'theme': theme, 'showSem': showSem,
    'sems': sems.map((s) => s.toJson()).toList(),
    'pom': pom.toJson(), 'colorThresholds': colorThresholds,
    'tagFilterMode': tagFilterMode, 'tagWhitelist': tagWhitelist,
    'tagBlacklist': tagBlacklist, 'installDate': installDate,
    'filterGroups': filterGroups.map((g) => g.toJson()).toList(),
    'activeGroup': activeGroup, 'appName': appName, 'showPomodoro': showPomodoro,
    'clockStyle': clockStyle, 'defaultCalView': defaultCalView,
    'lang': lang, 'dynamicColor': dynamicColor,
    'showTopClock': showTopClock,
    'topBarOffset': topBarOffset,
    'glassEffectIntensity': glassEffectIntensity,
    'followSystemTheme': followSystemTheme, 'darkTheme': darkTheme,
    'disposableHours': disposableHours,
    'customBgColor': customBgColor,
    'globalOpacity': globalOpacity,
    'topChromeOpacity': topChromeOpacity,
    'customBgImagePath': customBgImagePath,
    'betaSmartPlan': betaSmartPlan, 'betaUsageStats': betaUsageStats,
    'betaTaskGravity': betaTaskGravity,
    'betaStatsNewUI': betaStatsNewUI,
    'betaDeepFocusAnalysis': betaDeepFocusAnalysis,
    'betaAmbientFx': betaAmbientFx,
    'betaWeather': betaWeather,
    'betaPersistNotif': betaPersistNotif,
    'weatherApiKey': weatherApiKey,
    'weatherCity': weatherCity,
    'pinnedWeatherEffect': pinnedWeatherEffect,
    'weatherJwtSecret': weatherJwtSecret,
    'weatherJwtKid': weatherJwtKid,
    'weatherJwtSub': weatherJwtSub,
    'weatherApiHost': weatherApiHost,
    'noiseMonitorEnabled': noiseMonitorEnabled,
    'noisePomEnabled': noisePomEnabled,
    'noiseConsentShown': noiseConsentShown,
    'distractionAlertEnabled': distractionAlertEnabled,
    'focusQualityEnabled': focusQualityEnabled,
    'animationsEnhanced': animationsEnhanced,
    'autoFestivalTheme': autoFestivalTheme,
    'blackHole': blackHole.toJson(),
    'userAppCategories': userAppCategories,
    'aboutShortText': aboutShortText,
    'aboutFooterText': aboutFooterText,
    'currentAboutPreset': currentAboutPreset,
  };
}


// ── Pom Session record (for deep analysis) ───────────────────────────────────
class PomSession {
  final String date;       // YYYY-MM-DD
  final int hour;          // 0-23, start hour
  final int durationMins;  // planned duration
  final int actualMins;    // actual focus time
  final int pauseCount;    // number of pauses
  final bool completed;    // did user complete without reset?
  final int? taskId;
  const PomSession({required this.date, required this.hour,
      required this.durationMins, required this.actualMins,
      required this.pauseCount, required this.completed, this.taskId});
  factory PomSession.fromJson(Map<String, dynamic> j) => PomSession(
    date: j['date'] as String, hour: (j['hour'] ?? 0) as int,
    durationMins: (j['durationMins'] ?? 25) as int,
    actualMins: (j['actualMins'] ?? 0) as int,
    pauseCount: (j['pauseCount'] ?? 0) as int,
    completed: (j['completed'] ?? false) as bool,
    taskId: j['taskId'] as int?);
  Map<String, dynamic> toJson() => {
    'date': date, 'hour': hour, 'durationMins': durationMins,
    'actualMins': actualMins, 'pauseCount': pauseCount,
    'completed': completed, 'taskId': taskId,
  };
}
enum PomMode { focus, shortBreak, longBreak }
enum PomDisciplineMode { normal, semiStrict, strict }

PomDisciplineMode pomDisciplineModeFromKey(String key) {
  switch (key) {
    case 'semi_strict':
      return PomDisciplineMode.semiStrict;
    case 'strict':
      return PomDisciplineMode.strict;
    default:
      return PomDisciplineMode.normal;
  }
}

String pomDisciplineModeKey(PomDisciplineMode mode) {
  switch (mode) {
    case PomDisciplineMode.semiStrict:
      return 'semi_strict';
    case PomDisciplineMode.strict:
      return 'strict';
    case PomDisciplineMode.normal:
      return 'normal';
  }
}

class PomState {
  PomMode mode; int secsLeft, totalSecs, cycle, focusRoundsSinceLongBreak;
  bool running; int? selTaskId; int sessionFocusSecs; bool initialized;
  PomState({
    this.mode = PomMode.focus, this.secsLeft = 0, this.totalSecs = 0,
    this.cycle = 1, this.focusRoundsSinceLongBreak = 0,
    this.running = false, this.selTaskId,
    this.sessionFocusSecs = 0, this.initialized = false,
  });
  double get progress => totalSecs > 0 ? (totalSecs - secsLeft) / totalSecs : 0;
}

class ThemeConfig {
  final String name;
  final int bg, card, tx, ts, tm, acc, acc2, nb, na, nt, brd, pb, cb, ct;
  final List<int> tagColors;
  const ThemeConfig({
    required this.name, required this.bg, required this.card,
    required this.tx, required this.ts, required this.tm,
    required this.acc, required this.acc2, required this.nb,
    required this.na, required this.nt, required this.brd,
    required this.pb, required this.cb, required this.ct,
    required this.tagColors,
  });
}

const Map<String, ThemeConfig> kThemes = {
  'warm': ThemeConfig(name:'themes.warm', bg:0xFFF7F4EF, card:0xFFFFFFFF, tx:0xFF2C2A26, ts:0xFF7A7060, tm:0xFFB5ABA0, acc:0xFFC9A96E, acc2:0xFF7EB8A4, nb:0xFFEEE9E0, na:0xFF2C2A26, nt:0xFFF7F4EF, brd:0xFFF0ECE4, pb:0xFFE8E2D8, cb:0xFFF0ECE4, ct:0xFF6A6050, tagColors:[0xFFC9A96E,0xFF7EB8A4,0xFFE07B7B,0xFF8FA8C8,0xFFB89EC9,0xFFC8B87A,0xFF9AAB8A,0xFFD4836E]),
  'green': ThemeConfig(name:'themes.green', bg:0xFFEEF4F0, card:0xFFFFFFFF, tx:0xFF1E2E25, ts:0xFF5A7D68, tm:0xFF9AB8A4, acc:0xFF4A9068, acc2:0xFF82C4A0, nb:0xFFDDEEE3, na:0xFF1E2E25, nt:0xFFEEF4F0, brd:0xFFE0EDE5, pb:0xFFCFE0D5, cb:0xFFDDEEE3, ct:0xFF3A6050, tagColors:[0xFF3A7D5A,0xFF6AB08A,0xFFB06A3A,0xFF5A7AB0,0xFF9A6AB0,0xFFB0A03A,0xFF3A9AB0,0xFFE07060]),
  'indigo': ThemeConfig(name:'themes.indigo', bg:0xFFF0F2F8, card:0xFFFFFFFF, tx:0xFF1A2040, ts:0xFF5A6080, tm:0xFF9AA0C0, acc:0xFF5060D0, acc2:0xFF7A90E0, nb:0xFFDDE0F0, na:0xFF1A2040, nt:0xFFF0F2F8, brd:0xFFE0E4F0, pb:0xFFD0D5E8, cb:0xFFDDE0F0, ct:0xFF3A4070, tagColors:[0xFF5060D0,0xFF7A90E0,0xFFC06050,0xFF60A080,0xFFA060C0,0xFFC0A040,0xFF40A0C0,0xFFE07080]),
  'sunset': ThemeConfig(name:'themes.sunset', bg:0xFFFDF3EE, card:0xFFFFFFFF, tx:0xFF2E1A10, ts:0xFF8A5040, tm:0xFFC09080, acc:0xFFE07040, acc2:0xFFE0A060, nb:0xFFF5DDD0, na:0xFF2E1A10, nt:0xFFFDF3EE, brd:0xFFF0E0D5, pb:0xFFECD5C5, cb:0xFFF5DDD0, ct:0xFF7A4030, tagColors:[0xFFE07040,0xFFE0A060,0xFFC06080,0xFF806040,0xFF60A0A0,0xFFA08040,0xFF8060C0,0xFFE06060]),
  'lavender': ThemeConfig(name:'themes.lavender', bg:0xFFF4F0F8, card:0xFFFFFFFF, tx:0xFF2A1E35, ts:0xFF6A5080, tm:0xFFA890C0, acc:0xFF8060C0, acc2:0xFFB090E0, nb:0xFFE8E0F5, na:0xFF2A1E35, nt:0xFFF4F0F8, brd:0xFFE8E0F0, pb:0xFFDDD5EE, cb:0xFFE8E0F5, ct:0xFF5A4070, tagColors:[0xFF8060C0,0xFFB090E0,0xFFC06080,0xFF6080C0,0xFFA0C060,0xFFC0A040,0xFF60C0A0,0xFFE07060]),
  'dark': ThemeConfig(name:'themes.dark', bg:0xFF181E1B, card:0xFF232B27, tx:0xFFE5EDE6, ts:0xFF8A9E90, tm:0xFF4A5E50, acc:0xFF7EB8A4, acc2:0xFFC9A96E, nb:0xFF1E2822, na:0xFF7EB8A4, nt:0xFF181E1B, brd:0xFF2A3630, pb:0xFF2A3630, cb:0xFF232B27, ct:0xFF8AA890, tagColors:[0xFF7EB8A4,0xFFC9A96E,0xFFE07B7B,0xFF8FA8C8,0xFFB89EC9,0xFFC8B87A,0xFF9AAB8A,0xFFD4836E]),
  'cherry': ThemeConfig(name:'themes.cherry', bg:0xFFFDF0F3, card:0xFFFFFFFF, tx:0xFF2E1520, ts:0xFF8A5060, tm:0xFFC090A0, acc:0xFFE06080, acc2:0xFFF090A8, nb:0xFFF5D8E0, na:0xFF2E1520, nt:0xFFFDF0F3, brd:0xFFF5E0E5, pb:0xFFEED5DC, cb:0xFFF5D8E0, ct:0xFF7A4055, tagColors:[0xFFE06080,0xFFF090A8,0xFFC06050,0xFF8060C0,0xFF60A0C0,0xFFA0A040,0xFF60C080,0xFFD07040]),
  'forest': ThemeConfig(name:'themes.forest', bg:0xFFF0F5F2, card:0xFFFFFFFF, tx:0xFF1A2E20, ts:0xFF4A7055, tm:0xFF8AAA90, acc:0xFF2D7050, acc2:0xFF5AAA78, nb:0xFFD8EAD0, na:0xFF1A2E20, nt:0xFFF0F5F2, brd:0xFFD8E8D0, pb:0xFFC8DCC0, cb:0xFFD8EAD0, ct:0xFF346040, tagColors:[0xFF2D7050,0xFF5AAA78,0xFFB06030,0xFF5070B0,0xFF906AB0,0xFFA09030,0xFF3090A8,0xFFD06060]),
  // ── 节日 & 世界观主题 ──────────────────────────────────────────────────────
  'black_hole': ThemeConfig(
    name:'themes.black_hole',
    bg:0xFF05050A,
    card:0xFF0D0D14,
    tx:0xFFE0E0E0,
    ts:0xFF8A80A0,
    tm:0xFF4A4060,
    acc:0xFFA060FF,
    acc2:0xFF7040B0,
    nb:0xFF08080E,
    na:0xFFA060FF,
    nt:0xFF05050A,
    brd:0xFF1A152B,
    pb:0xFF6A40B0,
    cb:0xFF0A0A12,
    ct:0xFFD0A0FF,
    tagColors:[0xFFA060FF, 0xFF7040B0, 0xFF8A80A0, 0xFF5060D0, 0xFFB89EC9, 0xFF7A90E0, 0xFF9AAB8A, 0xFFD4836E]
  ),
  'spring': ThemeConfig(name:'themes.spring', bg:0xFFFDF5F7, card:0xFFFFFFFF, tx:0xFF2E1520, ts:0xFF8A6070, tm:0xFFCBA0B0, acc:0xFFE87090, acc2:0xFFF4A0B8, nb:0xFFF8E0E8, na:0xFF2E1520, nt:0xFFFDF5F7, brd:0xFFF5DDE5, pb:0xFFEDD0DA, cb:0xFFF5DDE5, ct:0xFF7A4055, tagColors:[0xFFE87090,0xFFF4A0B8,0xFF80B870,0xFF90A8E0,0xFFE0A060,0xFF70C0A8,0xFFB890D0,0xFFE07060]),
  'summer': ThemeConfig(name:'themes.summer', bg:0xFFF0F8FF, card:0xFFFFFFFF, tx:0xFF0D2840, ts:0xFF3A7090, tm:0xFF80B0C8, acc:0xFF1E90D0, acc2:0xFF60C8F0, nb:0xFFD0ECFA, na:0xFF0D2840, nt:0xFFF0F8FF, brd:0xFFD0E8F8, pb:0xFFBCDEF4, cb:0xFFD0E8F8, ct:0xFF1A6090, tagColors:[0xFF1E90D0,0xFF60C8F0,0xFF20B080,0xFF9060D0,0xFFE08820,0xFF30B8B0,0xFFD04060,0xFFE07040]),
  'autumn': ThemeConfig(name:'themes.autumn', bg:0xFFFDF6EE, card:0xFFFFFFFF, tx:0xFF2A1800, ts:0xFF8A5A20, tm:0xFFCCA060, acc:0xFFD47020, acc2:0xFFE89840, nb:0xFFF5E4CA, na:0xFF2A1800, nt:0xFFFDF6EE, brd:0xFFF0DEC0, pb:0xFFE8D0A8, cb:0xFFF0DEC0, ct:0xFF7A4010, tagColors:[0xFFD47020,0xFFE89840,0xFF8A9030,0xFFC84040,0xFF407090,0xFFA86030,0xFF60A860,0xFFB06090]),
  'winter': ThemeConfig(name:'themes.winter', bg:0xFFF5F8FF, card:0xFFFFFFFF, tx:0xFF1A2038, ts:0xFF5870A0, tm:0xFF9AB0D0, acc:0xFF4870C0, acc2:0xFF80A8E0, nb:0xFFE0E8F8, na:0xFF1A2038, nt:0xFFF5F8FF, brd:0xFFD8E4F4, pb:0xFFC8D8EE, cb:0xFFD8E4F4, ct:0xFF304080, tagColors:[0xFF4870C0,0xFF80A8E0,0xFF4090A0,0xFF8060B0,0xFF40A070,0xFFA09040,0xFF9050A0,0xFFD05050]),
  'lunar_new_year': ThemeConfig(name:'themes.lunar_new_year', bg:0xFFFFF5F5, card:0xFFFFFFFF, tx:0xFF3A0808, ts:0xFF8A2020, tm:0xFFC06060, acc:0xFFCC2020, acc2:0xFFEE8820, nb:0xFFFFE0E0, na:0xFF3A0808, nt:0xFFFFF5F5, brd:0xFFFFD0D0, pb:0xFFFFBCBC, cb:0xFFFFD0D0, ct:0xFF8A1010, tagColors:[0xFFCC2020,0xFFEE8820,0xFF9A6020,0xFF4A8020,0xFF208060,0xFF2040A0,0xFF6020A0,0xFFB04080]),
  'mid_autumn': ThemeConfig(name:'themes.mid_autumn', bg:0xFF1A1230, card:0xFF241C40, tx:0xFFEEE0C8, ts:0xFFA89870, tm:0xFF706050, acc:0xFFE8C060, acc2:0xFFD0A040, nb:0xFF201840, na:0xFFE8C060, nt:0xFF1A1230, brd:0xFF2E2450, pb:0xFF2A2048, cb:0xFF2E2450, ct:0xFFC8A840, tagColors:[0xFFE8C060,0xFFD0A040,0xFF70B860,0xFF6090D0,0xFFD06080,0xFF50C0B0,0xFF9070C0,0xFFE07040]),
  'world_tb_day': ThemeConfig(name:'themes.world_tb_day', bg:0xFFFFFFFF, card:0xFFF8F8F8, tx:0xFF101010, ts:0xFF606060, tm:0xFFA0A0A0, acc:0xFFD32F2F, acc2:0xFFB71C1C, nb:0xFFF0F0F0, na:0xFFD32F2F, nt:0xFFFFFFFF, brd:0xFFE0E0E0, pb:0xFFE57373, cb:0xFFF5F5F5, ct:0xFFC62828, tagColors:[0xFFD32F2F, 0xFFB71C1C, 0xFFE57373, 0xFFFFCDD2, 0xFF8A5A20, 0xFFCCA060, 0xFFD47020, 0xFFE89840]),
  // ── 世界性节日主题 ──────────────────────────────────────────────────────────
  // 世界水日 (3月22日) — 深海蓝 × 清澈水绿 × 气泡白
  'world_water_day': ThemeConfig(name:'themes.world_water_day', bg:0xFFEFF7FB, card:0xFFFFFFFF, tx:0xFF0A2840, ts:0xFF2E6E8E, tm:0xFF7AAEC8, acc:0xFF0E86B4, acc2:0xFF38C4C8, nb:0xFFD0EAF5, na:0xFF0A2840, nt:0xFFEFF7FB, brd:0xFFBEDEEE, pb:0xFFA8D0E8, cb:0xFFD0EAF5, ct:0xFF0E5070, tagColors:[0xFF0E86B4,0xFF38C4C8,0xFF1A9E7A,0xFF3878C0,0xFF7850B8,0xFF2CB088,0xFFE07040,0xFF8898C8]),
  // 端午节 (农历五月初五) — 荷塘碧绿 × 深水青 × 荷白
  'dragon_boat': ThemeConfig(name:'themes.dragon_boat', bg:0xFFEEF8F4, card:0xFFFFFFFF, tx:0xFF0D2820, ts:0xFF2A6E54, tm:0xFF7AB89A, acc:0xFF2A9C72, acc2:0xFF5DC49A, nb:0xFFCCECDE, na:0xFF0D2820, nt:0xFFEEF8F4, brd:0xFFB8DCCA, pb:0xFFA0CCBA, cb:0xFFCCECDE, ct:0xFF1A5C3A, tagColors:[0xFF2A9C72,0xFF5DC49A,0xFF3878A8,0xFFD4780A,0xFFB84040,0xFF7A70B0,0xFF38A8A0,0xFFD4A020]),
};

// 根据当前月份推荐季节主题
String? seasonalThemeSuggestion() {
  final now = DateTime.now();
  final m = now.month;
  final d = now.day;
  // ── 世界性节日（精确日期优先）────────────────────────────────────────────
  if (m == 3 && d == 22) return 'world_water_day'; // 世界水日
  if (m == 6 && d == 2)  return 'dragon_boat';     // 端午节2025（农历五月初五，近似公历6月2日±7天）
  if (m == 5 && d >= 28) return 'dragon_boat';     // 端午节提前窗口
  if (m == 6 && d <= 9)  return 'dragon_boat';     // 端午节范围窗口
  // ── 传统节日 ────────────────────────────────────────────────────────────
  if (m == 1 || m == 2) return 'lunar_new_year'; // 春节
  if (m == 9 && d >= 10 && d <= 20) return 'mid_autumn';
  // ── 季节 ────────────────────────────────────────────────────────────────
  if (m == 3 || m == 4) return 'spring';
  if (m == 5 || m == 6 || m == 7) return 'summer';
  if (m == 8 || m == 9 || m == 10) return 'autumn';
  return 'winter';
}

String seasonalThemeLabel() {
  final s = seasonalThemeSuggestion();
  return kThemes[s]?.name ?? '暖米';
}
