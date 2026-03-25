// lib/services/festival_calendar.dart
// 流水账内置节日日历
// 收录具有主题皮肤的国际/传统节日，供「关于」页展示详细介绍

import '../l10n/l10n.dart';

class FestivalInfo {
  final String id;          // 主题 key，对应 kThemes 中的 key
  final String name;        // 节日名称
  final String emoji;       // 代表 emoji
  final int month;          // 月
  final int day;            // 日（-1 = 浮动，由 dayLabel 描述）
  final String? dayLabel;   // 浮动日说明，如「农历正月初一」
  final String tagline;     // 一句话描述
  final String description; // 详细介绍（2-4段）
  final String themeReason; // 为什么这样设计主题色
  final List<String> facts; // 有趣事实 3-5条

  const FestivalInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.month,
    required this.day,
    this.dayLabel,
    required this.tagline,
    required this.description,
    required this.themeReason,
    required this.facts,
  });

  /// 是否是今天
  bool get isToday {
    final now = DateTime.now();
    if (day == -1) return false; // 浮动节日不做精确匹配
    return now.month == month && now.day == day;
  }

  String get dateLabel {
    if (dayLabel != null) return L.get(dayLabel!);
    final monthName = _monthNameEn(month);
    return L.get('screens.settings.festivalDate', {
      'month': month.toString(),
      'day': day.toString(),
      'monthName': monthName,
    });
  }

  static String _monthNameEn(int month) {
    const names = [
      '',
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    if (month < 1 || month > 12) return month.toString();
    return names[month];
  }
}

const List<FestivalInfo> kFestivals = [
  // ── 端午节 ───────────────────────────────────────────────────────────────
  FestivalInfo(
    id: 'dragon_boat',
    name: 'screens.settings.festivals.dragon_boat.name',
    emoji: '🐉',
    month: 6,
    day: -1,
    dayLabel: 'screens.settings.festivals.dragon_boat.dateLabel',
    tagline: 'screens.settings.festivals.dragon_boat.tagline',
    description: 'screens.settings.festivals.dragon_boat.desc',
    themeReason: 'screens.settings.festivals.dragon_boat.reason',
    facts: [
      'screens.settings.festivals.dragon_boat.facts.1',
      'screens.settings.festivals.dragon_boat.facts.2',
      'screens.settings.festivals.dragon_boat.facts.3',
      'screens.settings.festivals.dragon_boat.facts.4',
      'screens.settings.festivals.dragon_boat.facts.5',
    ],
  ),

  // ── 世界防治结核病日 ───────────────────────────────────────────────────
  FestivalInfo(
    id: 'world_tb_day',
    name: 'screens.settings.festivals.world_tb_day.name',
    emoji: '⚕️',
    month: 3,
    day: 24,
    tagline: 'screens.settings.festivals.world_tb_day.tagline',
    description: 'screens.settings.festivals.world_tb_day.desc',
    themeReason: 'screens.settings.festivals.world_tb_day.reason',
    facts: [
      'screens.settings.festivals.world_tb_day.facts.1',
      'screens.settings.festivals.world_tb_day.facts.2',
      'screens.settings.festivals.world_tb_day.facts.3',
    ],
  ),

  // ── 世界水日 ───────────────────────────────────────────────────────────
  FestivalInfo(
    id: 'world_water_day',
    name: 'screens.settings.festivals.world_water_day.name',
    emoji: '💧',
    month: 3,
    day: 22,
    tagline: 'screens.settings.festivals.world_water_day.tagline',
    description: 'screens.settings.festivals.world_water_day.desc',
    themeReason: 'screens.settings.festivals.world_water_day.reason',
    facts: [
      'screens.settings.festivals.world_water_day.facts.1',
      'screens.settings.festivals.world_water_day.facts.2',
      'screens.settings.festivals.world_water_day.facts.3',
      'screens.settings.festivals.world_water_day.facts.4',
      'screens.settings.festivals.world_water_day.facts.5',
    ],
  ),

  // ── 农历新年 ─────────────────────────────────────────────────────────────
  FestivalInfo(
    id: 'lunar_new_year',
    name: 'screens.settings.festivals.lunar_new_year.name',
    emoji: '🧧',
    month: 1,
    day: -1,
    dayLabel: 'screens.settings.festivals.lunar_new_year.dateLabel',
    tagline: 'screens.settings.festivals.lunar_new_year.tagline',
    description: 'screens.settings.festivals.lunar_new_year.desc',
    themeReason: 'screens.settings.festivals.lunar_new_year.reason',
    facts: [
      'screens.settings.festivals.lunar_new_year.facts.1',
      'screens.settings.festivals.lunar_new_year.facts.2',
      'screens.settings.festivals.lunar_new_year.facts.3',
      'screens.settings.festivals.lunar_new_year.facts.4',
    ],
  ),

  // ── 中秋节 ───────────────────────────────────────────────────────────────
  FestivalInfo(
    id: 'mid_autumn',
    name: 'screens.settings.festivals.mid_autumn.name',
    emoji: '🌕',
    month: 9,
    day: -1,
    dayLabel: 'screens.settings.festivals.mid_autumn.dateLabel',
    tagline: 'screens.settings.festivals.mid_autumn.tagline',
    description: 'screens.settings.festivals.mid_autumn.desc',
    themeReason: 'screens.settings.festivals.mid_autumn.reason',
    facts: [
      'screens.settings.festivals.mid_autumn.facts.1',
      'screens.settings.festivals.mid_autumn.facts.2',
      'screens.settings.festivals.mid_autumn.facts.3',
      'screens.settings.festivals.mid_autumn.facts.4',
    ],
  ),
];

/// 根据主题 key 获取节日信息
FestivalInfo? getFestivalByTheme(String themeKey) {
  try {
    return kFestivals.firstWhere((f) => f.id == themeKey);
  } catch (_) {
    return null;
  }
}

/// 今日是否有节日（有对应主题皮肤的）
FestivalInfo? getTodayFestival() {
  try {
    return kFestivals.firstWhere((f) => f.isToday);
  } catch (_) {
    return null;
  }
}
