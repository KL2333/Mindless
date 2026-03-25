// lib/screens/settings_screen.dart
// 设置界面 — 分组导航 + 二级子页面，美观简洁
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:io' as dart_io;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/shared_widgets.dart';
import '../services/weather_service.dart';
import '../beta/beta_panel.dart' show AppCategoryPage;
import '../services/crash_logger.dart';
import '../services/share_service.dart';
import '../beta/smart_plan.dart';
import '../services/festival_calendar.dart';
import '../l10n/l10n.dart';

/// 设置页分组卡片底色：跟随全局壁纸与「整体透明度」（AppState.cardColor）。
Color settingsCardFill(BuildContext context) => context.watch<AppState>().cardColor;

/// 节日详情/日历等使用节日主题 `ft.card` 时，在壁纸模式下套用相同的 surfaceOpacity。
Color settingsFestCardFill(BuildContext context, ThemeConfig ft) {
  final s = context.watch<AppState>();
  if (!s.showsGlobalWallpaper) return Color(ft.card);
  return Color(ft.card).withOpacity(s.surfaceOpacity);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;

    return Scaffold(
      backgroundColor: state.chromeBarColor(tc),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, tc),
          SliverList(
            delegate: SliverChildListDelegate([
              // ── 个性化 ──────────────────────────────────────────────
              _GroupHeader(label: L.personalization, tc: tc),
              _NavTile(
                icon: Icons.palette_outlined,
                title: L.visualCenter,
                subtitle: L.visualCenterSubtitle,
                tc: tc,
                onTap: () => _push(context, const _VisualCenterPage()),
              ),
              _NavTile(
                icon: Icons.language_outlined,
                title: L.language,
                subtitle: state.settings.lang == 'zh' ? L.chinese : L.english,
                tc: tc,
                onTap: () => _push(context, const _LanguagePage()),
              ),

              // ── 任务管理 ─────────────────────────────────────────────
              _GroupHeader(label: L.taskManagement, tc: tc),
              _NavTile(
                icon: Icons.label_outline_rounded,
                title: L.tagSystem,
                subtitle: L.tagSystemSubtitle,
                tc: tc,
                onTap: () => _push(context, const _TagSystemPage()),
              ),
              _NavTile(
                icon: Icons.analytics_outlined,
                title: L.statsView,
                subtitle: L.statsViewSubtitle,
                tc: tc,
                onTap: () => _push(context, const _StatsViewPage()),
              ),
              _NavTile(
                icon: Icons.calendar_month_outlined,
                title: L.semester,
                subtitle: L.semesterSubtitle,
                tc: tc,
                onTap: () => _push(context, _SemesterPage()),
              ),

              // ── 专注工具 ─────────────────────────────────────────────
              _GroupHeader(label: L.pomSettings, tc: tc),
              _NavTile(
                icon: Icons.timer_outlined,
                title: L.pomodoro,
                subtitle: L.pomSubtitle,
                tc: tc,
                onTap: () => _push(context, const _PomodoroSettingsPage()),
              ),

              // ── 系统与数据 ───────────────────────────────────────────
              _GroupHeader(label: L.general, tc: tc),
              _NavTile(
                icon: Icons.app_registration_rounded,
                title: L.general,
                subtitle: L.generalSubtitle,
                tc: tc,
                onTap: () => _push(context, const _GeneralAppPage()),
              ),
              _NavTile(
                icon: Icons.storage_rounded,
                title: L.dataSafety,
                subtitle: L.dataSafetySubtitle,
                tc: tc,
                onTap: () => _push(context, const _DataSafetyPage()),
              ),
              _NavTile(
                icon: Icons.science_outlined,
                title: L.lab,
                subtitle: L.labSubtitle,
                tc: tc,
                onTap: () => _push(context, const _BetaPage()),
              ),

              // ── 关于 ──────────────────────────────────────────────
              _GroupHeader(label: L.aboutGroup, tc: tc),
              _NavTile(
                icon: Icons.info_outline_rounded,
                title: L.aboutApp,
                subtitle: L.aboutSubtitle,
                tc: tc,
                onTap: () => _push(context, const _AboutPage()),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ThemeConfig tc) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100,
      backgroundColor: context.watch<AppState>().chromeBarColor(tc),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
        onPressed: () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(L.settings,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
      ),
    );
  }

  static void _push(BuildContext ctx, Widget page) =>
    Navigator.push(ctx, PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic)),
        child: FadeTransition(opacity: anim, child: child)),
    ));
}

// ── Shared sub-page scaffold ──────────────────────────────────────────────────
class _SubPage extends StatelessWidget {
  final String title;
  // tc is kept for callers that haven't migrated, but build always reads live state
  final ThemeConfig? tc;
  final Widget body;
  final List<Widget>? actions;
  const _SubPage({required this.title, this.tc,
    required this.body, this.actions});
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final liveTc = appState.themeConfig;
    final effectiveTc = tc ?? liveTc;
    return Scaffold(
      backgroundColor: appState.showsGlobalWallpaper
          ? Colors.transparent
          : Color(effectiveTc.bg),
      appBar: AppBar(
        backgroundColor: appState.chromeBarColor(liveTc), elevation: 0,
        title: Text(title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(liveTc.tx))),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(liveTc.ts)),
          onPressed: () => Navigator.pop(context)),
        actions: actions,
      ),
      body: body,
    );
  }
}

// ── Reusable row widgets ──────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  final ThemeConfig tc;
  final bool accent;
  const _GroupHeader({required this.label, required this.tc, this.accent = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6, top: 2),
    child: Text(label.toUpperCase(),
      style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700,
        color: accent ? const Color(0xFF7EB8A4) : Color(tc.ts))),
  );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final ThemeConfig tc;
  final VoidCallback onTap;
  final bool accent;
  const _NavTile({required this.icon, required this.title, required this.subtitle,
    required this.tc, required this.onTap, this.accent = false});
  @override
  Widget build(BuildContext context) {
    final c = accent ? const Color(0xFF7EB8A4) : Color(tc.acc);
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: settingsCardFill(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: c)),
        title: Text(title,
          style: TextStyle(fontSize: 14, color: Color(tc.tx))),
        subtitle: Text(subtitle,
          style: TextStyle(fontSize: 11, color: Color(tc.ts))),
        trailing: Icon(Icons.chevron_right_rounded, size: 18, color: Color(tc.tm)),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ThemeConfig tc;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.title, required this.value,
    required this.tc, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: Color(tc.acc).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: Color(tc.acc))),
      title: Text(title, style: TextStyle(fontSize: 14, color: Color(tc.tx))),
      trailing: AppSwitch(value: value, tc: tc, onChanged: onChanged),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-pages
// ─────────────────────────────────────────────────────────────────────────────

// ── Theme ─────────────────────────────────────────────────────────────────────
class _ThemePage extends StatelessWidget {
  const _ThemePage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(title: L.themeColors,
    body: ListView(padding: const EdgeInsets.all(16), children: [

      // Dynamic color (Material You)
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: settingsCardFill(context), borderRadius: BorderRadius.circular(14),
          border: state.settings.dynamicColor
              ? Border.all(color: Color(tc.acc), width: 1.5)
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7E57C2), Color(0xFF26A69A), Color(0xFFEF6C00)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L.dynamicColor,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(tc.tx))),
              Text(L.wallpaperTheme,
                style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            ])),
            AppSwitch(value: state.settings.dynamicColor, tc: tc,
              onChanged: (v) => state.setDynamicColor(v)),
          ]),
          if (state.settings.dynamicColor) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Color(tc.acc).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
              child: Text(L.dynamicEnabled,
                style: TextStyle(fontSize: 10, color: Color(tc.acc))),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      // Special Themes
      Text(L.specialThemes, style: TextStyle(fontSize: 11, color: Color(tc.ts), letterSpacing: 1)),
      const SizedBox(height: 10),
      _SpecialThemeTile(
        themeKey: 'black_hole',
        icon: Icons.brightness_3_rounded,
        title: L.themeBlackHole,
        subtitle: L.blackHoleThemeDesc,
        onTap: () => SettingsScreen._push(context, const _BlackHoleSettingsPage()),
      ),
      const SizedBox(height: 24),

      // Static themes grid
      Text(L.builtInPalette, style: TextStyle(fontSize: 11, color: Color(tc.ts), letterSpacing: 1)),
      const SizedBox(height: 10),
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8,
        childAspectRatio: 0.80,
        children: kThemes.entries
            .where((e) => e.key != 'black_hole') // Exclude black hole from grid
            .map((e) {
          final key = e.key; final t = e.value;
          final active = !state.settings.dynamicColor && state.settings.theme == key;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              state.setTheme(key);
              if (state.settings.dynamicColor) state.setDynamicColor(false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Color(t.bg),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? Color(tc.acc) : Color(t.brd),
                  width: active ? 2 : 1),
                boxShadow: active
                    ? [BoxShadow(color: Color(tc.acc).withOpacity(0.3), blurRadius: 8)]
                    : null,
              ),
              padding: const EdgeInsets.all(8),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(t.acc), Color(t.acc2)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: Colors.black12, width: 1)),
                ),
                const SizedBox(height: 6),
                Text(L.get(t.name),
                  style: TextStyle(fontSize: 9.5, color: Color(t.ts)),
                  textAlign: TextAlign.center),
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(Icons.check_circle, color: Color(tc.acc), size: 12)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),

      // Follow system dark mode
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L.followSystem,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(tc.tx))),
              Text(L.darkThemeAuto,
                style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            ])),
            AppSwitch(value: state.settings.followSystemTheme, tc: tc,
              onChanged: (v) => state.setFollowSystemTheme(v)),
          ]),
          if (state.settings.followSystemTheme) ...[
            Divider(color: Color(tc.brd), height: 20),
            Row(children: [
              Text(L.darkTheme, style: TextStyle(fontSize: 13, color: Color(tc.ts))),
              const Spacer(),
              DropdownButton<String>(
                value: state.settings.darkTheme,
                dropdownColor: settingsCardFill(context),
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 13, color: Color(tc.tx)),
                items: kThemes.entries
                    .where((e) => kThemes[e.key]!.bg < 0xFF888888) // dark themes
                    .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(L.get(e.value.name),
                        style: TextStyle(fontSize: 13, color: Color(tc.tx)))))
                    .toList()
                  ..addAll([
                    DropdownMenuItem(value: 'dark',
                      child: Text(kThemes['dark'] != null ? L.get(kThemes['dark']!.name) : L.darkThemeDefaultName,
                          style: TextStyle(fontSize: 13, color: Color(tc.tx)))),
                  ]),
                onChanged: (v) { if (v != null) state.setDarkTheme(v); },
              ),
            ]),
          ],
        ]),
      ),
    ]),
    );
  }
}

class _SpecialThemeTile extends StatelessWidget {
  final String themeKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SpecialThemeTile({
    required this.themeKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final active = state.settings.theme == themeKey && !state.settings.dynamicColor;
    final themeConfig = kThemes[themeKey]!;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        state.setTheme(themeKey);
        if (state.settings.dynamicColor) state.setDynamicColor(false);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: settingsCardFill(context),
          borderRadius: BorderRadius.circular(14),
          border: active ? Border.all(color: Color(tc.acc), width: 1.5) : null,
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Color(themeConfig.bg),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10)),
            child: Icon(icon, color: Color(themeConfig.acc), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(tc.tx))),
                if (themeKey == 'black_hole') ...[
                  const SizedBox(width: 8),
                  Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.orange.withOpacity(0.8)),
                ],
              ],
            ),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          ])),
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 20, color: Color(tc.ts)),
            onPressed: onTap,
          ),
          if (active) Icon(Icons.check_circle, color: Color(tc.acc), size: 18),
        ]),
      ),
    );
  }
}

class _BlackHoleSettingsPage extends StatelessWidget {
  const _BlackHoleSettingsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final s = state.settings.blackHole;

    return _SubPage(
      title: L.themeBlackHole,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(tc.card).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.orange.withOpacity(0.9)),
                    const SizedBox(width: 8),
                    Text(L.gargantuaWarningTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.orange.withOpacity(0.9))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(L.gargantuaWarningContent, style: TextStyle(fontSize: 12, color: Color(tc.ts), height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _GroupHeader(label: L.gargantuaAboutTitle, tc: tc),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(L.gargantuaAboutContent, style: TextStyle(fontSize: 12, color: Color(tc.ts), height: 1.6)),
          ),
          const SizedBox(height: 20),
          _GroupHeader(label: L.simulationParams, tc: tc),
          _SwitchTile(
            icon: Icons.blur_circular_rounded,
            title: L.accretionDisk,
            value: s.accretionDisk,
            tc: tc,
            onChanged: (v) => state.setBlackHoleAccretionDisk(v),
          ),
          _SwitchTile(
            icon: Icons.play_arrow_rounded,
            title: L.animateSimulation,
            value: s.animate,
            tc: tc,
            onChanged: (v) => state.setBlackHoleAnimate(v),
          ),
          const SizedBox(height: 16),
          _GroupHeader(label: L.advancedParams, tc: tc),
          _BlackHoleSlider(
            icon: Icons.speed_rounded,
            title: L.rotationSpeed,
            value: s.speed,
            min: 0.0, max: 0.05,
            tc: tc,
            onChanged: (v) => state.setBlackHoleSpeed(v),
          ),
          _BlackHoleSlider(
            icon: Icons.reorder_rounded,
            title: L.maxIterations,
            value: s.maxIterations.toDouble(),
            min: 16, max: 128,
            divisions: 7,
            tc: tc,
            onChanged: (v) => state.setBlackHoleMaxIterations(v.toInt()),
          ),
          const SizedBox(height: 24),
          Text(
            L.blackHoleSettingsHint,
            style: TextStyle(fontSize: 11, color: Color(tc.tm), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _BlackHoleSlider extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min, max;
  final int? divisions;
  final ThemeConfig tc;
  final ValueChanged<double> onChanged;

  const _BlackHoleSlider({
    required this.icon, required this.title, required this.value,
    required this.min, required this.max, this.divisions,
    required this.tc, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: Color(tc.acc)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, color: Color(tc.tx))),
        const Spacer(),
        Text(value.toStringAsFixed(divisions == null ? 3 : 0),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(tc.acc))),
      ]),
      Slider(
        value: value, min: min, max: max, divisions: divisions,
        activeColor: Color(tc.acc), inactiveColor: Color(tc.acc).withOpacity(0.2),
        onChanged: onChanged,
      ),
    ]),
  );
}

// ── Clock Style ───────────────────────────────────────────────────────────────
class _ClockStylePage extends StatelessWidget {
  const _ClockStylePage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final styles = [
      ('date',     '📅 ${L.dateTime}', L.clockStyleDateDesc),
      ('sunArc',   '☀️ ${L.sunArc}', L.clockStyleSunArcDesc),
      ('timeline', '📏 ${L.clockStyleTimelineLabel}', L.clockStyleTimelineDesc),
    ];
    return _SubPage(title: L.clockStyle,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _SwitchTile(
          icon: Icons.access_time_rounded,
          title: L.showTopClock,
          value: state.settings.showTopClock,
          tc: tc,
          onChanged: (_) => state.toggleShowTopClock(),
        ),
        const SizedBox(height: 24),
        Text(L.styleSelection, style: TextStyle(fontSize: 11, color: Color(tc.ts), letterSpacing: 1)),
        const SizedBox(height: 10),
        ...styles.map((s) {
          final active = state.settings.clockStyle == s.$1;
          return GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); state.setClockStyle(s.$1); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: active ? Color(tc.acc).withOpacity(0.10) : settingsCardFill(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? Color(tc.acc) : Colors.transparent,
                  width: 1.5),
              ),
              child: Row(children: [
                Text(s.$1 == 'date' ? '📅' : s.$1 == 'sunArc' ? '☀️' : '📏',
                  style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.$2.split(' ').skip(1).join(' '),
                    style: TextStyle(fontSize: 14, color: active ? Color(tc.acc) : Color(tc.tx),
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                  Text(s.$3, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
                ])),
                if (active) Icon(Icons.check_circle, color: Color(tc.acc), size: 18),
              ]),
            ),
          );
        }),
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(L.clockStyleHint,
            style: TextStyle(fontSize: 10, color: Color(tc.tm), fontStyle: FontStyle.italic))),
      ]));
  }
}

// ── Language ──────────────────────────────────────────────────────────────────
class _LanguagePage extends StatelessWidget {
  const _LanguagePage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(title: L.languageTitle,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final l in [('zh', L.chinese), ('en', L.english)]) ...[
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); state.setLang(l.$1); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: state.settings.lang == l.$1
                  ? Color(tc.acc).withOpacity(0.10) : settingsCardFill(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.settings.lang == l.$1 ? Color(tc.acc) : Colors.transparent,
                width: 1.5)),
            child: Row(children: [
              Text(l.$2, style: TextStyle(fontSize: 15, color: Color(tc.tx))),
              const Spacer(),
              if (state.settings.lang == l.$1)
                Icon(Icons.check_circle, color: Color(tc.acc), size: 18),
            ]),
          ),
        ),
      ],
      ]));
  }
}

// ── Default stats view ────────────────────────────────────────────────────────
class _DefaultViewPage extends StatelessWidget {
  const _DefaultViewPage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(title: L.defaultStatsView,
    body: ListView(padding: const EdgeInsets.all(16), children: [
      for (final v in [
        ('day', L.defaultCalViewDay, Icons.calendar_today_outlined),
        ('week', L.defaultCalViewWeek, Icons.view_week_outlined),
        ('month', L.defaultCalViewMonth, Icons.calendar_month_outlined),
        ('year', L.defaultCalViewYear, Icons.calendar_today),
      ])
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); state.setDefaultCalView(v.$1); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: state.settings.defaultCalView == v.$1
                  ? Color(tc.acc).withOpacity(0.10) : settingsCardFill(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.settings.defaultCalView == v.$1
                    ? Color(tc.acc) : Colors.transparent, width: 1.5)),
            child: Row(children: [
              Icon(v.$3, size: 18, color: Color(tc.ts)),
              const SizedBox(width: 12),
              Text(v.$2, style: TextStyle(fontSize: 14, color: Color(tc.tx))),
              const Spacer(),
              if (state.settings.defaultCalView == v.$1)
                Icon(Icons.check_circle, color: Color(tc.acc), size: 18),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Thresholds ────────────────────────────────────────────────────────────────
class _ThresholdsPage extends StatelessWidget {
  const _ThresholdsPage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(title: L.heatmapThreshold,
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(L.heatmapThresholdDesc,
        style: TextStyle(fontSize: 12, color: Color(tc.ts))),
      const SizedBox(height: 16),
      StatefulBuilder(builder: (_, setSt) {
        final t = state.settings.colorThresholds;
        final labels = [
          (L.yellowStart, 1, 20),
          (L.greenStart, 1, 20),
          (L.goldStart, 1, 30)
        ];
        return Column(children: [
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              SizedBox(width: 72, child: Text(labels[i].$1,
                style: TextStyle(fontSize: 12, color: Color(tc.tx)))),
              Expanded(child: Slider(
                value: t[i].toDouble(),
                min: labels[i].$2.toDouble(),
                max: labels[i].$3.toDouble(),
                divisions: labels[i].$3 - labels[i].$2,
                activeColor: Color(tc.acc),
                inactiveColor: Color(tc.brd),
                onChanged: (v) {
                  setSt(() {
                    final nt = List<int>.from(t);
                    nt[i] = v.round();
                    state.setColorThresholds(nt);
                  });
                },
              )),
              SizedBox(width: 36, child: Text('≥${t[i]}',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(tc.acc)))),
            ]),
          )),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(10)),
            child: Text(L.heatmapLegend(t[0], t[1], t[2]),
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          ),
        ]);
      }),
      ]));
  }
}

// ── Pomodoro ──────────────────────────────────────────────────────────────────
class _PomPage extends StatelessWidget {
  const _PomPage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final acc = Color(tc.acc);
    final p = state.settings.pom;

    return _SubPage(
      title: L.pomSettings,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 核心参数 ──────────────────────────────────────────────────
          _SectionHeader(L.pomParams, tc),
          _Card(
            tc: tc,
            child: StatefulBuilder(builder: (_, setSt) {
              return Column(children: [
                _EnhancedSliderRow(
                  icon: '⏱️',
                  label: L.focusDuration,
                  val: p.focusMins.toDouble(),
                  min: 5, max: 90, unit: L.minute,
                  tc: tc,
                  onChanged: (v) {
                    setSt(() {});
                    state.updatePomSettings(focusMins: v.round());
                  }),
                const SizedBox(height: 12),
                _EnhancedSliderRow(
                  icon: '☕',
                  label: L.shortBreak,
                  val: p.breakMins.toDouble(),
                  min: 1, max: 30, unit: L.minute,
                  tc: tc,
                  onChanged: (v) {
                    setSt(() {});
                    state.updatePomSettings(breakMins: v.round());
                  }),
                const SizedBox(height: 12),
                _EnhancedSliderRow(
                  icon: '🛌',
                  label: L.longBreak,
                  val: p.longBreakMins.toDouble(),
                  min: 5, max: 60, unit: L.minute,
                  tc: tc,
                  onChanged: (v) {
                    setSt(() {});
                    state.updatePomSettings(longBreakMins: v.round());
                  }),
                const SizedBox(height: 12),
                _EnhancedSliderRow(
                  icon: '🔄',
                  label: L.longBreakInterval,
                  val: p.longBreakInterval.toDouble(),
                  min: 2, max: 8, unit: L.pomRoundCount(0).replaceAll('0', '').trim(),
                  tc: tc,
                  onChanged: (v) {
                    setSt(() {});
                    state.updatePomSettings(longBreakInterval: v.round());
                  }),
                const SizedBox(height: 16),
                Divider(color: Color(tc.brd), height: 1),
                const SizedBox(height: 12),
                _SwitchRow(
                  L.trackFocusTime,
                  p.trackTime, tc,
                  (v) => state.updatePomSettings(trackTime: v)),
              ]);
            })),

          const SizedBox(height: 24),
          // ── 提醒设置 ──────────────────────────────────────────────────
          _SectionHeader(L.phaseEndReminder, tc),
          _Card(
            tc: tc,
            child: StatefulBuilder(builder: (_, setSt3) {
              return Column(children: [
                _SwitchRow(L.alarmSound, p.alarmSound, tc, (v) {
                  setSt3(() {});
                  state.updatePomSettings(alarmSound: v);
                }),
                _DescText(L.alarmSoundDesc, tc),
                const SizedBox(height: 12),
                Divider(color: Color(tc.brd), height: 1),
                const SizedBox(height: 12),
                _SwitchRow(L.vibrateReminder, p.alarmVibrate, tc, (v) {
                  setSt3(() {});
                  state.updatePomSettings(alarmVibrate: v);
                }),
                _DescText(L.vibrateReminderDesc, tc),
              ]);
            })),

          const SizedBox(height: 24),
          // ── 显示与刻度条 ──────────────────────────────────────────────
          _SectionHeader(L.clockStyleTimelineLabel, tc),
          _Card(
            tc: tc,
            child: StatefulBuilder(builder: (_, setSt2) {
              return Column(children: [
                _SwitchRow(L.showTopClock, p.showRuler, tc,
                  (v) { setSt2(() {}); state.updatePomSettings(showRuler: v); }),
                if (p.showRuler) ...[
                  const SizedBox(height: 16),
                  Divider(color: Color(tc.brd), height: 1),
                  const SizedBox(height: 16),
                  Row(children: [
                    Icon(Icons.straighten_rounded, size: 16, color: acc),
                    const SizedBox(width: 8),
                    Text(L.rulerPositionSize,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(tc.tx))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        state.updatePomSettings(
                          rulerTopFrac: 0.120, rulerHeightFrac: 0.600,
                          rulerLeft: 6.0, rulerWidth: 34.0);
                        setSt2(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: acc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(L.reset, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: acc)))),
                  ]),
                  const SizedBox(height: 16),
                  _SliderRow(L.topPosition, p.rulerTopFrac * 100, 5, 60, '%', tc,
                    (v) { setSt2(() {}); state.updatePomSettings(rulerTopFrac: v / 100); }),
                  _SliderRow(L.displayHeight, p.rulerHeightFrac * 100, 15, 80, '%', tc,
                    (v) { setSt2(() {}); state.updatePomSettings(rulerHeightFrac: v / 100); }),
                  _SliderRow(L.leftOffset, p.rulerLeft, 0, 80, 'px', tc,
                    (v) { setSt2(() {}); state.updatePomSettings(rulerLeft: v); }),
                  _SliderRow(L.width, p.rulerWidth, 16, 60, 'px', tc,
                    (v) { setSt2(() {}); state.updatePomSettings(rulerWidth: v); }),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: acc.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: acc.withOpacity(0.15))),
                    child: Text(
                      L.rulerPreviewHint,
                      style: TextStyle(fontSize: 10.5, color: Color(tc.ts), height: 1.45))),
                ],
              ]);
            })),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeConfig tc;
  const _SectionHeader(this.title, this.tc);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(title, style: TextStyle(
      fontSize: 11.5, fontWeight: FontWeight.w800,
      letterSpacing: 1.2, color: Color(tc.ts))));
}

class _DescText extends StatelessWidget {
  final String text;
  final ThemeConfig tc;
  const _DescText(this.text, this.tc);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
    child: Text(text, style: TextStyle(fontSize: 10.5, color: Color(tc.tm), height: 1.4)));
}

class _EnhancedSliderRow extends StatelessWidget {
  final String icon, label, unit;
  final double val, min, max;
  final ThemeConfig tc;
  final ValueChanged<double> onChanged;
  const _EnhancedSliderRow({
    required this.icon, required this.label, required this.val,
    required this.min, required this.max, required this.unit,
    required this.tc, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final acc = Color(tc.acc);
    return Column(children: [
      Row(children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(tc.tx))),
        const Spacer(),
        Text('${val.round()} $unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: acc)),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 3),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor: acc,
          inactiveTrackColor: Color(tc.brd),
          thumbColor: acc,
          overlayColor: acc.withOpacity(0.15),
        ),
        child: Slider(
          value: val, min: min, max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}

// ── App Name ──────────────────────────────────────────────────────────────────
class _AppNamePage extends StatefulWidget {
  const _AppNamePage();
  @override State<_AppNamePage> createState() => _AppNamePageState();
}
class _AppNamePageState extends State<_AppNamePage> {
  late TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: context.read<AppState>().settings.appName);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(title: L.appName,
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      _Card(tc: tc, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L.appNameHint,
          style: TextStyle(fontSize: 11, color: Color(tc.ts))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            style: TextStyle(fontSize: 15, color: Color(tc.tx), fontFamily: 'serif'),
            decoration: InputDecoration(
              hintText: L.defaultAppName, hintStyle: TextStyle(color: Color(tc.tm)),
              fillColor: Color(tc.cb)),
            onSubmitted: (v) {
              state.setAppName(v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(L.saved), duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating));
            },
            onTapOutside: (_) => state.setAppName(_ctrl.text),
          )),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () { _ctrl.text = L.defaultAppName; state.setAppName(L.defaultAppName); },
            child: Text(L.reset, style: TextStyle(color: Color(tc.ts)))),
        ]),
      ])),
      ])));
  }
}

// ── Tags ──────────────────────────────────────────────────────────────────────
class _TagsPage extends StatefulWidget {
  const _TagsPage();
  @override State<_TagsPage> createState() => _TagsPageState();
}
class _TagsPageState extends State<_TagsPage> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(title: L.tagManagement,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Card(tc: tc, child: Wrap(spacing: 8, runSpacing: 8,
          children: state.tags.map((tag) {
            final c = state.tagColor(tag);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tag, style: TextStyle(fontSize: 13, color: c)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => state.removeTag(tag),
                  child: Icon(Icons.close, size: 14, color: c.withOpacity(0.7))),
              ]));
          }).toList())),
        const SizedBox(height: 12),
        _Card(tc: tc, child: Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            style: TextStyle(fontSize: 14, color: Color(tc.tx)),
            decoration: InputDecoration(
              hintText: L.newTagHint,
              hintStyle: TextStyle(color: Color(tc.tm)),
              fillColor: Color(tc.cb)),
            textInputAction: TextInputAction.done,
            maxLength: 12,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onSubmitted: (_) { _addTag(state); },
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _addTag(state),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Color(tc.na), shape: BoxShape.circle),
              child: Icon(Icons.add, color: Color(tc.nt), size: 20))),
        ])),
      ]));
  }
  void _addTag(AppState state) {
    final tag = _ctrl.text.trim();
    if (tag.isEmpty) return;
    state.addTag(tag);
    _ctrl.clear();
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.tagAdded(tag)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating));
  }
}

// ── Tag Filter ────────────────────────────────────────────────────────────────
class _TagFilterPage extends StatefulWidget {
  const _TagFilterPage();
  @override State<_TagFilterPage> createState() => _TagFilterPageState();
}
class _TagFilterPageState extends State<_TagFilterPage> {
  final _groupCtrl = TextEditingController();
  @override void dispose() { _groupCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final mode = state.settings.tagFilterMode;
    return _SubPage(title: L.tagFilter,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Mode
        _Card(tc: tc, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.filterMode, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          const SizedBox(height: 10),
          Row(children: [
            for (final m in [('all',L.filterAll),('whitelist',L.filterWhitelist),('blacklist',L.filterBlacklist)]) ...[
              if (m.$1 != 'all') const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => state.setTagFilterMode(m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: mode == m.$1 ? Color(tc.na) : Color(tc.cb),
                    borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(m.$2,
                    style: TextStyle(fontSize: 13,
                      color: mode == m.$1 ? Color(tc.nt) : Color(tc.ts),
                      fontWeight: mode == m.$1 ? FontWeight.w600 : FontWeight.normal)))))),
            ],
          ]),
        ])),
        if (mode != 'all') ...[
          const SizedBox(height: 12),
          _Card(tc: tc, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mode == 'whitelist' ? L.whitelistDesc : L.blacklistDesc,
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: state.tags.map((tag) {
              final isIn = mode == 'whitelist'
                  ? state.settings.tagWhitelist.contains(tag)
                  : state.settings.tagBlacklist.contains(tag);
              final c = state.tagColor(tag);
              return GestureDetector(
                onTap: () { state.toggleTagInFilter(tag); setState(() {}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isIn ? c : Color(tc.cb),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isIn ? c : Color(tc.brd), width: 1.5)),
                  child: Text(tag,
                    style: TextStyle(fontSize: 12,
                      color: isIn ? Color(tc.nt) : Color(tc.ct)))));
            }).toList()),
          ])),
        ],
        // Saved groups
        if (state.settings.filterGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Card(tc: tc, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L.savedGroups, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: state.settings.filterGroups.map((g) {
              final isActive = state.settings.activeGroup == g.name;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => state.applyFilterGroup(isActive ? null : g.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? Color(tc.na) : Color(tc.cb),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16))),
                    child: Text(g.name,
                      style: TextStyle(fontSize: 12,
                        color: isActive ? Color(tc.nt) : Color(tc.ts))))),
                GestureDetector(
                  onTap: () => state.removeFilterGroup(g.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Color(tc.brd),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16))),
                    child: Text('×', style: TextStyle(fontSize: 13, color: Color(tc.tm))))),
              ]);
            }).toList()),
          ])),
        ],
      ]));
  }
}

// ── Semester ──────────────────────────────────────────────────────────────────
class _SemesterPage extends StatefulWidget {
  const _SemesterPage();
  @override State<_SemesterPage> createState() => _SemesterPageState();
}
class _SemesterPageState extends State<_SemesterPage> {
  bool _showAdd = false;
  DateTime? _semDate;
  final _numCtrl = TextEditingController();
  final _wksCtrl = TextEditingController();
  @override void dispose() { _numCtrl.dispose(); _wksCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final sems = [...state.settings.sems]..sort((a,b)=>a.start.compareTo(b.start));
    return _SubPage(title: L.semesterSettings,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Card(tc: tc, child: _SwitchRow(L.showSemesterWeek, state.settings.showSem, tc,
          (_) => state.toggleShowSem())),
        const SizedBox(height: 12),
        if (sems.isNotEmpty) ...[
          ...sems.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text(L.semesterNum(s.num.toString()),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(tc.acc))),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '${s.start}${s.weekCount != null ? ' · ${s.weekCount}${L.week}' : ''}',
                style: TextStyle(fontSize: 12, color: Color(tc.ts)))),
              GestureDetector(
                onTap: () => state.removeSemester(s.start),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: Color(tc.tm))),
            ]))),
        ],
        if (_showAdd) _Card(tc: tc, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.semesterStartDate, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final p = await showDatePicker(context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (p != null) setState(() => _semDate = p);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(8)),
              child: Text(
                _semDate != null ? DateUtils2.fmt(_semDate!) : L.selectDate,
                style: TextStyle(fontSize: 13,
                  color: _semDate != null ? Color(tc.tx) : Color(tc.tm))))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L.semesterNum('').replaceAll(' ', '').replaceAll(':', ''), style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              const SizedBox(height: 4),
              TextField(controller: _numCtrl, keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 13, color: Color(tc.tx)),
                decoration: InputDecoration(hintText: 'e.g. 3', fillColor: Color(tc.cb))),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L.weekCountHint, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              const SizedBox(height: 4),
              TextField(controller: _wksCtrl, keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 13, color: Color(tc.tx)),
                decoration: InputDecoration(hintText: 'e.g. 18', fillColor: Color(tc.cb))),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(tc.na),
                foregroundColor: Color(tc.nt), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                final num = int.tryParse(_numCtrl.text);
                if (_semDate == null || num == null) return;
                state.addSemester(num, DateUtils2.fmt(_semDate!), int.tryParse(_wksCtrl.text));
                setState(() { _showAdd = false; _semDate = null; _numCtrl.clear(); _wksCtrl.clear(); });
              }, child: Text(L.add))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: BorderSide(color: Color(tc.brd)),
                foregroundColor: Color(tc.ts), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => setState(() => _showAdd = false),
              child: Text(L.cancel))),
          ]),
        ]))
        else TextButton.icon(
          onPressed: () => setState(() => _showAdd = true),
          icon: const Icon(Icons.add),
          label: Text(L.addSemester),
          style: TextButton.styleFrom(foregroundColor: Color(tc.acc))),
      ]));
  }
}

// ── Data Overview ─────────────────────────────────────────────────────────────
class _DataPage extends StatelessWidget {
  const _DataPage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final total = state.tasks.length;
    final done  = state.tasks.where((t)=>t.done).length;
    final rate  = total > 0 ? (done/total*100).round() : 0;
    return _SubPage(title: L.dataOverview, tc: tc,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Card(tc: tc, child: Column(children: [
          _DR(L.firstUse, state.settings.installDate ?? '—', tc),
          Divider(color: Color(tc.brd), height: 1),
          _DR(L.totalTasks, '$total', tc),
          Divider(color: Color(tc.brd), height: 1),
          _DR(L.completedTasks, '$done', tc, Color(tc.acc)),
          Divider(color: Color(tc.brd), height: 1),
          _DR(L.completionRateLabel, '$rate%', tc),
        ])),
      ]));
  }
}

Widget _DR(String label, String val, ThemeConfig tc, [Color? vc]) =>
  Padding(padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Color(tc.tx)))),
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
        color: vc ?? Color(tc.tx))),
    ]));

// ── Beta ──────────────────────────────────────────────────────────────────────
class _BetaPage extends StatelessWidget {
  const _BetaPage();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final s = state.settings;
    const accent = Color(0xFF7EB8A4);
    return _SubPage(title: L.betaFeatures, tc: tc,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _BetaRow(context, '🤖', L.betaSmartPlan, L.betaSmartPlanDesc,
          s.betaSmartPlan, tc, (v) => state.setBetaFlag('smartPlan', v)),
        _BetaRow(context, '📱', L.betaUsageStats, L.betaUsageStatsDesc,
          s.betaUsageStats, tc, (v) => state.setBetaFlag('usageStats', v)),
        if (s.betaUsageStats) ...[
          const SizedBox(height: 4),
          _AppCategoryLink(),
          const SizedBox(height: 4),
        ],
        _BetaRow(context, '🌌', L.betaTaskGravity, L.betaTaskGravityDesc,
          s.betaTaskGravity, tc, (v) => state.setBetaFlag('taskGravity', v)),
        // 灵动岛已知在部分设备导致闪退，暂时停用
        // _BetaRow(context, '🏝', '灵动岛计时通知', ...),

        const SizedBox(height: 16),
        _BetaDivider(L.betaFocusEnhance, tc),
        _BetaRow(context, '📊', L.betaDeepFocusAnalysis,
          L.betaDeepFocusAnalysisDesc,
          s.betaDeepFocusAnalysis, tc,
          (v) => state.setBetaFlag('deepFocusAnalysis', v)),
        _BetaRow(context, '✨', L.betaAmbientFx,
          L.betaAmbientFxDesc,
          s.betaAmbientFx, tc,
          (v) => state.setBetaFlag('ambientFx', v)),
        _BetaRow(context, '🔔', L.betaPersistNotif,
          L.betaPersistNotifDesc,
          s.betaPersistNotif, tc,
          (v) => state.setBetaFlag('persistNotif', v)),

        const SizedBox(height: 16),
        _BetaDivider(L.betaWeatherEffects, tc),
        _BetaRow(context, '🌤', L.betaWeather,
          L.betaWeatherDesc,
          s.betaWeather, tc,
          (v) => state.setBetaFlag('weather', v)),
        if (s.betaWeather) ...[
          const SizedBox(height: 8),
          _WeatherConfigCard(state: state, tc: tc),
          const SizedBox(height: 4),
        ],

        const SizedBox(height: 16),
        _BetaDivider(L.seasonalTheme, tc),
        _BetaRow(context, '🎉', L.betaFestivalAutoTheme,
          L.betaFestivalAutoThemeDesc,
          s.autoFestivalTheme, tc,
          (v) => state.setAutoFestivalTheme(v)),

        const SizedBox(height: 16),
        _BetaDivider(L.betaFocusQualityAndEnv, tc),
        _BetaRow(context, '⭐', L.betaFocusQuality,
          L.betaFocusQualityDesc,
          s.focusQualityEnabled, tc,
          (v) => state.setFocusQuality(v)),
        _BetaRow(context, '🎙', L.betaNoisePom,
          L.betaNoisePomDesc,
          s.noisePomEnabled, tc,
          (v) => state.setNoisePomEnabled(v)),
        _BetaRow(context, '📵', L.betaDistractionAlert,
          L.betaDistractionAlertDesc,
          s.distractionAlertEnabled, tc,
          (v) => state.setDistractionAlert(v)),
        _BetaRow(context, '✨', L.betaAnimationsEnhanced,
          L.betaAnimationsEnhancedDesc,
          s.animationsEnhanced, tc,
          (v) => state.setAnimationsEnhanced(v)),

        const SizedBox(height: 24),
        // ── 危险区：数据导出 ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFc04040).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFc04040).withOpacity(0.4))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(L.betaDangerZone,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFFc04040))),
            ]),
            const SizedBox(height: 8),
            Text(L.betaDangerZoneDesc,
              style: TextStyle(fontSize: 11, color: Color(tc.ts), height: 1.5)),
            const SizedBox(height: 12),
            _DataExportButton(state: state, tc: tc),
          ])),
      ]));
  }
}

// ── 视觉中心 ────────────────────────────────────────────────────────────────
class _VisualCenterPage extends StatelessWidget {
  const _VisualCenterPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final todayFestival = getTodayFestival();
    final acc = Color(kThemes[todayFestival?.id ?? state.settings.theme]?.acc ?? tc.acc);
    return _SubPage(
      title: L.visualCenterTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GroupHeader(label: L.themeColors, tc: tc),
          _NavTile(
            icon: Icons.palette_outlined,
            title: L.themeColor,
            subtitle: state.settings.dynamicColor ? L.dynamicThemeDesc : L.builtInPalette,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _ThemePage()),
          ),
          _NavTile(
            icon: Icons.auto_awesome_outlined,
            title: L.seasonalTheme,
            subtitle: L.seasonalThemeSubtitle,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _SeasonalThemePage()),
          ),
          _NavTile(
            icon: Icons.public_rounded,
            title: L.festivalCalendar,
            subtitle: L.festivalCalendarSubtitle,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _FestivalCalendarPage()),
          ),
          if (todayFestival != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: acc.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: acc.withOpacity(0.18))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(todayFestival.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(L.get(todayFestival.name),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(tc.tx)))),
                  ]),
                  const SizedBox(height: 6),
                  Text(L.get(todayFestival.tagline),
                    style: TextStyle(fontSize: 12.5, color: Color(tc.ts), height: 1.5)),
                  const SizedBox(height: 6),
                  Text(L.get(todayFestival.description),
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Color(tc.ts), height: 1.5)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          _GroupHeader(label: L.wallpaperAndTransparency, tc: tc),
          _AppearanceContent(), // 提取自 _AppearancePage 的核心内容
          const SizedBox(height: 16),

          _GroupHeader(label: L.liquidGlass, tc: tc),
          _LiquidGlassContent(), // 提取自 _LiquidGlassSettingsPage 的核心内容
          const SizedBox(height: 16),

          _GroupHeader(label: L.componentDisplay, tc: tc),
          _NavTile(
            icon: Icons.access_time_rounded,
            title: L.topClock,
            subtitle: state.settings.showTopClock ? L.enabled : L.disabled,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _ClockStylePage()),
          ),
        ],
      ),
    );
  }
}

// 提取的外观配置内容组件
class _AppearanceContent extends StatelessWidget {
  const _AppearanceContent();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final hasImage = state.settings.customBgImagePath != null;

    return Column(
      children: [
        if (state.showsGlobalWallpaper) ...[
          _NavTile(
            icon: Icons.image_outlined,
            title: L.wallpaperSettings,
            subtitle: hasImage ? L.customImageSet : L.builtInWallpaper,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _AppearancePage()),
          ),
          _SliderTile(
            icon: Icons.opacity,
            title: L.globalOpacityTitle,
            value: state.settings.globalOpacity,
            min: 0.3,
            max: 1.0,
            tc: tc,
            onChanged: (v) => state.setGlobalOpacity(v),
            trailing: '${(state.settings.globalOpacity * 100).round()}%',
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.wallpaper_rounded, size: 20, color: Color(tc.ts)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L.wallpaperNotEnabled, style: TextStyle(fontSize: 14, color: Color(tc.tx))),
                Text(L.wallpaperEnableHint, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              ])),
              TextButton(
                onPressed: () => SettingsScreen._push(context, const _AppearancePage()),
                child: Text(L.goToSettings, style: TextStyle(color: Color(tc.acc)))),
            ]),
          ),
        ],
      ],
    );
  }
}

// 提取的 Liquid Glass 内容组件
class _LiquidGlassContent extends StatelessWidget {
  const _LiquidGlassContent();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return Column(
      children: [
        _SliderTile(
          icon: Icons.blur_on_rounded,
          title: L.glassTransparency,
          value: 1.0 - state.settings.glassEffectIntensity,
          min: 0.0,
          max: 1.0,
          tc: tc,
          onChanged: (v) => state.setGlassEffectIntensity(1.0 - v),
          trailing: '${((1.0 - state.settings.glassEffectIntensity) * 100).toInt()}%',
          subtitle: L.glassTransparencyDesc,
        ),
        _SliderTile(
          icon: Icons.vertical_align_center_rounded,
          title: L.topBarOffset,
          value: state.settings.topBarOffset,
          min: -40,
          max: 60,
          tc: tc,
          onChanged: (v) => state.setTopBarOffset(v),
          trailing: '${state.settings.topBarOffset.toInt()} px',
          subtitle: L.topBarOffsetDesc,
        ),
      ],
    );
  }
}

// 新增的 SliderTile 组件，用于统一样式
class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double value;
  final double min, max;
  final ThemeConfig tc;
  final ValueChanged<double> onChanged;
  final String trailing;

  const _SliderTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.tc,
    required this.onChanged,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final acc = Color(tc.acc);
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: settingsCardFill(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: acc.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: acc)),
            title: Text(title, style: TextStyle(fontSize: 14, color: Color(tc.tx))),
            subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 11, color: Color(tc.ts))) : null,
            trailing: Text(trailing, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: acc)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: acc,
                inactiveTrackColor: acc.withOpacity(0.1),
                thumbColor: acc,
                overlayColor: acc.withOpacity(0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 全局外观页 ────────────────────────────────────────────────────────────────
// ── 标签系统 ────────────────────────────────────────────────────────────────
class _TagSystemPage extends StatelessWidget {
  const _TagSystemPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(
      title: L.tagSystem,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GroupHeader(label: L.tagManagement, tc: tc),
          _NavTile(
            icon: Icons.label_outline_rounded,
            title: L.editTags,
            subtitle: L.editTagsSubtitle,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _TagsPage()),
          ),
          const SizedBox(height: 16),
          _GroupHeader(label: L.statsFilter, tc: tc),
          _NavTile(
            icon: Icons.filter_list_rounded,
            title: L.filterMode,
            subtitle: state.settings.tagFilterMode == 'all' ? L.filterModeSubtitleAll : L.filterModeSubtitleList,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _TagFilterPage()),
          ),
        ],
      ),
    );
  }
}

// ── 统计与视图 ──────────────────────────────────────────────────────────────
class _StatsViewPage extends StatelessWidget {
  const _StatsViewPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(
      title: L.statsView,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GroupHeader(label: L.defaultStatsView, tc: tc),
          _NavTile(
            icon: Icons.calendar_view_day_outlined,
            title: L.defaultStatsView,
            subtitle: L.get('screens.settings.defaultStatsViewSubtitle'),
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _DefaultViewPage()),
          ),
          const SizedBox(height: 16),
          _GroupHeader(label: L.heatmapThreshold, tc: tc),
          _NavTile(
            icon: Icons.color_lens_outlined,
            title: L.heatmapThreshold,
            subtitle: L.heatmapThresholdSubtitle,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _ThresholdsPage()),
          ),
        ],
      ),
    );
  }
}

// ── 通用设置 ────────────────────────────────────────────────────────────────
class _GeneralAppPage extends StatelessWidget {
  const _GeneralAppPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(
      title: L.general,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GroupHeader(label: L.basicInfo, tc: tc),
          _NavTile(
            icon: Icons.edit_note_rounded,
            title: L.appName,
            subtitle: state.settings.appName,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _AppNamePage()),
          ),
          const SizedBox(height: 16),
          _GroupHeader(label: L.shareAndExport, tc: tc),
          _NavTile(
            icon: Icons.ios_share_rounded,
            title: L.shareAndReport,
            subtitle: L.shareAndReportSubtitle,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _ShareReportPage()),
          ),
        ],
      ),
    );
  }
}

// ── 数据与安全 ──────────────────────────────────────────────────────────────
class _DataSafetyPage extends StatelessWidget {
  const _DataSafetyPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    return _SubPage(
      title: L.dataSafety,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GroupHeader(label: L.overview, tc: tc),
          _NavTile(
            icon: Icons.bar_chart_rounded,
            title: L.dataOverview,
            subtitle: L.overviewSubtitle,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _DataPage()),
          ),
          const SizedBox(height: 16),
          _GroupHeader(label: L.troubleshooting, tc: tc),
          _NavTile(
            icon: Icons.bug_report_outlined,
            title: L.crashLog,
            subtitle: L.crashLogSubtitle,
            tc: tc,
            onTap: () => SettingsScreen._push(context, const _CrashLogScreen()),
          ),
        ],
      ),
    );
  }
}

// ── About Page (Simple wrapper for existing _AboutScreen) ────────────────────
class _PomodoroSettingsPage extends StatelessWidget {
  const _PomodoroSettingsPage();
  @override
  Widget build(BuildContext context) => const _PomPage();
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();
  @override
  Widget build(BuildContext context) => const _AboutScreen();
}

// ── 季节 & 节日主题页 ─────────────────────────────────────────────────────────
class _SeasonalThemePage extends StatelessWidget {
  const _SeasonalThemePage();

  static List<(String, List<String>)> _getGroups() => [
    (L.themeGroupSeasons, ['spring', 'summer', 'autumn', 'winter']),
    (L.themeGroupTraditional, ['dragon_boat', 'lunar_new_year', 'mid_autumn']),
    (L.themeGroupWorld, ['world_water_day']),
    (L.themeGroupClassic, ['warm', 'green', 'indigo', 'sunset', 'lavender', 'dark', 'cherry', 'forest']),
    (L.themeGroupSpecial, []),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final acc = Color(tc.acc);
    final suggested = seasonalThemeSuggestion();
    final todayFestival = getTodayFestival();
    final groups = _getGroups();

    return _SubPage(title: L.seasonalThemeTitle,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // ── 今日节日特别 banner（优先于应景推荐）─────────────────────────
          if (todayFestival != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _FestivalDetailPage(festival: todayFestival))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      Color(kThemes[todayFestival.id]?.acc ?? tc.acc).withOpacity(0.18),
                      Color(kThemes[todayFestival.id]?.acc2 ?? tc.acc2).withOpacity(0.08),
                    ]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color(kThemes[todayFestival.id]?.acc ?? tc.acc).withOpacity(0.40),
                    width: 1.5)),
                child: Row(children: [
                  Text(todayFestival.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(kThemes[todayFestival.id]?.acc ?? tc.acc).withOpacity(0.20),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(L.todayLabel, style: TextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.w700,
                            color: Color(kThemes[todayFestival.id]?.acc ?? tc.acc)))),
                      const SizedBox(width: 6),
                      Text(L.get(todayFestival.name), style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: Color(tc.tx))),
                    ]),
                    const SizedBox(height: 4),
                    Text(L.get(todayFestival.tagline), style: TextStyle(
                        fontSize: 11, color: Color(tc.ts), height: 1.4)),
                    const SizedBox(height: 6),
                    Row(children: [
                      GestureDetector(
                        onTap: () {
                          state.setTheme(todayFestival.id);
                          HapticFeedback.mediumImpact();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Color(kThemes[todayFestival.id]?.acc ?? tc.acc),
                            borderRadius: BorderRadius.circular(10)),
                          child: Text(L.applyThemeBtn, style: const TextStyle(
                              fontSize: 11, color: Colors.white,
                              fontWeight: FontWeight.w700)))),
                      const SizedBox(width: 8),
                      Text(L.learnMoreFestival, style: TextStyle(
                          fontSize: 10, color: Color(tc.ts))),
                    ]),
                  ])),
                ]),
              ),
            ),

          // Seasonal suggestion banner
          if (suggested != null && suggested != todayFestival?.id) Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                acc.withOpacity(0.12), Color(tc.acc2).withOpacity(0.06)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: acc.withOpacity(0.25))),
            child: Row(children: [
              Text(_seasonEmoji(), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L.get('screens.settings.seasonalSuggestionTitle', {'name': kThemes[suggested] != null ? L.get(kThemes[suggested]!.name) : ''}),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: Color(tc.tx))),
                Text(L.get('screens.settings.seasonalSuggestionSubtitle'),
                  style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              ])),
              GestureDetector(
                onTap: () { state.setTheme(suggested); HapticFeedback.lightImpact(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: acc,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(L.get('screens.settings.applyNow'), style: const TextStyle(
                      fontSize: 12, color: Colors.white,
                      fontWeight: FontWeight.w700)))),
            ])),
          ...groups.map((group) {
            final (label, keys) = group;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Text(label, style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: Color(tc.ts)))),
              if (keys.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: settingsCardFill(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(tc.brd).withOpacity(0.6))),
                  child: Text(L.get('screens.settings.specialThemeEmpty'),
                      style: TextStyle(fontSize: 11, color: Color(tc.ts))))
              else
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10, crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: keys.map((key) {
                  final theme = kThemes[key];
                  if (theme == null) return const SizedBox.shrink();
                  final isSelected = state.settings.theme == key;
                  final festival = getFestivalByTheme(key);
                  final isFestival = festival != null;
                  return GestureDetector(
                    onTap: () { state.setTheme(key); HapticFeedback.lightImpact(); },
                    onLongPress: isFestival ? () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => _FestivalDetailPage(festival: festival))) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(theme.card),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Color(theme.acc) : Color(theme.brd),
                          width: isSelected ? 2.5 : 1.2)),
                      child: Row(children: [
                        // Color swatch — festival shows emoji instead
                        isFestival
                          ? Text(festival.emoji,
                              style: const TextStyle(fontSize: 18))
                          : Container(width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: Color(theme.acc),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Color(theme.acc2), width: 3))),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(L.get(theme.name), style: TextStyle(fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                color: Color(theme.tx))),
                            if (isFestival)
                              Text(festival.dateLabel, style: TextStyle(
                                  fontSize: 8.5, color: Color(theme.ts))),
                          ])),
                        if (isSelected)
                          Icon(Icons.check_rounded, size: 14,
                              color: Color(theme.acc))
                        else if (isFestival)
                          Icon(Icons.info_outline_rounded, size: 12,
                              color: Color(theme.ts)),
                      ])));
                }).toList()),
              const SizedBox(height: 8),
            ]);
          }),
        ]));
  }

  String _seasonEmoji() {
    final m = DateTime.now().month;
    if (m <= 2 || m == 12) return '❄️';
    if (m <= 4) return '🌸';
    if (m <= 7) return '☀️';
    if (m <= 10) return '🍂';
    return '🌙';
  }
}

// ── 节日详情页 ─────────────────────────────────────────────────────────────────
class _FestivalDetailPage extends StatelessWidget {
  final FestivalInfo festival;
  const _FestivalDetailPage({required this.festival});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc    = state.themeConfig;
    // Use festival theme colours if available, else fallback to current
    final ft    = kThemes[festival.id] ?? tc;
    final acc   = Color(ft.acc);
    final isCurrentTheme = state.settings.theme == festival.id;

    return Scaffold(
      backgroundColor:
          state.showsGlobalWallpaper ? Colors.transparent : Color(ft.bg),
      appBar: AppBar(
        backgroundColor: state.showsGlobalWallpaper
            ? state.chromeBarColor(ft)
            : Color(ft.bg),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(ft.ts)),
          onPressed: () => Navigator.pop(context)),
        title: Text(L.get(festival.name),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: Color(ft.tx))),
        actions: [
          if (!isCurrentTheme)
            TextButton(
              onPressed: () {
                state.setTheme(festival.id);
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              child: Text(L.get('screens.settings.applyTheme'), style: TextStyle(
                  color: acc, fontWeight: FontWeight.w700, fontSize: 14))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 48), children: [

        // ── Hero 节日标题区 ───────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [acc.withOpacity(0.18), Color(ft.acc2).withOpacity(0.08)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: acc.withOpacity(0.30))),
          child: Column(children: [
            Text(festival.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(L.get(festival.name), style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900,
                color: Color(ft.tx), letterSpacing: 1.0)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: acc.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10)),
              child: Text(festival.dateLabel, style: TextStyle(
                  fontSize: 12, color: acc, fontWeight: FontWeight.w600))),
            const SizedBox(height: 10),
            Text(L.get(festival.tagline), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(ft.ts),
                  height: 1.6, fontStyle: FontStyle.italic)),
          ])),

        // ── 节日介绍 ─────────────────────────────────────────────────────
        _FestSection(title: L.get('screens.settings.festivalIntro'), icon: '📖', ft: ft,
          child: Text(L.get(festival.description),
            style: TextStyle(fontSize: 13, color: Color(ft.ts), height: 1.7))),

        const SizedBox(height: 12),

        // ── 有趣事实 ─────────────────────────────────────────────────────
        _FestSection(title: L.get('screens.settings.interestingFacts'), icon: '💡', ft: ft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: festival.facts.asMap().entries.map((e) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3, right: 10),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: acc.withOpacity(0.15),
                      shape: BoxShape.circle),
                    child: Center(child: Text('${e.key + 1}',
                        style: TextStyle(fontSize: 9.5,
                            fontWeight: FontWeight.w800, color: acc)))),
                  Expanded(child: Text(L.get(e.value),
                      style: TextStyle(fontSize: 12.5,
                          color: Color(ft.ts), height: 1.55))),
                ]))).toList())),

        const SizedBox(height: 12),

        // ── 主题设计说明 ─────────────────────────────────────────────────
        _FestSection(title: L.get('screens.settings.themeDesignDesc'), icon: '🎨', ft: ft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colour swatches
              Row(children: [
                _ColorSwatch(label: L.get('screens.settings.primaryColor'), color: acc),
                const SizedBox(width: 8),
                _ColorSwatch(label: L.get('screens.settings.secondaryColor'), color: Color(ft.acc2)),
                const SizedBox(width: 8),
                _ColorSwatch(label: L.get('screens.settings.backgroundColor'), color: Color(ft.bg),
                    border: Color(ft.brd)),
              ]),
              const SizedBox(height: 10),
              Text(L.get(festival.themeReason),
                  style: TextStyle(fontSize: 12.5,
                      color: Color(ft.ts), height: 1.6)),
            ])),

        const SizedBox(height: 20),

        // Apply button
        if (!isCurrentTheme)
          GestureDetector(
            onTap: () {
              state.setTheme(festival.id);
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: acc,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: acc.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(festival.emoji),
                const SizedBox(width: 8),
                Text(L.get('screens.settings.applyThemeWithName', {'name': L.get(festival.name)}),
                  style: const TextStyle(fontSize: 14, color: Colors.white,
                      fontWeight: FontWeight.w800)),
              ])))
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: acc.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: acc.withOpacity(0.30))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_rounded, size: 18, color: acc),
              const SizedBox(width: 8),
              Text(L.get('screens.settings.themeAlreadyActive'),
                style: TextStyle(fontSize: 13, color: acc,
                    fontWeight: FontWeight.w700)),
            ])),
      ]));
  }
}

class _FestSection extends StatelessWidget {
  final String title, icon;
  final ThemeConfig ft;
  final Widget child;
  const _FestSection({required this.title, required this.icon,
      required this.ft, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: settingsFestCardFill(context, ft),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Color(ft.brd).withOpacity(0.6))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: Color(ft.tx))),
      ]),
      const SizedBox(height: 12),
      child,
    ]));
}

class _ColorSwatch extends StatelessWidget {
  final String label;
  final Color color;
  final Color? border;
  const _ColorSwatch({required this.label, required this.color, this.border});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: border != null ? Border.all(color: border!, width: 1.5) : null,
          boxShadow: [BoxShadow(color: color.withOpacity(0.30), blurRadius: 6)])),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
    ]);
}

// ── 分享与报告页 ──────────────────────────────────────────────────────────────
class _ShareReportPage extends StatefulWidget {
  const _ShareReportPage();
  @override State<_ShareReportPage> createState() => _ShareReportPageState();
}

class _ShareReportPageState extends State<_ShareReportPage> {
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final acc = Color(tc.acc);

    return _SubPage(title: L.get('screens.settings.shareAndReport'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Weekly report
          _ReportCard(
            icon: '📊', title: L.get('screens.settings.weeklyReport'), tc: tc, acc: acc,
            subtitle: L.get('screens.settings.weeklyReportSubtitle'),
            loading: _sharing,
            onShare: () async {
              setState(() => _sharing = true);
              final text = ShareService.buildWeeklyReport(state);
              await ShareService.shareText(text, subject: L.get('screens.settings.weeklyReportSubject'));
              if (mounted) setState(() => _sharing = false);
            }),
          const SizedBox(height: 12),
          // Monthly report
          _ReportCard(
            icon: '📅', title: L.get('screens.settings.monthlyReport'), tc: tc, acc: acc,
            subtitle: L.get('screens.settings.monthlyReportSubtitle'),
            loading: _sharing,
            onShare: () async {
              setState(() => _sharing = true);
              final text = ShareService.buildMonthlyReport(state);
              await ShareService.shareText(text, subject: L.get('screens.settings.monthlyReportSubject'));
              if (mounted) setState(() => _sharing = false);
            }),
          const SizedBox(height: 12),
          // Data export hint
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: settingsCardFill(context), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('💡', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(L.get('screens.settings.moreExportOptions'), style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Color(tc.tx))),
              ]),
              const SizedBox(height: 6),
              Text(L.get('screens.settings.moreExportOptionsDesc'),
                style: TextStyle(fontSize: 11.5, color: Color(tc.ts), height: 1.45)),
            ])),
        ]));
  }
}

class _ReportCard extends StatelessWidget {
  final String icon, title, subtitle;
  final ThemeConfig tc;
  final Color acc;
  final bool loading;
  final VoidCallback onShare;
  const _ReportCard({required this.icon, required this.title,
      required this.subtitle, required this.tc, required this.acc,
      required this.loading, required this.onShare});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: settingsCardFill(context), borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 6)]),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 32)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: Color(tc.tx))),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Color(tc.ts),
            height: 1.4)),
      ])),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: loading ? null : onShare,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: loading ? Color(tc.brd) : acc,
            borderRadius: BorderRadius.circular(10)),
          child: loading
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.ios_share_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(L.share, style: const TextStyle(fontSize: 12,
                  color: Colors.white, fontWeight: FontWeight.w700)),
            ]))),
    ]));
}

class _AppearancePage extends StatefulWidget {
  const _AppearancePage();
  @override State<_AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<_AppearancePage> {
  static const _bgCh = MethodChannel('com.lsz.app/bg_image');
  bool _picking = false;

  // Quick preset backgrounds
  static List<({String label, int? color})> _getBgPresets() => [
    (label: L.get('screens.common.default'), color: null),
    (label: L.get('screens.today.presets.warmWhite'), color: 0xFFFFF8F0),
    (label: L.get('screens.today.presets.beige'), color: 0xFFF7F3E8),
    (label: L.get('screens.today.presets.lightGreen'), color: 0xFFF0F5F0),
    (label: L.get('screens.today.presets.lightBlue'), color: 0xFFF0F4FA),
    (label: L.get('screens.today.presets.lightPurple'), color: 0xFFF5F0FA),
    (label: L.get('screens.today.presets.lightPink'), color: 0xFFFAF0F2),
    (label: L.get('screens.today.presets.limestone'), color: 0xFFF2F2F0),
    (label: L.get('screens.today.presets.darkGray'), color: 0xFF1C1C1E),
    (label: L.get('screens.today.presets.darkBlue'), color: 0xFF161B22),
    (label: L.get('screens.today.presets.darkGreen'), color: 0xFF141E18),
  ];

  Future<void> _pickImage(AppState state) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final path = await _bgCh.invokeMethod<String?>('pickImage');
      if (path != null && mounted) {
        state.setCustomBgImagePath(path);
        // When image is set, default opacity to 0.88 for glass effect
        if (state.settings.globalOpacity > 0.95) {
          state.setGlobalOpacity(0.88);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _clearImage(AppState state) async {
    try { await _bgCh.invokeMethod('clearImage'); } catch (_) {}
    state.setCustomBgImagePath(null);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final acc = Color(tc.acc);
    final hasImage = state.settings.customBgImagePath != null;

    return _SubPage(title: L.get('screens.settings.globalAppearance'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [

        // ── 自定义背景图片 ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: settingsCardFill(context), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.wallpaper_rounded, size: 18, color: acc),
              const SizedBox(width: 8),
              Text(L.get('screens.settings.customBgImage'),
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600, color: Color(tc.tx))),
            ]),
            const SizedBox(height: 4),
            Text(L.get('screens.settings.customBgImageHint'),
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            const SizedBox(height: 14),

            // Preview + pick button
            if (hasImage) ...[
              // Image preview strip
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(
                      dart_io.File(state.settings.customBgImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Color(tc.brd),
                        child: Center(child: Icon(
                            Icons.broken_image_rounded, color: Color(tc.tm)))),
                    ),
                    // Overlay with Opacity preview
                    Positioned.fill(child: Opacity(
                      opacity: 1.0 - state.settings.globalOpacity,
                      child: Container(color: Color(tc.bg)),
                    )),
                    // "当前效果预览" label
                    Positioned(
                      bottom: 8, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(L.get('screens.settings.currentPreview'),
                          style: const TextStyle(fontSize: 9, color: Colors.white)),
                      )),
                  ]),
                )),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: acc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: acc.withOpacity(0.30))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.photo_library_rounded, size: 15, color: acc),
                        const SizedBox(width: 6),
                        Text(L.get('screens.settings.changeWallpaper'),
                          style: TextStyle(fontSize: 12,
                              color: acc, fontWeight: FontWeight.w600)),
                      ]))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _clearImage(state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Color(tc.brd).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.delete_outline_rounded, size: 15,
                            color: Color(tc.ts)),
                        const SizedBox(width: 6),
                        Text(L.delete,
                          style: TextStyle(fontSize: 12, color: Color(tc.ts))),
                      ]))),
                ),
              ]),
            ] else ...[
              // No image — big pick button
              GestureDetector(
                onTap: _picking ? null : () => _pickImage(state),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: _picking
                        ? acc.withOpacity(0.06)
                        : acc.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: acc.withOpacity(0.20), width: 1.5)),
                  child: Column(children: [
                    Icon(_picking
                        ? Icons.hourglass_top_rounded
                        : Icons.add_photo_alternate_outlined,
                        size: 28, color: acc.withOpacity(0.7)),
                    const SizedBox(height: 8),
                    Text(_picking ? L.get('screens.settings.openingGallery') : L.get('screens.settings.uploadWallpaper'),
                      style: TextStyle(fontSize: 12,
                          color: acc, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(L.get('screens.settings.wallpaperUploadHint'),
                      style: TextStyle(fontSize: 10, color: Color(tc.tm))),
                  ]),
                )),
            ],
          ])),
        const SizedBox(height: 12),

        // ── 整体透明度 ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: settingsCardFill(context), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.opacity, size: 18, color: acc),
              const SizedBox(width: 8),
              Text(L.get('screens.settings.globalOpacityTitle'), style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: Color(tc.tx))),
              const Spacer(),
              Text('${(state.settings.globalOpacity * 100).round()}%',
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: acc)),
            ]),
            const SizedBox(height: 4),
            Text(hasImage
                ? L.get('screens.settings.globalOpacityHintImage')
                : L.get('screens.settings.globalOpacityHintNoImage'),
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: acc,
                inactiveTrackColor: Color(tc.brd),
                thumbColor: acc,
                overlayColor: acc.withOpacity(0.15)),
              child: Slider(
                value: state.settings.globalOpacity,
                min: 0.3, max: 1.0, divisions: 14,
                onChanged: (v) => state.setGlobalOpacity(v))),
            // Preview strip
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Opacity(
                opacity: state.settings.globalOpacity,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [acc, Color(tc.acc2), acc.withOpacity(0.3)]))))),
            // Quick presets row
            const SizedBox(height: 10),
            Row(children: [
              for (final preset in [
                (label: '100%', val: 1.0),
                (label: '90%',  val: 0.9),
                (label: '80%',  val: 0.8),
                (label: '70%',  val: 0.7),
                (label: '60%',  val: 0.6),
              ]) ...[
                Expanded(child: GestureDetector(
                  onTap: () {
                    state.setGlobalOpacity(preset.val);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: (state.settings.globalOpacity - preset.val).abs() < 0.01
                          ? acc.withOpacity(0.15)
                          : Color(tc.brd).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(preset.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5,
                        color: (state.settings.globalOpacity - preset.val).abs() < 0.01
                            ? acc : Color(tc.ts),
                        fontWeight: FontWeight.w600))))),
              ],
            ]),
          ])),
        const SizedBox(height: 12),

        // ── 顶栏 / 底栏透明度（与整体透明度相乘，仅背景图模式）────────────────
        if (hasImage) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: settingsCardFill(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.vertical_align_top_rounded, size: 18, color: acc),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      L.get('screens.settings.topChromeOpacityTitle'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(tc.tx),
                      ),
                    ),
                  ),
                  Text(
                    '${(state.settings.topChromeOpacity * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: acc,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  L.get('screens.settings.topChromeOpacityHint'),
                  style: TextStyle(fontSize: 11, color: Color(tc.ts)),
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: acc,
                    inactiveTrackColor: Color(tc.brd),
                    thumbColor: acc,
                    overlayColor: acc.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: state.settings.topChromeOpacity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    onChanged: (v) => state.setTopChromeOpacity(v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── 背景色（当无图片时作为底色使用）─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: settingsCardFill(context), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.format_paint_outlined, size: 18, color: acc),
              const SizedBox(width: 8),
              Text(L.get('screens.settings.globalBgColor'), style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: Color(tc.tx))),
            ]),
            const SizedBox(height: 4),
            Text(hasImage
                ? L.get('screens.settings.globalBgColorHintImage')
                : L.get('screens.settings.globalBgColorHintNoImage'),
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: _getBgPresets().map((p) {
              final selected = state.settings.customBgColor == p.color;
              return GestureDetector(
                onTap: () {
                  state.setCustomBgColor(p.color);
                  HapticFeedback.lightImpact();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: p.color != null ? Color(p.color!) : Color(tc.bg),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? acc : Color(tc.brd),
                      width: selected ? 2.5 : 1)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    if (selected)
                      Icon(Icons.check_rounded, size: 16, color: acc),
                    Text(p.label, style: TextStyle(
                      fontSize: 9.5,
                      color: p.color != null
                          ? (p.color! > 0xFF888888
                              ? const Color(0xFF444444)
                              : const Color(0xFFCCCCCC))
                          : Color(tc.ts),
                      fontWeight: selected
                          ? FontWeight.w700 : FontWeight.normal)),
                  ])));
            }).toList()),
            if (state.settings.customBgColor != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => state.setCustomBgColor(null),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: Color(tc.brd).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(L.get('screens.settings.restoreDefaultBg'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(tc.ts))))),
            ],
          ])),
        const SizedBox(height: 12),

        // ── 使用提示 ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: acc.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: acc.withOpacity(0.15))),
          child: Text(
            hasImage
                ? L.get('screens.settings.wallpaperModeTip')
                : L.get('screens.settings.colorModeTip'),
            style: TextStyle(
                fontSize: 11, color: Color(tc.ts), height: 1.5))),
      ]));
  }
}

class _AppCategoryLink extends StatelessWidget {
  const _AppCategoryLink();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final count = state.settings.userAppCategories.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<AppState>(),
            child: AppCategoryPage(tc: context.read<AppState>().themeConfig)))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Color(tc.cb), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(tc.brd))),
          child: Row(children: [
            const Text('🗂', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              count > 0 ? L.get('screens.settings.customCategoriesSet', {'count': count}) : L.get('screens.settings.customAppCategories'),
              style: TextStyle(fontSize: 12, color: Color(tc.ts)))),
            Icon(Icons.chevron_right_rounded, size: 16, color: Color(tc.tm)),
          ]),
        ),
      ),
    );
  }
}

// ── Beta section divider ──────────────────────────────────────────────────────
Widget _BetaDivider(String label, ThemeConfig tc) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(children: [
    Expanded(child: Divider(color: Color(tc.brd), height: 1)),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(fontSize: 10, color: Color(tc.tm),
        letterSpacing: 1.0, fontWeight: FontWeight.w600)),
    const SizedBox(width: 10),
    Expanded(child: Divider(color: Color(tc.brd), height: 1)),
  ]));

// ── Weather config card (v3) — 和风天气 QWeather JWT + API Key ─────────────
class _WeatherConfigCard extends StatefulWidget {
  final AppState state;
  final ThemeConfig tc;
  const _WeatherConfigCard({required this.state, required this.tc});
  @override State<_WeatherConfigCard> createState() => _WeatherConfigCardState();
}

class _WeatherConfigCardState extends State<_WeatherConfigCard> {
  late TextEditingController _keyCtrl, _cityCtrl, _jwtCtrl, _kidCtrl, _subCtrl, _hostCtrl;
  bool _showApiSection = false;
  bool _useJwt = false;
  bool _showKey = false; // show/hide private key

  static const List<WeatherType> _allTypes = [
    WeatherType.none, WeatherType.clear, WeatherType.sunnyCloudy,
    WeatherType.partlyCloudy, WeatherType.overcast, WeatherType.drizzle,
    WeatherType.lightRain, WeatherType.heavyRain, WeatherType.thunderstorm,
    WeatherType.hail, WeatherType.sleet, WeatherType.lightSnow,
    WeatherType.heavySnow, WeatherType.blizzard, WeatherType.fog,
    WeatherType.haze, WeatherType.sand, WeatherType.dustStorm,
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _keyCtrl  = TextEditingController(text: s.weatherApiKey);
    _cityCtrl = TextEditingController(text: s.weatherCity);
    _jwtCtrl  = TextEditingController(text: s.weatherJwtSecret);
    _kidCtrl  = TextEditingController(text: s.weatherJwtKid);
    _subCtrl  = TextEditingController(text: s.weatherJwtSub);
    _hostCtrl = TextEditingController(text: s.weatherApiHost);
    // 如果用户未填私钥，默认选 JWT 模式（内嵌凭据）
    _useJwt   = s.weatherJwtSecret.isNotEmpty || s.weatherApiKey.isEmpty;
  }

  @override
  void dispose() {
    _keyCtrl.dispose(); _cityCtrl.dispose(); _jwtCtrl.dispose();
    _kidCtrl.dispose(); _subCtrl.dispose();  _hostCtrl.dispose();
    super.dispose();
  }

  void _restart() {
    final s = widget.state.settings;
    if (s.betaWeather) {
      WeatherService.start(
        s.weatherApiKey, s.weatherCity, s.pinnedWeatherEffect,
        jwtSecret: s.weatherJwtSecret, jwtKid: s.weatherJwtKid,
        jwtSub: s.weatherJwtSub, apiHost: s.weatherApiHost,
        onUpdate: (_) { if (mounted) setState(() {}); },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tc = widget.tc;
    final acc = Color(tc.acc);
    final s = state.settings;
    final currentPinned = weatherTypeFromKey(s.pinnedWeatherEffect);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: settingsCardFill(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(tc.brd).withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 常驻天气特效选择 ──────────────────────────────────────────────
        Row(children: [
          Text(L.get('screens.settings.weather.pinnedEffect'), style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(tc.tx))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: acc.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
            child: Text(currentPinned == WeatherType.none ? L.get('screens.settings.weather.followRealtime') : L.get('screens.settings.weather.pinned'),
                style: TextStyle(fontSize: 9.5, color: acc, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 5),
        Text(L.get('screens.settings.weather.pinnedEffectHint'),
            style: TextStyle(fontSize: 10, color: Color(tc.ts))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _allTypes.map((type) {
            final meta = kWeatherMeta[type]!;
            final selected = currentPinned == type;
            return GestureDetector(
              onTap: () {
                state.setWeatherConfig(pinned: meta.key);
                WeatherService.setPinned(meta.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? acc.withOpacity(0.15) : Color(tc.bg).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? acc : Color(tc.brd).withOpacity(0.5),
                      width: selected ? 1.5 : 1.0)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(type == WeatherType.none ? '🌐' : meta.emoji,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(type == WeatherType.none ? L.get('screens.settings.weather.followRealtimeLabel') : meta.label,
                      style: TextStyle(fontSize: 10,
                          color: selected ? acc : Color(tc.tx),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
                ]),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),
        Divider(color: Color(tc.brd).withOpacity(0.5), height: 1),
        const SizedBox(height: 12),

        // ── 实时天气配置 ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _showApiSection = !_showApiSection),
          child: Row(children: [
            const Text('🌐', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 7),
            Text(L.get('screens.settings.weather.apiConfig'), style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(tc.tx))),
            const Spacer(),
            Icon(_showApiSection ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Color(tc.ts)),
          ]),
        ),

        if (_showApiSection) ...[
          const SizedBox(height: 10),

          // 内嵌凭据说明横幅
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: acc.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: acc.withOpacity(0.20)),
            ),
            child: Row(children: [
              const Text('✅', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L.get('screens.settings.weather.embeddedCreds'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: acc)),
                Text(L.get('screens.settings.weather.embeddedCredsHint'),
                    style: TextStyle(fontSize: 9.5, color: Color(tc.ts), height: 1.35),
                    maxLines: 2),
              ])),
            ]),
          ),
          const SizedBox(height: 10),

          // 城市
          _CfgRow(tc: tc, label: L.get('screens.settings.weather.city'), hint: 'Beijing / Tokyo',
            ctrl: _cityCtrl,
            onChanged: (v) {
              state.setWeatherConfig(city: v);
              _restart();
            }),
          const SizedBox(height: 8),

          // API Host（高级，留空使用内嵌）
          _CfgRow(tc: tc, label: 'API Host',
            hint: L.get('screens.settings.weather.hostHint'),
            ctrl: _hostCtrl,
            onChanged: (v) {
              state.setWeatherConfig(apiHost: v);
              _restart();
            }),
          const SizedBox(height: 10),

          // 认证方式切换
          Row(children: [
            GestureDetector(
              onTap: () => setState(() => _useJwt = false),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: !_useJwt ? acc : Colors.transparent,
                    border: Border.all(color: acc, width: 1.5)),
                  child: !_useJwt ? const Icon(Icons.check, size: 10, color: Colors.white) : null),
                const SizedBox(width: 5),
                const Text('API Key', style: TextStyle(fontSize: 11,
                    color: Colors.grey, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => setState(() => _useJwt = true),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _useJwt ? acc : Colors.transparent,
                    border: Border.all(color: acc, width: 1.5)),
                  child: _useJwt ? const Icon(Icons.check, size: 10, color: Colors.white) : null),
                const SizedBox(width: 5),
                Text(L.get('screens.settings.weather.jwtRecommended'), style: TextStyle(fontSize: 11,
                    color: _useJwt ? acc : Color(tc.ts), fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),

          if (!_useJwt) ...[
            // API Key 模式
            _CfgRow(tc: tc, label: 'API Key', hint: L.get('screens.settings.weather.apiKeyHint'),
              ctrl: _keyCtrl, obscure: !_showKey,
              onChanged: (v) {
                state.setWeatherConfig(apiKey: v);
                _restart();
              }),
            const SizedBox(height: 4),
            Text(L.get('screens.settings.weather.apiKeyHelp'),
                style: TextStyle(fontSize: 9.5, color: Color(tc.tm), height: 1.4)),
          ] else ...[
            // JWT 模式：需要 凭据ID(kid) + 项目ID(sub) + Ed25519私钥
            _CfgRow(tc: tc, label: L.get('screens.settings.weather.kidLabel'), hint: L.get('screens.settings.weather.kidHint'),
              ctrl: _kidCtrl,
              onChanged: (v) {
                state.setWeatherConfig(jwtKid: v);
                _restart();
              }),
            const SizedBox(height: 6),
            _CfgRow(tc: tc, label: L.get('screens.settings.weather.subLabel'), hint: L.get('screens.settings.weather.subHint'),
              ctrl: _subCtrl,
              onChanged: (v) {
                state.setWeatherConfig(jwtSub: v);
                _restart();
              }),
            const SizedBox(height: 6),
            // Private key multi-line
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(tc.bg).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(L.get('screens.settings.weather.privateKeyLabel'), style: TextStyle(
                      fontSize: 10.5, color: Color(tc.ts), fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showKey = !_showKey),
                    child: Text(_showKey ? L.get('screens.common.hide') : L.get('screens.common.show'),
                        style: TextStyle(fontSize: 9.5, color: acc))),
                ]),
                const SizedBox(height: 6),
                TextField(
                  controller: _jwtCtrl,
                  maxLines: _showKey ? 6 : 2,
                  obscureText: false,
                  style: TextStyle(fontSize: 9.5, color: Color(tc.tx),
                      fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText: '-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----',
                    hintStyle: TextStyle(fontSize: 9, color: Colors.grey),
                    isDense: true, border: InputBorder.none,
                    filled: false),
                  onChanged: (v) {
                    state.setWeatherConfig(jwtSecret: v);
                    _restart();
                  }),
              ])),
            const SizedBox(height: 6),
            Text(L.get('screens.settings.weather.jwtHelp'),
                style: TextStyle(fontSize: 9.5, color: Color(tc.tm), height: 1.45)),
          ],
        ],
      ]),
    );
  }
}

class _CfgRow extends StatelessWidget {
  final ThemeConfig tc;
  final String label, hint;
  final TextEditingController ctrl;
  final void Function(String)? onChanged;
  final bool obscure;
  const _CfgRow({required this.tc, required this.label, required this.hint,
      required this.ctrl, this.onChanged, this.obscure = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 58, child: Text(label,
        style: TextStyle(fontSize: 10.5, color: Color(tc.ts)))),
    const SizedBox(width: 8),
    Expanded(child: TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(fontSize: 11.5, color: Color(tc.tx)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 10, color: Color(tc.tm)),
        isDense: true, border: InputBorder.none,
        filled: true, fillColor: Color(tc.bg).withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7)),
      onChanged: onChanged)),
  ]);
}


Widget _BetaRow(BuildContext context, String icon, String title, String desc, bool value,
    ThemeConfig tc, ValueChanged<bool> onChanged) =>
  Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(tc.tx))),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(fontSize: 10.5, color: Color(tc.ts), height: 1.4)),
      ])),
      const SizedBox(width: 8),
      AppSwitch(value: value, tc: tc, onChanged: onChanged),
    ]),
  );

// ── Shared card/row helpers ───────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final ThemeConfig tc; final Widget child;
  const _Card({required this.tc, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Color(0x0C000000), blurRadius: 8)]),
    child: child);
}

Widget _SliderRow(String label, double val, double min, double max,
    String unit, ThemeConfig tc, ValueChanged<double> cb) =>
  StatefulBuilder(builder: (_, setSt) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      SizedBox(width: 68, child: Text(label, style: TextStyle(fontSize: 13, color: Color(tc.tx)))),
      Expanded(child: Slider(value: val, min: min, max: max,
        divisions: (max-min).round(),
        activeColor: Color(tc.acc), inactiveColor: Color(tc.brd),
        onChanged: (v) { setSt(() {}); cb(v); })),
      SizedBox(width: 46, child: Text('${val.round()} $unit', textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(tc.acc)))),
    ])));

Widget _SwitchRow(String label, bool val, ThemeConfig tc, ValueChanged<bool> cb) =>
  Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Color(tc.tx)))),
    AppSwitch(value: val, tc: tc, onChanged: cb),
  ]);

// ─────────────────────────────────────────────────────────────────────────────
// About screen + changelog
// ─────────────────────────────────────────────────────────────────────────────
class _AboutScreen extends StatelessWidget {
  const _AboutScreen();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final appName = state.settings.appName.trim();
    final showName = appName.isEmpty || appName == '流水账' || appName == 'Liushuizhang'
        ? L.get('screens.settings.defaultAppName')
        : appName;
    return Scaffold(
      backgroundColor:
          state.showsGlobalWallpaper ? Colors.transparent : Color(tc.bg),
      appBar: AppBar(
        backgroundColor: state.chromeBarColor(tc), elevation: 0,
        title: Text(L.aboutApp, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Center(child: Column(children: [
          ClipRRect(borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/about_icon.png', width: 80, height: 80, fit: BoxFit.cover)),
          const SizedBox(height: 16),
          Text(showName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
            color: Color(tc.tx), fontFamily: 'serif')),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('β.0.085', style: TextStyle(fontSize: 13, color: Color(tc.ts))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Color(tc.acc).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('β', style: TextStyle(fontSize: 11, color: Color(tc.acc), fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 4),
          Text(L.get('screens.about.subtitle'), style: TextStyle(fontSize: 12, color: Color(tc.tm))),
        ])),
        const SizedBox(height: 32),

        // ── 更新路线图 ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const _RoadmapPage())),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(tc.acc).withOpacity(0.10), Color(tc.acc2).withOpacity(0.06)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(tc.acc).withOpacity(0.20))),
            child: Row(children: [
              Text('🗺', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L.get('screens.about.futureRoadmap'), style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: Color(tc.tx))),
                const SizedBox(height: 3),
                Text(L.get('screens.about.roadmapSubtitle'),
                  style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(tc.tm)),
            ]))),
        const SizedBox(height: 12),

        // ── 节日日历 ────────────────────────────────────────────────────
        const SizedBox(height: 24),

        // Changelog
        Text(L.get('screens.about.changelog'), style: TextStyle(fontSize: 11, color: Color(tc.ts), letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ..._getChangelog().map((entry) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: settingsCardFill(context), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(tc.acc).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(entry.$1,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(tc.acc)))),
              const SizedBox(width: 8),
              Text(entry.$2, style: TextStyle(fontSize: 10, color: Color(tc.tm))),
            ]),
            const SizedBox(height: 8),
            ...entry.$3.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('· ', style: TextStyle(color: Color(tc.acc))),
                Expanded(child: Text(item,
                  style: TextStyle(fontSize: 12, color: Color(tc.ts), height: 1.5))),
              ]))),
          ]))),

        const SizedBox(height: 24),
        Center(child: Column(children: [
          Text('𝒜𝓇𝒾𝓈𝑜',
            style: TextStyle(fontSize: 28, color: Color(tc.acc), fontFamily: 'serif')),
          const SizedBox(height: 6),
          Text(L.get('screens.about.footerLabel'), style: TextStyle(fontSize: 12, color: Color(tc.ts))),
          Text('Mindless · Useless',
            style: TextStyle(fontSize: 11, color: Color(tc.tm), fontStyle: FontStyle.italic)),
        ])),
      ]),
    );
  }

  static const List<(String, String, String)> _changelogMeta = [
    ('β.0.085', '2026-03', 'beta_0_085'),
    ('β.0.084', '2026-03', 'beta_0_084'),
    ('β.0.083', '2026-03', 'beta_0_083'),
    ('β.0.082', '2026-03', 'beta_0_082'),
    ('β.0.081', '2026-03', 'beta_0_081'),
    ('β.0.080', '2026-03', 'beta_0_080'),
    ('β.0.079', '2026-03', 'beta_0_079'),
  ];

  static List<(String, String, List<String>)> _getChangelog() => _changelogMeta.map((e) {
    final items = L.get('screens.about.changelogData.${e.$3}')
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return (e.$1, e.$2, items);
  }).toList();
}
// ── 节日日历页 ─────────────────────────────────────────────────────────────────
class _FestivalCalendarPage extends StatelessWidget {
  const _FestivalCalendarPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc    = state.themeConfig;
    final acc   = Color(tc.acc);
    final today = DateTime.now();

    return Scaffold(
      backgroundColor:
          state.showsGlobalWallpaper ? Colors.transparent : Color(tc.bg),
      appBar: AppBar(
        backgroundColor: state.chromeBarColor(tc), elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context)),
        title: Text(L.get('screens.settings.festivalCalendar'), style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 48), children: [
        // Header note
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: acc.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: acc.withOpacity(0.18))),
          child: Text(
            L.get('screens.settings.festivalCalendarHint'),
            style: TextStyle(fontSize: 11, color: Color(tc.ts), height: 1.55))),

        // Festival list
        ...kFestivals.map((festival) {
          final ft = kThemes[festival.id] ?? tc;
          final festAcc = Color(ft.acc);
          final isToday = festival.isToday;
          final isCurrentTheme = state.settings.theme == festival.id;
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _FestivalDetailPage(festival: festival))),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: settingsFestCardFill(context, ft),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday
                      ? festAcc.withOpacity(0.60)
                      : Color(ft.brd).withOpacity(0.60),
                  width: isToday ? 2.0 : 1.0),
                boxShadow: isToday ? [BoxShadow(
                    color: festAcc.withOpacity(0.15),
                    blurRadius: 12, offset: const Offset(0, 3))] : null),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top strip with festival colour
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [festAcc, Color(ft.acc2)]),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(festival.emoji,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Text(L.get(festival.name), style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: Color(ft.tx))),
                            const SizedBox(width: 8),
                            if (isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: festAcc.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8)),
                                child: Text(L.get('time.today'), style: TextStyle(
                                    fontSize: 9.5, fontWeight: FontWeight.w700,
                                    color: festAcc))),
                            if (isCurrentTheme && !isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: festAcc.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8)),
                                child: Text(L.get('screens.settings.current'), style: TextStyle(
                                    fontSize: 9.5, color: festAcc))),
                          ]),
                          const SizedBox(height: 3),
                          Text(festival.dateLabel, style: TextStyle(
                              fontSize: 11, color: festAcc,
                              fontWeight: FontWeight.w600)),
                          const SizedBox(height: 5),
                          Text(L.get(festival.tagline), style: TextStyle(
                              fontSize: 11.5, color: Color(ft.ts),
                              height: 1.45)),
                        ])),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12,
                          color: Color(ft.tm)),
                    ]),
                  ),
                ]),
            ));
        }),
      ]),
    );
  }
}

// ── Roadmap Page ──────────────────────────────────────────────────────────────
class _RoadmapPage extends StatelessWidget {
  const _RoadmapPage();

  static List<(String, String, String)> _parseTriples(String raw) {
    final lines = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final out = <(String, String, String)>[];
    for (final line in lines) {
      final parts = line.split('||');
      if (parts.length < 3) continue;
      out.add((parts[0].trim(), parts[1].trim(), parts[2].trim()));
    }
    return out;
  }

  static List<(String, String, String, bool)> _parseItems(String raw) {
    final triples = _parseTriples(raw);
    return triples.map((t) => (t.$1, t.$2, t.$3, false)).toList();
  }

  static List<(String, String, String)> _getInstalled() =>
      _parseTriples(L.get('screens.about.roadmapData.installed'));

  static List<(String, List<(String, String, String, bool)>)> _getSections() => [
    (L.get('screens.about.roadmapData.sections.task.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.task.items'))),
    (L.get('screens.about.roadmapData.sections.search.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.search.items'))),
    (L.get('screens.about.roadmapData.sections.pomodoro.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.pomodoro.items'))),
    (L.get('screens.about.roadmapData.sections.stats.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.stats.items'))),
    (L.get('screens.about.roadmapData.sections.ai.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.ai.items'))),
    (L.get('screens.about.roadmapData.sections.ui.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.ui.items'))),
    (L.get('screens.about.roadmapData.sections.notif.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.notif.items'))),
    (L.get('screens.about.roadmapData.sections.platform.title'),
        _parseItems(L.get('screens.about.roadmapData.sections.platform.items'))),
  ];


  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final acc = Color(tc.acc);
    final installed = _getInstalled();
    final sections = _getSections();
    return Scaffold(
      backgroundColor:
          state.showsGlobalWallpaper ? Colors.transparent : Color(tc.bg),
      appBar: AppBar(
        backgroundColor: state.chromeBarColor(tc), elevation: 0,
        title: Text(L.get('screens.about.futureRoadmap'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: Color(tc.tx))),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
            onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: acc.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: acc.withOpacity(0.18))),
          child: Text(L.get('screens.about.roadmapLegend'),
            style: TextStyle(fontSize: 10.5, color: Color(tc.ts),
                height: 1.6))),

        // ── 已实装板块 ─────────────────────────────────────────────────────
        if (installed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Text(L.get('screens.about.roadmapInstalled'), style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: const Color(0xFF4A9068),
                letterSpacing: 0.5))),
          ...installed.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A9068).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4A9068).withOpacity(0.20))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.verified_rounded, size: 18,
                  color: Color(0xFF4A9068)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.$1, style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: Color(0xFF4A9068))),
                const SizedBox(height: 3),
                Text(item.$2, style: TextStyle(fontSize: 10.5,
                    color: Color(tc.ts), height: 1.4)),
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9068).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(item.$3, style: const TextStyle(
                    fontSize: 9.5, color: Color(0xFF4A9068),
                    fontWeight: FontWeight.w600))),
            ]),
          )),
          const SizedBox(height: 8),
        ],

        ...sections.map((section) {
          final sTitle = section.$1;
          final items  = section.$2;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Text(sTitle, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: Color(tc.ts),
                  letterSpacing: 0.5))),
            ...items.map((item) {
              final statusColor = item.$3 == 'planned'
                  ? acc
                  : item.$3 == 'researching'
                      ? const Color(0xFFDAA520)
                      : item.$3 == 'implementing'
                          ? const Color(0xFF3a90c0)
                          : Color(tc.tm);
              final statusIcon = item.$3 == 'implementing'
                  ? Icons.construction_rounded
                  : Icons.radio_button_unchecked_rounded;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: settingsCardFill(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 4)]),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(statusIcon, size: 18, color: statusColor.withOpacity(0.7)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.$1, style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700, color: Color(tc.tx))),
                    const SizedBox(height: 3),
                    Text(item.$2, style: TextStyle(fontSize: 10.5,
                        color: Color(tc.ts), height: 1.4)),
                  ])),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(item.$3 == 'planned'
                        ? L.get('screens.about.roadmapStatusPlanned')
                        : item.$3 == 'researching'
                            ? L.get('screens.about.roadmapStatusResearching')
                            : item.$3 == 'implementing'
                                ? L.get('screens.about.roadmapStatusImplementing')
                                : L.get('screens.about.roadmapStatusLater'), style: TextStyle(
                        fontSize: 9.5, color: statusColor,
                        fontWeight: FontWeight.w600))),
                ]));
            }),
          ]);
        }),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(L.get('screens.about.roadmapBlacklist'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: Color(tc.tm), letterSpacing: 0.5))),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: settingsCardFill(context).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _BlacklistRow(L.get('screens.about.roadmap.livingIsland'), L.get('screens.about.roadmap.livingIslandReason')),
            _BlacklistRow(L.get('screens.about.roadmap.statsUiSwitch'), L.get('screens.about.roadmap.statsUiSwitchReason')),
          ])),
      ]),
    );
  }
}

class _BlacklistRow extends StatelessWidget {
  final String title, reason;
  const _BlacklistRow(this.title, this.reason);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('✗ ', style: TextStyle(
          color: Color(0xFFc04040), fontWeight: FontWeight.w700)),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
            fontSize: 11, color: Color(0xFFc04040),
            decoration: TextDecoration.lineThrough,
            fontWeight: FontWeight.w600)),
        Text(reason, style: const TextStyle(
            fontSize: 10, color: Color(0xFF888888))),
      ])),
    ]));
}



// ─────────────────────────────────────────────────────────────────────────────
// 崩溃日志 / 操作记录查看页
// ─────────────────────────────────────────────────────────────────────────────
class _CrashLogScreen extends StatefulWidget {
  const _CrashLogScreen();
  @override
  State<_CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<_CrashLogScreen> {
  String _filter = 'all';   // all | error | action | warn
  String _search = '';
  bool _newestFirst = true;
  final _searchCtrl = TextEditingController();

  static List<(String, String, LogLevel?)> _getFilters() => [
    ('all',    L.get('screens.settings.logs.all'),   null),
    ('error',  L.get('screens.settings.logs.error'),   LogLevel.error),
    ('fatal',  L.get('screens.settings.logs.fatal'),   LogLevel.fatal),
    ('warn',   L.get('screens.settings.logs.warn'),   LogLevel.warn),
    ('action', L.get('screens.settings.logs.action'),   LogLevel.action),
    ('info',   L.get('screens.settings.logs.info'),   LogLevel.info),
  ];

  List<LogEntry> get _filtered {
    var entries = CrashLogger.entries.toList();
    if (_newestFirst) entries = entries.reversed.toList();

    // 级别过滤
    if (_filter != 'all') {
      final level = _getFilters().firstWhere((f) => f.$1 == _filter).$3;
      if (level != null) entries = entries.where((e) => e.level == level).toList();
    }
    // 关键字搜索
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      entries = entries.where((e) =>
          e.msg.toLowerCase().contains(q) ||
          e.tag.toLowerCase().contains(q) ||
          (e.detail?.toLowerCase().contains(q) ?? false)).toList();
    }
    return entries;
  }

  Color _levelColor(LogLevel l, ThemeConfig tc) {
    switch (l) {
      case LogLevel.fatal:  return const Color(0xFFE04040);
      case LogLevel.error:  return const Color(0xFFE07040);
      case LogLevel.warn:   return const Color(0xFFDAA520);
      case LogLevel.action: return const Color(0xFF4A9068);
      case LogLevel.info:   return Color(tc.ts);
    }
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final entries = _filtered;
    final filters = _getFilters();

    // 统计摘要
    final all = CrashLogger.entries;
    final errCount   = all.where((e) => e.level == LogLevel.error || e.level == LogLevel.fatal).length;
    final warnCount  = all.where((e) => e.level == LogLevel.warn).length;
    final actCount   = all.where((e) => e.level == LogLevel.action).length;

    return Scaffold(
      backgroundColor:
          state.showsGlobalWallpaper ? Colors.transparent : Color(tc.bg),
      appBar: AppBar(
        backgroundColor: state.chromeBarColor(tc), elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context)),
        title: Text(L.get('screens.settings.logs.title'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
        actions: [
          // 导出并分享
          IconButton(
            icon: Icon(Icons.share_rounded, size: 20, color: Color(tc.acc)),
            tooltip: L.get('screens.settings.logs.exportShare'),
            onPressed: () async {
              final report = CrashLogger.buildReport();
              try {
                final tempDir = await getTemporaryDirectory();
                final ts = DateTime.now().toString().substring(0, 19).replaceAll(':', '-').replaceAll(' ', '_');
                final file = File('${tempDir.path}/lsz_crashlog_$ts.txt');
                await file.writeAsString(report);
                
                await ShareService.shareFile(file.path, mime: 'text/plain');
                HapticFeedback.lightImpact();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(L.get('screens.settings.logs.shareFailed', {'error': e.toString()})),
                  ));
                }
              }
            },
          ),
          // 复制完整报告
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 20, color: Color(tc.acc)),
            tooltip: L.get('screens.settings.logs.copyReport'),
            onPressed: () {
              final report = CrashLogger.buildReport();
              Clipboard.setData(ClipboardData(text: report));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(L.get('screens.settings.logs.copySuccess', {
                  'count': all.length,
                  'charCount': report.length,
                }),
                  style: const TextStyle(fontSize: 12)),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
          ),
          // 清除日志
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: Color(tc.tm)),
            tooltip: L.get('screens.settings.logs.clearLogs'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: Colors.transparent,
                title: Text(L.get('screens.settings.logs.clearConfirmTitle'), style: TextStyle(color: Color(tc.tx))),
                content: Text(L.get('screens.settings.logs.clearConfirmContent', {'count': all.length}),
                    style: TextStyle(color: Color(tc.ts))),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context),
                    child: Text(L.cancel, style: TextStyle(color: Color(tc.ts)))),
                  TextButton(onPressed: () {
                    CrashLogger.clear();
                    Navigator.pop(context);
                    setState(() {});
                  }, child: Text(L.get('screens.settings.logs.clearLogs'),
                      style: const TextStyle(color: Color(0xFFE04040)))),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // ── 摘要卡片 ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(children: [
            _SummaryChip(count: all.length, label: L.get('screens.settings.logs.summaryTotal'), color: Color(tc.ts), tc: tc),
            const SizedBox(width: 6),
            _SummaryChip(count: errCount,  label: L.get('screens.settings.logs.summaryError'), color: const Color(0xFFE04040), tc: tc),
            const SizedBox(width: 6),
            _SummaryChip(count: warnCount, label: L.get('screens.settings.logs.summaryWarn'), color: const Color(0xFFDAA520), tc: tc),
            const SizedBox(width: 6),
            _SummaryChip(count: actCount,  label: L.get('screens.settings.logs.summaryAction'), color: const Color(0xFF4A9068), tc: tc),
          ]),
        ),

        // ── 搜索栏 ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            style: TextStyle(fontSize: 12, color: Color(tc.tx)),
            decoration: InputDecoration(
              hintText: L.get('screens.settings.logs.searchHint'),
              hintStyle: TextStyle(fontSize: 12, color: Color(tc.tm)),
              prefixIcon: Icon(Icons.search, size: 16, color: Color(tc.tm)),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 14, color: Color(tc.tm)),
                      onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
              fillColor: settingsCardFill(context),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
          ),
        ),

        // ── 级别过滤 chip 行 ──────────────────────────────────
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: filters.map((f) {
              final active = _filter == f.$1;
              final c = f.$3 != null ? _levelColor(f.$3!, tc) : Color(tc.ts);
              return GestureDetector(
                onTap: () => setState(() => _filter = f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? c.withOpacity(0.15) : settingsCardFill(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? c.withOpacity(0.6) : Color(tc.brd),
                      width: active ? 1.5 : 1.0)),
                  child: Text(f.$2,
                    style: TextStyle(fontSize: 11,
                      color: active ? c : Color(tc.tm),
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),

        // ── 排序切换 ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Row(children: [
            Text(L.get('screens.settings.logs.entriesCount', {'count': entries.length}),
                style: TextStyle(fontSize: 11, color: Color(tc.tm))),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _newestFirst = !_newestFirst),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 13, color: Color(tc.ts)),
                const SizedBox(width: 4),
                Text(_newestFirst
                    ? L.get('screens.settings.logs.sortNewestFirst')
                    : L.get('screens.settings.logs.sortOldestFirst'),
                  style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              ]),
            ),
          ]),
        ),

        // ── 日志列表 ──────────────────────────────────────────
        Expanded(
          child: entries.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 40, color: Color(tc.tm)),
                const SizedBox(height: 8),
                Text(_search.isNotEmpty
                    ? L.get('screens.settings.logs.emptyNoMatch')
                    : L.get('screens.settings.logs.emptyNoLogs'),
                  style: TextStyle(color: Color(tc.tm))),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                itemCount: entries.length,
                itemBuilder: (_, i) => _LogTile(
                  entry: entries[i],
                  tc: tc,
                  levelColor: _levelColor(entries[i].level, tc),
                ),
              ),
        ),
      ]),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final ThemeConfig tc;
  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
    required this.tc,
  });
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
    ]),
  ));
}

class _LogTile extends StatefulWidget {
  final LogEntry entry;
  final ThemeConfig tc;
  final Color levelColor;
  const _LogTile({
    required this.entry,
    required this.tc,
    required this.levelColor,
  });
  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final tc = widget.tc;
    final c = widget.levelColor;
    final hasDetail = e.detail != null && e.detail!.isNotEmpty;

    return GestureDetector(
      onTap: hasDetail ? () => setState(() => _expanded = !_expanded) : null,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: e.toString()));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.get('screens.settings.logs.copiedOne'), style: const TextStyle(fontSize: 12)),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: settingsCardFill(context),
          borderRadius: BorderRadius.circular(10),
          border: (e.level == LogLevel.error || e.level == LogLevel.fatal)
              ? Border.all(color: c.withOpacity(0.35), width: 1.2)
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 级别标签
              Container(
                margin: const EdgeInsets.only(top: 1),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(e.levelLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: c, letterSpacing: 0.5, fontFamily: 'monospace')),
              ),
              const SizedBox(width: 7),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签 + 消息
                  RichText(text: TextSpan(
                    style: TextStyle(fontSize: 11, color: Color(tc.ts)),
                    children: [
                      TextSpan(text: '[${e.tag}] ',
                        style: TextStyle(color: c.withOpacity(0.8),
                            fontWeight: FontWeight.w600)),
                      TextSpan(text: e.msg,
                        style: TextStyle(color: Color(tc.tx))),
                    ],
                  )),
                  const SizedBox(height: 2),
                  Text(e.ts,
                    style: TextStyle(fontSize: 9, color: Color(tc.tm),
                        fontFamily: 'monospace')),
                ],
              )),
              if (hasDetail)
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14, color: Color(tc.tm)),
            ]),
          ),
          // 展开的 detail（堆栈/错误信息）
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            child: _expanded && hasDetail
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(tc.bg),
                      borderRadius: BorderRadius.circular(6)),
                    child: SelectableText(
                      e.detail!,
                      style: TextStyle(
                        fontSize: 10, color: Color(tc.ts),
                        fontFamily: 'monospace', height: 1.5),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 数据导出危险按钮
// ─────────────────────────────────────────────────────────────────────────────
class _DataExportButton extends StatefulWidget {
  final AppState state;
  final ThemeConfig tc;
  const _DataExportButton({
    required this.state,
    required this.tc,
  });
  @override State<_DataExportButton> createState() => _DataExportButtonState();
}

class _DataExportButtonState extends State<_DataExportButton> {
  bool _confirmed = false;
  bool _exporting = false;

  String _buildExportText(AppState state) {
    final sb = StringBuffer();
    final today = state.todayKey;
    final tasks = state.tasks;
    final nowStr = DateTime.now().toString().substring(0, 19);

    sb.writeln('═══════════════════════════════════════════');
    sb.writeln(L.get('screens.settings.export.reportTitle'));
    sb.writeln(L.get('screens.settings.export.generatedAt', {'time': nowStr}));
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln();

    // ── 基本统计 ──────────────────────────────────────────────────────────
    sb.writeln(L.get('screens.settings.export.headerBasic'));
    sb.writeln(L.get('screens.settings.export.labelTotalTasks', {'count': tasks.length}));
    sb.writeln(L.get('screens.settings.export.labelCompleted', {'count': tasks.where((t) => t.done).length}));
    sb.writeln(L.get('screens.settings.export.labelPending', {'count': tasks.where((t) => !t.done && !t.ignored).length}));
    sb.writeln(L.get('screens.settings.export.labelIgnored', {'count': tasks.where((t) => t.ignored).length}));
    sb.writeln(L.get('screens.settings.export.labelOverdue', {
      'count': tasks.where((t) => !t.done && !t.ignored && t.originalDate.compareTo(today) < 0).length,
    }));
    final totalFocus = tasks.fold(0, (s, t) => s + t.focusSecs);
    sb.writeln(L.get('screens.settings.export.labelTotalFocus', {
      'hours': totalFocus ~/ 3600,
      'mins': totalFocus % 3600 ~/ 60,
    }));
    sb.writeln();

    // ── 标签分布 ──────────────────────────────────────────────────────────
    sb.writeln(L.get('screens.settings.export.headerTags'));
    for (final tag in state.tags) {
      final done = state.tagTotalDone(tag);
      final total = state.tagTotalCount(tag);
      final focus = state.tagFocusTime(tag);
      if (total > 0) {
        sb.writeln(L.get('screens.settings.export.tagLine', {
          'tag': tag,
          'done': done,
          'total': total,
          'focusMins': focus ~/ 60,
          'rate': state.tagCompletionRate(tag),
        }));
      }
    }
    sb.writeln();

    // ── 近30天每日完成 ────────────────────────────────────────────────────
    sb.writeln(L.get('screens.settings.export.headerDaily30'));
    final days30 = List.generate(30, (i) {
      final d = DateTime.parse('${today}T12:00:00').subtract(Duration(days: 30 - i));
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    });
    for (final d in days30) {
      final cnt = state.doneOnDay(d);
      if (cnt > 0) sb.writeln(L.get('screens.settings.export.dailyLine', {'date': d, 'count': cnt}));
    }
    sb.writeln();

    // ── 活力节律 ──────────────────────────────────────────────────────────
    sb.writeln(L.get('screens.settings.export.headerVitality30'));
    final vit = state.vitalityData(days30);
    sb.writeln(L.get('screens.settings.export.vitalityMorning', {'count': vit['morning']}));
    sb.writeln(L.get('screens.settings.export.vitalityAfternoon', {'count': vit['afternoon']}));
    sb.writeln(L.get('screens.settings.export.vitalityEvening', {'count': vit['evening']}));
    sb.writeln();

    // ── 偏差分析 ──────────────────────────────────────────────────────────
    final devData = state.deviationByDay(days30);
    if (devData.isNotEmpty) {
      final avg = devData.map((e) => e.$2).fold(0.0, (a, b) => a + b) / devData.length;
      sb.writeln(L.get('screens.settings.export.headerDeviation30'));
      sb.writeln(L.get('screens.settings.export.deviationAvg', {'avg': avg.toStringAsFixed(2)}));
      sb.writeln(L.get('screens.settings.export.deviationSamples', {'count': devData.length}));
      sb.writeln();
    }

    // ── 心理学分析 ────────────────────────────────────────────────────────
    sb.writeln(L.get('screens.settings.export.headerPsych'));
    final psych = PsychAnalyzer.analyze(state);
    sb.writeln(L.get('screens.settings.export.psychProcrastination', {'score': psych.procrastinationIndex}));
    sb.writeln(L.get('screens.settings.export.psychCognitive', {'value': psych.cognitivePattern}));
    sb.writeln(L.get('screens.settings.export.psychSelfEfficacy', {'value': psych.selfEfficacy}));
    sb.writeln(L.get('screens.settings.export.psychInsightsLabel'));
    for (final i in psych.insights) sb.writeln('    • $i');
    sb.writeln(L.get('screens.settings.export.psychAdviceLabel'));
    for (final r in psych.recommendations) sb.writeln('    → $r');
    sb.writeln();

    // ── 智能建议当前状态 ──────────────────────────────────────────────────
    sb.writeln(L.get('screens.settings.export.headerSmartPlan'));
    final plan = SmartPlan.suggest(state);
    sb.writeln(L.get('screens.settings.export.planSummary', {'text': plan.summary}));
    sb.writeln(L.get('screens.settings.export.planLoadWarning', {
      'text': plan.loadWarning.isEmpty ? L.get('screens.settings.export.none') : plan.loadWarning,
    }));
    sb.writeln(L.get('screens.settings.export.planTrend', {
      'text': plan.trendLabel.isEmpty ? L.get('screens.settings.export.none') : plan.trendLabel,
    }));
    sb.writeln(L.get('screens.settings.export.planMovesHeader', {'count': plan.moves.length}));
    for (final m in plan.moves.take(10)) {
      final t = state.tasks.firstWhere(
          (t) => t.id.toString() == m.taskId,
          orElse: () => state.tasks.first);
      final taskLabel = t.text.length > 20 ? '${t.text.substring(0, 20)}…' : t.text;
      sb.writeln(L.get('screens.settings.export.planMoveLine', {
        'task': taskLabel,
        'block': m.suggestedBlock,
        'reason': m.reason,
      }));
    }
    sb.writeln();

    // ── 任务明细（全部）──────────────────────────────────────────────────
    sb.writeln(L.get('screens.settings.export.headerAllTasks', {'count': tasks.length}));
    final recent = tasks;
    for (final t in recent) {
      sb.writeln('  [${t.done ? '✓' : t.ignored ? '×' : '○'}] ${t.text}');
      sb.writeln(L.get('screens.settings.export.taskMeta1', {
        'tags': t.tags.isEmpty ? L.get('screens.settings.export.none') : t.tags.join(','),
        'block': t.timeBlock,
      }));
      sb.writeln(L.get('screens.settings.export.taskMeta2', {
        'date': t.originalDate,
        'mins': t.focusSecs ~/ 60,
        'doneSuffix': t.done
            ? L.get('screens.settings.export.taskDoneSuffix', {'date': t.doneAt})
            : '',
      }));
    }
    sb.writeln();
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln(L.get('screens.settings.export.warning'));
    sb.writeln('═══════════════════════════════════════════');

    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    if (!_confirmed) {
      return GestureDetector(
        onTap: () => setState(() => _confirmed = true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFc04040),
            borderRadius: BorderRadius.circular(10)),
          child: Text(
            L.get('screens.settings.export.confirm'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      );
    }

    // Confirmed — show export options
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFc04040).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFc04040).withOpacity(0.3))),
        child: Column(children: [
          Text(L.get('screens.settings.export.chooseMethod'), style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: Color(tc.tx))),
          const SizedBox(height: 10),
          Column(children: [
            GestureDetector(
              onTap: _exporting ? null : () async {
                setState(() => _exporting = true);
                final text = _buildExportText(widget.state);
                await Clipboard.setData(ClipboardData(text: text));
                if (mounted) {
                  setState(() { _exporting = false; _confirmed = false; });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(L.get('screens.settings.export.copiedToClipboard', {'count': text.length})),
                    behavior: SnackBarBehavior.floating));
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFc04040),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(L.get('screens.settings.export.copyToClipboard'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _exporting ? null : () async {
                setState(() => _exporting = true);
                try {
                  final text = _buildExportText(widget.state);
                  Directory dir;
                  try {
                    dir = (await getExternalStorageDirectory()) ??
                          await getApplicationDocumentsDirectory();
                  } catch (_) {
                    dir = await getApplicationDocumentsDirectory();
                  }
                  final ts = DateTime.now()
                      .toString().substring(0, 19).replaceAll(':', '-').replaceAll(' ', '_');
                  final file = File('${dir.path}/lsz_export_$ts.txt');
                  await file.writeAsString(text, encoding: utf8);
                  if (mounted) {
                    setState(() { _exporting = false; _confirmed = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(L.get('screens.settings.export.savedTo', {
                        'path': file.path,
                        'count': text.length,
                      })),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 6)));
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() { _exporting = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(L.get('screens.settings.export.saveFailed', {'error': e.toString()})),
                      behavior: SnackBarBehavior.floating));
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(_exporting
                    ? L.get('screens.settings.export.generating')
                    : L.get('screens.settings.export.saveToTxt'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.white,
                      fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: () => setState(() => _confirmed = false),
        child: Text(L.cancel, style: TextStyle(fontSize: 11, color: Color(tc.tm))),
      ),
    ]);
  }
}
