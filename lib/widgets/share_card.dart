// lib/widgets/share_card.dart  v3
// 修复：截图卡片与预览分离。
//   - 预览：普通 SingleChildScrollView，用户可滚动查看
//   - 截图：把 ShareCardWidget 放入 OverlayEntry（固定宽度，强制完整渲染），
//           再调用 toImage()，最后移除 Overlay

import 'dart:math' show pi, max, sin, cos;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../beta/smart_plan.dart';
import '../beta/beta_flags.dart';
import '../services/share_service.dart';
import '../services/pom_deep_analysis.dart';
import '../l10n/l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// [days]        — 要分享的日期列表，null = 今日
// [periodLabel] — 标题副文字，如「本周」「2025年3月」，null = 今日总结
Future<void> showShareCardSheet(
  BuildContext context, {
  List<String>? days,
  String? periodLabel,
}) async {
  final state = context.read<AppState>();
  final effectiveDays = days ?? [state.todayKey];
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: state,
      child: _ShareCardSheet(days: effectiveDays, periodLabel: periodLabel),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ShareCardSheet extends StatefulWidget {
  final List<String> days;
  final String? periodLabel;
  const _ShareCardSheet({required this.days, this.periodLabel});
  @override
  State<_ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<_ShareCardSheet> {
  bool _sharing = false;

  /// 截图核心：把卡片渲染到屏外 Overlay，等一帧完成后截图，再清理
  Future<void> _doShare() async {
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);

    try {
      final state = context.read<AppState>();
      final cardKey = GlobalKey();
      final screenW = MediaQuery.of(context).size.width;

      // 1. 把卡片插入 Overlay（屏幕左上角之外，-9999px 向左偏移，不可见）
      final overlay = Overlay.of(context);
      late OverlayEntry entry;
      entry = OverlayEntry(builder: (_) => Positioned(
        left: -(screenW + 40),   // 完全移出屏幕
        top: 0,
        width: screenW,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: cardKey,
            child: ShareCardWidget(
              state: state,
              days: widget.days,
              periodLabel: widget.periodLabel,
            ),
          ),
        ),
      ));
      overlay.insert(entry);

      // 2. 等两帧，确保 Flutter 完整渲染（包括 CustomPaint、文字等）
      await Future.delayed(const Duration(milliseconds: 80));
      // ignore: use_build_context_synchronously
      if (!mounted) { entry.remove(); return; }

      // 3. 截图
      final boundary = cardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        entry.remove();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(L.shareCardRenderFailed)));
        }
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      entry.remove();

      if (byteData == null) return;

      final ok = await ShareService.shareBytes(
        byteData.buffer.asUint8List(),
        filename: 'lsz_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (!ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.shareCardShareFailed)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.shareCardError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final acc = Color(tc.acc);

    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Color(tc.bg),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 28,
                offset: const Offset(0, -6))
          ],
        ),
        child: Column(children: [
          // Handle
          const SizedBox(height: 10),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Color(tc.brd).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: acc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.ios_share_rounded, size: 13, color: acc),
                  const SizedBox(width: 5),
                  Text(widget.periodLabel != null
                          ? L.shareCardPeriod(widget.periodLabel!)
                          : L.shareCardToday,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: acc)),
                ]),
              ),
              const Spacer(),
              Text(L.shareCardFullVersion,
                  style: TextStyle(fontSize: 10, color: Color(tc.ts))),
            ]),
          ),
          const SizedBox(height: 12),

          // Preview — 普通滚动，不用于截图
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ShareCardWidget(
                state: state,
                days: widget.days,
                periodLabel: widget.periodLabel,
              ), // no RepaintBoundary here
            ),
          ),

          // Share button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: GestureDetector(
                onTap: _sharing ? null : _doShare,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _sharing
                        ? null
                        : LinearGradient(
                            colors: [acc, Color(tc.acc2)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: _sharing ? Color(tc.brd) : null,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _sharing
                        ? []
                        : [
                            BoxShadow(
                                color: acc.withOpacity(0.40),
                                blurRadius: 16,
                                offset: const Offset(0, 5))
                          ],
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_sharing)
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                        else
                          const Icon(Icons.download_rounded,
                              size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(_sharing ? L.shareCardGenerating : L.shareCardSaveShare,
                            style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card widget (用固定宽度父级约束渲染，不依赖 Scaffold/屏幕高度)
// ─────────────────────────────────────────────────────────────────────────────

class ShareCardWidget extends StatelessWidget {
  final AppState state;
  /// 要分享的日期列表。null = 只看今日（保持旧行为）
  final List<String>? days;
  /// 分享时间段标签，如「本周」「2025年3月」，用于 Header 副标题
  final String? periodLabel;
  const ShareCardWidget({
    super.key,
    required this.state,
    this.days,
    this.periodLabel,
  });

  static const _cMorning   = Color(0xFFe8982a);
  static const _cAfternoon = Color(0xFF3a90c0);
  static const _cEvening   = Color(0xFF7a5ab8);
  static const _cDone      = Color(0xFF4A9068);

  @override
  Widget build(BuildContext context) {
    final tc    = state.themeConfig;
    final acc   = Color(tc.acc);
    final acc2  = Color(tc.acc2);
    final now   = DateTime.now();
    final today = state.todayKey;

    // ── Period resolution ─────────────────────────────────────────────────
    // days == null  → today only
    // days provided → use the passed range
    final periodDays    = days ?? [today];
    final periodDaysSet = periodDays.toSet();

    // anchor = single-day target date, or latest date ≤ today for multi-day
    final anchorDate = periodDays.length == 1
        ? periodDays.first
        : (periodDays.where((d) => d.compareTo(today) <= 0).toList()..sort())
              .lastOrNull ?? today;

    // Single-day mode: any 1-day share (historical or today)
    final isSingleDay    = periodDays.length == 1;
    // Whether the anchor is today (affects 「今日」vs「当日」labels)
    final anchorIsToday  = anchorDate == today;
    // Keep isTodayMode as alias for backward-compat in remaining references
    final isTodayMode    = isSingleDay;

    // ── Tasks for the period ────────────────────────────────────────────
    // "当期任务" = created/rescheduled within the period dates
    final periodTasks = state.tasks
        .where((t) =>
            !t.ignored &&
            (periodDaysSet.contains(t.createdAt) ||
             (t.rescheduledTo != null && periodDaysSet.contains(t.rescheduledTo))))
        .toList();

    // For "今日任务" section: show tasks for the anchor date
    final anchorTasks = state.tasks
        .where((t) =>
            !t.ignored &&
            (t.createdAt == anchorDate || t.rescheduledTo == anchorDate))
        .toList();

    final byBlock = <String, List<TaskModel>>{
      'morning': [],
      'afternoon': [],
      'evening': [],
      'unassigned': [],
    };
    for (final t in anchorTasks) {
      (byBlock[t.timeBlock] ?? byBlock['unassigned']!).add(t);
    }

    // Done count for the period
    final periodDone = state.tasks
        .where((t) => !t.ignored && t.done &&
                      t.doneAt != null && periodDaysSet.contains(t.doneAt))
        .length;
    // Completion % based on period tasks
    final pct = periodTasks.isNotEmpty
        ? (periodDone / periodTasks.length * 100).round()
        : 0;

    // Focus for the period
    final periodFocus = () {
      final taskF = state.tasks
          .where((t) => t.doneAt != null && periodDaysSet.contains(t.doneAt))
          .fold(0, (int s, t) => s + t.focusSecs);
      final unboundF = periodDays.fold(0, (int s, d) =>
          s + (state.settings.unboundFocusByDate[d] ?? 0));
      return taskF + unboundF;
    }();

    // ── Stats bar-chart ────────────────────────────────────────────────────
    // Single-day: show anchor date + preceding 6 days (7 total) regardless of
    // which day is being shared. Multi-day: show up to 14 days of the period.
    final List<String> chartDays;
    if (isSingleDay) {
      final anchor = DateTime.parse('${anchorDate}T12:00:00');
      chartDays = List.generate(7, (i) {
        final d = anchor.subtract(Duration(days: 6 - i));
        return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      });
    } else {
      chartDays = periodDays.length <= 14
          ? periodDays
          : periodDays.sublist(periodDays.length - 14);
    }
    final chartData = chartDays.map((dk) {
      final d = DateTime.parse('${dk}T12:00:00');
      return (
        date: d,
        dk: dk,
        total: state.tasks
            .where((t) =>
                !t.ignored &&
                (t.createdAt == dk || t.rescheduledTo == dk))
            .length,
        done: state.tasks
            .where((t) => !t.ignored && t.done && t.doneAt == dk)
            .length,
      );
    }).toList();

    final vit      = state.vitalityData(periodDays);
    final devData  = state.deviationByDay(periodDays);
    final devAvg   = devData.isEmpty
        ? 0.0
        : devData.map((e) => e.$2).reduce((a, b) => a + b) / devData.length;

    final ignoredTotal  = state.tasks.where((t) => t.ignored).length;
    final ignoredPeriod = state.tasks
        .where((t) => t.ignored && periodDaysSet.contains(t.originalDate))
        .length;

    // Tag distribution for the period
    final tagDone = <String, int>{};
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null || !periodDaysSet.contains(t.doneAt)) continue;
      for (final tag in t.tags) {
        tagDone[tag] = (tagDone[tag] ?? 0) + 1;
      }
    }
    final topTags = (tagDone.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    final habits = _calcHabits(state);
    final pom    = PomDeepAnalysis.analyze(state);
    final suggestion =
        betaSmartPlan(state.settings) ? SmartPlan.suggest(state) : null;
    final psych =
        betaSmartPlan(state.settings) ? PsychAnalyzer.analyze(state) : null;

    // Hour distribution: always use anchorDate (the single day or latest day)
    final hourCnt = List<int>.filled(24, 0);
    for (final t in state.tasks) {
      if (!t.done || t.doneAt != anchorDate || t.doneHour == null) continue;
      hourCnt[t.doneHour!]++;
    }
    final maxHour =
        hourCnt.reduce((a, b) => a > b ? a : b).clamp(1, 9999);

    // ── Vitality max ─────────────────────────────────────────────────────
    final vitMax = [
      vit['morning'] ?? 0,
      vit['afternoon'] ?? 0,
      vit['evening'] ?? 0,
    ].reduce(max).clamp(1, 9999);

    // ── Bar chart max ─────────────────────────────────────────────────────
    final barMax = chartData
        .map((d) => d.total)
        .fold(1, (a, b) => a > b ? a : b);

    // ── Header labels ─────────────────────────────────────────────────────
    // Single-day: headerPeriodLabel is null → header shows 「今日/当日总结」
    // Multi-day: shows period label or auto-generated range label
    final headerPeriodLabel = periodLabel ??
        (isSingleDay ? null : _periodRangeLabel(periodDays));
    // Task section label
    final taskSectionLabel = isSingleDay
        ? (anchorIsToday ? L.shareCardTodayTasks : L.shareCardTargetDayTasks)
        : (periodLabel != null ? L.shareCardPeriodOverview(periodLabel!) : L.shareCardTasksOverview);
    // Stats section: single-day always shows trailing-7-day chart
    final _anchorD = DateTime.parse('${anchorDate}T12:00:00');
    final _chartStartD = _anchorD.subtract(const Duration(days: 6));
    final _chartRangeLabel = isSingleDay
        ? '${_chartStartD.month}/${_chartStartD.day}—${_anchorD.month}/${_anchorD.day} ' + L.shareCardLast7Days
        : (periodLabel ?? _periodRangeLabel(periodDays));
    final statsSectionLabel = isSingleDay
        ? _chartRangeLabel
        : '$_chartRangeLabel ' + L.shareCardStatsGlobal;
    // 4-grid number labels
    final doneLabel  = isSingleDay
        ? (anchorIsToday ? L.shareCardToday : L.shareCardTargetDayTasks)
        : (headerPeriodLabel ?? L.shareCardCurrentPeriod) + L.shareCardDone;
    final focusLabel = isSingleDay
        ? (anchorIsToday ? L.shareCardToday : L.shareCardTargetDayTasks)
        : (headerPeriodLabel ?? L.shareCardCurrentPeriod) + L.shareCardVitality;
    // Ignored label
    final ignoredPeriodLabel = isSingleDay
        ? (anchorIsToday ? L.shareCardToday : L.shareCardTargetDayTasks)
        : (periodLabel ?? L.shareCardCurrentPeriod);

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Color(tc.bg),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: acc.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ═══════════════════════════════ HEADER ═══════════════════════
          _Header(
              tc: tc, acc: acc, acc2: acc2, now: now,
              displayDate: anchorDate,
              pct: pct, done: periodDone, total: periodTasks.length,
              focusSecs: periodFocus,
              periodLabel: headerPeriodLabel),

          // ═══════════════════════════════ 任务详情 ══════════════════════
          _SecLabel(tc: tc, acc: acc, emoji: '📋',
              label: taskSectionLabel,
              sub: isSingleDay
                  ? '${anchorTasks.where((t) => t.done).length}/${anchorTasks.length} 件'
                  : '$periodDone 完成 · ${periodTasks.length - periodDone} 待完成'),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: isSingleDay
                // ── 日模式：原有时段分组 ──────────────────────────────────
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in [
                        ('morning',   '🌅', L.smartPlanMorning, _cMorning),
                        ('afternoon', '☀️', L.smartPlanAfternoon, _cAfternoon),
                        ('evening',   '🌙', L.smartPlanEvening, _cEvening),
                      ])
                        _TimeBlock(
                            tc: tc, state: state,
                            blk: e.$1, emoji: e.$2, label: e.$3, color: e.$4,
                            tasks: byBlock[e.$1] ?? []),
                      if ((byBlock['unassigned'] ?? []).isNotEmpty)
                        _TimeBlock(
                            tc: tc, state: state,
                            blk: 'unassigned', emoji: '📌', label: L.unassigned,
                            color: Color(tc.ts), tasks: byBlock['unassigned']!),
                      if (anchorTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: Text(L.shareCardNoTasks,
                                  style: TextStyle(
                                      fontSize: 11.5, color: Color(tc.tm))))),
                    ],
                  )
                // ── 周/月模式：期间全任务可视化 ──────────────────────────
                : _PeriodTaskOverview(
                    tc: tc,
                    state: state,
                    periodDays: periodDays,
                    periodDaysSet: periodDaysSet,
                    acc: acc,
                  ),
          ),

          // ═══════════════════════════════ 统计全局 ══════════════════════
          _SecLabel(tc: tc, acc: acc, emoji: '📊', label: L.shareCardStatsGlobal,
              sub: statsSectionLabel),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // 4宫格
                Row(children: [
                  _Num(tc: tc, c: _cDone,      icon: '✅', val: '$periodDone',
                      lbl: doneLabel),
                  const SizedBox(width: 7),
                  _Num(tc: tc, c: _cAfternoon, icon: '⏱', val: _dur(periodFocus),
                      lbl: focusLabel),
                  const SizedBox(width: 7),
                  _Num(tc: tc, c: _cMorning,   icon: '📋',
                      val: '${state.tasks.where((t) => !t.ignored).length}',
                      lbl: L.shareCardHistoryTasks),
                  const SizedBox(width: 7),
                  _Num(tc: tc, c: _cEvening,   icon: '🏷',
                      val: '${state.tags.length}', lbl: L.shareCardTagTotal),
                ]),
                const SizedBox(height: 8),

                // 完成情况柱状图（最多14天）
                _Card(tc: tc, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text('📅 ' + L.shareCardCompletionStats(statsSectionLabel),
                          style: TextStyle(fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(tc.tx))),
                      const Spacer(),
                      _Dot(color: _cDone),
                      const SizedBox(width: 3),
                      Text(L.shareCardDone,
                          style: TextStyle(fontSize: 8, color: Color(tc.ts))),
                      const SizedBox(width: 6),
                      _Dot(color: Color(tc.brd).withOpacity(0.7)),
                      const SizedBox(width: 3),
                      Text(L.shareCardNotDone,
                          style: TextStyle(fontSize: 8, color: Color(tc.ts))),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 72,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: chartData.map((d) {
                          final isToday = d.dk == anchorDate;
                          final p = d.total > 0 ? d.done / d.total : 0.0;
                          final totalH = d.total == 0
                              ? 4.0
                              : (d.total / barMax * 58).clamp(4.0, 58.0);
                          final doneH  = totalH * p;
                          final pendH  = totalH * (1 - p);
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      d.total > 0
                                          ? '${(p * 100).round()}%'
                                          : '',
                                      style: TextStyle(
                                          fontSize: isToday ? 8.5 : 7.5,
                                          color: isToday ? acc : Color(tc.ts),
                                          fontWeight: isToday
                                              ? FontWeight.w800
                                              : FontWeight.normal)),
                                  const SizedBox(height: 2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (pendH > 0)
                                          Container(
                                              height: pendH,
                                              color: isToday
                                                  ? acc.withOpacity(0.18)
                                                  : Color(tc.brd)
                                                      .withOpacity(0.45)),
                                        if (doneH > 0)
                                          Container(
                                            height: doneH,
                                            color: isToday
                                                ? acc
                                                : p >= 0.8
                                                    ? _cDone.withOpacity(0.75)
                                                    : p >= 0.5
                                                        ? _cMorning
                                                            .withOpacity(0.65)
                                                        : _cDone
                                                            .withOpacity(0.28),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      chartData.length <= 7
                                          ? ['一','二','三','四','五','六','日']
                                              [(d.date.weekday - 1) % 7]
                                          : '${d.date.month}/${d.date.day}',
                                      style: TextStyle(
                                          fontSize: chartData.length <= 7 ? 8.5 : 7.0,
                                          color: isToday ? acc : Color(tc.ts),
                                          fontWeight: isToday
                                              ? FontWeight.w800
                                              : FontWeight.normal)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 8),

                // 时段活力 + 完成时间
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Card(tc: tc, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('⚡ ' + L.shareCardVitality,
                            style: TextStyle(fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(tc.tx))),
                        const SizedBox(height: 8),
                        for (final e in [
                          ('morning',   '🌅', L.smartPlanMorning, _cMorning),
                          ('afternoon', '☀️', L.smartPlanAfternoon, _cAfternoon),
                          ('evening',   '🌙', L.smartPlanEvening, _cEvening),
                        ]) ...[
                          _VitalBar(
                              tc: tc,
                              emoji: e.$2, label: e.$3, color: e.$4,
                              count: vit[e.$1] ?? 0,
                              maxC: vitMax),
                          const SizedBox(height: 5),
                        ],
                      ],
                    ))),
                    const SizedBox(width: 8),
                    Expanded(child: _Card(tc: tc, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🕐 ' + L.shareCardDoneTime,
                            style: TextStyle(fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(tc.tx))),
                        const SizedBox(height: 8),
                        // 24h bar — 用绝对高度，不用 Fraction
                        SizedBox(
                          height: 44,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(24, (h) {
                              final cnt = hourCnt[h];
                              final barH = cnt == 0
                                  ? 2.0
                                  : (cnt / maxHour * 40 + 4)
                                      .clamp(4.0, 44.0);
                              final c = h >= 5 && h < 13
                                  ? _cMorning
                                  : h >= 13 && h < 18
                                      ? _cAfternoon
                                      : _cEvening;
                              return Expanded(
                                child: Container(
                                  height: barH,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 0.4),
                                  decoration: BoxDecoration(
                                    color: c.withOpacity(
                                        cnt == 0 ? 0.10 : 0.70),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(1.5)),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['0', '6', '12', '18', '23']
                              .map((h) => Text(h,
                                  style: TextStyle(
                                      fontSize: 7,
                                      color: Color(tc.ts))))
                              .toList(),
                        ),
                      ],
                    ))),
                  ],
                ),
                const SizedBox(height: 8),

                // 标签分布
                if (topTags.isNotEmpty) ...[
                  _Card(tc: tc, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏷 ' + (isSingleDay ? (anchorIsToday ? L.shareCardTodayTag : L.shareCardTargetDayTag) : L.shareCardTagDistribution),
                          style: TextStyle(fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(tc.tx))),
                      const SizedBox(height: 8),
                      ...topTags.map((e) {
                        final color = state.tagColor(e.key);
                        final maxV  = topTags.first.value;
                        final barW  = maxV > 0 ? e.value / maxV : 0.05;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(e.key,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Color(tc.tx)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            // 固定宽度进度条，不用 FractionallySizedBox
                            SizedBox(
                              width: 90,
                              height: 7,
                              child: Stack(children: [
                                Container(
                                    decoration: BoxDecoration(
                                        color: Color(tc.brd),
                                        borderRadius:
                                            BorderRadius.circular(4))),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 90 * barW.clamp(0.04, 1.0),
                                    decoration: BoxDecoration(
                                        color: color.withOpacity(0.72),
                                        borderRadius:
                                            BorderRadius.circular(4)),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 6),
                            Text('${e.value}',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: Color(tc.ts),
                                    fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }),
                    ],
                  )),
                  const SizedBox(height: 8),
                ],

                // 偏差 + 忽略
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Card(tc: tc, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📐 ' + L.shareCardDeviation,
                            style: TextStyle(fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(tc.tx))),
                        const SizedBox(height: 8),
                        if (devData.isEmpty)
                          Text(L.smartPlanNoData,
                              style: TextStyle(
                                  fontSize: 10, color: Color(tc.tm)))
                        else () {
                          final col = devAvg.abs() < 0.2
                              ? _cDone
                              : devAvg > 0
                                  ? _cMorning
                                  : _cAfternoon;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                devAvg.abs() < 0.2
                                    ? L.shareCardOnTime
                                    : devAvg > 0
                                        ? L.shareCardDelayed(devAvg.abs().toStringAsFixed(1))
                                        : L.shareCardAhead(devAvg.abs().toStringAsFixed(1)),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: col),
                              ),
                              const SizedBox(height: 2),
                              Text(L.shareCardPlanVsActual,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(tc.tm))),
                            ],
                          );
                        }(),
                      ],
                    ))),
                    const SizedBox(width: 8),
                    Expanded(child: _Card(tc: tc, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🗑 ' + L.shareCardIgnoreStats,
                            style: TextStyle(fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(tc.tx))),
                        const SizedBox(height: 8),
                        Text(L.shareCardTotalIgnored(ignoredTotal),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(tc.tx),
                                height: 1.0)),
                        Text(L.shareCardTotalIgnoredLabel,
                            style: TextStyle(
                                fontSize: 9, color: Color(tc.ts))),
                        const SizedBox(height: 2),
                        Text(L.shareCardPeriodIgnored(ignoredPeriodLabel, ignoredPeriod),
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFF888888))),
                      ],
                    ))),
                  ],
                ),
                const SizedBox(height: 8),

                // 习惯
                if (habits.isNotEmpty) ...[
                  _Card(tc: tc, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔥 习惯追踪（近30天）',
                          style: TextStyle(fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(tc.tx))),
                      const SizedBox(height: 8),
                      ...habits.take(4).map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: h.streak >= 7
                                      ? _cMorning
                                      : _cEvening.withOpacity(0.6))),
                          const SizedBox(width: 7),
                          Expanded(
                              child: Text(h.name,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(tc.tx)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: h.streak >= 7
                                    ? _cMorning.withOpacity(0.12)
                                    : _cEvening.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                h.streak >= 7
                                    ? '🔥 ${h.streak}天'
                                    : '${h.count}次/月',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: h.streak >= 7
                                        ? _cMorning
                                        : Color(tc.ts),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      )),
                    ],
                  )),
                  const SizedBox(height: 8),
                ],

                // 番茄钟
                if (pom.sampleCount >= 3) ...[
                  _Card(tc: tc, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Text('🍅 番茄钟深度分析',
                            style: TextStyle(fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(tc.tx))),
                        const Spacer(),
                        Text('${pom.sampleCount} 次',
                            style: TextStyle(
                                fontSize: 9, color: Color(tc.ts))),
                      ]),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 30,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(24, (h) {
                            final v    = pom.hourlyFocusMins[h];
                            final maxV = pom.hourlyFocusMins
                                .reduce((a, b) => a > b ? a : b);
                            if (maxV == 0) {
                              return const Expanded(child: SizedBox());
                            }
                            final frac = (v / maxV).clamp(0.0, 1.0);
                            final isBest = h == pom.bestHour;
                            return Expanded(
                              child: Container(
                                height: frac * 26 + 2,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 0.5),
                                decoration: BoxDecoration(
                                  color: isBest
                                      ? _cDone.withOpacity(0.90)
                                      : _cDone
                                          .withOpacity(0.20 + frac * 0.40),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(pom.peakLabel,
                          style: const TextStyle(
                              fontSize: 10,
                              color: _cDone,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(pom.continuityInsight,
                          style: TextStyle(
                              fontSize: 10, color: Color(tc.ts))),
                    ],
                  )),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          // ═══════════════════════════════ 智能建议 ══════════════════════
          if (suggestion != null && psych != null) ...[
            _SecLabel(
                tc: tc, acc: acc, emoji: '🤖', label: L.smartPlanTitle,
                sub: suggestion.hpi != null
                    ? 'HPI ${suggestion.hpi}'
                    : L.smartPlanDetailTitle),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // HPI 卡片：固定宽度避免布局漂移
                      SizedBox(width: 100,
                        child: _Card(tc: tc, child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CustomPaint(
                              painter: _Arc(
                                  value: (suggestion.hpi ?? 0) / 100,
                                  color: _hpiC(suggestion.hpi),
                                  track: Color(tc.brd),
                                  sw: 7),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${suggestion.hpi ?? '--'}',
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: _hpiC(suggestion.hpi),
                                            height: 1.0)),
                                    const Text('HPI',
                                        style: TextStyle(
                                            fontSize: 8,
                                            color: Color(0xFF888888))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (suggestion.hpiLabel != null)
                            Text(suggestion.hpiLabel!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: _hpiC(suggestion.hpi),
                                    fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: _procC(psych.procrastinationIndex)
                                    .withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                L.smartPlanProcrastinationIndex + ' ${psych.procrastinationIndex}',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: _procC(
                                        psych.procrastinationIndex),
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Card(tc: tc, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(L.smartPlanInsightOverview,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(tc.ts))),
                            const SizedBox(height: 6),
                            ...suggestion.insights.take(3).map((ins) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(ins.icon,
                                        style: const TextStyle(
                                            fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(ins.title,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: Color(tc.tx))),
                                          Text(ins.body,
                                              maxLines: 2,
                                              overflow: TextOverflow
                                                  .ellipsis,
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: Color(tc.ts),
                                                  height: 1.35)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            if (suggestion.insights.isEmpty)
                              Text(L.smartPlanNoData,
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      color: Color(tc.tm))),
                          ],
                        )),
                      ),
                    ],
                  )), // end IntrinsicHeight
                  const SizedBox(height: 8),

                  if (suggestion.summary.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: acc.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: acc.withOpacity(0.16)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: acc.withOpacity(0.12)),
                            child: const Center(
                                child: Text('🤖',
                                    style: TextStyle(fontSize: 14))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(suggestion.summary,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(tc.tx),
                                      height: 1.5))),
                        ],
                      ),
                    ),

                  if (psych.insights.isNotEmpty ||
                      psych.recommendations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _Card(tc: tc, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            '🧠 ' + L.smartPlanInsightOverview + '  ·  ${psych.cognitivePattern}',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(tc.tx))),
                        if (psych.insights.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(psych.insights.first,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(tc.tx),
                                  height: 1.45)),
                        ],
                        if (psych.recommendations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...psych.recommendations.take(2).map((rec) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                        color: acc.withOpacity(0.12),
                                        shape: BoxShape.circle),
                                    child: const Center(
                                        child: Text('💡',
                                            style: TextStyle(
                                                fontSize: 8))),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                      child: Text(rec,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Color(tc.tx),
                                              height: 1.4))),
                                ],
                              ),
                            )),
                        ],
                      ],
                    )),
                  ],
                ],
              ),
            ),
          ],

          // ═══════════════════════════════ FOOTER ═══════════════════════
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: acc.withOpacity(0.04),
              border: Border(
                  top: BorderSide(
                      color: Color(tc.brd).withOpacity(0.4),
                      width: 0.5)),
            ),
            child: Row(children: [
              Text('📝 ' + context.watch<AppState>().settings.appName + ' · Mindless',
                  style: TextStyle(
                      fontSize: 9,
                      color: Color(tc.ts),
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('β.0.084 · ' + L.shareCardTagline(_fmtDate(now)),
                  style: TextStyle(fontSize: 9, color: Color(tc.tm))),
            ]),
          ),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────
  static Color _hpiC(int? hpi) {
    if (hpi == null) return const Color(0xFF888888);
    if (hpi >= 80) return _cDone;
    if (hpi >= 65) return _cAfternoon;
    if (hpi >= 45) return const Color(0xFFDAA520);
    return const Color(0xFFE07040);
  }

  static Color _procC(int v) =>
      v < 35 ? _cDone : v < 60 ? _cMorning : const Color(0xFFc04040);

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  static String _dur(int s) {
    if (s <= 0) return '0m';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h${m}m' : '${m}m';
  }

  /// 从 days 列表生成简短区间标签，如「3/10—3/16」「3月」「2025年」
  static String _periodRangeLabel(List<String> days) {
    if (days.isEmpty) return L.get('widgets.shareCard.currentPeriod');
    if (days.length == 1) {
      final d = DateTime.parse('${days.first}T12:00:00');
      return '${d.month}月${d.day}日';
    }
    final first = DateTime.parse('${days.first}T12:00:00');
    final last  = DateTime.parse('${days.last}T12:00:00');
    // 整月
    if (first.day == 1 && last.day == DateTime(last.year, last.month + 1, 0).day) {
      return '${first.year == last.year ? '' : '${first.year}年'}${first.month}月';
    }
    // 整年
    if (days.length >= 365 && first.month == 1 && first.day == 1) {
      return '${first.year}年';
    }
    // 整周或其他
    if (first.month == last.month) {
      return '${first.month}月${first.day}—${last.day}日';
    }
    return '${first.month}/${first.day}—${last.month}/${last.day}';
  }

  static List<_Habit> _calcHabits(AppState state) {
    final today  = state.todayKey;
    final days30 = List.generate(30, (i) {
      final d = DateTime.parse('${today}T12:00:00')
          .subtract(Duration(days: 30 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
    final freq = <String, int>{};
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null || !days30.contains(t.doneAt!)) continue;
      final k = t.text.trim().substring(0, t.text.length.clamp(0, 12));
      if (k.length < 2) continue;
      freq[k] = (freq[k] ?? 0) + 1;
    }
    return freq.entries.where((e) => e.value >= 5).map((e) {
      int streak = 0;
      for (int i = days30.length - 1; i >= 0; i--) {
        final has = state.tasks.any((t) =>
            t.done &&
            t.doneAt == days30[i] &&
            t.text
                .trim()
                .startsWith(e.key.substring(0, e.key.length.clamp(0, 8))));
        if (has) streak++;
        else break;
      }
      return _Habit(name: e.key, count: e.value, streak: streak);
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time block
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Period Task Overview — 周/月模式下的全期任务可视化
// 分三块：① 完成环 + 数字摘要  ② 按标签完成横条  ③ 按日期分组任务列表
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodTaskOverview extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final List<String> periodDays;
  final Set<String> periodDaysSet;
  final Color acc;

  const _PeriodTaskOverview({
    required this.tc,
    required this.state,
    required this.periodDays,
    required this.periodDaysSet,
    required this.acc,
  });

  static const _cDone    = ShareCardWidget._cDone;
  static const _cMorning = ShareCardWidget._cMorning;
  static const _cEvening = ShareCardWidget._cEvening;

  @override
  Widget build(BuildContext context) {
    // ── 收集当期全部任务 ──────────────────────────────────────────────
    final allPeriodTasks = state.tasks
        .where((t) =>
            !t.ignored &&
            (periodDaysSet.contains(t.createdAt) ||
             (t.rescheduledTo != null &&
              periodDaysSet.contains(t.rescheduledTo))))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final doneList    = allPeriodTasks.where((t) =>
        t.done && t.doneAt != null && periodDaysSet.contains(t.doneAt)).toList();
    final pendingList = allPeriodTasks.where((t) => !t.done).toList();
    final doneCount   = doneList.length;
    // total and pct are computed after overdueAtPeriodStart is known (see below)

    // ── 标签完成统计（当期） ───────────────────────────────────────────
    final tagDoneMap  = <String, int>{};
    final tagTotalMap = <String, int>{};
    for (final t in allPeriodTasks) {
      for (final tag in t.tags) {
        if (!state.tagCountsInStats(tag)) continue;
        tagTotalMap[tag] = (tagTotalMap[tag] ?? 0) + 1;
        if (t.done && t.doneAt != null && periodDaysSet.contains(t.doneAt)) {
          tagDoneMap[tag] = (tagDoneMap[tag] ?? 0) + 1;
        }
      }
    }
    // 所有当期有任务的标签，按「当期完成数 DESC，总数 DESC」排序，无上限
    final allTagKeys = tagTotalMap.keys.toList()
      ..sort((a, b) {
        final dc = (tagDoneMap[b] ?? 0).compareTo(tagDoneMap[a] ?? 0);
        if (dc != 0) return dc;
        return tagTotalMap[b]!.compareTo(tagTotalMap[a]!);
      });
    final maxTagDone = allTagKeys.isEmpty
        ? 1
        : allTagKeys
            .map((t) => tagDoneMap[t] ?? 0)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, 99999);

    // ── 逾期未完成任务（createdAt/originalDate 早于当期，仍未完成） ──────
    final overdueAtPeriodStart = state.tasks.where((t) =>
        !t.done && !t.ignored &&
        t.originalDate.compareTo(periodDays.first) < 0 &&
        // 没有改期到当期内（那些已经归入 allPeriodTasks）
        (t.rescheduledTo == null ||
         !periodDaysSet.contains(t.rescheduledTo))).toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));

    // ── 按日分组：遍历当期所有天，收集该天创建/改期的任务 ─────────────
    final dayTasks = <String, List<TaskModel>>{};
    for (final t in allPeriodTasks) {
      final key = t.rescheduledTo != null && periodDaysSet.contains(t.rescheduledTo)
          ? t.rescheduledTo!
          : t.createdAt;
      // 确保 key 在当期内（createdAt 可能超出当期范围但已被 allPeriodTasks 纳入）
      final effectiveKey = periodDaysSet.contains(key) ? key : periodDays.first;
      (dayTasks[effectiveKey] ??= []).add(t);
    }
    final sortedDays = dayTasks.keys.toList()..sort();

    // Total includes overdue items for the summary ring
    final total = allPeriodTasks.length + overdueAtPeriodStart.length;
    final pct   = total > 0 ? (doneCount / total * 100).round() : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ── ① 完成环 + 摘要数字 ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Color(tc.card),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: acc.withOpacity(0.14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 环形完成率
              SizedBox(
                width: 72, height: 72,
                child: CustomPaint(
                  painter: _Arc(
                    value: pct / 100,
                    color: _cDone,
                    track: Color(tc.brd),
                    sw: 7,
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$pct%',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _cDone,
                              height: 1.0)),
                      Text(L.shareCardDone,
                          style: TextStyle(
                              fontSize: 8.5, color: Color(tc.ts))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // 数字摘要
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SummaryRow(
                      color: _cDone,
                      icon: Icons.check_circle_rounded,
                      label: L.shareCardDone,
                      value: L.shareCardDoneCount(doneCount),
                      tc: tc,
                    ),
                    const SizedBox(height: 7),
                    _SummaryRow(
                      color: Color(tc.tm),
                      icon: Icons.radio_button_unchecked_rounded,
                      label: L.shareCardNotDone,
                      value: L.shareCardPendingCount(pendingList.length + overdueAtPeriodStart.length),
                      tc: tc,
                    ),
                    const SizedBox(height: 7),
                    _SummaryRow(
                      color: _cMorning,
                      icon: Icons.calendar_today_rounded,
                      label: L.shareCardActiveDays,
                      value: L.shareCardDaysCount(sortedDays.length),
                      tc: tc,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 右侧完成/未完成数字大字
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('$total',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(tc.tx),
                          height: 1.0)),
                  Text(L.shareCardTasksTotal,
                      style: TextStyle(
                          fontSize: 9, color: Color(tc.ts))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── ② 标签完成横条 ─────────────────────────────────────────────
        if (allTagKeys.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Color(tc.card),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(tc.brd).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏷 ' + L.shareCardTagDistribution,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(tc.tx))),
                const SizedBox(height: 10),
                ...allTagKeys.map((tag) {
                  final done      = tagDoneMap[tag] ?? 0;
                  final tagTotal  = tagTotalMap[tag] ?? 0;
                  final rate      = tagTotal > 0 ? (done / tagTotal * 100).round() : 0;
                  final frac      = maxTagDone > 0 ? done / maxTagDone : 0.0;
                  final color     = state.tagColor(tag);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: color)),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(tag,
                                  style: TextStyle(
                                      fontSize: 10, color: Color(tc.tx)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          Text('$done/$tagTotal',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(tc.ts),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 32,
                            child: Text('$rate%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: color,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(children: [
                            Container(
                              height: 5,
                              color: color.withOpacity(0.12),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: frac.clamp(0.0, 1.0),
                              child: Container(
                                  height: 5, color: color.withOpacity(0.75)),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── ③ 逾期区块 + 按日期分组任务列表 ──────────────────────────────
        if (sortedDays.isEmpty && overdueAtPeriodStart.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: Text(L.shareCardNoTasksPeriod,
                    style: TextStyle(fontSize: 11, color: Color(tc.tm)))))
        else ...[
          // 逾期区块（当期开始前创建且未完成的任务）
          if (overdueAtPeriodStart.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: Color(tc.card),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFc04040).withOpacity(0.28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
                    child: Row(children: [
                      const Text('⚠️',
                          style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(L.shareCardOverdueNotDone,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFc04040))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFc04040).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(L.shareCardDoneCount(overdueAtPeriodStart.length),
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFc04040),
                                fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Text(L.shareCardOverdueBefore,
                          style: TextStyle(
                              fontSize: 9, color: Color(tc.ts))),
                    ]),
                  ),
                  Divider(
                      height: 1,
                      color: const Color(0xFFc04040).withOpacity(0.18)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: overdueAtPeriodStart.map((t) =>
                          _TaskChip(
                            task: t, done: false,
                            tc: tc, state: state,
                            overdue: true,
                          )).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 每日明细
          if (sortedDays.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Color(tc.card),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(tc.brd).withOpacity(0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
                  child: Row(children: [
                    Text('📅 ' + L.shareCardDailyTaskDetails,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(tc.tx))),
                    const Spacer(),
                    _MiniLegend(color: _cDone,       label: L.shareCardDone),
                    const SizedBox(width: 8),
                    _MiniLegend(color: Color(tc.tm), label: L.shareCardNotDone),
                  ]),
                ),
                Divider(height: 1, color: Color(tc.brd).withOpacity(0.4)),
                // day rows
                ...sortedDays.asMap().entries.map((entry) {
                  final i      = entry.key;
                  final dayKey = entry.value;
                  final tasks  = dayTasks[dayKey]!;
                  final d      = DateTime.parse('${dayKey}T12:00:00');
                  final dDone  = tasks.where((t) =>
                      t.done && t.doneAt != null &&
                      periodDaysSet.contains(t.doneAt)).length;
                  final dPend  = tasks.length - dDone;
                  final wd     = [
                    L.mondayShort,
                    L.tuesdayShort,
                    L.wednesdayShort,
                    L.thursdayShort,
                    L.fridayShort,
                    L.saturdayShort,
                    L.sundayShort
                  ];
                  final isLast = i == sortedDays.length - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 日期行
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: acc.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                    '${d.month}/${d.day} ${wd[d.weekday - 1]}',
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        color: acc,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              // 迷你完成/未完成图示
                              ...List.generate(dDone.clamp(0, 8), (_) =>
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                        color: _cDone.withOpacity(0.75),
                                        borderRadius: BorderRadius.circular(2)),
                                  ),
                                )),
                              ...List.generate(dPend.clamp(0, 8), (_) =>
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                        color: Color(tc.brd).withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(2)),
                                  ),
                                )),
                              if (dDone + dPend > 16)
                                Text('+${tasks.length - 16}',
                                    style: TextStyle(
                                        fontSize: 8, color: Color(tc.ts))),
                              const Spacer(),
                              Text('$dDone/${tasks.length}',
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      color: dDone == tasks.length
                                          ? _cDone
                                          : Color(tc.ts),
                                      fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 6),
                            // 任务行：完成的在前，用删除线；未完成的在后
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                ...tasks.where((t) =>
                                    t.done && t.doneAt != null &&
                                    periodDaysSet.contains(t.doneAt))
                                  .map((t) => _TaskChip(
                                        task: t, done: true,
                                        tc: tc, state: state)),
                                ...tasks.where((t) => !t.done)
                                  .map((t) => _TaskChip(
                                        task: t, done: false,
                                        tc: tc, state: state)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(height: 1,
                            color: Color(tc.brd).withOpacity(0.3)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── 摘要行 ──────────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label, value;
  final ThemeConfig tc;
  const _SummaryRow({
    required this.color, required this.icon,
    required this.label, required this.value, required this.tc,
  });
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 12, color: color),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
    const Spacer(),
    Text(value,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  ]);
}

// ── 图例点 ───────────────────────────────────────────────────────────────────
class _MiniLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MiniLegend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(fontSize: 8, color: color)),
  ]);
}

// ── 任务 Chip（用于周/月模式每日任务展示） ───────────────────────────────────
class _TaskChip extends StatelessWidget {
  final TaskModel task;
  final bool done;
  final bool overdue;
  final ThemeConfig tc;
  final AppState state;
  const _TaskChip({
    required this.task, required this.done,
    required this.tc, required this.state,
    this.overdue = false,
  });
  @override
  Widget build(BuildContext context) {
    final tagColor = task.tags.isNotEmpty
        ? state.tagColor(task.tags.first)
        : Color(ShareCardWidget._cDone.value);
    final Color bgColor;
    final Color txColor;
    final Color borderColor;
    if (overdue) {
      bgColor     = const Color(0xFFc04040).withOpacity(0.08);
      txColor     = const Color(0xFFc04040).withOpacity(0.85);
      borderColor = const Color(0xFFc04040).withOpacity(0.30);
    } else if (done) {
      bgColor     = tagColor.withOpacity(0.10);
      txColor     = tagColor;
      borderColor = tagColor.withOpacity(0.22);
    } else {
      bgColor     = Color(tc.brd).withOpacity(0.35);
      txColor     = Color(tc.tm);
      borderColor = Color(tc.brd).withOpacity(0.4);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (overdue) ...[
          const Icon(Icons.schedule_rounded, size: 9,
              color: Color(0xFFc04040)),
          const SizedBox(width: 3),
        ] else if (done) ...[
          Icon(Icons.check_rounded, size: 9, color: tagColor),
          const SizedBox(width: 3),
        ],
        Text(
          task.text.length > 14
              ? '${task.text.substring(0, 13)}…'
              : task.text,
          style: TextStyle(
              fontSize: 9.5,
              color: txColor,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: txColor.withOpacity(0.6),
              decorationThickness: 1.2),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _TimeBlock extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final String blk, emoji, label;
  final Color color;
  final List<TaskModel> tasks;

  const _TimeBlock({
    required this.tc, required this.state, required this.blk,
    required this.emoji, required this.label, required this.color,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final done    = tasks.where((t) => t.done).toList();
    final pending = tasks.where((t) => !t.done).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                  bottom: BorderSide(
                      color: color.withOpacity(0.12), width: 0.5)),
            ),
            child: Row(children: [
              Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('$emoji $label',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${done.length}/${tasks.length}',
                    style: TextStyle(
                        fontSize: 9.5,
                        color: color,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          // tasks
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...done.map((t) =>
                    _TLine(task: t, done: true, tc: tc, state: state)),
                ...pending.map((t) =>
                    _TLine(task: t, done: false, tc: tc, state: state)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task line
// ─────────────────────────────────────────────────────────────────────────────

class _TLine extends StatelessWidget {
  final TaskModel task;
  final bool done;
  final ThemeConfig tc;
  final AppState state;

  const _TLine({
    required this.task, required this.done,
    required this.tc, required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 14,
                color: done
                    ? const Color(0xFF4A9068)
                    : Color(tc.tm)),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(task.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: done ? Color(tc.ts) : Color(tc.tx),
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                        decorationColor: Color(tc.ts),
                        height: 1.3)),
                if (task.tags.isNotEmpty || task.focusSecs > 0) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    ...task.tags.take(3).map((tag) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color:
                                  state.tagColor(tag).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: state
                                      .tagColor(tag)
                                      .withOpacity(0.30),
                                  width: 0.5),
                            ),
                            child: Text(tag,
                                style: TextStyle(
                                    fontSize: 8.5,
                                    color: state.tagColor(tag),
                                    fontWeight: FontWeight.w600)),
                          ),
                        )),
                    if (task.tags.length > 3)
                      Text('+${task.tags.length - 3}',
                          style: TextStyle(
                              fontSize: 8.5, color: Color(tc.tm))),
                    if (task.focusSecs > 0) ...[
                      const Spacer(),
                      Icon(Icons.timer_outlined,
                          size: 9, color: Color(tc.ts)),
                      const SizedBox(width: 2),
                      Text(_sec(task.focusSecs),
                          style: TextStyle(
                              fontSize: 9, color: Color(tc.ts))),
                    ],
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _sec(int s) {
    final m = s ~/ 60;
    return m < 60 ? '${m}m' : '${m ~/ 60}h${m % 60}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SecLabel extends StatelessWidget {
  final ThemeConfig tc;
  final Color acc;
  final String emoji, label, sub;
  const _SecLabel({required this.tc, required this.acc,
      required this.emoji, required this.label, required this.sub});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
    child: Row(children: [
      Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
              color: acc, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(tc.tx))),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: acc.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Text(sub,
            style: TextStyle(
                fontSize: 9.5,
                color: acc,
                fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

class _Header extends StatelessWidget {
  final ThemeConfig tc;
  final Color acc, acc2;
  final DateTime now;
  final String? displayDate; // 'YYYY-MM-DD' — overrides now for the date shown
  final int pct, done, total, focusSecs;
  final String? periodLabel;
  const _Header({required this.tc, required this.acc, required this.acc2,
      required this.now, this.displayDate,
      required this.pct, required this.done,
      required this.total, required this.focusSecs, this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final appName = context.watch<AppState>().settings.appName;
    final f = focusSecs <= 0
        ? '0m'
        : focusSecs ~/ 3600 > 0
            ? '${focusSecs ~/ 3600}h${(focusSecs % 3600) ~/ 60}m'
            : '${(focusSecs % 3600) ~/ 60}m';
    // Use displayDate if provided (for historical shares), else use now
    final String dateStr;
    if (displayDate != null) {
      final d = DateTime.parse('${displayDate}T12:00:00');
      dateStr = '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    } else {
      dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    }
    final subtitle = periodLabel != null
        ? L.shareCardPeriodSummaryWithDate(periodLabel!, dateStr)
        : L.shareCardSummaryWithDate(dateStr);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [acc, acc2.withOpacity(0.85)]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(13)),
          child: const Center(
              child: Text('📝', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(appName,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withOpacity(0.82))),
              const SizedBox(height: 6),
              Row(children: [
                _Badge(text: '✅ $done/$total ' + L.shareCardItemsUnit),
                const SizedBox(width: 6),
                _Badge(text: '⏱ $f'),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 58,
          height: 58,
          child: CustomPaint(
            painter: _Arc(
                value: pct / 100,
                color: Colors.white,
                track: Colors.white.withOpacity(0.25),
                sw: 5.5),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$pct%',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0)),
                Text(L.shareCardDone,
                    style: TextStyle(
                        fontSize: 7.5,
                        color: Colors.white.withOpacity(0.85))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8)),
    child: Text(text,
        style: const TextStyle(
            fontSize: 9.5,
            color: Colors.white,
            fontWeight: FontWeight.w600)));
}

class _Card extends StatelessWidget {
  final ThemeConfig tc;
  final Widget child;
  const _Card({required this.tc, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
    child: child);
}

class _Num extends StatelessWidget {
  final ThemeConfig tc;
  final Color c;
  final String icon, val, lbl;
  const _Num({required this.tc, required this.c,
      required this.icon, required this.val, required this.lbl});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.15), width: 0.5)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 3),
      Text(val,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: c,
              height: 1.1)),
      Text(lbl,
          style: TextStyle(fontSize: 8, color: Color(tc.ts)),
          textAlign: TextAlign.center),
    ])));
}

class _VitalBar extends StatelessWidget {
  final ThemeConfig tc;
  final String emoji, label;
  final Color color;
  final int count, maxC;
  const _VitalBar({required this.tc, required this.emoji, required this.label,
      required this.color, required this.count, required this.maxC});
  @override
  Widget build(BuildContext context) {
    final barFrac = maxC > 0 ? (count / maxC).clamp(0.04, 1.0) : 0.04;
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 5),
      SizedBox(
          width: 28,
          child: Text(label,
              style: TextStyle(fontSize: 9, color: Color(tc.ts)))),
      Expanded(
        child: SizedBox(
          height: 6,
          child: Stack(children: [
            Container(
                decoration: BoxDecoration(
                    color: Color(tc.brd),
                    borderRadius: BorderRadius.circular(3))),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: barFrac,
                child: Container(
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(3))),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
          width: 22,
          child: Text('$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color))),
    ]);
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ─────────────────────────────────────────────────────────────────────────────
// Arc painter
// ─────────────────────────────────────────────────────────────────────────────

class _Arc extends CustomPainter {
  final double value;
  final Color color, track;
  final double sw;
  const _Arc(
      {required this.value,
      required this.color,
      required this.track,
      required this.sw});

  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = (s.shortestSide - sw) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    c.drawArc(rect, -pi / 2, pi * 2, false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
    if (value > 0)
      c.drawArc(rect, -pi / 2, pi * 2 * value.clamp(0.0, 1.0), false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_Arc o) => o.value != value || o.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
class _Habit {
  final String name;
  final int count, streak;
  const _Habit({required this.name, required this.count, required this.streak});
}
