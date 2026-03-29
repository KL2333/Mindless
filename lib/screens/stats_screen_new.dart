// lib/screens/stats_screen_new.dart
// β 统计界面 — Bento 砖块仪表盘（已升为默认美术，不再是分支）
// 详情页复用 stats_screen.dart 中的丰富实现

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../l10n/l10n.dart';
import '../widgets/calendar_widgets.dart';
import '../widgets/deviation_chart.dart';
import '../widgets/shared_widgets.dart';
import 'dart:math' show pi, cos, sin, max, min;
import 'stats_screen.dart' show
    FocusDetailPage,
    DeviationDetailPage,
    DeviationChartThumb;
import '../beta/smart_plan.dart';
import '../beta/beta_flags.dart';
import '../beta/usage_stats_service.dart';
import '../services/pom_deep_analysis.dart';
import '../services/environment_sound_service.dart';
import '../services/focus_quality_service.dart';
import '../widgets/share_card.dart';

enum _CalV { day, week, month, year }

// ─────────────────────────────────────────────────────────────────────────────
class StatsScreenNew extends StatefulWidget {
  final int enterTick;
  final double animationFactor; // 0.0 at today/pom, 1.0 at stats, interpolates in between
  const StatsScreenNew({super.key, required this.enterTick, required this.animationFactor});
  @override
  State<StatsScreenNew> createState() => _StatsScreenNewState();
}

class _StatsScreenNewState extends State<StatsScreenNew> {
  _CalV _cv = _CalV.week;
  String _anchor = '';
  String _selected = '';
  int _enterTick = 0;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _anchor = s.todayKey; _selected = _anchor;
    const m = {'day':_CalV.day,'week':_CalV.week,'month':_CalV.month,'year':_CalV.year};
    _cv = m[s.settings.defaultCalView] ?? _CalV.week;
    _enterTick = widget.enterTick;
  }

  @override
  void didUpdateWidget(covariant StatsScreenNew oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enterTick != widget.enterTick) {
      setState(() => _enterTick = widget.enterTick);
    }
  }

  List<String> get _days {
    switch (_cv) {
      case _CalV.day:   return [_anchor];
      case _CalV.week:  return DateUtils2.weekDays(_anchor);
      case _CalV.month: return DateUtils2.monthDays(_anchor);
      case _CalV.year:  return DateUtils2.yearDays(_anchor);
    }
  }

  void _navP(int dir) {
    final d = DateUtils2.parse(_anchor);
    DateTime n;
    switch (_cv) {
      case _CalV.day:   n = d.add(Duration(days: dir)); break;
      case _CalV.week:  n = d.add(Duration(days: dir * 7)); break;
      case _CalV.month: n = DateTime(d.year, d.month + dir, 1); break;
      case _CalV.year:  n = DateTime(d.year + dir, 1, 1); break;
    }
    setState(() { _anchor = DateUtils2.fmt(n); if (_cv == _CalV.day) _selected = _anchor; });
  }

  String _mainLbl(AppState s) {
    final d = DateUtils2.parse(_anchor);
    switch (_cv) {
      case _CalV.day:   return L.get('screens.statsNew.dateFormat', {'year': d.year, 'month': d.month, 'day': d.day});
      case _CalV.week:  return L.get('screens.statsNew.weekFormat', {'year': d.year, 'week': DateUtils2.weekOfYear(_anchor)});
      case _CalV.month: return L.get('screens.statsNew.monthFormat', {'year': d.year, 'month': d.month});
      case _CalV.year:  return L.get('screens.statsNew.yearFormat', {'year': d.year});
    }
  }

  String _subLbl(AppState s) {
    final sem = s.getSemInfo(_anchor);
    switch (_cv) {
      case _CalV.day:
        String r = L.get('screens.statsNew.dayOfYear', {'day': DateUtils2.dayOfYear(_anchor), 'week': DateUtils2.weekOfYear(_anchor)});
        if (sem != null) r += L.get('screens.statsNew.semesterWeek', {'num': sem.num, 'week': sem.week});
        return r;
      case _CalV.week:
        final wd = DateUtils2.weekDays(_anchor);
        String r = L.get('screens.statsNew.weekRange', {'start': DateUtils2.fmtShort(wd.first), 'end': DateUtils2.fmtShort(wd.last)});
        if (sem != null) r += L.get('screens.statsNew.semesterWeek', {'num': sem.num, 'week': sem.week});
        return r;
      case _CalV.month: return sem != null ? L.get('screens.statsNew.semesterWeek', {'num': sem.num, 'week': sem.week}) : '';
      case _CalV.year:  return '';
    }
  }

  void _push(Widget page) => Navigator.push(context, _slideRoute(page));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final days = _days;
    final today = state.todayKey;
    final pLbl = [
      L.get('screens.stats.today'),
      L.get('screens.stats.week'),
      L.get('screens.stats.month'),
      L.get('screens.stats.year'),
    ][_cv.index];

    final doneCount = days.fold(0, (s, d) => s + state.doneOnDay(d));
    final newCount  = days.where((d) => state.tasks.any((t) => t.createdAt == d)).length;
    final actSet    = <String>{};
    for (final t in state.tasks) { if (t.done && days.contains(t.doneAt)) actSet.addAll(t.tags); }

    final vit       = state.vitalityData(days);
    final vitTotal  = (vit['morning']??0)+(vit['afternoon']??0)+(vit['evening']??0);
    final bestVit   = vitTotal > 0 ? vit.entries.reduce((a,b) => a.value>=b.value?a:b) : null;
    final totalFocus= _periodFocus(state, days);
    final allFocus  = _allFocus(state);
    final topTag    = _topTag(state, days);

    final topPad = MediaQuery.of(context).padding.top;
    final showClock = state.settings.showTopClock;
    final appBarHeight = showClock ? 78.0 : 46.0;
    final topMargin = 8.0;
    final barBottom = topPad + appBarHeight + topMargin + 8 + state.settings.topBarOffset; // Precise spacing + Dynamic Offset

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onHorizontalDragEnd: (det) {
          final v = det.primaryVelocity ?? 0;
          if (v.abs() < 200) return;
          HapticFeedback.selectionClick();
          setState(() {
            if (v < 0) {
              _cv = _CalV.values[(_cv.index + 1).clamp(0, 3)];
            } else {
              _cv = _CalV.values[(_cv.index - 1).clamp(0, 3)];
            }
            if (_cv == _CalV.day) _selected = _anchor;
          });
        },
        child: ListView(padding: EdgeInsets.fromLTRB(13, barBottom, 13, 110), children: [
          _calTabs(state, tc),
          const SizedBox(height: 8),
          _navRow(state, tc),
          const SizedBox(height: 6),
          const CalColorLegend(),
          _calBody(state, tc, today),
          const SizedBox(height: 14),

          // ── Bento grid ─────────────────────────────────────
          _BentoGrid(children: [

            // ① 完成数 — wide (2-col)
            _BentoCell(cols: 2, rows: 1,
              child: _StatBrick(tc: tc, accent: Color(tc.acc),
                icon: state.settings.theme == 'black_hole' ? '📡' : '✅',
                value: '$doneCount', label: L.get('screens.statsNew.periodCompletion', {'period': pLbl}),
                sub: L.get('screens.statsNew.newTasks', {'count': newCount}),
                onTap: () => _push(_CompletionPage(state: state, days: days, pLbl: pLbl, tc: tc)))),

            // ② 标签完成概览 — tall 1-col × 2-row
            _BentoCell(cols: 1, rows: 2,
              child: _TagBrick(tc: tc, state: state, days: days, actSet: actSet, animationFactor: widget.animationFactor,
                onTap: () => _push(_TagPage(state: state, days: days, pLbl: pLbl, tc: tc)))),

            // ③ 时段活力 — 1-col
            _BentoCell(cols: 1, rows: 1,
              child: _VitalityBrick(tc: tc, vit: vit, vitTotal: vitTotal, bestVit: bestVit, animationFactor: widget.animationFactor,
                onTap: () => _push(_VitalityPage(state: state, days: days, pLbl: pLbl, tc: tc)))),

            // ④ 专注时长 — 1-col → 进 FocusDetailPage（完整版）
            _BentoCell(cols: 1, rows: 1,
              child: _StatBrick(tc: tc, accent: const Color(0xFFe8982a),
                icon: state.settings.theme == 'black_hole' ? '⚛️' : '🍅',
                value: _fmtT(totalFocus),
                label: L.get('screens.stats.periodFocus', {'period': pLbl}),
                sub: L.get('screens.stats.totalFocusTime', {'value': _fmtT(allFocus)}),
                onTap: () => _push(FocusDetailPage(days: days, state: state, tc: tc, pLbl: pLbl)))),

            // ⑤ 标签排行mini — wide (2-col)
            _BentoCell(cols: 2, rows: 1,
              child: _RankMini(tc: tc, state: state, animationFactor: widget.animationFactor,
                onTap: () => _push(_RankPage(state: state, days: days, pLbl: pLbl, tc: tc)))),

            // ⑥ 完成时间分布 — 1-col
            _BentoCell(cols: 1, rows: 1,
              child: _TimelineBrick(tc: tc, state: state, days: days, animationFactor: widget.animationFactor,
                onTap: () => _push(_CompletionTimelinePage(state: state, days: days, pLbl: pLbl, tc: tc)))),

            // ⑦ 偏差分析 — 带缩略图，week/month 显示
            if (_cv == _CalV.week || _cv == _CalV.month) ...[
              _BentoCell(cols: 1, rows: 1,
                child: _DeviationBrick(tc: tc, state: state, days: days,
                  onTap: () => _push(DeviationDetailPage(days: days, state: state, tc: tc)))),
            ],

            // ⑧ 忽略统计 — 1-col
            _BentoCell(cols: 1, rows: 1,
              child: _IgnoreBrick(tc: tc, state: state, days: days,
                onTap: () => _push(_IgnorePage(state: state, tc: tc)))),

            // ⑨ 屏幕使用分析 β — 1-col (only when enabled)
            if (betaUsageStats(state.settings))
              _BentoCell(cols: 1, rows: 1,
                child: _UsageStatsBrick(state: state, tc: tc)),

            // ⑩ 心理分析 + 环境声分析 — 1-col 各占一半，并排
            _BentoCell(cols: 1, rows: 1,
              child: _PsychBrick(tc: tc, state: state, animationFactor: widget.animationFactor,
                onTap: () => _push(_PsychPage(state: state, tc: tc)))),

            _BentoCell(cols: 1, rows: 1,
              child: _NoiseBrick(tc: tc, state: state,
                onTap: () => _push(_NoisePage(tc: tc, state: state)))),

            // ⑪ 习惯追踪 — 1-col（精简样式）
            _BentoCell(cols: 1, rows: 1,
              child: _HabitBrick(tc: tc, state: state,
                onTap: () => _push(_HabitPage(state: state, tc: tc)))),

            // ⑫ 番茄钟深度分析 β — 1-col × 2-row（窄高，像标签砖块）
            if (betaDeepFocusAnalysis(state.settings))
              _BentoCell(cols: 1, rows: 2,
                child: _DeepFocusBrick(tc: tc, state: state, animationFactor: widget.animationFactor,
                  onTap: () => _push(_DeepFocusPage(tc: tc, state: state)))),

            // ⑬ 心流指数 — 1-col（独立入口，与番茄钟深度配对）
            _BentoCell(cols: 1, rows: 1,
              child: _FlowBrick(tc: tc, state: state, animationFactor: widget.animationFactor,
                onTap: () => _push(_FlowDetailPage(tc: tc, state: state)))),
            ]),

          // 屏幕使用分析已移入 Bento Grid
        ]),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────
  Widget _calTabs(AppState state, ThemeConfig tc) {
    final lbs = [
      L.get('screens.stats.day'),
      L.get('screens.stats.week'),
      L.get('screens.stats.month'),
      L.get('screens.stats.year'),
    ];
    return Row(children: [
      // Tab pills - Use unified LiquidSegmentedControl for physical reveal effect
      Expanded(
        child: LiquidSegmentedControl(
          labels: lbs,
          currentIndex: _cv.index,
          onValueChanged: (i) {
            if (_cv.index == i) return;
            HapticFeedback.selectionClick();
            setState(() {
              _cv = _CalV.values[i];
              if (_cv == _CalV.day) _selected = _anchor;
            });
          },
          tc: tc,
          width: double.infinity, // Use full width of Expanded
          height: 36,
        ),
      ),
      const SizedBox(width: 8),
      // Share button
      GestureDetector(
        onTap: () => showShareCardSheet(
          context,
          days: _days,
          periodLabel: _cv == _CalV.day ? null : _mainLbl(context.read<AppState>()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: state.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(tc.acc).withOpacity(0.30), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.ios_share_rounded, size: 13, color: Color(tc.acc)),
            const SizedBox(width: 4),
            Text(L.get('screens.statsNew.share'), style: TextStyle(
                fontSize: 11, color: Color(tc.acc),
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }

  Widget _navRow(AppState s, ThemeConfig tc) {
    final sub = _subLbl(s);
    return Row(children: [
      IconButton(onPressed: () => _navP(-1), icon: const Icon(Icons.chevron_left), color: Color(tc.ts), visualDensity: VisualDensity.compact),
      Expanded(child: Column(children: [
        Text(_mainLbl(s), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(tc.tx))),
        if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 9.5, color: Color(tc.ts)), textAlign: TextAlign.center),
      ])),
      IconButton(onPressed: () => _navP(1), icon: const Icon(Icons.chevron_right), color: Color(tc.ts), visualDensity: VisualDensity.compact),
    ]);
  }

  Widget _calBody(AppState s, ThemeConfig tc, String today) {
    switch (_cv) {
      case _CalV.day:   return DayViewBadges(dateStr: _anchor, state: s);
      case _CalV.week:  return WeekCalGrid(anchor: _anchor, selected: _selected, state: s, onSelect: (d) => setState(() => _selected = d));
      case _CalV.month: return MonthCalGrid(anchor: _anchor, selected: _selected, state: s, onSelect: (d) => setState(() => _selected = d));
      case _CalV.year:  return YearCalGrid(anchor: _anchor, state: s, onDayTap: (d) { setState(() { _selected = d; _anchor = d; _cv = _CalV.day; }); });
    }
  }

  static int _periodFocus(AppState s, List<String> days) {
    final ds = days.toSet();
    final tf = s.tasks.where((t)=>t.done&&t.doneAt!=null&&ds.contains(t.doneAt)).fold(0,(int a,t)=>a+t.focusSecs);
    final uf = s.settings.unboundFocusByDate.entries.where((e)=>ds.contains(e.key)).fold(0,(int a,e)=>a+e.value);
    return tf + uf;
  }
  static int _allFocus(AppState s) {
    final tf = s.tasks.fold(0,(int a,t)=>a+t.focusSecs);
    final uf = s.settings.unboundFocusByDate.values.fold(0,(int a,v)=>a+v);
    return tf + uf;
  }
  static String? _topTag(AppState s, List<String> days) {
    final c = <String,int>{};
    for (final t in s.tasks) { if (t.done && days.contains(t.doneAt)) for (final g in t.tags) c[g]=(c[g]??0)+1; }
    return c.isEmpty ? null : c.entries.reduce((a,b)=>a.value>=b.value?a:b).key;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bento layout
// ─────────────────────────────────────────────────────────────────────────────
class _BentoCell { final int cols,rows; final Widget child; const _BentoCell({required this.cols,required this.rows,required this.child}); }

class _BentoGrid extends StatefulWidget {
  final List<_BentoCell> children;
  const _BentoGrid({required this.children});
  @override State<_BentoGrid> createState() => _BentoGridState();
}

class _BentoGridState extends State<_BentoGrid> {
  late List<int> _order;
  int? _dragging;

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.children.length, (i) => i);
  }

  @override
  void didUpdateWidget(_BentoGrid old) {
    super.didUpdateWidget(old);
    if (old.children.length != widget.children.length) {
      _order = List.generate(widget.children.length, (i) => i);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    // Slightly taller base unit to prevent small-font/locale overflows.
    const unitH = 112.0;
    final ordered = _order.map((i) => widget.children[i]).toList();

    return LayoutBuilder(builder: (_, bc) {
      final colW = (bc.maxWidth - gap) / 2;
      final positioned = <Widget>[];
      final cur = [0.0, 0.0];
      double maxH = 0;
      for (int oi = 0; oi < ordered.length; oi++) {
        final cell = ordered[oi];
        final origIdx = _order[oi];
        final cw = cell.cols == 2 ? bc.maxWidth : colW;
        final ch = unitH * cell.rows + gap * (cell.rows - 1);
        double x, y;
        if (cell.cols == 2) {
          // Align both columns before spanning full width
          final maxCur = cur[0] > cur[1] ? cur[0] : cur[1];
          y = maxCur;
          x = 0;
          cur[0] = cur[1] = y + ch + gap;
        } else {
          final col = cur[0] <= cur[1] ? 0 : 1;
          y = cur[col]; x = col == 0 ? 0 : colW + gap;
          cur[col] = y + ch + gap;
        }
        maxH = maxH > y + ch ? maxH : y + ch;
        positioned.add(Positioned(
          left: x, top: y, width: cw, height: ch,
          child: _DraggableBrick(
            index: oi,
            isDragging: _dragging == oi,
            onDragStart: () => setState(() => _dragging = oi),
            onDragEnd: () => setState(() => _dragging = null),
            onAccept: (from) {
              setState(() {
                final fromIdx = from;
                final toIdx = oi;
                if (fromIdx == toIdx) return;
                final tmp = _order[fromIdx];
                _order[fromIdx] = _order[toIdx];
                _order[toIdx] = tmp;
              });
              HapticFeedback.lightImpact();
            },
            child: cell.child)));
      }
      return SizedBox(height: maxH, child: Stack(children: positioned));
    });
  }
}

class _DraggableBrick extends StatelessWidget {
  final int index;
  final bool isDragging;
  final VoidCallback onDragStart, onDragEnd;
  final void Function(int) onAccept;
  final Widget child;
  const _DraggableBrick({required this.index, required this.isDragging,
      required this.onDragStart, required this.onDragEnd,
      required this.onAccept, required this.child});
  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (_, candidate, __) => LongPressDraggable<int>(
        data: index,
        onDragStarted: onDragStart,
        onDragEnd: (_) => onDragEnd(),
        hapticFeedbackOnStart: true,
        feedback: SizedBox.expand(child: Opacity(opacity: 0.7, child: child)),
        childWhenDragging: AnimatedOpacity(
          opacity: 0.3, duration: const Duration(milliseconds: 200),
          child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: candidate.isNotEmpty
              ? (Matrix4.identity()..scale(0.96))
              : Matrix4.identity(),
          child: child)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brick widgets
// ─────────────────────────────────────────────────────────────────────────────
class _BrickShell extends StatelessWidget {
  final ThemeConfig tc; final Color accent; final VoidCallback onTap; final Widget child;
  const _BrickShell({required this.tc, required this.accent, required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => Material(
    color: Color(tc.card), borderRadius: BorderRadius.circular(18), clipBehavior: Clip.hardEdge,
    child: InkWell(onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Stack(children: [
        Positioned(right: -20, bottom: -20, child: Container(width: 70, height: 70,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.07)))),
        Positioned(left: 0, top: 18, bottom: 18, child: Container(width: 3,
          decoration: BoxDecoration(color: accent.withOpacity(0.5), borderRadius: BorderRadius.circular(3)))),
        SizedBox(width: double.infinity, height: double.infinity, child: child),
      ])));
}

class _StatBrick extends StatelessWidget {
  final ThemeConfig tc; final Color accent; final String icon,value,label; final String? sub; final VoidCallback onTap;
  const _StatBrick({required this.tc,required this.accent,required this.icon,required this.value,required this.label,this.sub,required this.onTap});
  @override
  Widget build(BuildContext context) => _BrickShell(tc: tc, accent: accent, onTap: onTap,
    child: Padding(padding: const EdgeInsets.fromLTRB(14,14,14,12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(icon,style:const TextStyle(fontSize:18)),const Spacer(),Icon(Icons.arrow_forward_ios_rounded,size:10,color:Color(tc.tm))]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:Color(tc.tx),height:1.0)),
        const SizedBox(height:2),
        Text(label, style: TextStyle(fontSize:10.5,color:Color(tc.ts)), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (sub != null)
          Flexible(
            child: Text(sub!, style: TextStyle(fontSize:9,color:accent.withOpacity(0.8)),
              maxLines:1,overflow:TextOverflow.ellipsis),
          ),
      ])));
}

class _VitalityBrick extends StatelessWidget {
  final ThemeConfig tc;
  final Map<String, int> vit;
  final int vitTotal;
  final MapEntry<String, int>? bestVit;
  final double animationFactor;
  final VoidCallback onTap;
  const _VitalityBrick({
    required this.tc,
    required this.vit,
    required this.vitTotal,
    required this.bestVit,
    required this.animationFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mx = vitTotal > 0 ? [vit['morning']!, vit['afternoon']!, vit['evening']!].reduce((a, b) => a > b ? a : b) : 1;
    final morning = L.get('screens.statsNew.morning');
    final afternoon = L.get('screens.statsNew.afternoon');
    final evening = L.get('screens.statsNew.evening');
    final blks = [('morning', morning, Color(0xFFe8982a)), ('afternoon', afternoon, Color(0xFF3a90c0)), ('evening', evening, Color(0xFF7a5ab8))];

    return _BrickShell(tc: tc, accent: const Color(0xFFe8982a), onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('⚡', style: TextStyle(fontSize: 18)), const Spacer(), Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm))]),
          const SizedBox(height: 4),
          Text(L.get('screens.statsNew.vitality'), style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
          const SizedBox(height: 10),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: blks.map((b) {
            final cnt = vit[b.$1] ?? 0;
            final pct = mx > 0 ? cnt / mx : 0.0;
            final isBest = bestVit?.key == b.$1 && cnt > 0;
            // Use animationFactor to drive the height
            final currentHeightFactor = (pct * animationFactor).clamp(0.02, 1.0);

            return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: 58, child: Align(alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(heightFactor: currentHeightFactor,
                    child: Container(decoration: BoxDecoration(color: isBest ? b.$3 : b.$3.withOpacity(0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))))))),
                const SizedBox(height: 4),
                Text(b.$2, style: TextStyle(fontSize: 8, color: isBest ? b.$3 : Color(tc.tm))),
              ])));
          }).toList())),
          const SizedBox(height: 6),
          Text(bestVit != null ? L.get('screens.statsNew.bestVitality', {'time': _bn(bestVit!.key), 'count': bestVit!.value}) : L.get('screens.statsNew.noData'),
            style: TextStyle(fontSize: 9, color: Color(tc.acc))),
        ])));
  }
  static String _bn(String k) => {
    'morning': L.get('screens.statsNew.morning'),
    'afternoon': L.get('screens.statsNew.afternoon'),
    'evening': L.get('screens.statsNew.evening')
  }[k]??k;
}

// Tag mini brick — tall 2-row, shows each tag's completion bar
class _TagBrick extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final List<String> days;
  final Set<String> actSet;
  final double animationFactor;
  final VoidCallback onTap;
  const _TagBrick({
    required this.tc,
    required this.state,
    required this.days,
    required this.actSet,
    required this.animationFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysSet = days.toSet();
    // 只统计当期有数据的标签，按当期完成数排序
    final tags = state.tags.where((t) => state.tagCountsInStats(t)).toList();
    // 当期每标签完成数
    final periodDoneMap = <String, int>{};
    // 当期每标签总任务数（被创建在当期）
    final periodTotalMap = <String, int>{};
    for (final t in state.tasks) {
      if (t.ignored) continue;
      for (final tag in t.tags) {
        if (!state.tagCountsInStats(tag)) continue;
        // 当期总任务：createdAt 或 rescheduledTo 在 days 内
        if (daysSet.contains(t.createdAt) ||
            (t.rescheduledTo != null && daysSet.contains(t.rescheduledTo))) {
          periodTotalMap[tag] = (periodTotalMap[tag] ?? 0) + 1;
        }
        // 当期完成：doneAt 在 days 内
        if (t.done && t.doneAt != null && daysSet.contains(t.doneAt)) {
          periodDoneMap[tag] = (periodDoneMap[tag] ?? 0) + 1;
        }
      }
    }
    // 排序：当期完成数 DESC，没有当期数据的放后面
    tags.sort((a, b) =>
        (periodDoneMap[b] ?? 0).compareTo(periodDoneMap[a] ?? 0));
    // 只显示当期有完成或有任务的标签，最多5个
    final top5 = tags
        .where((t) => (periodDoneMap[t] ?? 0) > 0 || (periodTotalMap[t] ?? 0) > 0)
        .take(5)
        .toList();
    // 若当期全空则退化为全部标签前5
    final displayTags = top5.isNotEmpty
        ? top5
        : tags.take(5).toList();
    final maxDone = displayTags.isEmpty
        ? 1
        : displayTags.map((t) => periodDoneMap[t] ?? 0).reduce((a, b) => a > b ? a : b).clamp(1, 99999);

    return _BrickShell(tc: tc, accent: Color(tc.acc2), onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🏷', style: TextStyle(fontSize: 18)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 3),
          Text(L.get('screens.statsNew.tagCompletion'), style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
          Text(L.get('screens.statsNew.activeTags', {'count': actSet.length}),
            style: TextStyle(fontSize: 8.5, color: Color(tc.acc2).withOpacity(0.8))),
          const SizedBox(height: 10),
          if (displayTags.isEmpty)
            Expanded(child: Center(
              child: Text(L.get('screens.statsNew.noData'), style: TextStyle(fontSize: 10, color: Color(tc.tm)))))
          else
            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: displayTags.map((tag) {
                final c = state.tagColor(tag);
                final done  = periodDoneMap[tag] ?? 0;
                final total = periodTotalMap[tag] ?? 0;
                // 当期完成率（若有当期任务则用当期，否则显示 0%）
                final rate  = total > 0 ? (done / total * 100).round() : 0;
                final frac  = (done / maxDone) * animationFactor;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(tag,
                      style: TextStyle(fontSize: 9.5, color: c),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(L.get('screens.statsNew.tagStats', {'done': done, 'total': total, 'rate': rate}),
                      style: TextStyle(fontSize: 8.5, color: Color(tc.ts))),
                  ]),
                  const SizedBox(height: 3),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft, widthFactor: frac.clamp(0.02, 1.0),
                    child: Container(height: 4,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(2)))),
                ]);
              }).toList(),
            )),
        ])));
  }
}

class _RankMini extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final double animationFactor;
  final VoidCallback onTap;
  const _RankMini({
    required this.tc,
    required this.state,
    required this.animationFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = state.tags.where((t) => state.tagCountsInStats(t) && state.tagTotalDone(t) > 0).toList()
      ..sort((a, b) => state.tagTotalDone(b).compareTo(state.tagTotalDone(a)));
    final top4 = sorted.take(4).toList();
    final mx = top4.isEmpty ? 1 : state.tagTotalDone(top4.first);
    return _BrickShell(tc: tc, accent: Color(tc.acc2), onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('📊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(L.get('screens.statsNew.completionRank'), style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 10),
          if (top4.isEmpty)
            Text(L.get('screens.statsNew.noData'), style: TextStyle(fontSize: 10, color: Color(tc.tm)))
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: top4.asMap().entries.map((e) {
              final tag = e.value;
              final c = state.tagColor(tag);
              final cnt = state.tagTotalDone(tag);
              final frac = (mx > 0 ? cnt / mx : 0.0) * animationFactor;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(children: [
                  SizedBox(height: 40,
                    child: Align(alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(heightFactor: frac.clamp(0.05, 1.0),
                        child: Container(decoration: BoxDecoration(
                          color: c, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))))))),
                  const SizedBox(height: 4),
                  Text('$cnt', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(tc.tx))),
                  const SizedBox(height: 2),
                  Text(tag, style: TextStyle(fontSize: 8, color: c),
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ]),
              ));
            }).toList()),
        ])));
  }
}

class _DevBrick extends StatelessWidget {
  final ThemeConfig tc; final AppState state; final List<String> days; final VoidCallback onTap;
  const _DevBrick({required this.tc,required this.state,required this.days,required this.onTap});
  @override
  Widget build(BuildContext context) {
    final data = state.deviationByDay(days);
    final avg = data.isEmpty ? 0.0 : data.map((e)=>e.$2).reduce((a,b)=>a+b)/data.length;
    String lbl;
    Color col;
    if (data.isEmpty) {
      lbl = L.get('screens.statsNew.noDeviationData');
      col = Color(tc.tm);
    } else if (avg.abs() < 0.2) {
      lbl = L.get('screens.statsNew.onTime');
      col = const Color(0xFF4A9068);
    } else if (avg > 0) {
      lbl = L.get('screens.statsNew.overallDelayed', {'avg': avg.toStringAsFixed(1)});
      col = const Color(0xFFe8982a);
    } else {
      lbl = L.get('screens.statsNew.overallAdvanced', {'avg': (-avg).toStringAsFixed(1)});
      col = const Color(0xFF3a90c0);
    }

    // Always show sparkline — use flat line as placeholder when no data
    final sparkData = data.isNotEmpty
        ? data.map((e) => e.$2).toList()
        : [0.0, 0.0, 0.0, 0.0, 0.0];

    return _BrickShell(
        tc: tc,
        accent: const Color(0xFF9A7AB8),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📐', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                Text(L.get('screens.statsNew.deviation'),
                    style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
                const SizedBox(height: 4),
                Text(lbl,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: col)),
                const SizedBox(height: 2),
                Text(L.get('screens.statsNew.plannedVsActual'),
                    style: TextStyle(fontSize: 9, color: Color(tc.tm))),
              ]),
              const Spacer(),
              // Sparkline always rendered
              _Spark(
                  data: sparkData,
                  tc: tc,
                  color: data.isEmpty ? Color(tc.brd) : col),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: Color(tc.tm)),
            ])));
  }
}

class _Spark extends StatelessWidget {
  final List<double> data; final ThemeConfig tc; final Color? color;
  const _Spark({required this.data, required this.tc, this.color});
  @override
  Widget build(BuildContext context) => SizedBox(width:56,height:32,
    child:CustomPaint(painter:_SparkP(data:data,color:color??Color(tc.acc))));
}
class _SparkP extends CustomPainter {
  final List<double> data; final Color color;
  const _SparkP({required this.data,required this.color});
  @override
  void paint(Canvas c, Size s) {
    if (data.length<2) return;
    final mn=data.reduce((a,b)=>a<b?a:b); final mx=data.reduce((a,b)=>a>b?a:b);
    final rng=(mx-mn).abs()<0.01?1.0:mx-mn;
    final p=Paint()..color=color..strokeWidth=1.5..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    final path=Path();
    for(int i=0;i<data.length;i++){
      final x=i/(data.length-1)*s.width; final y=s.height-((data[i]-mn)/rng)*s.height;
      if(i==0) path.moveTo(x,y); else path.lineTo(x,y);
    }
    c.drawPath(path,p);
  }
  @override bool shouldRepaint(_SparkP o) => o.data!=data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail page scaffold
// ─────────────────────────────────────────────────────────────────────────────
class _DP extends StatelessWidget {
  final String title; final ThemeConfig tc; final Widget body;
  const _DP({required this.title,required this.tc,required this.body});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Color(tc.bg),
    appBar: AppBar(backgroundColor:Color(tc.bg), elevation:0,
      title:Text(title,style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Color(tc.tx))),
      leading:IconButton(icon:Icon(Icons.arrow_back_ios_rounded,size:18,color:Color(tc.ts)),onPressed:()=>Navigator.pop(context))),
    body: body);
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail pages
// ─────────────────────────────────────────────────────────────────────────────

// Completion
class _CompletionPage extends StatelessWidget {
  final AppState state; final List<String> days; final String pLbl; final ThemeConfig tc;
  const _CompletionPage({required this.state,required this.days,required this.pLbl,required this.tc});
  @override
  Widget build(BuildContext context) {
    final done=days.fold(0,(s,d)=>s+state.doneOnDay(d));
    final newC=days.where((d)=>state.tasks.any((t)=>t.createdAt==d)).length;
    final byDay={for(final d in days) d: state.doneOnDay(d)};
    final mx=byDay.values.isEmpty?1:byDay.values.reduce((a,b)=>a>b?a:b);

    // Block distribution for pie
    final ds=days.toSet();
    final blkCount = {'morning': 0, 'afternoon': 0, 'evening': 0};
    for (final t in state.tasks) {
      if (!t.done || !ds.contains(t.doneAt)) continue;
      final blk = t.doneTimeBlock ?? (t.doneHour != null
          ? AppState.hourToTimeBlock(t.doneHour!, 0) : null);
      if (blk != null && blkCount.containsKey(blk)) blkCount[blk] = blkCount[blk]! + 1;
    }
    final blkTotal = blkCount.values.fold(0,(a,b)=>a+b);

    // Hour distribution for overlay curve
    final hourCount = List<int>.filled(24, 0);
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null || !ds.contains(t.doneAt)) continue;
      if (t.doneHour != null) hourCount[t.doneHour!]++;
    }

    return _DP(title:L.get('screens.statsNew.completionTitle', {'period': pLbl}),tc:tc, body:ListView(padding:const EdgeInsets.all(16), children:[
      Row(children:[_BigStat(tc:tc,val:'$done',lbl:L.get('screens.statsNew.periodCompleted', {'period': pLbl})),const SizedBox(width:10),_BigStat(tc:tc,val:'$newC',lbl:L.get('screens.statsNew.periodAdded', {'period': pLbl}))]),
      const SizedBox(height:20),
      if (days.length>1) ...[
        _Lbl(tc:tc,text:L.get('screens.statsNew.dailyCompletion')), const SizedBox(height:10),
        _DayBarsWithCurve(byDay:byDay,hourCount:hourCount,mx:mx,tc:tc),
        const SizedBox(height:20),
      ],
      if (blkTotal > 0) ...[
        _Lbl(tc:tc,text:L.get('screens.statsNew.timeBlockDistribution')), const SizedBox(height:10),
        _BlockPieChart(blkCount:blkCount,blkTotal:blkTotal,tc:tc),
        const SizedBox(height:20),
      ],
      _Lbl(tc:tc,text:L.get('screens.statsNew.completedTasks')), const SizedBox(height:8),
      ...state.tasks.where((t)=>t.done&&days.contains(t.doneAt))
          .map((t)=>_TLine(task:t,tc:tc)),
    ]));
  }
}

// Vitality
class _VitalityPage extends StatelessWidget {
  final AppState state; final List<String> days; final String pLbl; final ThemeConfig tc;
  const _VitalityPage({required this.state,required this.days,required this.pLbl,required this.tc});

  @override
  Widget build(BuildContext context) {
    final morning = L.get('screens.statsNew.morning');
    final afternoon = L.get('screens.statsNew.afternoon');
    final evening = L.get('screens.statsNew.evening');
    final blks=[('morning',morning,'🌅',Color(0xFFe8982a)),('afternoon',afternoon,'☀️',Color(0xFF3a90c0)),('evening',evening,'🌙',Color(0xFF7a5ab8))];

    final vit=state.vitalityData(days);
    final tot=(vit['morning']??0)+(vit['afternoon']??0)+(vit['evening']??0);
    final mx=tot>0?[vit['morning']!,vit['afternoon']!,vit['evening']!].reduce((a,b)=>a>b?a:b):1;
    final best=tot>0?vit.entries.reduce((a,b)=>a.value>=b.value?a:b):null;
    final ds=days.toSet();
    String cr(String blk){
      final all=state.tasks.where((t)=>t.timeBlock==blk&&ds.contains(t.createdAt)).length;
      final dn=state.tasks.where((t)=>t.timeBlock==blk&&t.done&&t.doneAt!=null&&ds.contains(t.doneAt)).length;
      return all==0?'—':'${(dn/all*100).round()}%';
    }
    return _DP(title:L.get('screens.statsNew.vitality'),tc:tc,body:ListView(padding:const EdgeInsets.all(16),children:[
      _Lbl(tc:tc,text:L.get('screens.statsNew.completionDistribution', {'period': pLbl})), const SizedBox(height:14),
      SizedBox(height:130,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:blks.map((b){
        final cnt=vit[b.$1]??0; final pct=mx>0?cnt/mx:0.0; final isBest=best?.key==b.$1&&cnt>0;
        return Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
          Text('$cnt',style:TextStyle(fontSize:14,fontWeight:isBest?FontWeight.w800:FontWeight.w500,color:cnt>0?b.$4:Color(tc.tm))),
          const SizedBox(height:6),
          Flexible(child:FractionallySizedBox(heightFactor:pct>0?pct.clamp(0.05,1.0):0.04,widthFactor:0.55,
            child:TweenAnimationBuilder<double>(tween:Tween(begin:0,end:pct.clamp(0.05,1.0)),
              duration:const Duration(milliseconds:700),curve:Curves.easeOut,
              builder:(_,v,__)=>FractionallySizedBox(heightFactor:v,widthFactor:1,
                child:Container(decoration:BoxDecoration(color:b.$4,borderRadius:const BorderRadius.vertical(top:Radius.circular(6)))))))),
          const SizedBox(height:8),
          Text('${b.$3} ${b.$2}${isBest?' ⚡':''}',style:TextStyle(fontSize:10,color:isBest?b.$4:Color(tc.ts))),
        ]));
      }).toList())),
      const SizedBox(height:24),
      _Lbl(tc:tc,text:L.get('screens.statsNew.completionRateByBlock')), const SizedBox(height:10),
      ...blks.map((b)=>_RR(lbl:'${b.$3} ${b.$2}',rate:cr(b.$1),col:b.$4,tc:tc)),
      if (best!=null)...[
        const SizedBox(height:16),
        Container(padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(color:Color(tc.cb),borderRadius:BorderRadius.circular(12)),
          child:Text(L.get('screens.statsNew.vitalitySummary', {'time': _bn(best.key), 'period': pLbl, 'count': best.value}),
            style:TextStyle(fontSize:12,color:Color(tc.ts),height:1.5))),
      ],
    ]));
  }
  static String _bn(String k)=>{
    'morning': L.get('screens.statsNew.morning'),
    'afternoon': L.get('screens.statsNew.afternoon'),
    'evening': L.get('screens.statsNew.evening')
  }[k]??k;
}

// Tags
class _TagPage extends StatelessWidget {
  final AppState state; final List<String> days; final String pLbl; final ThemeConfig tc;
  const _TagPage({required this.state,required this.days,required this.pLbl,required this.tc});
  @override
  Widget build(BuildContext context) {
    final tags=state.tags.where((t)=>state.tagCountsInStats(t)).toList()
      ..sort((a,b)=>state.tagTotalDone(b).compareTo(state.tagTotalDone(a)));
    return _DP(title:L.get('screens.statsNew.tagDetails'),tc:tc,body:ListView(padding:const EdgeInsets.all(16),children:[
      _Lbl(tc:tc,text:L.get('screens.statsNew.tagStatsHeader', {'period': pLbl})), const SizedBox(height:10),
      ...tags.map((tag){
        final c=state.tagColor(tag);
        final rate=state.tagCompletionRate(tag);
        final period=state.tagDoneInPeriod(tag,days);
        final total=state.tagTotalDone(tag);
        final focus=state.tagFocusTime(tag);
        return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(color:state.cardColor,borderRadius:BorderRadius.circular(14),
            boxShadow:[BoxShadow(color:Color(0x0C000000),blurRadius:6)]),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Container(width:10,height:10,decoration:BoxDecoration(shape:BoxShape.circle,color:c)),
              const SizedBox(width:8),
              Text(tag,style:TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:c)),
              const Spacer(),
              Text('$rate%',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:c)),
            ]),
            const SizedBox(height:10),
            Row(children:[
              _MS(tc:tc,val:'$period',lbl:L.get('screens.statsNew.periodCompleted', {'period': pLbl})),
              _MS(tc:tc,val:'$total',lbl:L.get('screens.statsNew.totalCompleted')),
              if(focus>0) _MS(tc:tc,val:_fmtT(focus),lbl:L.get('screens.statsNew.focus')),
            ]),
            const SizedBox(height:8),
            ClipRRect(borderRadius:BorderRadius.circular(4),
              child:TweenAnimationBuilder<double>(tween:Tween(begin:0,end:rate/100.0),
                duration:const Duration(milliseconds:600),curve:Curves.easeOut,
                builder:(_,v,__)=>LinearProgressIndicator(value:v,backgroundColor:Color(tc.brd),color:c,minHeight:6))),
          ]));
      }),
    ]));
  }
}

// Ranking
class _RankPage extends StatelessWidget {
  final AppState state; final List<String> days; final String pLbl; final ThemeConfig tc;
  const _RankPage({required this.state,required this.days,required this.pLbl,required this.tc});
  @override
  Widget build(BuildContext context) {
    final sorted=state.tags.where((t)=>state.tagCountsInStats(t)&&state.tagTotalDone(t)>0).toList()
      ..sort((a,b)=>state.tagTotalDone(b).compareTo(state.tagTotalDone(a)));
    final mx=sorted.isEmpty?1:state.tagTotalDone(sorted.first);
    return _DP(title:L.get('screens.statsNew.completionRank'),tc:tc,body:ListView(padding:const EdgeInsets.all(16),children:[
      _Lbl(tc:tc,text:L.get('screens.statsNew.tagTotalCompletion')), const SizedBox(height:14),
      ...sorted.asMap().entries.map((e){
        final tag=e.value; final idx=e.key; final c=state.tagColor(tag);
        final cnt=state.tagTotalDone(tag); final frac=mx>0?cnt/mx:0.0;
        return Padding(padding:const EdgeInsets.only(bottom:12),
          child:Row(children:[
            SizedBox(width:24,child:Text('${idx+1}',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:Color(tc.tm)))),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:2),
                  decoration:BoxDecoration(color:c.withOpacity(0.15),borderRadius:BorderRadius.circular(8)),
                  child:Text(tag,style:TextStyle(fontSize:12,color:c))),
                const Spacer(),
                Text('$cnt',style:TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Color(tc.tx))),
              ]),
              const SizedBox(height:6),
              TweenAnimationBuilder<double>(tween:Tween(begin:0,end:frac),
                duration:Duration(milliseconds:400+idx*60),curve:Curves.easeOut,
                builder:(_,v,__)=>ClipRRect(borderRadius:BorderRadius.circular(3),
                  child:LinearProgressIndicator(value:v,backgroundColor:Color(tc.brd),color:c,minHeight:6))),
            ])),
          ]));
      }),
    ]));
  }
}

// Focus
class _FocusPage extends StatelessWidget {
  final AppState state; final List<String> days; final String pLbl; final ThemeConfig tc;
  const _FocusPage({required this.state,required this.days,required this.pLbl,required this.tc});
  @override
  Widget build(BuildContext context) {
    final ds=days.toSet();
    final tf=state.tasks.where((t)=>t.done&&t.doneAt!=null&&ds.contains(t.doneAt)).fold(0,(a,t)=>a+t.focusSecs).toInt();
    final uf=state.settings.unboundFocusByDate.entries.where((e)=>ds.contains(e.key)).fold(0,(a,e)=>a+e.value).toInt();
    final total=tf+uf;
    final at=(state.tasks.fold(0,(a,t)=>a+t.focusSecs)+state.settings.unboundFocusByDate.values.fold(0,(a,v)=>a+v)).toInt();
    final daily={for(final d in days) d:state.tasks.where((t)=>t.doneAt==d).fold(0,(int a,t)=>a+t.focusSecs)+(state.settings.unboundFocusByDate[d]??0)};
    final mx=daily.values.isEmpty?1:daily.values.reduce((a,b)=>a>b?a:b);
    final tags=state.tags.where((t)=>state.tagCountsInStats(t)&&state.tagFocusTime(t)>0).toList()
      ..sort((a,b)=>state.tagFocusTime(b).compareTo(state.tagFocusTime(a)));
    return _DP(title:L.get('screens.statsNew.focusStats'),tc:tc,body:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[_BigStat(tc:tc,val:_fmtT(total),lbl:L.get('screens.statsNew.periodFocus', {'period': pLbl})),const SizedBox(width:10),_BigStat(tc:tc,val:_fmtT(at),lbl:L.get('screens.statsNew.totalFocus'))]),
      const SizedBox(height:20),
      if(days.length>1&&mx>0)...[
        _Lbl(tc:tc,text:L.get('screens.statsNew.dailyFocusDuration')), const SizedBox(height:10),
        SizedBox(height:60,child:Row(crossAxisAlignment:CrossAxisAlignment.end,
          children:days.take(31).map((d){
            final secs=daily[d]??0; final frac=mx>0?secs/mx:0.0;
            return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:0.5),
              child:TweenAnimationBuilder<double>(tween:Tween(begin:0,end:frac),
                duration:const Duration(milliseconds:500),curve:Curves.easeOut,
                builder:(_,v,__)=>FractionallySizedBox(heightFactor:v.clamp(0.04,1.0),alignment:Alignment.bottomCenter,
                  child:Container(decoration:BoxDecoration(color:Color(tc.acc).withOpacity(0.55+0.45*v),
                    borderRadius:const BorderRadius.vertical(top:Radius.circular(2))))))));
          }).toList())),
        const SizedBox(height:20),
      ],
      _Lbl(tc:tc,text:L.get('screens.statsNew.tagFocusRank')), const SizedBox(height:10),
      ...tags.map((tag){
        final c=state.tagColor(tag); final ft=state.tagFocusTime(tag);
        final ts=state.tasks.where((t)=>t.done&&t.tags.contains(tag)&&t.focusSecs>0).toList()
          ..sort((a,b)=>b.focusSecs.compareTo(a.focusSecs));
        return _ETagFocus(tag:tag,color:c,tc:tc,ft:ft,tasks:ts);
      }),
    ]));
  }
}

// Deviation
class _DevPage extends StatelessWidget {
  final AppState state; final List<String> days; final String pLbl; final ThemeConfig tc;
  const _DevPage({required this.state,required this.days,required this.pLbl,required this.tc});
  @override
  Widget build(BuildContext context) => _DP(title:L.get('screens.statsNew.deviation'),tc:tc,body:ListView(
    padding:const EdgeInsets.all(16), children:[
      Container(padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:state.cardColor,borderRadius:BorderRadius.circular(12)),
        child:Text('偏差 = 实际完成时段 − 计划时段\n正值 = 拖延，负值 = 提前',
          style:TextStyle(fontSize:11,color:Color(tc.ts),height:1.6))),
      const SizedBox(height:16),
      DeviationChart(days:days,state:state,title:'$pLbl偏差'),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable detail-page widgets
// ─────────────────────────────────────────────────────────────────────────────
class _DayBars extends StatelessWidget {
  final Map<String,int> byDay; final int mx; final ThemeConfig tc;
  const _DayBars({required this.byDay,required this.mx,required this.tc});
  @override
  Widget build(BuildContext context) => SizedBox(height:80,child:Row(crossAxisAlignment:CrossAxisAlignment.end,
    children:byDay.entries.map((e){
      final frac=mx>0?e.value/mx:0.0;
      return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:1),
        child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
          if(e.value>0) Text('${e.value}',style:TextStyle(fontSize:8,color:Color(tc.ts))),
          const SizedBox(height:2),
          TweenAnimationBuilder<double>(tween:Tween(begin:0,end:frac.clamp(0.04,1.0)),
            duration:const Duration(milliseconds:500),curve:Curves.easeOut,
            builder:(_,v,__)=>FractionallySizedBox(heightFactor:v,alignment:Alignment.bottomCenter,
              child:Container(decoration:BoxDecoration(color:Color(tc.acc).withOpacity(0.7),
                borderRadius:const BorderRadius.vertical(top:Radius.circular(2)))))),
        ])));
    }).toList()));
}

class _TLine extends StatelessWidget {
  final TaskModel task; final ThemeConfig tc;
  const _TLine({required this.task,required this.tc});
  @override
  Widget build(BuildContext context) => Padding(padding:const EdgeInsets.symmetric(vertical:5),
    child:Row(children:[
      Icon(Icons.check_circle_outline_rounded,size:14,color:Color(tc.acc)),
      const SizedBox(width:8),
      Expanded(child:Text(task.text,style:TextStyle(fontSize:12,color:Color(tc.ts)),maxLines:2,overflow:TextOverflow.ellipsis)),
    ]));
}

class _RR extends StatelessWidget {
  final String lbl,rate; final Color col; final ThemeConfig tc;
  const _RR({required this.lbl,required this.rate,required this.col,required this.tc});
  @override
  Widget build(BuildContext context) => Padding(padding:const EdgeInsets.symmetric(vertical:7),
    child:Row(children:[Text(lbl,style:TextStyle(fontSize:13,color:Color(tc.ts))),const Spacer(),
      Text(rate,style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:col))]));
}

class _BigStat extends StatelessWidget {
  final ThemeConfig tc; final String val,lbl; final Color? color;
  const _BigStat({required this.tc,required this.val,required this.lbl,this.color});
  @override
  Widget build(BuildContext context) => Expanded(child:Container(
    padding:const EdgeInsets.symmetric(vertical:14,horizontal:16),
    decoration:BoxDecoration(color:Color(tc.card),borderRadius:BorderRadius.circular(14),
      boxShadow:[BoxShadow(color:Color(0x0C000000),blurRadius:8)]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(val,style:TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:color??Color(tc.acc))),
      const SizedBox(height:4),
      Text(lbl,style:TextStyle(fontSize:10,color:Color(tc.ts))),
    ])));
}

class _MS extends StatelessWidget {
  final ThemeConfig tc; final String val,lbl;
  const _MS({required this.tc,required this.val,required this.lbl});
  @override
  Widget build(BuildContext context) => Expanded(child:Column(children:[
    Text(val,style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Color(tc.tx))),
    const SizedBox(height:2),
    Text(lbl,style:TextStyle(fontSize:9,color:Color(tc.ts)),textAlign:TextAlign.center),
  ]));
}

class _Lbl extends StatelessWidget {
  final ThemeConfig tc; final String text;
  const _Lbl({required this.tc,required this.text});
  @override
  Widget build(BuildContext context) => Text(text,style:TextStyle(fontSize:9.5,letterSpacing:1.1,color:Color(tc.ts)));
}

class _ETagFocus extends StatefulWidget {
  final String tag; final Color color; final ThemeConfig tc; final int ft; final List<TaskModel> tasks;
  const _ETagFocus({required this.tag,required this.color,required this.tc,required this.ft,required this.tasks});
  @override State<_ETagFocus> createState() => _ETagFocusState();
}
class _ETagFocusState extends State<_ETagFocus> {
  bool _open=false;
  @override
  Widget build(BuildContext context) {
    final tc=widget.tc;
    return Container(margin:const EdgeInsets.only(bottom:8),
      decoration:BoxDecoration(color:Color(tc.card),borderRadius:BorderRadius.circular(12)),
      child:Column(children:[
        InkWell(onTap:()=>setState(()=>_open=!_open),borderRadius:BorderRadius.circular(12),
          child:Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),
            child:Row(children:[
              Container(width:9,height:9,decoration:BoxDecoration(shape:BoxShape.circle,color:widget.color)),
              const SizedBox(width:8),
              Text(widget.tag,style:TextStyle(fontSize:13,color:widget.color)),
              const SizedBox(width:5),
              Icon(_open?Icons.expand_less:Icons.expand_more,size:14,color:Color(tc.tm)),
              const Spacer(),
              Text(_fmtT(widget.ft),style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:Color(tc.acc))),
            ]))),
        AnimatedSize(duration:const Duration(milliseconds:220),curve:Curves.easeInOutCubic,
          child:_open?Column(children:[
            Divider(height:1,color:Color(tc.brd)),
            ...widget.tasks.take(8).map((t)=>Padding(padding:const EdgeInsets.fromLTRB(30,7,14,7),
              child:Row(children:[
                Expanded(child:Text(t.text,style:TextStyle(fontSize:11,color:Color(tc.ts)),maxLines:1,overflow:TextOverflow.ellipsis)),
                const SizedBox(width:8),
                Text(_fmtT(t.focusSecs),style:TextStyle(fontSize:11,color:widget.color)),
              ]))),
          ]):const SizedBox.shrink()),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
String _fmtT(int s) {
  if(s<=0) return '—';
  if(s<60) return '${s}${L.second}';
  if(s<3600) return '${s~/60}${L.minute}';
  return '${s~/3600}${L.hour}${s%3600~/60>0?' ${s%3600~/60}${L.minuteShort}':''}';
}

PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  transitionDuration:const Duration(milliseconds:320),
  pageBuilder:(_,__,___)=>page,
  transitionsBuilder:(_,anim,__,child){
    final c=CurvedAnimation(parent:anim,curve:Curves.easeInOutCubic);
    return SlideTransition(position:Tween<Offset>(begin:const Offset(1,0),end:Offset.zero).animate(c),
      child:FadeTransition(opacity:anim,child:child));
  });

// ─────────────────────────────────────────────────────────────────────────────
// 完成时间分布砖块
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineBrick extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final List<String> days;
  final double animationFactor;
  final VoidCallback onTap;
  const _TimelineBrick({
    required this.tc,
    required this.state,
    required this.days,
    required this.animationFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = days.toSet();
    final hourCount = List<int>.filled(24, 0);
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null || !ds.contains(t.doneAt)) continue;
      if (t.doneHour != null) hourCount[t.doneHour!]++;
    }
    final total = hourCount.fold(0, (a, b) => a + b);
    final maxH  = hourCount.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final peakH = hourCount.indexOf(maxH);

    Color barColor(int h) => h >= 5 && h < 13
        ? const Color(0xFFe8982a)
        : h >= 13 && h < 18
            ? const Color(0xFF3a90c0)
            : const Color(0xFF7a5ab8);

    return _BrickShell(tc: tc, accent: const Color(0xFF3a90c0), onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🕐', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(child: Text(L.get('screens.statsNew.bento.completionTime'),
              style: TextStyle(fontSize: 10.5, color: Color(tc.ts)))),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 6),
          Text(total == 0 ? '—' : L.get('screens.stats.itemCount', {'count': total.toString()}),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: Color(tc.tx))),
          if (total > 0)
            Text(L.get('screens.statsNew.bento.peakHour', {'hour': peakH.toString()}),
                style: TextStyle(fontSize: 9, color: Color(tc.tm))),
          const SizedBox(height: 8),
          // 24h 迷你柱
          SizedBox(height: 28,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final cnt = hourCount[h];
                final frac = (cnt / maxH) * animationFactor;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.4),
                  child: FractionallySizedBox(
                    heightFactor: (frac * 0.9 + 0.1 * animationFactor).clamp(0.01, 1.0),
                    alignment: Alignment.bottomCenter,
                    child: Container(decoration: BoxDecoration(
                      color: barColor(h).withOpacity(cnt > 0 ? 0.75 : 0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
                    )),
                  ),
                ));
              }),
            ),
          ),
        ]),
      ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 偏差砖块（带趋势迷你折线，替换旧 _DevBrick）
// ─────────────────────────────────────────────────────────────────────────────
class _DeviationBrick extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final List<String> days;
  final VoidCallback onTap;
  const _DeviationBrick({required this.tc, required this.state,
      required this.days, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = state.deviationByDay(days);
    final avg  = data.isEmpty ? 0.0
        : data.map((e) => e.$2).reduce((a, b) => a + b) / data.length;

    String lbl; Color col;
    if (data.isEmpty)  { lbl = L.get('screens.statsNew.bento.deviationNoData'); col = Color(tc.tm); }
    else if (avg.abs() < 0.2) { lbl = L.get('screens.statsNew.bento.deviationOnTime'); col = const Color(0xFF4A9068); }
    else if (avg > 0)  { lbl = L.get('screens.statsNew.bento.deviationDelayed', {'value': avg.toStringAsFixed(1)}); col = const Color(0xFFe8982a); }
    else               { lbl = L.get('screens.statsNew.bento.deviationAhead', {'value': (-avg).toStringAsFixed(1)}); col = const Color(0xFF3a90c0); }

    final sparkData = data.isNotEmpty
        ? data.map((e) => e.$2).toList()
        : [0.0, 0.0, 0.0];

    return _BrickShell(tc: tc, accent: const Color(0xFF9A7AB8), onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('📐', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(child: Text(L.get('screens.statsNew.bento.estimateDeviation'),
              style: TextStyle(fontSize: 10.5, color: Color(tc.ts)))),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 4),
          Text(lbl, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700, color: col)),
          const SizedBox(height: 2),
          Text(L.get('screens.statsNew.bento.plannedVsActualBlocks'),
              style: TextStyle(fontSize: 9, color: Color(tc.tm))),
          const Spacer(),
          _Spark(data: sparkData, tc: tc, color: data.isEmpty ? Color(tc.brd) : col),
        ]),
      ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 完成时间分布详情页（Bento 美术风格）
// ─────────────────────────────────────────────────────────────────────────────
class _CompletionTimelinePage extends StatefulWidget {
  final AppState state;
  final List<String> days;
  final String pLbl;
  final ThemeConfig tc;
  const _CompletionTimelinePage({required this.state, required this.days,
      required this.pLbl, required this.tc});
  @override
  State<_CompletionTimelinePage> createState() => _CompletionTimelinePageState();
}

class _CompletionTimelinePageState extends State<_CompletionTimelinePage> {
  final Map<int, bool> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tc    = widget.tc;
    final ds    = widget.days.toSet();

    final hourTasks = List<List<TaskModel>>.generate(24, (_) => []);
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null || !ds.contains(t.doneAt)) continue;
      if (t.doneHour != null) hourTasks[t.doneHour!].add(t);
    }
    final hourCount = hourTasks.map((l) => l.length).toList();
    final total  = hourCount.fold(0, (a, b) => a + b);
    final maxH   = hourCount.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final peakH  = hourCount.indexOf(maxH);

    final morningTotal   = hourCount.sublist(5, 13).fold(0, (a, b) => a + b);
    final afternoonTotal = hourCount.sublist(13, 18).fold(0, (a, b) => a + b);
    final eveningTotal   = (hourCount.sublist(0, 5) + hourCount.sublist(18)).fold(0, (a, b) => a + b);

    Color blkColor(int h) => h >= 5 && h < 13
        ? const Color(0xFFe8982a)
        : h >= 13 && h < 18
            ? const Color(0xFF3a90c0)
            : const Color(0xFF7a5ab8);

    final hourSuffix = L.i18n.currentLanguage == 'zh' ? '时' : 'h';
    return _DP(title: L.get('screens.statsNew.bento.completionTimeDistribution'), tc: tc,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        // 汇总卡
        Row(children: [
          _BigStat(tc: tc, val: '$total', lbl: L.get('screens.statsNew.periodCompleted', {'period': widget.pLbl})),
          const SizedBox(width: 8),
          _BigStat(tc: tc, val: '$peakH$hourSuffix', lbl: L.get('screens.statsNew.bento.peakHourLabel'),
            color: blkColor(peakH)),
        ]),
        const SizedBox(height: 14),

        // 时段分布三块
        Row(children: [
          _SmallStatChip(label: '${L.morningEmoji} ${L.morning}', count: morningTotal,
              color: const Color(0xFFe8982a), tc: tc),
          const SizedBox(width: 8),
          _SmallStatChip(label: '${L.afternoonEmoji} ${L.afternoon}', count: afternoonTotal,
              color: const Color(0xFF3a90c0), tc: tc),
          const SizedBox(width: 8),
          _SmallStatChip(label: '${L.eveningEmoji} ${L.evening}', count: eveningTotal,
              color: const Color(0xFF7a5ab8), tc: tc),
        ]),
        const SizedBox(height: 16),

        // 24h 柱状图
        _Lbl(tc: tc, text: L.get('screens.statsNew.bento.hourlyCompletionDistribution')),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          decoration: BoxDecoration(color: state.cardColor,
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            SizedBox(height: 72,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(24, (h) {
                  final cnt  = hourCount[h];
                  final frac = cnt / maxH;
                  return Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (cnt > 0 && frac > 0.55)
                        Text('$cnt', style: TextStyle(fontSize: 7, color: blkColor(h))),
                      const SizedBox(height: 2),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: frac * 0.9 + 0.1),
                        duration: Duration(milliseconds: 350 + h * 8),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => FractionallySizedBox(
                          heightFactor: v.clamp(0.08, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(decoration: BoxDecoration(
                            color: blkColor(h).withOpacity(cnt > 0 ? 0.75 : 0.15),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                          )),
                        ),
                      ),
                    ]),
                  ));
                }),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('0h', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
              Text('6h', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
              Text('12h', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
              Text('18h', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
              Text('23h', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // 各小时任务明细
        _Lbl(tc: tc, text: L.get('screens.stats.hourlyCompletionDetails')),
        const SizedBox(height: 8),
        ...List.generate(24, (h) {
          final tasks = hourTasks[h];
          if (tasks.isEmpty) return const SizedBox.shrink();
          final exp = _expanded[h] ?? false;
          return Container(
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(color: state.cardColor,
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _expanded[h] = !exp),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: blkColor(h))),
                    const SizedBox(width: 8),
                    Text('${h.toString().padLeft(2, '0')}:00',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: blkColor(h), fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    Text('${tasks.length} 件',
                      style: TextStyle(fontSize: 11, color: Color(tc.ts))),
                    const Spacer(),
                    Icon(exp ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: Color(tc.tm)),
                  ]),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                child: exp ? Column(children: [
                  Divider(height: 1, color: Color(tc.brd)),
                  ...tasks.map((t) => Padding(
                    padding: const EdgeInsets.fromLTRB(30, 7, 14, 7),
                    child: Row(children: [
                      Expanded(child: Text(t.text,
                        style: TextStyle(fontSize: 11, color: Color(tc.tx)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (t.doneAt != null)
                        Text(t.doneAt!, style: TextStyle(fontSize: 9, color: Color(tc.tm))),
                    ]),
                  )),
                ]) : const SizedBox.shrink(),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 小统计 chip（用于详情页汇总行）
// ─────────────────────────────────────────────────────────────────────────────
class _SmallStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final ThemeConfig tc;
  const _SmallStatChip({required this.label, required this.count,
      required this.color, required this.tc});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: color)),
      const SizedBox(height: 4),
      Text('$count 件', style: TextStyle(fontSize: 14,
          fontWeight: FontWeight.w700, color: color)),
    ]),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// 柱状图 + 趋势曲线叠加（当周完成量）
// ─────────────────────────────────────────────────────────────────────────────
class _DayBarsWithCurve extends StatelessWidget {
  final Map<String, int> byDay;
  final List<int> hourCount; // for smooth curve overlay
  final int mx;
  final ThemeConfig tc;
  const _DayBarsWithCurve({required this.byDay, required this.hourCount,
      required this.mx, required this.tc});

  @override
  Widget build(BuildContext context) {
    final acc = Color(tc.acc);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        SizedBox(height: 90, child: CustomPaint(
          painter: _BarCurvePainter(
            values: byDay.values.toList(),
            mx: mx > 0 ? mx : 1,
            barColor: acc.withOpacity(0.55),
            lineColor: acc,
          ),
          size: const Size(double.infinity, 90),
        )),
        const SizedBox(height: 6),
        // Day labels
        Row(children: byDay.entries.map((e) {
          final d = DateUtils2.parse(e.key);
          return Expanded(child: Text(
            '${d.month}/${d.day}',
            style: TextStyle(fontSize: 7, color: Color(tc.tm)),
            textAlign: TextAlign.center,
          ));
        }).toList()),
      ]),
    );
  }
}

class _BarCurvePainter extends CustomPainter {
  final List<int> values;
  final int mx;
  final Color barColor, lineColor;
  const _BarCurvePainter({required this.values, required this.mx,
      required this.barColor, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final w = size.width / values.length;
    final barP = Paint()..color = barColor;
    final lineP = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw bars
    for (int i = 0; i < values.length; i++) {
      final frac = values[i] / mx;
      final barH = (frac * size.height * 0.85).clamp(2.0, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * w + 2, size.height - barH, w - 4, barH),
        const Radius.circular(3));
      canvas.drawRRect(rect, barP);
    }

    // Draw smooth curve through bar tops
    if (values.length >= 2) {
      final pts = List.generate(values.length, (i) {
        final frac = values[i] / mx;
        return Offset(i * w + w / 2, size.height - (frac * size.height * 0.85).clamp(2.0, size.height));
      });
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 0; i < pts.length - 1; i++) {
        final cp1 = Offset((pts[i].dx + pts[i+1].dx) / 2, pts[i].dy);
        final cp2 = Offset((pts[i].dx + pts[i+1].dx) / 2, pts[i+1].dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i+1].dx, pts[i+1].dy);
      }
      canvas.drawPath(path, lineP);
      // Dots
      for (final pt in pts) {
        canvas.drawCircle(pt, 3, Paint()..color = lineColor);
      }
    }
  }

  @override bool shouldRepaint(_BarCurvePainter o) => o.values != values;
}

// ─────────────────────────────────────────────────────────────────────────────
// 时段分布饼图
// ─────────────────────────────────────────────────────────────────────────────
class _BlockPieChart extends StatelessWidget {
  final Map<String, int> blkCount;
  final int blkTotal;
  final ThemeConfig tc;
  const _BlockPieChart({required this.blkCount, required this.blkTotal, required this.tc});

  @override
  Widget build(BuildContext context) {
    const blks = [
      ('morning',   '🌅 上午', Color(0xFFe8982a)),
      ('afternoon', '☀️ 下午', Color(0xFF3a90c0)),
      ('evening',   '🌙 晚上', Color(0xFF7a5ab8)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        SizedBox(width: 100, height: 100, child: CustomPaint(
          painter: _PiePainter(
            values: [
              blkCount['morning']!.toDouble(),
              blkCount['afternoon']!.toDouble(),
              blkCount['evening']!.toDouble(),
            ],
            colors: const [Color(0xFFe8982a), Color(0xFF3a90c0), Color(0xFF7a5ab8)],
          ),
        )),
        const SizedBox(width: 20),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: blks.map((b) {
            final cnt = blkCount[b.$1] ?? 0;
            final pct = blkTotal > 0 ? (cnt / blkTotal * 100).round() : 0;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(width: 10, height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: b.$3)),
                const SizedBox(width: 8),
                Expanded(child: Text(b.$2, style: TextStyle(fontSize: 11, color: Color(tc.ts)))),
                Text('$cnt件 ($pct%)', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600, color: b.$3)),
              ]),
            );
          }).toList(),
        )),
      ]),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _PiePainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    double startAngle = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, true,
        Paint()..color = colors[i % colors.length],
      );
      startAngle += sweep;
    }
    // White hole center
    canvas.drawCircle(center, radius * 0.5,
        Paint()..color = Colors.white.withOpacity(0.9));
  }

  @override bool shouldRepaint(_PiePainter o) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 忽略统计砖块
// ─────────────────────────────────────────────────────────────────────────────
class _IgnoreBrick extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final List<String> days;
  final VoidCallback onTap;
  const _IgnoreBrick({required this.tc, required this.state,
      required this.days, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final ignoredTotal = state.tasks.where((t) => t.ignored).length;
    final ignoredPeriod = state.tasks
        .where((t) => t.ignored && days.contains(t.originalDate)).length;
    return _BrickShell(tc: tc, accent: const Color(0xFF888888), onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('🗑', style: TextStyle(fontSize: 18)),
            const Spacer(), Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm))]),
          const Spacer(),
          Text('$ignoredTotal', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
              color: Color(tc.tx), height: 1.0)),
          const SizedBox(height: 3),
          Text(L.get('screens.statsNew.bento.ignoreTotal', {'count': ignoredTotal.toString()}),
              style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
          Text(L.get('screens.statsNew.bento.ignorePeriodCount', {'count': ignoredPeriod.toString()}),
              style: TextStyle(fontSize: 9, color: const Color(0xFF888888))),
        ])));
  }
}

// 忽略统计详情页
class _IgnorePage extends StatefulWidget {
  final AppState state;
  final ThemeConfig tc;
  const _IgnorePage({required this.state, required this.tc});
  @override State<_IgnorePage> createState() => _IgnorePageState();
}
class _IgnorePageState extends State<_IgnorePage> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tc = widget.tc;
    final ignored = state.tasks.where((t) => t.ignored).toList()
      ..sort((a, b) => b.id.compareTo(a.id)); // newest first
    // Tag distribution among ignored
    final tagCount = <String, int>{};
    for (final t in ignored) {
      for (final tag in t.tags) tagCount[tag] = (tagCount[tag] ?? 0) + 1;
    }
    final topTags = tagCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _DP(title: L.get('screens.statsNew.bento.ignoreTitle'), tc: tc,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Summary
        Row(children: [
          _BigStat(tc: tc, val: '${ignored.length}', lbl: L.get('screens.statsNew.bento.ignoreTotal', {'count': ignored.length.toString()}),
              color: const Color(0xFF888888)),
          const SizedBox(width: 8),
          _BigStat(tc: tc, val: '${(ignored.length /
              (state.tasks.length > 0 ? state.tasks.length : 1) * 100).round()}%',
            lbl: L.get('screens.statsNew.bento.ignoreRate'), color: const Color(0xFF888888)),
        ]),
        const SizedBox(height: 16),

        if (topTags.isNotEmpty) ...[
          _Lbl(tc: tc, text: L.get('screens.statsNew.bento.ignoredByTag')),
          const SizedBox(height: 8),
          ...topTags.take(6).map((e) {
            final c = state.tagColor(e.key);
            return Padding(padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                const SizedBox(width: 8),
                Expanded(child: Text(e.key,
                    style: TextStyle(fontSize: 12, color: Color(tc.ts)))),
                Text('${e.value}', style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600, color: Color(tc.tx))),
              ]));
          }),
          const SizedBox(height: 16),
        ],

        _Lbl(tc: tc, text: L.get('screens.statsNew.bento.ignoredTasksCancelable')),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF888888).withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF888888).withOpacity(0.25))),
          child: Text(L.get('screens.statsNew.bento.unignoreHint'),
            style: TextStyle(fontSize: 11, color: Color(tc.ts)))),
        const SizedBox(height: 8),

        if (ignored.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(L.get('screens.statsNew.bento.noIgnoredTasks'),
                style: TextStyle(fontSize: 12, color: Color(tc.tm))))),

        ...ignored.map((t) {
          final tagColor = t.tags.isNotEmpty
              ? state.tagColor(t.tags.first) : Color(tc.ts);
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: state.cardColor, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 4, height: 36,
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.text, style: TextStyle(fontSize: 12, color: Color(tc.ts)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(L.get('screens.statsNew.bento.createdAt', {'date': t.originalDate}),
                    style: TextStyle(fontSize: 9, color: Color(tc.tm))),
              ])),
              TextButton(
                onPressed: () {
                  state.unignoreTask(t.id);
                  setState(() {});
                  HapticFeedback.lightImpact();
                  final shortText = t.text.length > 10 ? '${t.text.substring(0, 10)}…' : t.text;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(L.get('screens.statsNew.bento.unignoredSnack', {'text': shortText})),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                },
                style: TextButton.styleFrom(
                  foregroundColor: Color(tc.acc),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(L.get('screens.statsNew.bento.restore'), style: const TextStyle(fontSize: 11)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 心理分析砖块
// ─────────────────────────────────────────────────────────────────────────────
class _PsychBrick extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final double animationFactor;
  final VoidCallback onTap;
  const _PsychBrick({
    required this.tc,
    required this.state,
    required this.animationFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile = PsychAnalyzer.analyze(state);
    final procrastColor = profile.procrastinationIndex < 35
        ? const Color(0xFF4A9068)
        : profile.procrastinationIndex < 60
            ? const Color(0xFFe8982a)
            : const Color(0xFFc04040);
    return _BrickShell(tc: tc, accent: const Color(0xFF8060C0), onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🧠', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(L.get('screens.statsNew.bento.psychologyAnalysis'),
                style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
            const SizedBox(height: 4),
            Text(profile.cognitivePattern,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(tc.tx))),
            const SizedBox(height: 2),
            Text(L.get('screens.statsNew.bento.procrastinationIndex', {
              'value': profile.procrastinationIndex.toString(),
            }),
              style: TextStyle(fontSize: 10, color: procrastColor,
                  fontWeight: FontWeight.w600)),
          ]),
          const Spacer(),
          // Procrastination meter driven by animationFactor
          SizedBox(width: 40, height: 40, child: CircularProgressIndicator(
            value: (profile.procrastinationIndex / 100) * animationFactor,
            backgroundColor: Color(tc.brd),
            valueColor: AlwaysStoppedAnimation(procrastColor),
            strokeWidth: 5,
          )),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm)),
        ])));
  }
}

// 心理分析详情页
class _PsychPage extends StatelessWidget {
  final AppState state;
  final ThemeConfig tc;
  const _PsychPage({required this.state, required this.tc});
  @override
  Widget build(BuildContext context) {
    final profile = PsychAnalyzer.analyze(state);
    final procrastColor = profile.procrastinationIndex < 35
        ? const Color(0xFF4A9068)
        : profile.procrastinationIndex < 60
            ? const Color(0xFFe8982a)
            : const Color(0xFFc04040);
    return _DP(title: L.get('screens.statsNew.bento.psychologyReport'), tc: tc,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // 拖延指数
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: state.cardColor,
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            SizedBox(width: 70, height: 70, child: CustomPaint(
              painter: _GaugePainter(
                value: profile.procrastinationIndex / 100,
                color: procrastColor,
                trackColor: Color(tc.brd),
              ),
              child: Center(child: Text('${profile.procrastinationIndex}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: procrastColor))),
            )),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(L.get('screens.statsNew.bento.procrastinationTendencyIndex'),
                  style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              const SizedBox(height: 4),
              Text(profile.procrastinationIndex < 35
                  ? L.get('screens.statsNew.bento.procrastinationLow')
                  : profile.procrastinationIndex < 60
                      ? L.get('screens.statsNew.bento.procrastinationMid')
                      : L.get('screens.statsNew.bento.procrastinationHigh'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: procrastColor)),
              const SizedBox(height: 4),
              Text(L.get('screens.statsNew.bento.cognitivePattern', {'pattern': profile.cognitivePattern}),
                style: TextStyle(fontSize: 11, color: Color(tc.tx))),
            ])),
          ])),
        const SizedBox(height: 14),

        // 自我效能
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Color(tc.cb),
              borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💪 ', style: TextStyle(fontSize: 14)),
            Expanded(child: Text(profile.selfEfficacy,
              style: TextStyle(fontSize: 12, color: Color(tc.ts), height: 1.5))),
          ])),
        const SizedBox(height: 14),

        // 洞察
        _Lbl(tc: tc, text: L.get('screens.statsNew.bento.behavioralInsights')),
        const SizedBox(height: 8),
        ...profile.insights.map((insight) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: state.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 6)]),
          child: Text(insight,
              style: TextStyle(fontSize: 12, color: Color(tc.ts), height: 1.6)))),
        const SizedBox(height: 14),

        if (profile.recommendations.isNotEmpty) ...[
          _Lbl(tc: tc, text: L.get('screens.statsNew.bento.targetedImprovements')),
          const SizedBox(height: 8),
          ...profile.recommendations.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(tc.acc).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(tc.acc).withOpacity(0.20))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.key + 1}. ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(tc.acc))),
              Expanded(child: Text(e.value,
                style: TextStyle(fontSize: 12, color: Color(tc.tx), height: 1.5))),
            ]))),
        ],

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Color(tc.brd).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10)),
          child: Text(L.get('screens.statsNew.bento.psychDisclaimer'),
            style: TextStyle(fontSize: 10, color: Color(tc.tm), height: 1.5))),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color, trackColor;
  const _GaugePainter({required this.value, required this.color, required this.trackColor});
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 5;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
      0, 2 * pi, false,
      Paint()..color = trackColor..strokeWidth = 8..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
      -pi / 2, 2 * pi * value, false,
      Paint()..color = color..strokeWidth = 8..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_GaugePainter o) => o.value != value;
}

// ─────────────────────────────────────────────────────────────────────────────
// β 屏幕使用分析砖块 (在统计页展示)
// ─────────────────────────────────────────────────────────────────────────────
class _UsageStatsBrick extends StatefulWidget {
  final AppState state;
  final ThemeConfig tc;
  const _UsageStatsBrick({required this.state, required this.tc});
  @override State<_UsageStatsBrick> createState() => _UsageStatsBrickState();
}
class _UsageStatsBrickState extends State<_UsageStatsBrick> {
  bool _loading = true;
  bool _hasPerm = false;
  UsageSummary? _usage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _hasPerm = await UsageStatsService.hasPermission();
    if (_hasPerm && mounted) {
      _usage = await UsageStatsService.getTodayUsage(
        userCategories: widget.state.settings.userAppCategories);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final acc = const Color(0xFF3a90c0);

    if (_loading) {
      return Container(
        decoration: BoxDecoration(
          color: Color(tc.card), borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.all(14),
        child: Row(mainAxisSize: MainAxisSize.max, children: [
          SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2,
              color: acc.withOpacity(0.7))),
          const SizedBox(width: 10),
          Text(L.get('screens.statsNew.bento.loading'),
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
        ]),
      );
    }

    if (!_hasPerm) {
      return _BrickShell(tc: tc, accent: acc,
        onTap: () => UsageStatsService.requestPermission(),
        child: Padding(padding: const EdgeInsets.fromLTRB(14,14,14,12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('📱', style: TextStyle(fontSize: 18)),
              const Spacer(),
              Icon(Icons.lock_outline, size: 14, color: Color(tc.tm)),
            ]),
            const SizedBox(height: 14),
            Text(L.get('screens.statsNew.bento.usageAnalysis'), style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Color(tc.tx))),
            const SizedBox(height: 3),
            Text(L.get('screens.statsNew.bento.tapToGrantPermission'),
                style: TextStyle(fontSize: 10, color: Color(tc.ts))),
          ])));
    }

    final u = _usage;
    if (u == null) return const SizedBox.shrink();

    final focusSecs = widget.state.todayFocusSecs();
    final effScore = u.efficiencyScore(focusSecs);
    final entertainH = (u.totalEntertainMs / 3600000);
    final focusH = focusSecs / 3600;

    // Score color
    final scoreColor = effScore >= 70
        ? const Color(0xFF4A9068)
        : effScore >= 40
            ? const Color(0xFFe8982a)
            : const Color(0xFFc04040);

    return _BrickShell(tc: tc, accent: acc,
      onTap: () => Navigator.push(context, _slideRoute(
          _UsageDetailPage(state: widget.state, usage: u, tc: tc))),
      child: Padding(padding: const EdgeInsets.fromLTRB(14,14,14,12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('📱', style: TextStyle(fontSize: 18)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 4),
          Text(L.get('screens.statsNew.bento.usageAnalysis'),
              style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$effScore', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: scoreColor, height: 1.0)),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 3),
              child: Text('/100', style: TextStyle(fontSize: 11, color: Color(tc.tm)))),
          ]),
          const SizedBox(height: 2),
          Text(L.get('screens.statsNew.bento.focusEntertainmentSummary', {
            'focus': focusH.toStringAsFixed(1),
            'entertain': entertainH.toStringAsFixed(1),
          }), style: TextStyle(fontSize: 9, color: Color(tc.ts))),
        ])));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 屏幕使用分析详情页
// ─────────────────────────────────────────────────────────────────────────────
class _UsageDetailPage extends StatelessWidget {
  final AppState state;
  final UsageSummary usage;
  final ThemeConfig tc;
  const _UsageDetailPage({required this.state, required this.usage, required this.tc});

  @override
  Widget build(BuildContext context) {
    final focusSecs = state.todayFocusSecs();
    final effScore = usage.efficiencyScore(focusSecs);
    final entertainH = usage.totalEntertainMs / 3600000;
    final focusH = focusSecs / 3600;
    final scoreColor = effScore >= 70
        ? const Color(0xFF4A9068)
        : effScore >= 40 ? const Color(0xFFe8982a) : const Color(0xFFc04040);

    // Build sorted app list
    final apps = usage.apps.where((a) => a.ms > 60000).toList()
      ..sort((a, b) => b.ms.compareTo(a.ms));

    // Get insights from smart plan
    final plan = SmartPlan.suggest(state, usage: usage);
    final screenInsights = plan.insights
        .where((i) => i.source == InsightSource.screen ||
                      i.source == InsightSource.crossScreen)
        .toList();

    return _DP(title: L.get('screens.statsNew.bento.usageAnalysisBeta'), tc: tc,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Score card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: state.cardColor,
            borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            SizedBox(width: 64, height: 64, child: CustomPaint(
              painter: _GaugePainter(value: effScore / 100,
                  color: scoreColor, trackColor: Color(tc.brd)),
              child: Center(child: Text('$effScore',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: scoreColor))),
            )),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(L.get('screens.statsNew.bento.efficiencyHealthIndex'),
                  style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              const SizedBox(height: 4),
              Text(effScore >= 70
                  ? L.get('screens.statsNew.bento.statusGood')
                  : effScore >= 40
                      ? L.get('screens.statsNew.bento.statusImprove')
                      : L.get('screens.statsNew.bento.statusAdjust'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: scoreColor)),
              const SizedBox(height: 4),
              Text(L.get('screens.statsNew.bento.focusEntertainmentSummary', {
                'focus': focusH.toStringAsFixed(1),
                'entertain': entertainH.toStringAsFixed(1),
              }), style: TextStyle(fontSize: 10, color: Color(tc.ts))),
            ])),
          ])),
        const SizedBox(height: 14),

        // Category breakdown
        _Lbl(tc: tc, text: L.get('screens.statsNew.bento.todayAppCategoryUsage')),
        const SizedBox(height: 8),
        _CategoryBar(usage: usage, tc: tc),
        const SizedBox(height: 14),

        // App list
        if (apps.isNotEmpty) ...[
          _Lbl(tc: tc, text: L.get('screens.statsNew.bento.appUsageDuration')),
          const SizedBox(height: 8),
          ...apps.take(12).map((app) {
            final mins = app.ms ~/ 60000;
            final maxMs = apps.first.ms.toDouble();
            final frac = maxMs > 0 ? app.ms / maxMs : 0.0;
            final typeColor = const {
              'game': Color(0xFFc04040),
              'video': Color(0xFF7a5ab8),
              'social': Color(0xFF3a90c0),
              'work': Color(0xFF4A9068),
            }[app.type] ?? const Color(0xFF888888);
            return Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 8, height: 8,
                  child: Container(decoration: BoxDecoration(
                    shape: BoxShape.circle, color: typeColor))),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(app.appName,
                      style: TextStyle(fontSize: 11, color: Color(tc.tx)),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${mins}${L.minute}', style: TextStyle(
                        fontSize: 10, color: Color(tc.ts))),
                  ]),
                  const SizedBox(height: 3),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: v, minHeight: 4,
                        backgroundColor: Color(tc.brd),
                        color: typeColor.withOpacity(0.7)))),
                ])),
              ]));
          }),
        ],

        // Screen-based insights
        if (screenInsights.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Lbl(tc: tc, text: L.get('screens.statsNew.bento.screenTaskCrossInsights')),
          const SizedBox(height: 8),
          ...screenInsights.map((ins) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: state.cardColor,
              borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ins.icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ins.title, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Color(tc.tx))),
                const SizedBox(height: 3),
                Text(ins.body, style: TextStyle(
                    fontSize: 10, color: Color(tc.ts), height: 1.4)),
              ])),
            ]))),
        ],
      ]),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final UsageSummary usage;
  final ThemeConfig tc;
  const _CategoryBar({required this.usage, required this.tc});

  @override
  Widget build(BuildContext context) {
    final cats = <(String, int, Color)>[
      (L.get('screens.statsNew.bento.categoryWork'), usage.totalWorkMs, const Color(0xFF4A9068)),
      (L.get('screens.statsNew.bento.categoryGame'), usage.totalGameMs, const Color(0xFFc04040)),
      (L.get('screens.statsNew.bento.categoryVideo'), usage.totalVideoMs, const Color(0xFF7a5ab8)),
      (L.get('screens.statsNew.bento.categorySocial'), usage.totalSocialMs, const Color(0xFF3a90c0)),
      (L.get('screens.statsNew.bento.categoryMusic'), usage.totalMusicMs, const Color(0xFFe8982a)),
      (L.get('screens.statsNew.bento.categoryNews'), usage.totalNewsMs, const Color(0xFF888888)),
    ].where((c) => c.$2 > 0).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final total = cats.fold(0, (s, c) => s + c.$2);
    if (total == 0) return Text(L.get('screens.statsNew.noData'),
        style: TextStyle(fontSize: 11, color: Color(tc.tm)));

    return Column(children: [
      // Bar chart
      Container(
        height: 12,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Color(tc.brd)),
        child: Row(
          children: cats.map((c) => Flexible(
            flex: c.$2,
            child: Container(color: c.$3))).toList())),
      const SizedBox(height: 8),
      // Legend
      Wrap(spacing: 10, runSpacing: 5,
        children: cats.map((c) {
          final mins = c.$2 ~/ 60000;
          final pct = (c.$2 / total * 100).round();
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.$3)),
            const SizedBox(width: 4),
            Text(L.get('screens.statsNew.bento.categoryLegendItem', {
              'label': c.$1,
              'mins': mins.toString(),
              'unit': L.minute,
              'pct': pct.toString(),
            }),
              style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
          ]);
        }).toList()),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 习惯追踪砖块
// ─────────────────────────────────────────────────────────────────────────────
class _HabitBrick extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final VoidCallback onTap;
  const _HabitBrick({required this.tc, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final habits = _topHabits(state);
    const acc = Color(0xFF7a5ab8);
    final fireCount = habits.where((h) => h.streak >= 7).length;
    return _BrickShell(tc: tc, accent: acc, onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Text(L.get('screens.statsNew.bento.habitTracking'),
                style: TextStyle(fontSize: 10, color: Color(tc.ts))),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 7),
          if (habits.isEmpty)
            Text(L.get('screens.statsNew.bento.habitBrickHint'),
              style: TextStyle(fontSize: 9.5, color: Color(tc.tm)))
          else ...[
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${habits.length}', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: acc, height: 1.0)),
                Text(L.get('screens.statsNew.bento.habitCountLabel'),
                    style: TextStyle(fontSize: 8.5, color: Color(tc.ts))),
              ]),
              const SizedBox(width: 12),
              if (fireCount > 0) Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$fireCount', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: const Color(0xFFe8982a), height: 1.0)),
                Text(L.get('screens.statsNew.bento.streak7DaysPlus'),
                    style: TextStyle(fontSize: 8.5, color: Color(tc.ts))),
              ]),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: acc.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6)),
              child: Text(habits.first.name,
                style: TextStyle(fontSize: 9.5, color: acc,
                    fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ])));
  }

  static List<_HabitData> _topHabits(AppState state) {
    final today = state.todayKey;
    final days30 = List.generate(30, (i) {
      final d = DateTime.parse('${today}T12:00:00')
          .subtract(Duration(days: 30 - i));
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    });
    final freq = <String, int>{};
    final lastSeen = <String, String>{};
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null) continue;
      if (!days30.contains(t.doneAt!)) continue;
      final key = t.text.trim().substring(0, t.text.length.clamp(0, 12));
      if (key.length < 2) continue;
      freq[key] = (freq[key] ?? 0) + 1;
      if (lastSeen[key] == null || t.doneAt!.compareTo(lastSeen[key]!) > 0) {
        lastSeen[key] = t.doneAt!;
      }
    }
    final habits = freq.entries.where((e) => e.value >= 5).map((e) {
      int streak = 0;
      for (int i = days30.length - 1; i >= 0; i--) {
        final d = days30[i];
        final done = state.tasks.any((t) => t.done && t.doneAt == d &&
            t.text.trim().startsWith(e.key.substring(0, e.key.length.clamp(0,6))));
        if (done) streak++; else break;
      }
      return _HabitData(name: e.key, count: e.value, streak: streak);
    }).toList()..sort((a, b) => b.streak != a.streak
        ? b.streak.compareTo(a.streak)
        : b.count.compareTo(a.count));
    return habits;
  }
}
class _HabitData {
  final String name;
  final int count, streak;
  const _HabitData({required this.name, required this.count, required this.streak});
}

// 习惯追踪详情页
class _HabitPage extends StatelessWidget {
  final AppState state;
  final ThemeConfig tc;
  const _HabitPage({required this.state, required this.tc});

  @override
  Widget build(BuildContext context) {
    final habits = _HabitBrick._topHabits(state);
    final today = state.todayKey;
    final dayUnit = L.i18n.currentLanguage == 'zh' ? '天' : 'd';

    return _DP(title: L.get('screens.statsNew.bento.habitTracking'), tc: tc,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF7a5ab8).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
          child: Text(L.get('screens.statsNew.bento.habitPageHint'),
              style: TextStyle(fontSize: 11, color: Color(tc.ts), height: 1.5))),
        const SizedBox(height: 14),

        if (habits.isEmpty) ...[
          Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Text('🌱', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text(L.get('screens.statsNew.bento.noHabitsTitle'),
                style: TextStyle(fontSize: 14, color: Color(tc.tx))),
              const SizedBox(height: 4),
              Text(L.get('screens.statsNew.bento.noHabitsSubtitle'),
                style: TextStyle(fontSize: 11, color: Color(tc.tm))),
            ]))),
        ] else
          ...habits.map((h) {
            final todayDone = state.tasks.any((t) =>
                t.done && t.doneAt == today &&
                t.text.trim().startsWith(h.name.substring(0, h.name.length.clamp(0,6))));
            final streakColor = h.streak >= 14 ? const Color(0xFFc04040)
                : h.streak >= 7 ? const Color(0xFFe8982a)
                : h.streak >= 3 ? const Color(0xFF4A9068)
                : const Color(0xFF888888);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: state.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(h.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: Color(tc.tx)))),
                  if (todayDone)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A9068).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(L.get('screens.statsNew.bento.todayDone'),
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF4A9068))))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFe8982a).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(L.get('screens.statsNew.bento.todayTodo'),
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFFe8982a)))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _MS(tc: tc, val: '${h.count}', lbl: L.get('screens.statsNew.bento.last30Days')),
                  _MS(tc: tc, val: h.streak > 0 ? '${h.streak}$dayUnit' : '—', lbl: L.get('screens.statsNew.bento.streak')),
                  Expanded(child: Column(children: [
                    Text(h.streak >= 14 ? L.get('screens.statsNew.bento.habitStrengthSuper')
                        : h.streak >= 7 ? L.get('screens.statsNew.bento.habitStrengthStable')
                        : h.streak >= 3 ? L.get('screens.statsNew.bento.habitStrengthBuilding')
                        : L.get('screens.statsNew.bento.habitStrengthStarting'),
                      style: TextStyle(fontSize: 11, color: streakColor,
                          fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(L.get('screens.statsNew.bento.timesPerWeek', {
                      'value': (h.count / 30 * 7).toStringAsFixed(1),
                    }),
                      style: TextStyle(fontSize: 9, color: Color(tc.tm))),
                  ])),
                ]),
                // Streak bar (last 14 days)
                const SizedBox(height: 10),
                _Lbl(tc: tc, text: L.get('screens.statsNew.bento.last14DaysCompletion')),
                const SizedBox(height: 5),
                _HabitCalRow(habitName: h.name, state: state, tc: tc),
              ]));
          }),
      ]),
    );
  }
}

class _HabitCalRow extends StatelessWidget {
  final String habitName;
  final AppState state;
  final ThemeConfig tc;
  const _HabitCalRow({required this.habitName, required this.state, required this.tc});
  @override
  Widget build(BuildContext context) {
    final today = state.todayKey;
    final days14 = List.generate(14, (i) {
      final d = DateTime.parse('${today}T12:00:00').subtract(Duration(days: 13 - i));
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    });
    final prefix = habitName.substring(0, habitName.length.clamp(0, 6));
    return Row(children: days14.asMap().entries.map((e) {
      final d = e.value;
      final done = state.tasks.any((t) =>
          t.done && t.doneAt == d && t.text.trim().startsWith(prefix));
      final isToday = d == today;
      return Expanded(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        height: 20,
        decoration: BoxDecoration(
          color: done
              ? const Color(0xFF7a5ab8).withOpacity(0.7)
              : Color(tc.brd).withOpacity(0.4),
          borderRadius: BorderRadius.circular(3),
          border: isToday ? Border.all(
              color: const Color(0xFF7a5ab8), width: 1.5) : null),
      ));
    }).toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 番茄钟深度分析砖块
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// 心流指数砖块 — 1×1，显示近期均值 + 趋势迷你折线
// ─────────────────────────────────────────────────────────────────────────────
class _FlowBrick extends StatefulWidget {
  final ThemeConfig tc;
  final AppState state;
  final double animationFactor;
  final VoidCallback onTap;
  const _FlowBrick({
    required this.tc,
    required this.state,
    required this.animationFactor,
    required this.onTap,
  });
  @override State<_FlowBrick> createState() => _FlowBrickState();
}

class _FlowBrickState extends State<_FlowBrick> {
  double? _avgFlow;
  List<double> _sparkValues = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final avg   = await FocusQualityService.avgFlowIndex(days: 14);
    final trend = await FocusQualityService.flowTrend(days: 14);
    if (mounted) setState(() {
      _avgFlow     = avg;
      _sparkValues = trend.map((t) => t.flow).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc  = widget.tc;
    final avg = _avgFlow;
    final score = avg != null ? (avg * 100).round() : null;
    final phaseColor = score == null ? Color(tc.ts)
        : score >= 80 ? const Color(0xFFFFB300)
        : score >= 60 ? Color(tc.acc)
        : score >= 35 ? const Color(0xFF3a90c0)
        : Color(tc.ts);
    final phase = score == null ? L.get('screens.statsNew.noData')
        : score >= 80 ? L.get('screens.pomodoro.flowStateDeep')
        : score >= 60 ? L.get('screens.pomodoro.flowStateFocused')
        : score >= 35 ? L.get('screens.pomodoro.flowStateEntering')
        : L.get('screens.pomodoro.flowStateWarmingUp');

    return _BrickShell(tc: tc, accent: phaseColor, onTap: widget.onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text(score == null ? '💧'
                : score >= 80 ? '🔥'
                : score >= 60 ? '✨'
                : '💧',
              style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Text(L.get('screens.pomodoro.flowIndex'),
                style: TextStyle(fontSize: 10, color: Color(tc.ts))),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 7),
          if (score == null)
            Text(L.get('screens.statsNew.bento.flowCompletePomHint'),
              style: TextStyle(fontSize: 9.5, color: Color(tc.tm)))
          else ...[
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic, children: [
              Text('${(score * widget.animationFactor).round()}', style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800,
                  color: phaseColor, height: 1.0)),
              const SizedBox(width: 4),
              Text(L.get('screens.statsNew.bento.flowScoreUnit'), style: TextStyle(fontSize: 10,
                  color: phaseColor.withOpacity(0.7))),
            ]),
            Text(phase, style: TextStyle(fontSize: 9,
                color: phaseColor.withOpacity(0.8),
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            // Sparkline driven by animationFactor
            if (_sparkValues.length >= 2)
              SizedBox(height: 20,
                child: CustomPaint(
                  painter: _MiniSparkPainter(
                    values: _sparkValues, color: phaseColor, animationFactor: widget.animationFactor),
                  size: Size.infinite)),
          ],
        ])));
  }
}

class _MiniSparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double animationFactor;
  const _MiniSparkPainter({required this.values, required this.color, required this.animationFactor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final n = values.length;
    final paint = Paint()
      ..color = color ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    final path = Path();
    
    // Calculate how many segments to draw based on animationFactor
    final limit = (n - 1) * animationFactor;
    
    for (int i = 0; i < n; i++) {
      if (i > limit + 1) break;
      
      final x = i / (n - 1) * size.width;
      final y = (1.0 - values[i]) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = (i - 1) / (n - 1) * size.width;
        final py = (1.0 - values[i - 1]) * size.height;
        
        if (i <= limit) {
          final cx = (px + x) / 2;
          path.cubicTo(cx, py, cx, y, x, y);
        } else {
          // Interpolate the last segment
          final t = (limit - (i - 1));
          final targetX = px + (x - px) * t;
          final targetY = py + (y - py) * t;
          final cx = (px + targetX) / 2;
          path.cubicTo(cx, py, cx, targetY, targetX, targetY);
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MiniSparkPainter o) => o.values != values || o.animationFactor != animationFactor;
}

// ─────────────────────────────────────────────────────────────────────────────
// 心流指数详情页
// ─────────────────────────────────────────────────────────────────────────────
class _FlowDetailPage extends StatefulWidget {
  final ThemeConfig tc;
  final AppState state;
  const _FlowDetailPage({required this.tc, required this.state});
  @override State<_FlowDetailPage> createState() => _FlowDetailPageState();
}

class _FlowDetailPageState extends State<_FlowDetailPage> {
  List<({String date, double flow})>? _trend;
  double? _avgFlow;

  @override
  void initState() {
    super.initState();
    FocusQualityService.flowTrend(days: 30).then((t) {
      if (mounted) setState(() => _trend = t);
    });
    FocusQualityService.avgFlowIndex(days: 14).then((a) {
      if (mounted) setState(() => _avgFlow = a);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc  = widget.tc;
    const acc = Color(0xFFFFB300);

    return _DP(title: L.get('screens.pomodoro.flowIndex'), tc: tc,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [

        // ── 说明卡 ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L.get('screens.statsNew.bento.flowWhatIsTitle'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(tc.tx))),
            const SizedBox(height: 6),
            Text(L.get('screens.statsNew.bento.flowWhatIsBody'),
              style: TextStyle(fontSize: 11, color: Color(tc.ts), height: 1.6)),
          ])),
        const SizedBox(height: 12),

        // ── 近期趋势图 ───────────────────────────────────────────────────
        if (_trend != null && _trend!.length >= 2) ...[
          _DSLabel('📈', L.get('screens.statsNew.bento.flowTrend30Days'), tc),
          _DS(tc: tc, accent: acc, child: _FlowTrendChart(
            trend: _trend!, avgFlow: _avgFlow, tc: tc, acc: acc)),
          const SizedBox(height: 12),
        ] else if (_trend != null && _trend!.isEmpty) ...[
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🍅', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(L.get('screens.statsNew.bento.noFlowRecords'),
                  style: TextStyle(fontSize: 16, color: Color(tc.tx))),
              const SizedBox(height: 8),
              Text(L.get('screens.statsNew.bento.flowAutoRecordedHint'),
                style: TextStyle(fontSize: 12, color: Color(tc.ts))),
            ]))),
        ],

        // ── 提升建议 ────────────────────────────────────────────────────
        _DS(tc: tc, accent: acc, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('💡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(L.get('screens.statsNew.bento.flowImproveTitle'), style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: acc)),
          ]),
          const SizedBox(height: 10),
          for (final tip in [
            (L.get('screens.statsNew.bento.flowTip1Title'), L.get('screens.statsNew.bento.flowTip1Body')),
            (L.get('screens.statsNew.bento.flowTip2Title'), L.get('screens.statsNew.bento.flowTip2Body')),
            (L.get('screens.statsNew.bento.flowTip3Title'), L.get('screens.statsNew.bento.flowTip3Body')),
            (L.get('screens.statsNew.bento.flowTip4Title'), L.get('screens.statsNew.bento.flowTip4Body')),
          ]) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                  margin: const EdgeInsets.only(top: 2, right: 8),
                  width: 4, height: 4,
                  decoration: BoxDecoration(
                    color: acc, shape: BoxShape.circle)),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tip.$1, style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: Color(tc.tx))),
                  Text(tip.$2, style: TextStyle(fontSize: 10.5,
                      color: Color(tc.ts), height: 1.4)),
                ])),
              ])),
          ],
        ])),
      ]));
  }
}

class _DeepFocusBrick extends StatelessWidget {
  final ThemeConfig tc;
  final AppState state;
  final double animationFactor;
  final VoidCallback onTap;
  const _DeepFocusBrick({
    required this.tc,
    required this.state,
    required this.animationFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final report = PomDeepAnalysis.analyze(state);
    const acc = Color(0xFF4A9068);
    return _BrickShell(tc: tc, accent: acc, onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──────────────────────────────────────────────────
          Row(children: [
            const Text('🍅', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Expanded(child: Text('番茄钟深度',
              style: TextStyle(fontSize: 10, color: Color(tc.ts)))),
            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(tc.tm)),
          ]),
          const SizedBox(height: 10),
          if (report.sampleCount < 3)
            Expanded(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
              const Text('🍅', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text('完成 3 次后\n查看分析',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(tc.tm))),
            ])))
          else ...[
            // ── Key numbers ─────────────────────────────────────────
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${report.sampleCount}', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: acc, height: 1.0)),
                Text('次专注', style: TextStyle(fontSize: 8.5,
                    color: Color(tc.ts))),
              ]),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${report.suggestedFocusMins}m', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: acc.withOpacity(0.75), height: 1.0)),
                Text('建议时长', style: TextStyle(fontSize: 8.5,
                    color: Color(tc.ts))),
              ]),
            ]),
            const SizedBox(height: 10),
            // ── 24h mini heatmap bar ────────────────────────────────
            SizedBox(height: 30, child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final v = report.hourlyFocusMins[h];
                final maxV = report.hourlyFocusMins
                    .reduce((a, b) => a > b ? a : b);
                if (maxV == 0) return const Expanded(child: SizedBox());
                final frac = (v / maxV).clamp(0.0, 1.0) * animationFactor;
                final isBest = h == report.bestHour;
                return Expanded(child: Container(
                  height: frac * 26 + (2 * animationFactor),
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    color: isBest
                        ? acc.withOpacity(0.9)
                        : acc.withOpacity(0.20 + frac * 0.40),
                    borderRadius: BorderRadius.circular(1.5)),
                ));
              }))),
            const SizedBox(height: 5),
            Text(report.peakLabel,
              style: TextStyle(fontSize: 9.5, color: acc,
                  fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            // ── Continuity insight ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: acc.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8)),
              child: Text(report.continuityInsight,
                style: TextStyle(fontSize: 9.5, color: Color(tc.ts),
                    height: 1.4),
                maxLines: 3, overflow: TextOverflow.ellipsis)),
          ],
        ])));
  }
}


class _DeepFocusPage extends StatefulWidget {
  final ThemeConfig tc;
  final AppState state;
  const _DeepFocusPage({required this.tc, required this.state});
  @override
  State<_DeepFocusPage> createState() => _DeepFocusPageState();
}

class _DeepFocusPageState extends State<_DeepFocusPage> {
  List<double>? _hourlyNoiseScore;
  double? _overallNoiseScore;
  List<SessionNoiseReport>? _noiseSessions;
  // 心流指数统计
  List<({String date, double flow})>? _flowTrend;
  double? _avgFlowIndex;

  @override
  void initState() {
    super.initState();
    _loadNoise();
    _loadFlow();
  }

  Future<void> _loadFlow() async {
    final trend = await FocusQualityService.flowTrend(days: 14);
    final avg   = await FocusQualityService.avgFlowIndex(days: 14);
    if (mounted) setState(() { _flowTrend = trend; _avgFlowIndex = avg; });
  }

  Future<void> _loadNoise() async {
    final scores = await NoiseHistoryStore.hourlyNoiseScore(days: 30);
    final overall = await NoiseHistoryStore.overallScore(days: 30);
    final sessions = await NoiseHistoryStore.recent(days: 30, source: 'pomodoro');
    if (mounted) {
      setState(() {
        _hourlyNoiseScore = scores;
        _overallNoiseScore = overall;
        _noiseSessions = sessions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc     = widget.tc;
    final state  = widget.state;
    final report = PomDeepAnalysis.analyze(state);
    const acc    = Color(0xFF4A9068);
    const noiseAcc = Color(0xFF3a90c0);

    return _DP(title: '番茄钟深度分析', tc: tc,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [

        if (report.sampleCount < 3) ...[
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🍅', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('暂无足够番茄钟数据', style: TextStyle(
                  fontSize: 16, color: Color(tc.tx))),
              const SizedBox(height: 8),
              Text('至少完成 3 次番茄钟后查看专注分析\n当前: ${report.sampleCount} 次',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(tc.ts))),
            ]))),
        ] else ...[

          // ── 概览 ────────────────────────────────────────────────────
          _DS(tc: tc, accent: acc, child: Column(children: [
            Row(children: [
              _DSStat('${report.sampleCount}', '次专注', acc),
              _DSStat('${report.suggestedFocusMins}分', '建议时长', acc),
              _DSStat(_hourStr(report.bestHour), '最高效', acc),
            ]),
            const SizedBox(height: 8),
            Text(report.continuityInsight,
              style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          ])),
          const SizedBox(height: 12),

          // ── 24h 专注分布 ────────────────────────────────────────────
          _DSLabel('⏰', '24小时专注分布（深色=高效时段）', tc),
          _DS(tc: tc, accent: acc, child: _HourlyHeatmap(
            focusMins: report.hourlyFocusMins,
            interruptScore: report.hourlyInterruptScore,
            bestHour: report.bestHour, tc: tc, acc: acc)),
          const SizedBox(height: 12),

          // ── 近7天折线 ───────────────────────────────────────────────
          _DSLabel('📅', '近7天专注时长 & 完成率', tc),
          _DS(tc: tc, accent: acc, child: _WeeklyLineChart(
            focusH: report.weeklyFocusHours,
            compRate: report.weeklyCompletionRate,
            tc: tc, acc: acc)),
          const SizedBox(height: 12),

          // ── 时长分布 ────────────────────────────────────────────────
          _DSLabel('📊', '专注时长分布（分钟）', tc),
          _DS(tc: tc, accent: acc, child: _DurationHistogram(
            buckets: report.focusDurationBuckets,
            suggestedBucket: report.suggestedFocusMins ~/ 5,
            tc: tc, acc: acc)),
          const SizedBox(height: 12),

          // ── 打断倾向 ────────────────────────────────────────────────
          _DSLabel('⚡', '时段打断倾向（越亮=越容易被打断）', tc),
          _DS(tc: tc, accent: acc, child: _InterruptBar(
            interruptScore: report.hourlyInterruptScore, tc: tc)),
          const SizedBox(height: 12),
        ],

        // ── 心流指数趋势（有数据时显示）────────────────────────────────
        if (_flowTrend != null && _flowTrend!.length >= 2) ...[
          _DSLabel('🔥', L.get('screens.statsNew.bento.flowTrend30Days'), tc),
          _DS(tc: tc, accent: acc, child: _FlowTrendChart(
            trend: _flowTrend!, avgFlow: _avgFlowIndex, tc: tc, acc: acc)),
          const SizedBox(height: 12),
        ],

        // ── 环境声历史分析（有数据时显示） ─────────────────────────────
        if (_noiseSessions != null && _noiseSessions!.isNotEmpty) ...[
          _DSLabel('🎙', L.get('screens.statsNew.noise.envFocus30Days'), tc),
          _DS(tc: tc, accent: noiseAcc, child: _NoiseHistorySection(
            tc: tc,
            sessions: _noiseSessions!,
            overallScore: _overallNoiseScore ?? 0,
            hourlyScores: _hourlyNoiseScore,
          )),
          const SizedBox(height: 12),
        ],

        // ── 个性化建议 ──────────────────────────────────────────────
        if (report.sampleCount >= 3) ...[
          _DS(tc: tc, accent: acc,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🎯', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(L.get('screens.statsNew.noise.personalAdvice'), style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: acc)),
            ]),
            const SizedBox(height: 8),
            _SuggestionRow('⏱', L.get('screens.statsNew.noise.suggestFocusMins', {
                  'mins': report.suggestedFocusMins.toString(),
                }),
                L.get('screens.statsNew.noise.suggestBasedOnMedian'), tc),
            _SuggestionRow('🌅', L.get('screens.statsNew.noise.bestFocusTime', {
                  'hour': _hourStr(report.bestHour),
                }),
                report.peakLabel, tc),
            if (_overallNoiseScore != null && _overallNoiseScore! > 0)
              _SuggestionRow(
                _overallNoiseScore! >= 0.7 ? '🤫' : '🔊',
                _overallNoiseScore! >= 0.7
                    ? L.get('screens.statsNew.noise.envGood')
                    : L.get('screens.statsNew.noise.envNoisy'),
                L.get('screens.statsNew.noise.envScoreSummary', {
                  'count': (_noiseSessions?.length ?? 0).toString(),
                  'score': (_overallNoiseScore! * 100).round().toString(),
                }),
                tc),
          ])),
        ],
      ]));
  }

  static String _hourStr(int h) {
    if (h < 6)   return '凌晨$h时';
    if (h < 12)  return '上午$h时';
    if (h == 12) return '正午';
    if (h < 18)  return '下午${h-12}时';
    return '晚上${h-12}时';
  }
}

// ── Helpers: localized noise level label ─────────────────────────────────────
String _noiseLevelLabel(NoiseLevel level) {
  switch (level) {
    case NoiseLevel.silent:
      return L.get('screens.statsNew.noise.level.silent');
    case NoiseLevel.quiet:
      return L.get('screens.statsNew.noise.level.quiet');
    case NoiseLevel.moderate:
      return L.get('screens.statsNew.noise.level.moderate');
    case NoiseLevel.loud:
      return L.get('screens.statsNew.noise.level.loud');
    case NoiseLevel.veryLoud:
      return L.get('screens.statsNew.noise.level.veryLoud');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 环境声 Bento 砖块
// ─────────────────────────────────────────────────────────────────────────────
class _NoiseBrick extends StatefulWidget {
  final ThemeConfig tc;
  final AppState state;
  final VoidCallback onTap;
  const _NoiseBrick({required this.tc, required this.state, required this.onTap});
  @override State<_NoiseBrick> createState() => _NoiseBrickState();
}

class _NoiseBrickState extends State<_NoiseBrick> {
  SessionNoiseReport? _latest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await NoiseHistoryStore.allSorted();
    if (mounted && all.isNotEmpty) setState(() => _latest = all.first);
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    const noiseAcc = Color(0xFF3a90c0);
    final latest = _latest;
    return _BrickShell(tc: tc, accent: noiseAcc, onTap: widget.onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(children: [
          // Icon / emoji
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: noiseAcc.withOpacity(0.12),
            ),
            child: Center(child: Text(
              latest != null ? latest.dominantLevel.emoji : '🎙',
              style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(L.get('screens.statsNew.noise.title'), style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(tc.tx))),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(tc.tm)),
              ]),
              const SizedBox(height: 4),
              if (latest != null) ...[
                Text(L.get('screens.statsNew.noise.avgDbLabel', {
                      'db': latest.avgDb.round().toString(),
                      'label': _noiseLevelLabel(latest.dominantLevel),
                    }),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: Color(latest.dominantLevel.colorHex))),
                Text(latest.isManual
                    ? L.get('screens.statsNew.noise.manualMeasure')
                    : L.get('screens.statsNew.noise.pomSampling'),
                    style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
              ] else
                Text(L.get('screens.statsNew.noise.start30s'),
                    style: TextStyle(fontSize: 10.5, color: Color(tc.ts))),
            ],
          )),
        ]),
      ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 环境声独立详情页
// ─────────────────────────────────────────────────────────────────────────────
class _NoisePage extends StatefulWidget {
  final ThemeConfig tc;
  final AppState state;
  const _NoisePage({required this.tc, required this.state});
  @override State<_NoisePage> createState() => _NoisePageState();
}

class _NoisePageState extends State<_NoisePage> {
  bool _measuring = false;
  SessionNoiseReport? _lastReport;
  List<SessionNoiseReport> _history = [];
  List<double> _liveReadings = [];
  StreamSubscription<double>? _liveSub;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final all = await NoiseHistoryStore.allSorted();
    if (mounted) setState(() => _history = all);
  }

  Future<void> _startMeasure() async {
    if (_measuring) return;
    final startTime = DateTime.now();
    setState(() {
      _measuring = true;
      _liveReadings = [];
      _lastReport = null;
    });
    HapticFeedback.mediumImpact();

    final collectedReadings = <double>[];

    // Subscribe to EventChannel stream — each emission = one second's dB
    _liveSub?.cancel();
    _liveSub = EnvironmentSoundService.liveDbStream.listen(
      (db) {
        collectedReadings.add(db);
        if (mounted) setState(() => _liveReadings = List.from(collectedReadings));
      },
      onDone: () async {
        // Stream ended (30 samples received or native error)
        final report = await EnvironmentSoundService.buildReportFromReadings(
            collectedReadings, startTime);
        if (mounted) {
          setState(() {
            _measuring = false;
            _lastReport = report;
          });
          _loadHistory();
        }
      },
      onError: (_) {
        if (mounted) setState(() => _measuring = false);
      },
      cancelOnError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    const noiseAcc = Color(0xFF3a90c0);
    final report = _lastReport;

    return _DP(title: L.get('screens.statsNew.noise.title'), tc: tc,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [

        // ── 测量卡 ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [noiseAcc.withOpacity(0.14), noiseAcc.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: noiseAcc.withOpacity(0.30)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: noiseAcc.withOpacity(0.12)),
                child: Center(child: Text(
                  _measuring
                    ? '🎙'
                    : (report?.dominantLevel.emoji ?? '🎙'),
                  style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(L.get('screens.statsNew.noise.singleSession'), style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: Color(tc.tx))),
                  const SizedBox(height: 2),
                  if (_measuring)
                    Text(L.get('screens.statsNew.noise.recording', {
                          'current': _liveReadings.length.toString(),
                        }),
                        style: TextStyle(fontSize: 11, color: noiseAcc))
                  else if (report != null) ...[
                    Text(L.get('screens.statsNew.noise.avgDbDashLabel', {
                          'db': report.avgDb.round().toString(),
                          'label': _noiseLevelLabel(report.dominantLevel),
                        }),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(report.dominantLevel.colorHex))),
                    Text(report.assessment,
                        style: TextStyle(fontSize: 10, color: Color(tc.ts),
                            height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ] else
                    Text(L.get('screens.statsNew.noise.tapToRecord'),
                        style: TextStyle(fontSize: 11, color: Color(tc.ts))),
                ],
              )),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _measuring ? null : _startMeasure,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _measuring ? Color(tc.brd) : noiseAcc,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _measuring ? [] : [BoxShadow(
                        color: noiseAcc.withOpacity(0.35),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: _measuring
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
                ),
              ),
            ]),

            // ── 实时分贝仪表盘 ─────────────────────────────────────────
            if (_measuring || _liveReadings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LiveDbMeter(readings: _liveReadings, tc: tc, acc: noiseAcc),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // ── 番茄钟采样总览曲线（所有 pomodoro 采样点连成折线） ─────────
        FutureBuilder<List<SessionNoiseReport>>(
          future: NoiseHistoryStore.allSorted(source: 'pomodoro'),
          builder: (ctx, snap) {
            final pomSessions = snap.data ?? [];
            if (pomSessions.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 8),
                  child: Text(L.get('screens.statsNew.noise.pomTrend'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 0.6, color: Color(tc.ts)))),
                Container(
                  decoration: BoxDecoration(
                    color: Color(tc.card),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF4A9068).withOpacity(0.25)),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        const Text('🍅', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(L.get('screens.statsNew.noise.samplesLine', {
                              'count': pomSessions.length.toString(),
                            }),
                            style: TextStyle(fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(tc.tx))),
                        const Spacer(),
                        Text(L.get('screens.statsNew.noise.latestDb', {
                              'db': pomSessions.last.avgDb.round().toString(),
                            }),
                            style: const TextStyle(fontSize: 9.5,
                                color: Color(0xFF4A9068),
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 80,
                        child: CustomPaint(
                          painter: _PomodoroNoiseCurvePainter(
                            sessions: pomSessions,
                            tc: tc,
                          ),
                          size: const Size(double.infinity, 80),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Y-axis labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(L.get('screens.statsNew.noise.yQuiet'), style: TextStyle(
                              fontSize: 7.5, color: Color(tc.tm))),
                          Text(L.get('screens.statsNew.noise.yModerate'), style: TextStyle(
                              fontSize: 7.5, color: Color(tc.tm))),
                          Text(L.get('screens.statsNew.noise.yNoisy'), style: TextStyle(
                              fontSize: 7.5, color: Color(tc.tm))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),

        // ── 历史记录列表 ────────────────────────────────────────────────
        if (_history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(L.get('screens.statsNew.noise.history'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 0.6, color: Color(tc.ts)))),
          ..._history.take(50).map((r) => _NoiseHistoryRow(
              report: r, tc: tc)),
        ] else
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎙', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(L.get('screens.statsNew.noise.noHistory'), style: TextStyle(fontSize: 14, color: Color(tc.ts))),
              const SizedBox(height: 6),
              Text(L.get('screens.statsNew.noise.tapRecordHint'),
                  style: TextStyle(fontSize: 11, color: Color(tc.tm))),
            ]))),
      ]));
  }
}

// ── 实时分贝仪表盘 ────────────────────────────────────────────────────────────
class _LiveDbMeter extends StatelessWidget {
  final List<double> readings;
  final ThemeConfig tc;
  final Color acc;
  const _LiveDbMeter({required this.readings, required this.tc, required this.acc});

  @override
  Widget build(BuildContext context) {
    const totalBars = 30;
    final current = readings.isNotEmpty ? readings.last : 0.0;
    final level = NoiseLevelX.fromDb(current);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Current dB big display
      Row(children: [
        Text(readings.isEmpty ? '--' : '${current.round()}',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                color: Color(level.colorHex), height: 1.0)),
        const SizedBox(width: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text('dB', style: TextStyle(fontSize: 14, color: Color(tc.ts))),
          Text(readings.isEmpty ? L.get('screens.statsNew.noise.waiting') : _noiseLevelLabel(level),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(level.colorHex))),
        ]),
        const Spacer(),
        Text(L.get('screens.statsNew.noise.secondsProgress', {
              'current': readings.length.toString(),
            }),
            style: TextStyle(fontSize: 10, color: Color(tc.ts))),
      ]),
      const SizedBox(height: 10),

      // Bar chart of readings so far
      SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(totalBars, (i) {
            final hasReading = i < readings.length;
            final db = hasReading ? readings[i] : 0.0;
            final lv = NoiseLevelX.fromDb(db);
            final frac = hasReading
                ? ((db - 20) / 80).clamp(0.05, 1.0)
                : 0.0;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0.8),
                height: frac * 44 + (hasReading ? 4 : 2),
                decoration: BoxDecoration(
                  color: hasReading
                      ? Color(lv.colorHex).withOpacity(0.80)
                      : Color(tc.brd).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['0s', '10s', '20s', '30s'].map((l) =>
            Text(l, style: TextStyle(fontSize: 8, color: Color(tc.tm)))).toList()),

      // Color legend
      const SizedBox(height: 8),
      Wrap(spacing: 10, children: NoiseLevel.values.map((l) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: Color(l.colorHex),
                  shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text('${l.label}', style: TextStyle(fontSize: 8.5, color: Color(tc.ts))),
        ])).toList()),
    ]);
  }
}

// ── 历史记录行 ────────────────────────────────────────────────────────────────
class _NoiseHistoryRow extends StatelessWidget {
  final SessionNoiseReport report;
  final ThemeConfig tc;
  const _NoiseHistoryRow({required this.report, required this.tc});

  @override
  Widget build(BuildContext context) {
    final t = report.sessionStart;
    final dateStr = '${t.month}/${t.day} '
        '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    final hasCurve = report.samples.length > 1;
    final levelColor = Color(report.dominantLevel.colorHex);
    final isManual = report.isManual;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(tc.brd).withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, hasCurve ? 4 : 10),
            child: Row(children: [
              Text(report.dominantLevel.emoji,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Text('${report.avgDb.round()} dB',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: levelColor)),
                    const SizedBox(width: 5),
                    Text('· ${report.dominantLevel.label}',
                        style: TextStyle(fontSize: 11,
                            color: Color(tc.ts))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isManual
                            ? const Color(0xFF3a90c0).withOpacity(0.10)
                            : const Color(0xFF4A9068).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(isManual ? '手动' : '番茄钟',
                          style: TextStyle(
                              fontSize: 8.5,
                              color: isManual
                                  ? const Color(0xFF3a90c0)
                                  : const Color(0xFF4A9068),
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  Text(dateStr,
                      style: TextStyle(fontSize: 9, color: Color(tc.tm))),
                ],
              )),
            ]),
          ),

          // ── Sparkline curve (only when multiple samples exist) ──────
          if (hasCurve) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SizedBox(
                height: 44,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    samples: report.samples,
                    tc: tc,
                    baseColor: levelColor,
                  ),
                  size: const Size(double.infinity, 44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sparkline painter for a single session's 30s samples ─────────────────────
class _SparklinePainter extends CustomPainter {
  final List<NoiseSample> samples;
  final ThemeConfig tc;
  final Color baseColor;

  const _SparklinePainter({
    required this.samples,
    required this.tc,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    const dbMin = 20.0;
    const dbMax = 90.0;

    final n = samples.length;
    final w = size.width;
    final h = size.height;

    // Draw horizontal reference lines at 30, 45, 60, 75 dB
    final refPaint = Paint()
      ..color = Color(tc.brd).withOpacity(0.35)
      ..strokeWidth = 0.5;
    for (final ref in [30.0, 45.0, 60.0, 75.0]) {
      final y = h - (ref - dbMin) / (dbMax - dbMin) * h;
      if (y >= 0 && y <= h) {
        canvas.drawLine(Offset(0, y), Offset(w, y), refPaint);
      }
    }

    // Build path
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final db = samples[i].dbLevel.clamp(dbMin, dbMax);
      final y = h - (db - dbMin) / (dbMax - dbMin) * h;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        // Smooth cubic bezier
        final prevX = (i - 1) / (n - 1) * w;
        final prevDb = samples[i - 1].dbLevel.clamp(dbMin, dbMax);
        final prevY = h - (prevDb - dbMin) / (dbMax - dbMin) * h;
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    // Fill area under curve
    fillPath.lineTo(w, h);
    fillPath.close();
    final fillPaint = Paint()
      ..color = baseColor.withOpacity(0.10)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw curve line with color varying by noise level
    final linePaint = Paint()
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw each segment colored by its noise level
    for (int i = 1; i < n; i++) {
      final x0 = (i - 1) / (n - 1) * w;
      final x1 = i / (n - 1) * w;
      final db0 = samples[i - 1].dbLevel.clamp(dbMin, dbMax);
      final db1 = samples[i].dbLevel.clamp(dbMin, dbMax);
      final y0 = h - (db0 - dbMin) / (dbMax - dbMin) * h;
      final y1 = h - (db1 - dbMin) / (dbMax - dbMin) * h;
      final segColor = Color(samples[i].level.colorHex);
      linePaint.color = segColor.withOpacity(0.85);
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), linePaint);
    }

    // Draw dots at each sample point
    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final db = samples[i].dbLevel.clamp(dbMin, dbMax);
      final y = h - (db - dbMin) / (dbMax - dbMin) * h;
      final dotColor = Color(samples[i].level.colorHex);
      canvas.drawCircle(
        Offset(x, y),
        n <= 10 ? 3.0 : (n <= 20 ? 2.0 : 1.5),
        Paint()..color = dotColor..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.samples != samples || old.baseColor != baseColor;
}

// ── Pomodoro sessions overview curve painter ──────────────────────────────────
// Each pomodoro session = one point (its avgDb). X=time, Y=dB.
class _PomodoroNoiseCurvePainter extends CustomPainter {
  final List<SessionNoiseReport> sessions; // newest first from allSorted
  final ThemeConfig tc;

  const _PomodoroNoiseCurvePainter({
    required this.sessions,
    required this.tc,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sessions.length < 2) {
      // Single point — just draw a dot
      if (sessions.isEmpty) return;
      final db = sessions.first.avgDb.clamp(20.0, 90.0);
      final y = size.height - (db - 20) / 70 * size.height;
      canvas.drawCircle(
        Offset(size.width / 2, y),
        4,
        Paint()..color = Color(sessions.first.dominantLevel.colorHex),
      );
      return;
    }

    // sessions is newest-first, reverse for chronological display
    final ordered = sessions.reversed.toList();
    const dbMin = 20.0;
    const dbMax = 90.0;
    final n = ordered.length;
    final w = size.width;
    final h = size.height;

    // Reference lines
    final refPaint = Paint()
      ..color = Color(tc.brd).withOpacity(0.30)
      ..strokeWidth = 0.5;
    for (final ref in [30.0, 45.0, 60.0, 75.0]) {
      final y = h - (ref - dbMin) / (dbMax - dbMin) * h;
      if (y >= 0 && y <= h) {
        canvas.drawLine(Offset(0, y), Offset(w, y), refPaint);
      }
    }

    // Noise level zone fills (very subtle background bands)
    final zonePairs = [
      (20.0, 30.0, const Color(0xFF4A9068)),   // silent — green
      (30.0, 45.0, const Color(0xFF3a90c0)),   // quiet — blue
      (45.0, 60.0, const Color(0xFFe8c84a)),   // moderate — yellow
      (60.0, 75.0, const Color(0xFFe8982a)),   // loud — orange
      (75.0, 90.0, const Color(0xFFc04040)),   // very loud — red
    ];
    for (final zone in zonePairs) {
      final y1 = h - (zone.$2 - dbMin) / (dbMax - dbMin) * h;
      final y2 = h - (zone.$1 - dbMin) / (dbMax - dbMin) * h;
      canvas.drawRect(
        Rect.fromLTRB(0, y1.clamp(0.0, h), w, y2.clamp(0.0, h)),
        Paint()..color = zone.$3.withOpacity(0.05),
      );
    }

    // Build fill path
    final fillPath = Path();
    fillPath.moveTo(0, h);

    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final db = ordered[i].avgDb.clamp(dbMin, dbMax);
      final y = h - (db - dbMin) / (dbMax - dbMin) * h;
      if (i == 0) {
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) / (n - 1) * w;
        final prevDb = ordered[i - 1].avgDb.clamp(dbMin, dbMax);
        final prevY = h - (prevDb - dbMin) / (dbMax - dbMin) * h;
        final cpX = (prevX + x) / 2;
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    fillPath.lineTo(w, h);
    fillPath.close();

    // Gradient-like fill using dominant level color of last session
    final lastColor = Color(ordered.last.dominantLevel.colorHex);
    canvas.drawPath(fillPath,
        Paint()..color = lastColor.withOpacity(0.08)..style = PaintingStyle.fill);

    // Curve line — color per segment
    final linePaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i < n; i++) {
      final x0 = (i - 1) / (n - 1) * w;
      final x1 = i / (n - 1) * w;
      final db0 = ordered[i - 1].avgDb.clamp(dbMin, dbMax);
      final db1 = ordered[i].avgDb.clamp(dbMin, dbMax);
      final y0 = h - (db0 - dbMin) / (dbMax - dbMin) * h;
      final y1 = h - (db1 - dbMin) / (dbMax - dbMin) * h;
      final cpX = (x0 + x1) / 2;
      final segPath = Path()
        ..moveTo(x0, y0)
        ..cubicTo(cpX, y0, cpX, y1, x1, y1);
      linePaint.color = Color(ordered[i].dominantLevel.colorHex).withOpacity(0.90);
      canvas.drawPath(segPath, linePaint);
    }

    // Dots with level color
    final dotR = n <= 15 ? 4.0 : n <= 30 ? 3.0 : 2.0;
    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final db = ordered[i].avgDb.clamp(dbMin, dbMax);
      final y = h - (db - dbMin) / (dbMax - dbMin) * h;
      final dotColor = Color(ordered[i].dominantLevel.colorHex);
      // White halo
      canvas.drawCircle(Offset(x, y), dotR + 1.5,
          Paint()..color = Color(tc.card)..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x, y), dotR,
          Paint()..color = dotColor..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_PomodoroNoiseCurvePainter old) =>
      old.sessions != sessions;
}


// ─────────────────────────────────────────────────────────────────────────────
// 单次环境声测量卡片
// ─────────────────────────────────────────────────────────────────────────────
class _NoiseMeasureCard extends StatelessWidget {
  final ThemeConfig tc;
  final bool measuring;
  final NoiseSample? latestSample;
  final VoidCallback onTap;
  const _NoiseMeasureCard({required this.tc, required this.measuring,
      required this.latestSample, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const noiseAcc = Color(0xFF3a90c0);
    final sample = latestSample;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [noiseAcc.withOpacity(0.12), noiseAcc.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: noiseAcc.withOpacity(0.30)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        // Icon area
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: noiseAcc.withOpacity(0.12),
          ),
          child: Center(child: Text(
            sample != null ? sample.level.emoji : '🎙',
            style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('环境声单次分析', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: Color(tc.tx))),
          const SizedBox(height: 3),
          if (sample != null) ...[
            Text('${sample.dbLevel.round()} dB — ${sample.level.label}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(sample.level.colorHex))),
            Text(_noiseAssessment(sample.dbLevel, sample.level),
                style: TextStyle(fontSize: 10, color: Color(tc.ts), height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ] else
            Text('点击开始测量（麦克风录音约 2 秒）',
                style: TextStyle(fontSize: 11, color: Color(tc.ts))),
        ])),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: measuring ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: measuring ? Color(tc.brd) : noiseAcc,
              borderRadius: BorderRadius.circular(12),
              boxShadow: measuring ? [] : [BoxShadow(
                  color: noiseAcc.withOpacity(0.35),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: measuring
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: Colors.white))
              : const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 环境声历史展示区（番茄钟抽样汇总）
// ─────────────────────────────────────────────────────────────────────────────
class _NoiseHistorySection extends StatelessWidget {
  final ThemeConfig tc;
  final List<SessionNoiseReport> sessions;
  final double overallScore;  // 0-1
  final List<double>? hourlyScores;  // 24 items, 0=no data
  const _NoiseHistorySection({required this.tc, required this.sessions,
      required this.overallScore, this.hourlyScores});

  @override
  Widget build(BuildContext context) {
    const noiseAcc = Color(0xFF3a90c0);

    // Level distribution
    final levelCount = <NoiseLevel, int>{};
    for (final s in sessions) levelCount[s.dominantLevel] = (levelCount[s.dominantLevel] ?? 0) + 1;
    final sortedLevels = NoiseLevel.values.where((l) => (levelCount[l] ?? 0) > 0).toList();

    // Recent samples from last 5 sessions
    final recentSessions = sessions.length > 5
        ? sessions.sublist(sessions.length - 5)
        : sessions;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Overview row
      Row(children: [
        // Score ring
        SizedBox(width: 56, height: 56, child: CustomPaint(
          painter: _ScoreArc(value: overallScore,
              color: overallScore >= 0.7 ? const Color(0xFF4A9068)
                  : overallScore >= 0.5 ? noiseAcc
                  : const Color(0xFFe8982a),
              track: Color(tc.brd)),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(overallScore * 100).round()}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                    color: overallScore >= 0.7 ? const Color(0xFF4A9068) : noiseAcc,
                    height: 1.0)),
            Text('分', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
          ])),
        )),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${sessions.length} 次测量', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(tc.tx))),
          const SizedBox(height: 4),
          // Level distribution mini-bar
          Row(children: sortedLevels.map((l) {
            final frac = (levelCount[l] ?? 0) / sessions.length;
            return Expanded(
              flex: ((levelCount[l] ?? 0) * 100).round().clamp(1, 100),
              child: Container(
                height: 8,
                margin: const EdgeInsets.only(right: 1.5),
                decoration: BoxDecoration(
                  color: Color(l.colorHex).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4)),
              ),
            );
          }).toList()),
          const SizedBox(height: 4),
          // Legend
          Row(children: sortedLevels.take(3).map((l) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: Color(l.colorHex), shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Text('${l.label} ${levelCount[l]}次',
                  style: TextStyle(fontSize: 8.5, color: Color(tc.ts))),
            ]),
          )).toList()),
        ])),
      ]),

      // Hourly noise quality bar (if data available)
      if (hourlyScores != null && hourlyScores!.any((s) => s > 0)) ...[
        const SizedBox(height: 12),
        Text('各时段噪音质量（绿=安静，红=嘈杂）',
            style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
        const SizedBox(height: 6),
        SizedBox(height: 20, child: Row(
          children: List.generate(24, (h) {
            final score = hourlyScores![h];
            final hasData = score > 0;
            Color barColor;
            if (!hasData) barColor = Color(tc.brd).withOpacity(0.3);
            else if (score >= 0.8) barColor = const Color(0xFF4A9068).withOpacity(0.80);
            else if (score >= 0.6) barColor = noiseAcc.withOpacity(0.70);
            else if (score >= 0.4) barColor = const Color(0xFFe8c84a).withOpacity(0.75);
            else barColor = const Color(0xFFc04040).withOpacity(0.70);
            return Expanded(child: Container(
              height: hasData ? 16 : 4,
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ));
          }),
        )),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['0','6','12','18','23'].map((h) =>
              Text(h, style: TextStyle(fontSize: 7, color: Color(tc.tm)))).toList()),
        ),
      ],

      // Recent sessions list
      if (recentSessions.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('最近 ${recentSessions.length} 次测量',
            style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
        const SizedBox(height: 6),
        ...recentSessions.reversed.take(5).map((s) {
          final t = s.sessionStart;
          final timeStr = '${t.month}/${t.day} ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(s.dominantLevel.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.assessment, style: TextStyle(
                    fontSize: 10, color: Color(tc.tx)), maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(timeStr, style: TextStyle(fontSize: 9, color: Color(tc.tm))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Color(s.dominantLevel.colorHex).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('${s.avgDb.round()} dB',
                    style: TextStyle(fontSize: 9,
                        color: Color(s.dominantLevel.colorHex),
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }),
      ],
    ]);
  }
}

// Simple arc painter for noise score
class _ScoreArc extends CustomPainter {
  final double value;
  final Color color, track;
  const _ScoreArc({required this.value, required this.color, required this.track});
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width/2; final cy = s.height/2;
    final r = (s.shortestSide - 5) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const sw = 5.0;
    c.drawArc(rect, -3.14/2, 3.14*2, false,
        Paint()..color=track..style=PaintingStyle.stroke..strokeWidth=sw..strokeCap=StrokeCap.round);
    if (value > 0)
      c.drawArc(rect, -3.14/2, 3.14*2*value.clamp(0,1), false,
          Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=sw..strokeCap=StrokeCap.round);
  }
  @override bool shouldRepaint(_ScoreArc o) => o.value != value;
}

class _DS extends StatelessWidget {
  final ThemeConfig tc;
  final Color accent;
  final Widget child;
  const _DS({required this.tc, required this.accent, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Color(tc.card),
      borderRadius: BorderRadius.circular(14),
      border: Border(left: BorderSide(color: accent.withOpacity(0.5), width: 3)),
      boxShadow: [BoxShadow(color: Color(0x07000000), blurRadius: 6)]),
    child: child);
}

class _DSStat extends StatelessWidget {
  final String val, label;
  final Color color;
  const _DSStat(this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
        color: color, height: 1.0)),
    Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
  ]));
}

class _DSLabel extends StatelessWidget {
  final String icon, label;
  final ThemeConfig tc;
  const _DSLabel(this.icon, this.label, this.tc);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 10.5, color: Color(tc.ts),
          fontWeight: FontWeight.w600)),
    ]));
}

// 24h heatmap grid
class _HourlyHeatmap extends StatelessWidget {
  final List<double> focusMins, interruptScore;
  final int bestHour;
  final ThemeConfig tc;
  final Color acc;
  const _HourlyHeatmap({required this.focusMins, required this.interruptScore,
      required this.bestHour, required this.tc, required this.acc});
  @override
  Widget build(BuildContext context) {
    final maxV = focusMins.reduce((a, b) => a > b ? a : b);
    return Column(children: [
      // Hour grid (12 per row)
      for (int row = 0; row < 2; row++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: List.generate(12, (col) {
            final h = row * 12 + col;
            final v = maxV > 0 ? focusMins[h] / maxV : 0.0;
            final isBest = h == bestHour;
            final label = h % 6 == 0 ? '${h}h' : '';
            return Expanded(child: Column(children: [
              Container(
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isBest
                      ? acc
                      : acc.withOpacity(0.08 + v * 0.7),
                  borderRadius: BorderRadius.circular(3),
                  border: isBest ? Border.all(color: acc, width: 1.5) : null),
              ),
              if (label.isNotEmpty)
                Text(label, style: TextStyle(fontSize: 7, color: Color(tc.tm))),
            ]));
          }))),
      const SizedBox(height: 4),
      Row(children: [
        Container(width: 12, height: 12,
          decoration: BoxDecoration(color: acc.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('少', style: TextStyle(fontSize: 9, color: Color(tc.tm))),
        const Spacer(),
        Container(width: 12, height: 12,
          decoration: BoxDecoration(color: acc,
              borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('最高效', style: TextStyle(fontSize: 9, color: Color(tc.tm))),
      ]),
    ]);
  }
}

// Weekly line chart (dual axis: focus hours + completion rate)
// ─────────────────────────────────────────────────────────────────────────────
// 心流指数趋势图 — 折线 + 四阶段色带背景 + 均值参考线
// ─────────────────────────────────────────────────────────────────────────────
class _FlowTrendChart extends StatelessWidget {
  final List<({String date, double flow})> trend;
  final double? avgFlow;
  final ThemeConfig tc;
  final Color acc;

  const _FlowTrendChart({
    required this.trend, required this.avgFlow,
    required this.tc, required this.acc,
  });

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();

    final avg     = avgFlow ?? 0.5;
    final avgPct  = (avg * 100).round();
    final phase   = avgPct >= 80 ? '深度心流' : avgPct >= 60 ? '专注状态'
                  : avgPct >= 35 ? '进入中' : '预热';
    final phaseColor = avgPct >= 80 ? const Color(0xFFFFB300)
                     : avgPct >= 60 ? acc
                     : avgPct >= 35 ? const Color(0xFF3a90c0)
                     : Color(tc.ts);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── 均值 badge ──────────────────────────────────────────────────────
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: phaseColor.withOpacity(0.13),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: phaseColor.withOpacity(0.35))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(avgPct >= 80 ? '🔥' : avgPct >= 60 ? '✨' : '💧',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text('$avgPct 分',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: phaseColor)),
            const SizedBox(width: 6),
            Text(phase,
              style: TextStyle(fontSize: 11, color: phaseColor.withOpacity(0.8))),
          ])),
        const SizedBox(width: 8),
        Text('近14天均值', style: TextStyle(fontSize: 10, color: Color(tc.ts))),
      ]),
      const SizedBox(height: 12),
      // ── 曲线图 ──────────────────────────────────────────────────────────
      SizedBox(
        height: 90,
        child: CustomPaint(
          painter: _FlowCurvePainter(
            trend: trend, avgFlow: avg, acc: acc,
            gridColor: Color(tc.brd),
            textColor: Color(tc.tm)),
          size: Size.infinite)),
      const SizedBox(height: 6),
      // ── 分段标注 ────────────────────────────────────────────────────────
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        for (final item in [
          (label: '深度心流', color: const Color(0xFFFFB300)),
          (label: '专注', color: acc),
          (label: '进入中', color: const Color(0xFF3a90c0)),
        ]) ...[
          Container(width: 8, height: 8,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.7),
              shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(item.label, style: TextStyle(fontSize: 9, color: Color(tc.ts))),
          const SizedBox(width: 10),
        ],
      ]),
    ]);
  }
}

class _FlowCurvePainter extends CustomPainter {
  final List<({String date, double flow})> trend;
  final double avgFlow;
  final Color acc, gridColor, textColor;

  const _FlowCurvePainter({
    required this.trend, required this.avgFlow,
    required this.acc, required this.gridColor, required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;
    final w = size.width, h = size.height;
    final padL = 12.0, padR = 12.0, padT = 6.0, padB = 16.0;
    final chartW = w - padL - padR;
    final chartH = h - padT - padB;

    // ── 四阶段色带背景 ────────────────────────────────────────────────────
    final bands = [
      (from: 0.80, to: 1.00, color: const Color(0xFFFFB300).withOpacity(0.08)),
      (from: 0.60, to: 0.80, color: acc.withOpacity(0.07)),
      (from: 0.35, to: 0.60, color: const Color(0xFF3a90c0).withOpacity(0.06)),
      (from: 0.00, to: 0.35, color: gridColor.withOpacity(0.08)),
    ];
    for (final band in bands) {
      final top    = padT + (1.0 - band.to)   * chartH;
      final bottom = padT + (1.0 - band.from) * chartH;
      canvas.drawRect(
        Rect.fromLTRB(padL, top, padL + chartW, bottom),
        Paint()..color = band.color);
    }

    // ── 参考线（0.35 / 0.60 / 0.80）─────────────────────────────────────
    for (final level in [0.35, 0.60, 0.80]) {
      final y = padT + (1.0 - level) * chartH;
      canvas.drawLine(
        Offset(padL, y), Offset(padL + chartW, y),
        Paint()..color = gridColor.withOpacity(0.4)..strokeWidth = 0.5
          ..style = PaintingStyle.stroke);
    }

    // ── 均值虚线 ──────────────────────────────────────────────────────────
    final avgY = padT + (1.0 - avgFlow) * chartH;
    final dashPaint = Paint()..color = acc.withOpacity(0.5)..strokeWidth = 1.0;
    double dx = padL;
    while (dx < padL + chartW) {
      canvas.drawLine(Offset(dx, avgY), Offset(dx + 5, avgY), dashPaint);
      dx += 9;
    }

    // ── 折线曲线 ──────────────────────────────────────────────────────────
    final n = trend.length;
    Offset _pt(int i) {
      final x = padL + (n == 1 ? chartW / 2 : i / (n - 1) * chartW);
      final y = padT + (1.0 - trend[i].flow) * chartH;
      return Offset(x, y);
    }

    // 填充区域
    final fillPath = Path();
    fillPath.moveTo(padL, padT + chartH);
    for (int i = 0; i < n; i++) {
      final pt = _pt(i);
      if (i == 0) fillPath.lineTo(pt.dx, pt.dy);
      else {
        final prev = _pt(i - 1);
        final cx = (prev.dx + pt.dx) / 2;
        fillPath.cubicTo(cx, prev.dy, cx, pt.dy, pt.dx, pt.dy);
      }
    }
    fillPath.lineTo(padL + chartW, padT + chartH);
    fillPath.close();
    canvas.drawPath(fillPath,
      Paint()..color = acc.withOpacity(0.10)..style = PaintingStyle.fill);

    // 主折线
    final linePaint = Paint()
      ..color = acc ..strokeWidth = 1.8 ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final linePath = Path();
    for (int i = 0; i < n; i++) {
      final pt = _pt(i);
      if (i == 0) { linePath.moveTo(pt.dx, pt.dy); continue; }
      final prev = _pt(i - 1);
      final cx = (prev.dx + pt.dx) / 2;
      linePath.cubicTo(cx, prev.dy, cx, pt.dy, pt.dx, pt.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // 数据点
    for (int i = 0; i < n; i++) {
      final pt  = _pt(i);
      final flow = trend[i].flow;
      final dotColor = flow >= 0.80 ? const Color(0xFFFFB300)
                     : flow >= 0.60 ? acc
                     : flow >= 0.35 ? const Color(0xFF3a90c0)
                     : gridColor;
      canvas.drawCircle(pt, 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 2.5, Paint()..color = dotColor);
    }

    // X轴日期标签（首 / 末 / 中间）
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final labelIdxs = n <= 2 ? List.generate(n, (i) => i)
        : [0, n ~/ 2, n - 1];
    for (final i in labelIdxs) {
      final dateStr = trend[i].date;
      final label = dateStr.length >= 10
          ? '${int.tryParse(dateStr.substring(5,7)) ?? 0}/${int.tryParse(dateStr.substring(8,10)) ?? 0}'
          : dateStr;
      tp.text = TextSpan(text: label, style: TextStyle(
          fontSize: 8, color: textColor));
      tp.layout();
      final pt = _pt(i);
      tp.paint(canvas, Offset(pt.dx - tp.width / 2,
          padT + chartH + 3));
    }
  }

  @override
  bool shouldRepaint(_FlowCurvePainter o) =>
      o.trend != trend || o.avgFlow != avgFlow;
}

class _WeeklyLineChart extends StatelessWidget {
  final List<double> focusH, compRate;
  final ThemeConfig tc;
  final Color acc;
  const _WeeklyLineChart({required this.focusH, required this.compRate,
      required this.tc, required this.acc});
  @override
  Widget build(BuildContext context) {
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    final maxH = focusH.reduce((a, b) => a > b ? a : b).clamp(0.1, 24.0);
    return SizedBox(height: 80, child: CustomPaint(
      painter: _LineChartPainter(
        focusH: focusH, compRate: compRate, maxH: maxH,
        lineColor: acc, rateColor: const Color(0xFF3a90c0),
        gridColor: Color(tc.brd)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) => Text(weekDays[i],
          style: TextStyle(fontSize: 8, color: Color(tc.tm)))))));
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> focusH, compRate;
  final double maxH;
  final Color lineColor, rateColor, gridColor;
  const _LineChartPainter({required this.focusH, required this.compRate,
      required this.maxH, required this.lineColor, required this.rateColor,
      required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height - 16;
    final stepX = w / (focusH.length - 1);

    // Grid lines
    for (int i = 0; i <= 3; i++) {
      final y = h - (i / 3) * h;
      canvas.drawLine(Offset(0, y), Offset(w, y),
          Paint()..color = gridColor.withOpacity(0.3)..strokeWidth = 0.5);
    }

    // Focus hours line
    final focusPath = Path();
    for (int i = 0; i < focusH.length; i++) {
      final x = i * stepX;
      final y = h - (focusH[i] / maxH).clamp(0.0, 1.0) * h;
      i == 0 ? focusPath.moveTo(x, y) : focusPath.lineTo(x, y);
    }
    canvas.drawPath(focusPath, Paint()
      ..color = lineColor..strokeWidth = 2..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Completion rate line
    final ratePath = Path();
    for (int i = 0; i < compRate.length; i++) {
      final x = i * stepX;
      final y = h - compRate[i].clamp(0.0, 1.0) * h;
      i == 0 ? ratePath.moveTo(x, y) : ratePath.lineTo(x, y);
    }
    canvas.drawPath(ratePath, Paint()
      ..color = rateColor..strokeWidth = 1.5..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Dots
    for (int i = 0; i < focusH.length; i++) {
      final x = i * stepX;
      canvas.drawCircle(Offset(x, h - (focusH[i] / maxH).clamp(0.0, 1.0) * h),
          3.5, Paint()..color = lineColor);
    }
  }

  @override bool shouldRepaint(_LineChartPainter o) => false;
}

// Duration histogram
class _DurationHistogram extends StatelessWidget {
  final List<int> buckets;
  final int suggestedBucket;
  final ThemeConfig tc;
  final Color acc;
  const _DurationHistogram({required this.buckets, required this.suggestedBucket,
      required this.tc, required this.acc});
  @override
  Widget build(BuildContext context) {
    final maxV = buckets.reduce((a, b) => a > b ? a : b);
    if (maxV == 0) return Text('暂无数据', style: TextStyle(
        fontSize: 11, color: Color(tc.tm)));
    return Column(children: [
      SizedBox(height: 56, child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(buckets.length, (i) {
          final v = buckets[i];
          final frac = v / maxV;
          final isSuggested = i == suggestedBucket.clamp(0, 11);
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, children: [
              if (v > 0) Text('$v', style: TextStyle(
                  fontSize: 7, color: isSuggested ? acc : Color(tc.ts))),
              Container(
                height: (frac * 44).clamp(4.0, 44.0),
                decoration: BoxDecoration(
                  color: isSuggested ? acc : acc.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2))),
            ])));
        }))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ['0', '15', '30', '45', '60+'].map((l) =>
          Text(l, style: TextStyle(fontSize: 8, color: Color(tc.tm)))).toList()),
      const SizedBox(height: 2),
      Text('分钟', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
    ]);
  }
}

// Interrupt bar chart
class _InterruptBar extends StatelessWidget {
  final List<double> interruptScore;
  final ThemeConfig tc;
  const _InterruptBar({required this.interruptScore, required this.tc});
  @override
  Widget build(BuildContext context) {
    final maxV = interruptScore.reduce((a, b) => a > b ? a : b);
    const intColor = Color(0xFFe8982a);
    if (maxV == 0) return Text('暂无数据',
        style: TextStyle(fontSize: 11, color: Color(tc.tm)));
    return Column(children: [
      SizedBox(height: 32, child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (h) {
          final v = maxV > 0 ? interruptScore[h] / maxV : 0.0;
          return Expanded(child: Container(
            height: (v * 28).clamp(2.0, 28.0),
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: intColor.withOpacity(0.2 + v * 0.7),
              borderRadius: BorderRadius.circular(1.5)),
          ));
        }))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ['0h', '6h', '12h', '18h', '23h'].map((l) =>
          Text(l, style: TextStyle(fontSize: 8, color: Color(tc.tm)))).toList()),
    ]);
  }
}

// Helper: noise assessment text (mirrors EnvironmentSoundService._buildAssessment)
String _noiseAssessment(double db, NoiseLevel level) {
  switch (level) {
    case NoiseLevel.silent:   return '极安静 ${db.round()}dB — 图书馆级，专注效果极佳 🤫';
    case NoiseLevel.quiet:    return '安静 ${db.round()}dB — 适合深度专注 ✅';
    case NoiseLevel.moderate: return '适中 ${db.round()}dB — 轻微背景音，基本不影响专注 💡';
    case NoiseLevel.loud:     return '嘈杂 ${db.round()}dB — 建议使用耳机或换安静环境 🔈';
    case NoiseLevel.veryLoud: return '非常嘈杂 ${db.round()}dB — 强烈建议换一个安静环境 🔇';
  }
}

class _SuggestionRow extends StatelessWidget {
  final String icon, title, sub;
  final ThemeConfig tc;
  const _SuggestionRow(this.icon, this.title, this.sub, this.tc);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Color(tc.tx))),
        Text(sub, style: TextStyle(fontSize: 10, color: Color(tc.ts),
            height: 1.3)),
      ])),
    ]));
}
