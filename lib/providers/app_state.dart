// lib/providers/app_state.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../l10n/l10n.dart';
import '../services/notification_service.dart';
import '../services/crash_logger.dart';
import '../services/pom_engine.dart';

class AppState extends ChangeNotifier {
  static const _sk = 'lsz_flutter_v1';

  List<TaskModel> tasks = [];
  List<String> tags = ['工作', '生活', '学习', '健康'];
  AppSettings settings = AppSettings();

  // ── Pomodoro engine — never disposed while app is alive ─────────────────
  final PomEngine engine = PomEngine();
  Timer? _notifDebounce;

  // ── Load / Save ─────────────────────────────────────────────
  Future<void> load() async {
    CrashLogger.info('AppState', 'load() start');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sk);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        tasks = (m['tasks'] as List).map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
        tags = List<String>.from(m['tags'] ?? ['工作', '生活', '学习', '健康']);
        settings = AppSettings.fromJson(m['settings'] as Map<String, dynamic>? ?? {});
        CrashLogger.info('AppState', 'load() ok — tasks=${tasks.length} tags=${tags.length}');
      } catch (e, s) {
        CrashLogger.error('AppState', 'load() JSON parse failed — data reset', err: e, stack: s);
      }
    } else {
      CrashLogger.info('AppState', 'load() — no saved data, fresh install');
    }
    if (settings.installDate == null) {
      settings.installDate = todayKey;
      await _persist(prefs);
    }
    L.setLanguage(settings.lang);
    L.i18n.setTheme(settings.theme);

    // Wire PomEngine flush callbacks
    engine.onFocusTimeFlush = (secs, taskId) {
      if (!settings.pom.trackTime) return;
      if (taskId != null) {
        addFocusTime(taskId, secs);
      } else {
        final today = todayKey;
        settings.unboundFocusByDate[today] =
            (settings.unboundFocusByDate[today] ?? 0) + secs;
        _persist();
      }
    };

    engine.init(settings.pom);
    _scheduleNotifications();
  }

  Future<void> _persist([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_sk, jsonEncode({
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'tags': tags, 'settings': settings.toJson(),
    }));
  }

  void _save() { _persist(); notifyListeners(); }

  /// Force a UI refresh without persisting.
  /// Used for time-based rollovers (e.g. 5am app-day boundary).
  void refreshUi() => notifyListeners();

  void _scheduleNotifications() {
    _notifDebounce?.cancel();
    _notifDebounce = Timer(const Duration(seconds: 2), () {
      final today = todayKey;
      final morning = tasks.where((t) => !t.done && t.createdAt == today && t.timeBlock == 'morning').map((t) => t.text).toList();
      final afternoon = tasks.where((t) => !t.done && t.createdAt == today && t.timeBlock == 'afternoon').map((t) => t.text).toList();
      final evening = tasks.where((t) => !t.done && t.createdAt == today && t.timeBlock == 'evening').map((t) => t.text).toList();
      NotificationService.scheduleAll(morning: morning, afternoon: afternoon, evening: evening);
    });
  }

  // ── Computed ─────────────────────────────────────────────────
  int get pendingCount => tasks.where((t) => !t.done).length;

  String get todayKey => appDateKey(DateTime.now());
  static String appDateKey(DateTime real) {
    final effective = real.hour < 5 ? real.subtract(const Duration(days: 1)) : real;
    return dateKey(effective);
  }
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  static String fmt25h(int realHour, int minute) {
    final h = realHour < 5 ? realHour + 24 : realHour;
    return '${h.toString().padLeft(2,'0')}:${minute.toString().padLeft(2,'0')}';
  }

  int doneOnDay(String day) => tasks.where((t) => t.done && t.doneAt == day).length;

  static String hourToTimeBlock(int hour, int minute) {
    if (hour >= 5 && hour < 13) return 'morning';
    if (hour >= 13 && (hour < 18 || (hour == 18 && minute < 30))) return 'afternoon';
    return 'evening';
  }

  bool tagCountsInStats(String tag) {
    switch (settings.tagFilterMode) {
      case 'whitelist': return settings.tagWhitelist.contains(tag);
      case 'blacklist': return !settings.tagBlacklist.contains(tag);
      default: return true;
    }
  }

  Color tagColor(String tag) {
    final t = kThemes[settings.theme] ?? kThemes['warm']!;
    final idx = tags.indexOf(tag);
    return Color(t.tagColors[idx >= 0 ? idx % t.tagColors.length : 0]);
  }

  ThemeConfig? _dynamicThemeConfig;
  String? _resolvedThemeName;

  void setDynamicThemeConfig(ThemeConfig? tc) { _dynamicThemeConfig = tc; }

  void setResolvedThemeName(String name) {
    if (_resolvedThemeName == name) return;
    _resolvedThemeName = name;
    notifyListeners();
  }

  ThemeConfig get themeConfig {
    if (settings.dynamicColor && _dynamicThemeConfig != null) return _dynamicThemeConfig!;
    final name = _resolvedThemeName ?? settings.theme;
    return kThemes[name] ?? kThemes['warm']!;
  }

  /// 当前有效的 Surface 透明度。
  /// 便捷 Color getter：Screen 内用 state.cardColor / state.bgColor 替代 Color(tc.card) / Color(tc.bg)
  /// 有背景图时自动带透明度，无背景图时100%不透明，文字色始终不透明。
  Color get cardColor => Color(themeConfig.card).withOpacity(surfaceOpacity);
  Color get bgColor   => Color(themeConfig.bg).withOpacity(surfaceOpacity);

  /// 当前有效的 Surface 透明度。
  /// 有背景图时 = globalOpacity（让背景图透出）；无背景图时恒为 1.0（文字/UI 完全不透明）。
  double get surfaceOpacity {
    final hasImage = settings.customBgImagePath != null;
    final hasGlobalBg = !hasImage && (settings.theme == 'dragon_boat' || settings.theme == 'black_hole');
    if (!hasImage && !hasGlobalBg) return 1.0;
    return settings.globalOpacity.clamp(0.1, 1.0);
  }

  /// 已设置相册背景图或端午节内置背景（全局壁纸层会铺在所有路由下）。
  bool get showsGlobalWallpaper =>
      (settings.customBgImagePath != null &&
          settings.customBgImagePath!.isNotEmpty) ||
      settings.theme == 'dragon_boat' ||
      settings.theme == 'black_hole';

  /// 顶部/底栏 chrome：主题底色 × (整体透明度 × 顶栏系数)
  Color chromeBarColor(ThemeConfig tc) {
    if (!showsGlobalWallpaper) return Color(tc.bg);
    final a = (settings.globalOpacity * settings.topChromeOpacity).clamp(0.05, 1.0);
    return Color(tc.bg).withOpacity(a);
  }

  /// 底栏胶囊背景
  Color chromeNavBarColor(ThemeConfig tc) {
    if (!showsGlobalWallpaper) return Color(tc.nb);
    final a = (settings.globalOpacity * settings.topChromeOpacity).clamp(0.05, 1.0);
    return Color(tc.nb).withOpacity(a);
  }

  /// 横屏侧栏导航
  Color chromeRailNavColor(ThemeConfig tc) {
    const base = 0.82;
    if (!showsGlobalWallpaper) return Color(tc.nb).withOpacity(base);
    final a = (base * settings.globalOpacity * settings.topChromeOpacity).clamp(0.12, 1.0);
    return Color(tc.nb).withOpacity(a);
  }

  bool isGoldDay(int cnt) => cnt >= settings.colorThresholds[2];

  Color heatColor(int cnt, bool isFuture, String dateStr) {
    if (isFuture) return Color(themeConfig.brd);
    final install = settings.installDate;
    if (install != null && dateStr.compareTo(install) < 0 && cnt == 0) return Color(themeConfig.brd);
    final t = settings.colorThresholds;
    const c0 = [214,75,65]; const c3 = [218,168,50]; const c6 = [68,164,96]; const c10 = [205,155,28];
    List<int> lerp(List<int> a, List<int> b, double v) =>
        [for (int i=0;i<3;i++) (a[i]+(b[i]-a[i])*v.clamp(0,1)).round()];
    List<int> rgb;
    if (cnt<=0) rgb=c0;
    else if (cnt<t[0]) rgb=lerp(c0,c3,cnt/t[0]);
    else if (cnt<t[1]) rgb=lerp(c3,c6,(cnt-t[0])/(t[1]-t[0]));
    else rgb=lerp(c6,c10,(cnt-t[1])/(t[2]-t[1]));
    return Color.fromARGB(255,rgb[0],rgb[1],rgb[2]);
  }

  int todayFocusSecs() {
    final today = todayKey;
    final taskFocus = tasks
        .where((t) => t.doneAt == today || t.createdAt == today)
        .fold(0, (s, t) => s + t.focusSecs);
    final unbound = settings.unboundFocusByDate[today] ?? 0;
    return taskFocus + unbound;
  }

  // ── Task CRUD ─────────────────────────────────────────────────
  void addTask({required String text, required List<String> tags,
      required String timeBlock, String? forDate, bool done = false}) {
    final now = DateTime.now();
    final date = forDate ?? todayKey;
    final blk = done ? hourToTimeBlock(now.hour, now.minute) : null;
    tasks.insert(0, TaskModel(
      id: now.millisecondsSinceEpoch, text: text, tags: tags,
      done: done, createdAt: date, originalDate: date,
      originalTimeBlock: timeBlock,
      doneAt: done ? date : null, timeBlock: timeBlock,
      doneHour: done ? now.hour : null, doneTimeBlock: blk,
    ));
    CrashLogger.action('TaskCRUD', 'addTask "${text.length > 20 ? text.substring(0,20) : text}" blk=$timeBlock date=$date done=$done');
    _save(); _scheduleNotifications();
  }

  void toggleTask(int id) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = tasks[idx];
    final now = DateTime.now();
    if (!t.done) {
      final blk = hourToTimeBlock(now.hour, now.minute);
      tasks[idx] = t.copyWith(done: true, doneAt: todayKey, doneHour: now.hour, doneTimeBlock: blk);
      CrashLogger.action('TaskCRUD', 'toggleTask id=$id → DONE blk=$blk');
    } else {
      tasks[idx] = t.copyWith(done: false, clearDoneAt: true, clearDoneTimeBlock: true);
      CrashLogger.action('TaskCRUD', 'toggleTask id=$id → UNDONE');
    }
    _save();
  }

  void editTask(int id, String text) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(text: text);
    _save();
  }

  void deleteTask(int id) {
    if (engine.selTaskId == id) engine.selectTask(null);
    tasks.removeWhere((t) => t.id == id);
    CrashLogger.action('TaskCRUD', 'deleteTask id=$id');
    _save(); _scheduleNotifications();
  }

  void setTaskQuadrant(int id, int? q) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(quadrant: q, clearQuadrant: q == null);
    _save();
  }

  void setTaskTimeBlock(int id, String block) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(timeBlock: block);
    _save();
  }

  void setTaskDoneTimeBlock(int id, String blk) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(doneTimeBlock: blk);
    _save();
  }

  void ignoreTask(int id) {
    CrashLogger.tap('AppState', 'ignoreTask id=$id');
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(ignored: true);
    _save();
  }

  void unignoreTask(int id) {
    CrashLogger.tap('AppState', 'unignoreTask id=$id');
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(ignored: false);
    _save();
  }

  void rescheduleTask(int id) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(rescheduledTo: todayKey);
    _save();
  }

  void unrescheduleTask(int id) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(clearRescheduledTo: true);
    _save();
  }

  bool isOverdue(TaskModel t) =>
      !t.done && !t.ignored && t.originalDate.compareTo(todayKey) < 0;

  void setTagRowCount(int n) { settings.tagRowCount = n.clamp(1, 5); _save(); }

  void addFocusTime(int id, int secs) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(focusSecs: tasks[idx].focusSecs + secs);
    _save();
  }

  // ── Tags ──────────────────────────────────────────────────────
  void addTag(String tag) { if (!tags.contains(tag)) { tags.add(tag); _save(); } }
  void removeTag(String tag) {
    tags.remove(tag);
    for (final t in tasks) t.tags.remove(tag);
    settings.tagWhitelist.remove(tag); settings.tagBlacklist.remove(tag);
    _save();
  }
  void reorderTag(int oldIdx, int newIdx) {
    if (oldIdx == newIdx) return;
    final tag = tags.removeAt(oldIdx);
    tags.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, tag);
    _save();
  }

  // ── Settings ──────────────────────────────────────────────────
  void setTheme(String name) {
    settings.theme = name;
    L.i18n.setTheme(name);
    _save();
  }
  void toggleShowSem() { settings.showSem = !settings.showSem; _save(); }
  void toggleShowTopClock() { settings.showTopClock = !settings.showTopClock; _save(); }
  void setTopBarOffset(double val) { settings.topBarOffset = val; _save(); }
  void setGlassEffectIntensity(double val) { settings.glassEffectIntensity = val; _save(); }
  void setAppName(String name) { settings.appName = name.isEmpty ? '流水账' : name; _save(); }
  void toggleShowPomodoro() { settings.showPomodoro = !settings.showPomodoro; _save(); }
  void setClockStyle(String s) { settings.clockStyle = s; _save(); }
  void setDefaultCalView(String v) { settings.defaultCalView = v; _save(); }
  void setLang(String l) { settings.lang = l; L.setLanguage(l); _save(); }
  void toggleDynamicColor() { settings.dynamicColor = !settings.dynamicColor; _save(); }
  void setDynamicColor(bool v) { settings.dynamicColor = v; _save(); }
  void setFollowSystemTheme(bool v) { settings.followSystemTheme = v; _save(); }
  void setDarkTheme(String name) { settings.darkTheme = name; _save(); }
  void setDisposableHours(double h) { settings.disposableHours = h.clamp(1.0, 16.0); _save(); }
  void setColorThresholds(List<int> t) { settings.colorThresholds = t; _save(); }

  void setBetaFlag(String key, bool val) {
    switch (key) {
      case 'smartPlan':         settings.betaSmartPlan         = val; break;
      case 'usageStats':        settings.betaUsageStats        = val; break;
      case 'taskGravity':       settings.betaTaskGravity       = val; break;
      case 'livingIsland':      settings.betaLivingIsland      = val; break;
      case 'statsNewUI':        settings.betaStatsNewUI        = val; break;
      case 'deepFocusAnalysis': settings.betaDeepFocusAnalysis = val; break;
      case 'ambientFx':         settings.betaAmbientFx         = val; break;
      case 'weather':           settings.betaWeather           = val; break;
      case 'persistNotif':      settings.betaPersistNotif      = val; break;
    }
    _save();
    notifyListeners();
  }

  void setWeatherConfig({String? apiKey, String? city, String? pinned, String? jwtSecret, String? jwtKid, String? jwtSub, String? apiHost}) {
    if (apiKey != null)    settings.weatherApiKey = apiKey;
    if (city != null)      settings.weatherCity   = city;
    if (pinned != null)    settings.pinnedWeatherEffect = pinned;
    if (jwtSecret != null) settings.weatherJwtSecret = jwtSecret;
    if (jwtKid != null)    settings.weatherJwtKid = jwtKid;
    if (jwtSub != null)    settings.weatherJwtSub = jwtSub;
    if (apiHost != null)   settings.weatherApiHost = apiHost;
    _save();
    notifyListeners();
  }
  void setCustomBgColor(int? color) {
    settings.customBgColor = color;
    notifyListeners(); _save();
  }
  void setCustomBgImagePath(String? path) {
    settings.customBgImagePath = path;
    notifyListeners(); _save();
  }

  void setGlobalOpacity(double opacity) {
    settings.globalOpacity = opacity.clamp(0.3, 1.0);
    notifyListeners();
    _save();
  }

  void setTopChromeOpacity(double opacity) {
    settings.topChromeOpacity = opacity.clamp(0.1, 1.0);
    notifyListeners();
    _save();
  }

  void setNoiseMonitor(bool v) { settings.noiseMonitorEnabled = v; notifyListeners(); _save(); }
  void setNoisePomEnabled(bool v) { settings.noisePomEnabled = v; notifyListeners(); _save(); }
  void markNoiseConsentShown(bool agreed) {
    settings.noiseConsentShown = true;
    settings.noisePomEnabled = agreed;
    notifyListeners();
    _save();
  }
  void setDistractionAlert(bool v) { settings.distractionAlertEnabled = v; notifyListeners(); _save(); }
  void setFocusQuality(bool v) { settings.focusQualityEnabled = v; notifyListeners(); _save(); }
  void setAnimationsEnhanced(bool v) { settings.animationsEnhanced = v; notifyListeners(); _save(); }
  void setAutoFestivalTheme(bool v) { settings.autoFestivalTheme = v; notifyListeners(); _save(); }

  void setBlackHoleAccretionDisk(bool v) { settings.blackHole.accretionDisk = v; notifyListeners(); _save(); }
  void setBlackHoleAnimate(bool v) { settings.blackHole.animate = v; notifyListeners(); _save(); }
  void setBlackHoleSpeed(double v) { settings.blackHole.speed = v; notifyListeners(); _save(); }
  void setBlackHoleMaxIterations(int v) { settings.blackHole.maxIterations = v; notifyListeners(); _save(); }

  void addCustomEntertainApp(String pkg) {
    final p = pkg.trim();
    if (p.isEmpty) return;
    settings.userAppCategories[p] = 'custom';
    _save();
  }
  void removeCustomEntertainApp(String pkg) { settings.userAppCategories.remove(pkg); _save(); }
  void setAppCategory(String pkg, String? category) {
    if (category == null) settings.userAppCategories.remove(pkg);
    else settings.userAppCategories[pkg] = category;
    _save();
  }
  void resetAppCategories() { settings.userAppCategories.clear(); _save(); }

  void setTagFilterMode(String mode) {
    settings.tagFilterMode = mode;
    if (mode == 'whitelist') settings.tagBlacklist = [];
    if (mode == 'blacklist') settings.tagWhitelist = [];
    if (mode == 'all') { settings.tagWhitelist = []; settings.tagBlacklist = []; }
    _save();
  }
  void toggleTagInFilter(String tag) {
    if (settings.tagFilterMode == 'whitelist') {
      if (settings.tagWhitelist.contains(tag)) settings.tagWhitelist.remove(tag);
      else settings.tagWhitelist.add(tag);
    } else if (settings.tagFilterMode == 'blacklist') {
      if (settings.tagBlacklist.contains(tag)) settings.tagBlacklist.remove(tag);
      else settings.tagBlacklist.add(tag);
    }
    _save();
  }
  void addFilterGroup(String name, String mode, List<String> tags) {
    settings.filterGroups.removeWhere((g) => g.name == name);
    settings.filterGroups.add(FilterGroup(name: name, mode: mode, tags: List.from(tags)));
    _save();
  }
  void removeFilterGroup(String name) {
    settings.filterGroups.removeWhere((g) => g.name == name);
    if (settings.activeGroup == name) settings.activeGroup = null;
    _save();
  }
  void applyFilterGroup(String? name) {
    settings.activeGroup = name;
    if (name == null) { setTagFilterMode('all'); return; }
    final matches = settings.filterGroups.where((g) => g.name == name).toList();
    if (matches.isEmpty) return;
    final g = matches.first;
    settings.tagFilterMode = g.mode;
    if (g.mode == 'whitelist') { settings.tagWhitelist = List.from(g.tags); settings.tagBlacklist = []; }
    else if (g.mode == 'blacklist') { settings.tagBlacklist = List.from(g.tags); settings.tagWhitelist = []; }
    else { settings.tagWhitelist = []; settings.tagBlacklist = []; }
    _save();
  }

  void addSemester(int num, String start, int? weekCount) {
    settings.sems.removeWhere((s) => s.start == start);
    settings.sems.add(SemesterInfo(num: num, start: start, weekCount: weekCount));
    settings.sems.sort((a, b) => a.start.compareTo(b.start));
    _save();
  }
  void removeSemester(String start) { settings.sems.removeWhere((s) => s.start == start); _save(); }

  void updatePomSettings({int? focusMins, int? breakMins, int? longBreakMins,
      int? longBreakInterval, bool? autoNext, bool? trackTime, bool? showProgress,
      bool? showRuler, double? rulerTopFrac, double? rulerHeightFrac,
      double? rulerLeft, double? rulerWidth,
      bool? alarmSound, bool? alarmVibrate}) {
    if (focusMins != null) settings.pom.focusMins = focusMins;
    if (breakMins != null) settings.pom.breakMins = breakMins;
    if (longBreakMins != null) settings.pom.longBreakMins = longBreakMins;
    if (longBreakInterval != null) settings.pom.longBreakInterval = longBreakInterval;
    if (autoNext != null) settings.pom.autoNext = autoNext;
    if (trackTime != null) settings.pom.trackTime = trackTime;
    if (showProgress != null) settings.pom.showProgress = showProgress;
    if (showRuler != null) settings.pom.showRuler = showRuler;
    if (rulerTopFrac != null) settings.pom.rulerTopFrac = rulerTopFrac.clamp(0.05, 0.60);
    if (rulerHeightFrac != null) settings.pom.rulerHeightFrac = rulerHeightFrac.clamp(0.15, 0.80);
    if (rulerLeft != null) settings.pom.rulerLeft = rulerLeft.clamp(0.0, 80.0);
    if (rulerWidth != null) settings.pom.rulerWidth = rulerWidth.clamp(16.0, 60.0);
    if (alarmSound != null) settings.pom.alarmSound = alarmSound;
    if (alarmVibrate != null) settings.pom.alarmVibrate = alarmVibrate;
    if (!engine.running) engine.reinit(settings.pom);
    _save();
  }

  // ── Legacy pom shims (used by task_tile play button etc.) ───────────────
  // These delegate to PomEngine so existing call sites don't need changing.
  void pomStart() => engine.start(settings.pom);
  void pomPause() => engine.pause();
  void pomReset() => engine.reset(settings.pom);
  void pomSkip()  => engine.skip(settings.pom);
  void pomSelectTask(int? id) => engine.selectTask(id);
  void pomCatchUp() => engine.catchUp(settings.pom);

  /// Called by MainShell so any screen can trigger a tab switch to pomodoro.
  static VoidCallback? switchToPomodoroTab;

  // ── Stats helpers ─────────────────────────────────────────────
  int tagDoneInPeriod(String tag, List<String> days) {
    if (!tagCountsInStats(tag)) return 0;
    final s = days.toSet();
    return tasks.where((t) => t.done && t.tags.contains(tag) && s.contains(t.doneAt)).length;
  }
  int tagTotalDone(String tag) { if (!tagCountsInStats(tag)) return 0; return tasks.where((t) => t.done && t.tags.contains(tag)).length; }
  int tagTotalCount(String tag) => tasks.where((t) => t.tags.contains(tag)).length;
  int tagCompletionRate(String tag) { final tot = tagTotalCount(tag); return tot == 0 ? 0 : (tagTotalDone(tag)/tot*100).round(); }
  int tagFocusTime(String tag) => tasks.where((t) => t.tags.contains(tag)).fold(0, (s, t) => s + t.focusSecs);
  int tagFocusInPeriod(String tag, List<String> days) {
    if (!tagCountsInStats(tag)) return 0;
    final s = days.toSet();
    return tasks.where((t) => t.tags.contains(tag) && s.contains(t.doneAt)).fold(0, (acc, t) => acc + t.focusSecs);
  }

  Map<String, int> vitalityData(List<String> days) {
    final s = days.toSet();
    final m = {'morning': 0, 'afternoon': 0, 'evening': 0};
    for (final t in tasks) {
      if (!t.done || !s.contains(t.doneAt)) continue;
      final blk = t.doneTimeBlock ?? (t.doneHour != null ? hourToTimeBlock(t.doneHour!, 0) : null);
      if (blk != null) m[blk] = (m[blk] ?? 0) + 1;
    }
    return m;
  }

  List<(String, double)> deviationByDay(List<String> days) {
    const blockIdx = {'morning': 0, 'afternoon': 1, 'evening': 2};
    final result = <(String, double)>[];
    for (final day in days) {
      final relevant = tasks.where((t) {
        if (!t.done || t.doneAt != day) return false;
        final planned = t.originalTimeBlock;
        final actual = t.doneTimeBlock;
        return planned != 'unassigned' && actual != null &&
               blockIdx.containsKey(planned) && blockIdx.containsKey(actual);
      }).toList();
      if (relevant.isEmpty) continue;
      final avg = relevant.map((t) =>
        (blockIdx[t.doneTimeBlock]! - blockIdx[t.originalTimeBlock]!).toDouble()
      ).reduce((a, b) => a + b) / relevant.length;
      result.add((day, avg));
    }
    return result;
  }

  SemesterWeek? getSemInfo(String dateStr) {
    if (!settings.showSem) return null;
    final matching = settings.sems.where((s) => s.start.compareTo(dateStr) <= 0).toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) => b.start.compareTo(a.start));
    final sem = matching.first;
    final diff = DateTime.parse('${dateStr}T12:00:00').difference(DateTime.parse('${sem.start}T12:00:00')).inDays;
    final week = diff ~/ 7 + 1;
    if (sem.weekCount != null && week > sem.weekCount!) return null;
    return SemesterWeek(num: sem.num, week: week);
  }

  int totalFocusForDate(String date) {
    final taskFocus = tasks
        .where((t) => t.doneAt == date || t.createdAt == date)
        .fold(0, (s, t) => s + t.focusSecs);
    final unbound = settings.unboundFocusByDate[date] ?? 0;
    return taskFocus + unbound;
  }

  int unboundFocusForDate(String date) => settings.unboundFocusByDate[date] ?? 0;

  @override
  void dispose() {
    _notifDebounce?.cancel();
    engine.dispose();
    super.dispose();
  }
}

class SemesterWeek { final int num, week; const SemesterWeek({required this.num, required this.week}); }

class DateUtils2 {
  static String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  static DateTime parse(String s) => DateTime.parse('${s}T12:00:00');
  static String addDays(String s, int n) => fmt(parse(s).add(Duration(days: n)));
  static int dayOfYear(String s) { final d = parse(s); return d.difference(DateTime(d.year,1,1)).inDays+1; }
  static int weekOfYear(String s) { final d = parse(s); return ((dayOfYear(s)+(DateTime(d.year,1,1).weekday+6)%7-1)/7).ceil(); }
  static List<String> weekDays(String anchor) { final d = parse(anchor); final mon = d.subtract(Duration(days:(d.weekday-1)%7)); return List.generate(7,(i)=>fmt(mon.add(Duration(days:i)))); }
  static List<String> monthDays(String anchor) {
    final d = parse(anchor);
    final n = DateTime(d.year, d.month + 1, 0).day;
    return List.generate(n, (i) {
      final day = i + 1;
      final ms = d.month.toString().padLeft(2, '0');
      final ds = day.toString().padLeft(2, '0');
      return '${d.year}-$ms-$ds';
    });
  }
  static List<String> yearDays(String anchor) { final y=parse(anchor).year; final a=<String>[]; for(int m=1;m<=12;m++){final n=DateTime(y,m+1,0).day; for(int d=1;d<=n;d++){final ms=m.toString().padLeft(2,'0'); final ds=d.toString().padLeft(2,'0'); a.add('$y-$ms-$ds');}} return a; }
  static String getDefaultBlock() { final h=DateTime.now().hour; return h<12?'morning':h<18?'afternoon':'evening'; }
  static String fmtFull(String s) { final d=parse(s); return '${d.year}年${d.month}月${d.day}日'; }
  static String fmtShort(String s) { final d=parse(s); return '${d.month}月${d.day}日'; }
}
