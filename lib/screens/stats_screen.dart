// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/calendar_widgets.dart';
import '../widgets/task_tile.dart';
import '../widgets/deviation_chart.dart';
import '../l10n/l10n.dart';

enum CalView { day, week, month, year }
enum TagSort { byRank, byAlpha }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late Map<UIField, String> _ui;
  CalView _calView = CalView.week; // will be overridden in initState
  String _anchor = '';
  String _selected = '';
  bool _calDone = true;
  List<String> _calSelTags = [];
  final Set<String> _expandedTimeTags = {};
  bool _showTimeStat = false; // false=count, true=time
  TagSort _tagSort = TagSort.byRank;
  late AnimationController _toggleAnim;
  CalView? _prevCalView; // for slide direction

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _anchor = state.todayKey; _selected = _anchor; _calDone = true;
    // Use user's preferred default view
    const viewMap = {'day': CalView.day, 'week': CalView.week, 'month': CalView.month, 'year': CalView.year};
    _calView = viewMap[state.settings.defaultCalView] ?? CalView.week;
    
    // 初始化 UI 展示协议数据
    _refreshUI();

    _toggleAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _toggleAnim.forward();
  }

  void _refreshUI() {
    _ui = DisplayAdapter.getDisplayData(StatsPageState(_calView.name));
  }

  @override
  void dispose() { _toggleAnim.dispose(); super.dispose(); }

  List<String> _periodDays(AppState state) {
    switch (_calView) {
      case CalView.day: return [_anchor];
      case CalView.week: return DateUtils2.weekDays(_anchor);
      case CalView.month: return DateUtils2.monthDays(_anchor);
      case CalView.year: return DateUtils2.yearDays(_anchor);
    }
  }

  void _navP(int dir) {
    final d = DateUtils2.parse(_anchor);
    DateTime next;
    switch (_calView) {
      case CalView.day: next = d.add(Duration(days: dir)); break;
      case CalView.week: next = d.add(Duration(days: dir * 7)); break;
      case CalView.month: next = DateTime(d.year, d.month + dir, 1); break;
      case CalView.year: next = DateTime(d.year + dir, 1, 1); break;
    }
    setState(() { 
      _anchor = DateUtils2.fmt(next); 
      if (_calView == CalView.day) _selected = _anchor;
      _refreshUI();
    });
  }

  String _mainLabel(AppState state) {
    final d = DateUtils2.parse(_anchor);
    switch (_calView) {
      case CalView.day: return L.statsDateFormat(d.year, d.month, d.day);
      case CalView.week: return L.statsWeekFormat(d.year, DateUtils2.weekOfYear(_anchor));
      case CalView.month: return L.statsMonthFormat(d.year, d.month);
      case CalView.year: return L.statsYearFormat(d.year);
    }
  }

  String _subLabel(AppState state) {
    final sem = state.getSemInfo(_anchor);
    switch (_calView) {
      case CalView.day:
        String s = L.statsDayOfYear(DateUtils2.dayOfYear(_anchor), DateUtils2.weekOfYear(_anchor));
        if (sem != null) s += ' · ${L.semesterNum(sem.num.toString())} ${sem.week}${L.week}';
        return s;
      case CalView.week:
        final wd = DateUtils2.weekDays(_anchor);
        String s = '${DateUtils2.fmtShort(wd.first)} — ${DateUtils2.fmtShort(wd.last)}';
        if (sem != null) s += ' · ${L.semesterNum(sem.num.toString())} ${sem.week}${L.week}';
        return s;
      case CalView.month: return sem != null ? '${L.semesterNum(sem.num.toString())} ${sem.week}${L.week}' : '';
      case CalView.year: return '';
    }
  }

  List<String> _sortedTags(AppState state, List<String> days) {
    final filtered = state.tags.where((t) => state.tagCountsInStats(t)).toList();
    if (_tagSort == TagSort.byAlpha) {
      filtered.sort((a, b) => a.compareTo(b));
    } else {
      filtered.sort((a, b) => state.tagTotalDone(b).compareTo(state.tagTotalDone(a)));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final days = _periodDays(state);
    final today = state.todayKey;
    final pLbl = [_ui[UIField.statsToday]!, _ui[UIField.statsWeek]!, _ui[UIField.statsMonth]!, _ui[UIField.statsYear]!][_calView.index];

    final doneCount = days.fold(0, (s, d) => s + state.doneOnDay(d));
    final newCount = days.where((d) => state.tasks.any((t) => t.createdAt == d)).length;
    final actSet = <String>{};
    for (final t in state.tasks) { if (t.done && days.contains(t.doneAt)) actSet.addAll(t.tags); }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v.abs() < 200) return; // 过滤慢速误触
          HapticFeedback.selectionClick();
          setState(() {
            _prevCalView = _calView;
            if (v < 0) {
              // 向左滑 → 下一个视图（日→周→月→年）
              final next = (_calView.index + 1).clamp(0, CalView.values.length - 1);
              _calView = CalView.values[next];
            } else {
              // 向右滑 → 上一个视图
              final prev = (_calView.index - 1).clamp(0, CalView.values.length - 1);
              _calView = CalView.values[prev];
            }
            if (_calView == CalView.day) _selected = _anchor;
            _refreshUI();
          });
        },
        child: ListView(
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 24),
        children: [
          _buildCalTabs(state, tc),
          const SizedBox(height: 8),
          _buildNavRow(state, tc),
          const SizedBox(height: 6),
          const CalColorLegend(),
          _buildAnimatedCalBody(state, tc, today),
          const SizedBox(height: 10),
          _buildStatCards(state, tc, doneCount, newCount, actSet.length, pLbl),
          const SizedBox(height: 10),
          if (_calView != CalView.year) _buildVitality(state, tc, days, pLbl),
          if (state.tags.isNotEmpty) ...[
            _buildTagTable(state, tc, days, pLbl),
            const SizedBox(height: 10),
            _buildBarChart(state, tc),
            const SizedBox(height: 10),
            if (state.settings.pom.trackTime) _buildTimeStats(state, tc, days, pLbl),
            const SizedBox(height: 10),
            _buildPomStats(state, tc, days, pLbl),
            const SizedBox(height: 10),
            // 任务完成时间分布曲线
            _buildCompletionTimeline(state, tc, days, pLbl),
          ],
          // 偏差分析：缩略图可点击进入详情页
          if (_calView == CalView.week || _calView == CalView.month) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => DeviationDetailPage(days: days, state: state, tc: tc),
              )),
              child: DeviationChartThumb(days: days, state: state),
            ),
          ],
          // 日历视图：显示当日任务列表 + 添加功能
          if (_calView == CalView.day) _buildDayDetail(state, tc, today),
        ],
      ),
      ), // GestureDetector
    );
  }

  // 日历区域带滑动动画切换
  Widget _buildAnimatedCalBody(AppState state, ThemeConfig tc, String today) {
    final prev = _prevCalView;
    final goRight = prev == null || _calView.index > prev.index;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInQuart,
        transitionBuilder: (child, anim) {
          // 新内容从侧边滑入，旧内容同时向反方向淡出缩小
          final isIncoming = child.key == ValueKey(_calView);
          if (isIncoming) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(goRight ? 0.55 : -0.55, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuart)),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: const Interval(0.0, 0.6))),
                child: child,
              ),
            );
          } else {
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: Offset(goRight ? -0.3 : 0.3, 0),
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeInQuart)),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                    CurvedAnimation(parent: anim, curve: const Interval(0.0, 0.5))),
                child: child,
              ),
            );
          }
        },
        child: KeyedSubtree(
          key: ValueKey(_calView),
          child: _buildCalBody(state, tc, today),
        ),
      ),
    );
  }

  Widget _buildCalTabs(AppState state, ThemeConfig tc) {
    final labels = [_ui[UIField.calendarTab]!, _ui[UIField.weekCalTab]!, _ui[UIField.monthCalTab]!, _ui[UIField.yearCalTab]!];
    return Container(
      decoration: BoxDecoration(color: Color(tc.brd), borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(2),
      child: Row(children: List.generate(4, (i) {
        final active = _calView.index == i;
        return Expanded(child: GestureDetector(
          onTap: () {
            if (_calView.index == i) return;
            HapticFeedback.selectionClick();
            setState(() {
              _prevCalView = _calView;
              _calView = CalView.values[i];
              if (_calView == CalView.day) _selected = _anchor;
              _refreshUI();
            });
          },
          child: AnimatedContainer(duration: const Duration(milliseconds: 220), curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: active ? state.cardColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: active ? [BoxShadow(color: Color(0x18000000), blurRadius: 4, offset: Offset(0,1))] : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 12,
                color: active ? Color(tc.tx) : Color(tc.ts),
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                fontFamily: 'sans-serif',
              ),
              child: Text(labels[i], textAlign: TextAlign.center),
            ),
          ),
        ));
      })),
    );
  }

  Widget _buildNavRow(AppState state, ThemeConfig tc) {
    final sub = _subLabel(state);
    return Row(children: [
      IconButton(onPressed: () => _navP(-1), icon: const Icon(Icons.chevron_left), color: Color(tc.ts)),
      Expanded(child: Column(children: [
        Text(_mainLabel(state), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(tc.tx))),
        if (sub.isNotEmpty) ...[const SizedBox(height: 2), Text(sub, style: TextStyle(fontSize: 10, color: Color(tc.ts)), textAlign: TextAlign.center)],
      ])),
      IconButton(onPressed: () => _navP(1), icon: const Icon(Icons.chevron_right), color: Color(tc.ts)),
    ]);
  }

  Widget _buildCalBody(AppState state, ThemeConfig tc, String today) {
    switch (_calView) {
      case CalView.day: return DayViewBadges(dateStr: _anchor, state: state);
      case CalView.week: return WeekCalGrid(anchor: _anchor, selected: _selected, state: state, onSelect: (d) => setState(() => _selected = d));
      case CalView.month: return MonthCalGrid(anchor: _anchor, selected: _selected, state: state, onSelect: (d) => setState(() => _selected = d));
      case CalView.year: return YearCalGrid(anchor: _anchor, state: state, onDayTap: (d) { setState(() { _selected = d; _anchor = d; _calView = CalView.day; _refreshUI(); }); });
    }
  }

  Widget _buildStatCards(AppState state, ThemeConfig tc, int done, int newC, int tags, String pLbl) {
    return Row(children: [
      _statCard(state, tc, '$done', L.statsPeriodDone(pLbl)),
      const SizedBox(width: 8),
      _statCard(state, tc, '$newC', L.statsPeriodNew(pLbl)),
      const SizedBox(width: 8),
      _statCard(state, tc, '$tags', _ui[UIField.statsNewActiveTags] ?? L.statsActiveTags),
    ]);
  }

  Widget _statCard(AppState state, ThemeConfig tc, String val, String lbl) => Expanded(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 400), curve: Curves.easeOut,
    builder: (_, v, child) => Transform.scale(scale: 0.92 + 0.08 * v, child: Opacity(opacity: v, child: child)),
    child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(children: [Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(tc.tx))), const SizedBox(height: 4), Text(lbl, style: TextStyle(fontSize: 9.5, color: Color(tc.ts)))]))));

  Widget _buildVitality(AppState state, ThemeConfig tc, List<String> days, String pLbl) {
    final vit = state.vitalityData(days);
    final total = (vit['morning']??0) + (vit['afternoon']??0) + (vit['evening']??0);
    if (total == 0) return const SizedBox.shrink();
    final mx = [vit['morning']!, vit['afternoon']!, vit['evening']!].reduce((a, b) => a > b ? a : b);
    final blocks = [
      {'k': 'morning',   'n': L.morning, 'c': Color(0xFFe8982a)},
      {'k': 'afternoon', 'n': L.afternoon, 'c': Color(0xFF3a90c0)},
      {'k': 'evening',   'n': L.evening, 'c': Color(0xFF7a5ab8)},
    ];
    final bestKey = vit.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final daySet = days.toSet();

    // Completion rate per block: done tasks / all tasks in that block during period
    Map<String, String> compRate(String blk) {
      final allInBlk = state.tasks.where((t) =>
          t.timeBlock == blk && daySet.contains(t.createdAt)).length;
      final doneInBlk = state.tasks.where((t) =>
          t.timeBlock == blk && t.done && t.doneAt != null && daySet.contains(t.doneAt)).length;
      if (allInBlk == 0) return {'rate': '—', 'raw': '0'};
      final pct = (doneInBlk / allInBlk * 100).round();
      return {'rate': '$pct%', 'raw': '$pct'};
    }

    // Worst block = lowest completion rate (with data)
    String? worstBlk;
    int worstRate = 101;
    for (final b in ['morning', 'afternoon', 'evening']) {
      final r = compRate(b);
      final pct = int.tryParse(r['raw']!);
      if (pct != null && pct < worstRate) { worstRate = pct; worstBlk = b; }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_ui[UIField.vitalityAnalysis]!, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
        const SizedBox(height: 12),
        SizedBox(height: 80, child: Row(crossAxisAlignment: CrossAxisAlignment.end,
          children: blocks.map((b) {
            final k = b['k'] as String; final cnt = vit[k] ?? 0;
            final pct = mx > 0 ? cnt / mx : 0.0; final isBest = k == bestKey && cnt > 0;
            final col = b['c'] as Color;
            return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('$cnt', style: TextStyle(fontSize: 11, fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
                  color: cnt > 0 ? col : Color(tc.tm))),
              const SizedBox(height: 4),
              Flexible(child: FractionallySizedBox(
                heightFactor: pct > 0 ? pct.clamp(0.08, 1.0) : 0.04, widthFactor: 0.55,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct.clamp(0.08, 1.0)),
                  duration: const Duration(milliseconds: 600), curve: Curves.easeOut,
                  builder: (_, v, __) => FractionallySizedBox(heightFactor: v, widthFactor: 1,
                    child: Container(decoration: BoxDecoration(color: col,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))))))),
              const SizedBox(height: 6),
              Text('${b['n']}${isBest ? ' ⚡' : ''}',
                style: TextStyle(fontSize: 9.5, color: isBest ? col : Color(tc.ts),
                    fontWeight: isBest ? FontWeight.w600 : FontWeight.normal)),
            ]));
          }).toList())),
        const SizedBox(height: 10),
        // Completion rate per block
        Divider(color: Color(tc.brd), height: 1),
        const SizedBox(height: 8),
        Row(children: [
          Text(L.statsCompletionRateByBlock, style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
          const Spacer(),
          ...blocks.map((b) {
            final k = b['k'] as String; final col = b['c'] as Color;
            final r = compRate(k);
            final isWorst = k == worstBlk && r['rate'] != '—';
            return Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(children: [
                Text(r['rate']!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: isWorst ? const Color(0xFFc04040) : col)),
                Text(b['n'] as String,
                  style: TextStyle(fontSize: 8.5, color: isWorst ? const Color(0xFFc04040) : Color(tc.ts))),
              ]),
            );
          }),
        ]),
        if (worstBlk != null) ...[
          const SizedBox(height: 6),
          Text(
            L.statsInsightLowestRate(kBlocks[worstBlk]!['emoji']!, kBlocks[worstBlk]!['name']!),
            style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
        ],
        if (total > 0) ...[
          const SizedBox(height: 4),
          Text(L.statsInsightBestVitality(kBlocks[bestKey]!['name']!, vit[bestKey]!),
            style: TextStyle(fontSize: 10, color: Color(tc.ts))),
        ],
      ]));
  }

  Widget _buildTagTable(AppState state, ThemeConfig tc, List<String> days, String pLbl) {
    final sorted = _sortedTags(state, days);
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_ui[UIField.tagCompletion]!, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
          const Spacer(),
          // Count / Time toggle
          _TogglePill(left: L.statsByCount, right: L.statsByTime, isRight: _showTimeStat, tc: tc, onToggle: (v) => setState(() { _toggleAnim.reset(); _showTimeStat = v; _toggleAnim.forward(); })),
          const SizedBox(width: 8),
          // Sort toggle
          GestureDetector(
            onTap: () => setState(() => _tagSort = _tagSort == TagSort.byRank ? TagSort.byAlpha : TagSort.byRank),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(8)),
              child: Text(_tagSort == TagSort.byRank ? _ui[UIField.byRank]! : _ui[UIField.byAlpha]!, style: TextStyle(fontSize: 9.5, color: Color(tc.ts)))),
          ),
        ]),
        const SizedBox(height: 10),
        // Header
        Row(children: [
          const Expanded(flex: 3, child: SizedBox()),
          Expanded(child: Text(L.statsPeriod(pLbl), textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: Color(tc.ts)))),
          Expanded(child: Text(_ui[UIField.statsTotal]!, textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: Color(tc.ts)))),
          Expanded(flex: 2, child: Text(_showTimeStat ? _ui[UIField.focusRateLabel]! : _ui[UIField.completionRateLabel]!, textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: Color(tc.ts)))),
        ]),
        Divider(color: Color(tc.brd)),
        FadeTransition(
          opacity: CurvedAnimation(parent: _toggleAnim, curve: Curves.easeIn),
          child: Column(children: sorted.map((tag) {
            final c = state.tagColor(tag);
            final rate = state.tagCompletionRate(tag);
            String periodVal, totalVal;
            if (_showTimeStat) {
              periodVal = _fmtTime(state.tagFocusInPeriod(tag, days));
              totalVal = _fmtTime(state.tagFocusTime(tag));
            } else {
              periodVal = '${state.tagDoneInPeriod(tag, days)}';
              totalVal = '${state.tagTotalDone(tag)}';
            }
            return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
              Expanded(flex: 3, child: Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: c)), const SizedBox(width: 5), Flexible(child: Text(tag, style: TextStyle(fontSize: 12, color: c), overflow: TextOverflow.ellipsis))])),
              Expanded(child: Text(periodVal, textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(tc.tx)))),
              Expanded(child: Text(totalVal, textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: Color(tc.ts)))),
              Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(width: (rate * 0.35).clamp(2.0, 38.0), height: 3, decoration: BoxDecoration(color: c.withOpacity(0.55), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                SizedBox(width: 32, child: Text('$rate%', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: c))),
              ])),
            ]));
          }).toList()),
        ),
      ]));
  }

  Widget _buildBarChart(AppState state, ThemeConfig tc) {
    final sorted = state.tags.where((t) => state.tagCountsInStats(t) && state.tagTotalDone(t) > 0).toList()..sort((a, b) => state.tagTotalDone(b).compareTo(state.tagTotalDone(a)));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final mx = state.tagTotalDone(sorted.first);
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L.statsTotalCompletionRank, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
        const SizedBox(height: 10),
        ...sorted.asMap().entries.map((e) {
          final tag = e.value; final idx = e.key; final c = state.tagColor(tag); final cnt = state.tagTotalDone(tag); final pct = mx > 0 ? cnt / mx : 0.0;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
            SizedBox(width: 16, child: Text('${idx + 1}', style: TextStyle(fontSize: 9.5, color: Color(tc.tm)))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(tag, style: TextStyle(fontSize: 11, color: c))),
            const SizedBox(width: 8),
            Expanded(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: pct), duration: Duration(milliseconds: 400 + idx * 60), curve: Curves.easeOut,
              builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: v, backgroundColor: Color(tc.brd), color: c, minHeight: 3)))),
            const SizedBox(width: 8),
            Text('$cnt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(tc.tx))),
          ]));
        }),
      ]));
  }

  Widget _buildTimeStats(AppState state, ThemeConfig tc,
      List<String> days, String pLbl) {
    final tagsSorted = state.tags.where((t) => state.tagCountsInStats(t) && state.tagFocusTime(t) > 0).toList()..sort((a, b) => state.tagFocusTime(b).compareTo(state.tagFocusTime(a)));
    if (tagsSorted.isEmpty) return const SizedBox.shrink();
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(L.statsFocusTimeStats, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FocusDetailPage(days: days, state: state, tc: tc, pLbl: pLbl))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Color(tc.acc).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(L.statsDetails, style: TextStyle(fontSize: 9.5, color: Color(tc.acc))),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 13, color: Color(tc.acc)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ...tagsSorted.map((tag) {
          final c = state.tagColor(tag); final ft = state.tagFocusTime(tag); final expanded = _expandedTimeTags.contains(tag);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(onTap: () => setState(() { if (expanded) _expandedTimeTags.remove(tag); else _expandedTimeTags.add(tag); }),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                const SizedBox(width: 5), Text(tag, style: TextStyle(fontSize: 13, color: c)),
                const SizedBox(width: 4), Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: Color(tc.tm)),
                const Spacer(), Text('⏱ ${_fmtTime(ft)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(tc.acc))),
              ]))),
            AnimatedSize(duration: const Duration(milliseconds: 220), curve: Curves.easeInOutCubic,
              child: expanded ? Column(children: () { final ts = state.tasks.where((t) => t.tags.contains(tag) && t.focusSecs > 0).toList()..sort((a, b) => b.focusSecs.compareTo(a.focusSecs)); return ts.map((t) => Padding(padding: const EdgeInsets.fromLTRB(16, 3, 0, 3), child: Row(children: [Expanded(child: Text(t.text, style: TextStyle(fontSize: 11, color: Color(tc.ts)), overflow: TextOverflow.ellipsis, maxLines: 1)), const SizedBox(width: 8), Text(_fmtTime(t.focusSecs), style: TextStyle(fontSize: 11, color: Color(tc.acc)))]))).toList(); }()) : const SizedBox.shrink()),
            Divider(height: 1, color: Color(tc.brd)),
          ]);
        }),
      ]));
  }

  Widget _buildDayDetail(AppState state, ThemeConfig tc, String today) {
    final effectiveDate = _calView == CalView.day ? _anchor : _selected;
    if (effectiveDate.isEmpty) return const SizedBox.shrink();
    final dayTasks = state.tasks
        .where((t) => t.doneAt == effectiveDate || (t.createdAt == effectiveDate && !t.done))
        .toList();
    return Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateUtils2.fmtFull(effectiveDate), style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
        const SizedBox(height: 10),
        // Add task only in day calendar view
        if (_calView == CalView.day) ...[
          _buildCalAdd(state, tc, effectiveDate),
          const SizedBox(height: 8),
        ],
        if (dayTasks.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(L.statsNoTasksOnDate, style: TextStyle(fontSize: 12, color: Color(tc.tm)))))
        else ...dayTasks.map((t) => TaskTile(task: t)),
      ]));
  }

  Widget _buildCalAdd(AppState state, ThemeConfig tc, String dateStr) {
    final ctrl = TextEditingController();
    return StatefulBuilder(builder: (ctx, setSt) => Container(
      padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(11)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L.statsAddTaskOnDate, style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: ctrl, style: TextStyle(fontSize: 13, color: Color(tc.tx), fontFamily: 'serif'),
            decoration: InputDecoration(hintText: L.statsLogSomething, hintStyle: TextStyle(color: Color(tc.tm)), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true, filled: false),
            onSubmitted: (v) { if (v.trim().isEmpty) return; state.addTask(text: v.trim(), tags: List.from(_calSelTags), timeBlock: DateUtils2.getDefaultBlock(), forDate: dateStr, done: _calDone); ctrl.clear(); setSt(() {}); })),
          GestureDetector(onTap: () { if (ctrl.text.trim().isEmpty) return; state.addTask(text: ctrl.text.trim(), tags: List.from(_calSelTags), timeBlock: DateUtils2.getDefaultBlock(), forDate: dateStr, done: _calDone); ctrl.clear(); setSt(() {}); },
            child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(tc.na), shape: BoxShape.circle), child: Icon(Icons.add, color: Color(tc.nt), size: 20))),
        ]),
        const SizedBox(height: 7),
        Wrap(spacing: 4, runSpacing: 4, children: state.tags.map((tag) {
          final sel = _calSelTags.contains(tag); final c = state.tagColor(tag);
          return GestureDetector(onTap: () => setState(() { if (sel) _calSelTags.remove(tag); else _calSelTags.add(tag); }),
            child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sel ? c : state.cardColor, borderRadius: BorderRadius.circular(9)), child: Text(tag, style: TextStyle(fontSize: 10, color: sel ? Color(tc.nt) : Color(tc.ct)))));
        }).toList()),
        const SizedBox(height: 7),
        GestureDetector(onTap: () => setState(() => _calDone = !_calDone), child: Row(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 150), width: 14, height: 14, decoration: BoxDecoration(color: _calDone ? Color(tc.acc) : Colors.transparent, borderRadius: BorderRadius.circular(3), border: Border.all(color: _calDone ? Color(tc.acc) : Color(tc.tm), width: 1.5)), child: _calDone ? Icon(Icons.check, size: 9, color: Color(tc.nt)) : null),
          const SizedBox(width: 5), Text(L.statsMarkAsDone, style: TextStyle(fontSize: 11, color: Color(tc.ts))),
        ])),
      ])));
  }

  Widget _buildPomStats(AppState state, ThemeConfig tc, List<String> days, String pLbl) {
    if (!state.settings.showPomodoro) return const SizedBox.shrink();
    final daySet = days.toSet();

    // Task-bound focus in period
    final taskFocusSecs = state.tasks
        .where((t) => t.done && t.doneAt != null && daySet.contains(t.doneAt))
        .fold(0, (s, t) => s + t.focusSecs);
    // Unbound focus in period
    final unboundSecs = state.settings.unboundFocusByDate.entries
        .where((e) => daySet.contains(e.key))
        .fold(0, (s, e) => s + e.value);
    final totalFocusSecs = taskFocusSecs + unboundSecs;

    // All-time (task-bound + unbound)
    final allTimeTask = state.tasks.fold(0, (s, t) => s + t.focusSecs);
    final allTimeUnbound = state.settings.unboundFocusByDate.values
        .fold(0, (s, v) => s + v);
    final allTimeFocusSecs = allTimeTask + allTimeUnbound;

    if (allTimeFocusSecs == 0) return const SizedBox.shrink();

    final focusTasksDone = state.tasks.where((t) =>
        t.done && t.focusSecs > 0 && t.doneAt != null && daySet.contains(t.doneAt)).length;

    // Daily breakdown (task + unbound)
    final dailyFocus = <String, int>{};
    for (final day in days) {
      final tf = state.tasks
          .where((t) => t.doneAt == day)
          .fold(0, (s, t) => s + t.focusSecs);
      final ub = state.settings.unboundFocusByDate[day] ?? 0;
      dailyFocus[day] = tf + ub;
    }
    final maxDaily = dailyFocus.values.isEmpty ? 1
        : dailyFocus.values.reduce((a, b) => a > b ? a : b);
    if (maxDaily == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(L.statsPomodoroStats, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
          const Spacer(),
          Text(pLbl, style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _pomCard(tc, _fmtTime(totalFocusSecs), L.statsPeriodFocus(pLbl)),
          const SizedBox(width: 8),
          _pomCard(tc, '$focusTasksDone', L.statsFocusedTasks),
          const SizedBox(width: 8),
          _pomCard(tc, _fmtTime(allTimeFocusSecs), L.statsTotalFocus),
        ]),
        if (days.length > 1 && maxDaily > 0) ...[
          const SizedBox(height: 14),
          Text(L.statsDailyFocusDuration, style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.take(31).map((day) {
                final secs = dailyFocus[day] ?? 0;
                final frac = maxDaily > 0 ? secs / maxDaily : 0.0;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => FractionallySizedBox(
                      heightFactor: v.clamp(0.04, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(tc.acc).withOpacity(0.65 + 0.35 * v),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ));
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }

  // ─── 任务完成时间分布曲线（按小时统计）─────────────────────────────────────
  Widget _buildCompletionTimeline(AppState state, ThemeConfig tc,
      List<String> days, String pLbl) {
    final daySet = days.toSet();
    // 统计每小时完成数（0-23）
    final hourCount = List<int>.filled(24, 0);
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null) continue;
      if (!daySet.contains(t.doneAt)) continue;
      if (t.doneHour != null) hourCount[t.doneHour!]++;
    }
    final total = hourCount.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    final maxH = hourCount.reduce((a, b) => a > b ? a : b).clamp(1, 999);

    // 峰值小时
    final peakHour = hourCount.indexOf(maxH);
    final peakBlk = peakHour >= 5 && peakHour < 13 ? L.morning
        : peakHour >= 13 && peakHour < 18 ? L.afternoon : L.evening;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _CompletionTimelineDetailPage(
          days: days, state: state, tc: tc, pLbl: pLbl),
      )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: state.cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(L.statsCompletionTimeline, style: TextStyle(
                fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
            const Spacer(),
            Text(L.statsTotalItems(total), style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
          ]),
          const SizedBox(height: 4),
          Text(L.statsPeakTime(peakHour, peakBlk),
            style: TextStyle(fontSize: 9, color: Color(tc.tm))),
          const SizedBox(height: 10),
          // 24小时柱状分布
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final cnt = hourCount[h];
                final frac = cnt / maxH;
                // 颜色按时段
                final barColor = h >= 5 && h < 13
                    ? const Color(0xFFe8982a)
                    : h >= 13 && h < 18
                        ? const Color(0xFF3a90c0)
                        : const Color(0xFF7a5ab8);
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: Duration(milliseconds: 400 + h * 8),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (cnt > 0 && v > 0.5)
                          Text('$cnt', style: TextStyle(
                              fontSize: 6, color: barColor)),
                        FractionallySizedBox(
                          heightFactor: (v * 0.96 + 0.04).clamp(0.04, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor.withOpacity(cnt > 0 ? 0.75 : 0.12),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ));
              }),
            ),
          ),
          const SizedBox(height: 4),
          // X轴：只显示关键小时
          Row(children: [
            Text('0', style: TextStyle(fontSize: 7, color: Color(tc.tm))),
            const Spacer(),
            Text('6', style: TextStyle(fontSize: 7, color: Color(tc.tm))),
            const Spacer(),
            Text('12', style: TextStyle(fontSize: 7, color: Color(tc.tm))),
            const Spacer(),
            Text('18', style: TextStyle(fontSize: 7, color: Color(tc.tm))),
            const Spacer(),
            Text('23', style: TextStyle(fontSize: 7, color: Color(tc.tm))),
          ]),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(tc.acc).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(L.get('screens.stats.viewDetails'), style: TextStyle(fontSize: 9.5, color: Color(tc.acc))),
                const SizedBox(width: 3),
                Icon(Icons.chevron_right_rounded, size: 13, color: Color(tc.acc)),
              ]),
            )),
        ]),
      ),
    );
  }

  Widget _pomCard(ThemeConfig tc, String val, String lbl) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.acc))),
        const SizedBox(height: 3),
        Text(lbl, style: TextStyle(fontSize: 9, color: Color(tc.ts)), textAlign: TextAlign.center),
      ]),
    ));

  String _fmtTime(int sec) {
    if (sec <= 0) return '—';
    if (sec < 60) return L.get('time.second', {'count': sec});
    if (sec < 3600) return L.get('time.minute', {'count': sec ~/ 60});
    return L.get('time.hourMinute', {'hour': sec ~/ 3600, 'minute': sec % 3600 ~/ 60});
  }
}

// Small pill toggle widget
class _TogglePill extends StatelessWidget {
  final String left, right;
  final bool isRight;
  final ThemeConfig tc;
  final ValueChanged<bool> onToggle;
  const _TogglePill({required this.left, required this.right, required this.isRight, required this.tc, required this.onToggle});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onToggle(!isRight),
    child: Container(
      decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Pill(label: left, active: !isRight, tc: tc),
        _Pill(label: right, active: isRight, tc: tc),
      ]),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String label; final bool active; final ThemeConfig tc;
  const _Pill({required this.label, required this.active, required this.tc});
  @override
  Widget build(BuildContext context) => AnimatedContainer(duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: active ? Color(tc.na) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: TextStyle(fontSize: 9.5, color: active ? Color(tc.nt) : Color(tc.ts), fontWeight: active ? FontWeight.w600 : FontWeight.normal)));
}

// ─────────────────────────────────────────────────────────────────────────────
// 预估偏差缩略图（替代原折线，可点击进详情）
// ─────────────────────────────────────────────────────────────────────────────
class DeviationChartThumb extends StatelessWidget {
  final List<String> days;
  final AppState state;
  const DeviationChartThumb({super.key, required this.days, required this.state});

  @override
  Widget build(BuildContext context) {
    final tc = state.themeConfig;
    // 复用 DeviationChart 但加上点击提示角标
    return Stack(
      children: [
        DeviationChart(days: days, state: state, title: L.get('screens.stats.deviationAnalysis')),
        Positioned(
          right: 14, bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(tc.acc).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(L.get('screens.stats.viewDetails'), style: TextStyle(fontSize: 9.5, color: Color(tc.acc))),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, size: 13, color: Color(tc.acc)),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 预估偏差详情页
// ─────────────────────────────────────────────────────────────────────────────
class DeviationDetailPage extends StatelessWidget {
  final List<String> days;
  final AppState state;
  final ThemeConfig tc;
  const DeviationDetailPage({super.key, required this.days, required this.state, required this.tc});

  @override
  Widget build(BuildContext context) {
    // 计算所有任务偏差原始数据
    final taskData = <_DevEntry>[];
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null) continue;
      if (t.originalTimeBlock == 'unassigned') continue;
      if (!days.contains(t.doneAt) && !days.contains(t.originalDate)) continue;

      final plannedSlot = _absSlotDetail(t.originalDate, t.originalTimeBlock);
      String actualBlk;
      if (t.doneTimeBlock != null) {
        actualBlk = t.doneTimeBlock!;
      } else if (t.doneHour != null) {
        actualBlk = AppState.hourToTimeBlock(t.doneHour!, 0);
      } else {
        continue;
      }
      final actualSlot = _absSlotDetail(t.doneAt!, actualBlk);
      final dev = (actualSlot - plannedSlot).toDouble();
      taskData.add(_DevEntry(task: t, dev: dev, actualBlk: actualBlk));
    }
    taskData.sort((a, b) => b.dev.compareTo(a.dev));

    final onTime   = taskData.where((e) => e.dev.abs() < 0.5).length;
    final late     = taskData.where((e) => e.dev >= 0.5).length;
    final early    = taskData.where((e) => e.dev <= -0.5).length;
    final avgDev   = taskData.isEmpty ? 0.0
        : taskData.map((e) => e.dev).reduce((a, b) => a + b) / taskData.length;
    final maxLate  = taskData.isEmpty ? 0.0 : taskData.map((e) => e.dev).reduce((a, b) => a > b ? a : b);
    final maxEarly = taskData.isEmpty ? 0.0 : taskData.map((e) => e.dev).reduce((a, b) => a < b ? a : b);

    String fmtDev(double v) {
      final s = v.abs().round();
      final d = s ~/ 3; final r = s % 3;
      final bn = [L.get('screens.stats.morning'),L.get('screens.stats.afternoon'),L.get('screens.stats.evening')][r.clamp(0, 2)];
      if (s == 0) return L.get('screens.stats.onTime');
      return '${v > 0 ? '+' : '-'}${d > 0 ? L.get('time.day', {'count': d}) : ''}${r > 0 ? bn : ''}';
    }

    // 按偏差分桶（-6~+6时段）
    final buckets = <int, int>{};
    for (final e in taskData) {
      final b = e.dev.round().clamp(-6, 6);
      buckets[b] = (buckets[b] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: Color(tc.bg),
      appBar: AppBar(
        backgroundColor: Color(tc.bg), elevation: 0,
        title: Text(L.get('screens.stats.deviationDetails'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          // 完整折线图（大图）
          DeviationChart(days: days, state: state, title: L.get('screens.stats.deviationTrend')),
          const SizedBox(height: 14),

          // 汇总指标卡
          _sectionLabel(L.get('screens.stats.summaryMetrics'), tc),
          const SizedBox(height: 6),
          Row(children: [
            _metricCard(L.get('screens.stats.onTime'), L.get('screens.stats.itemCount', {'count': onTime}), const Color(0xFF4A9068), tc),
            const SizedBox(width: 8),
            _metricCard(L.get('screens.stats.delayed'), L.get('screens.stats.itemCount', {'count': late}), const Color(0xFFE07040), tc),
            const SizedBox(width: 8),
            _metricCard(L.get('screens.stats.ahead'), L.get('screens.stats.itemCount', {'count': early}), const Color(0xFF5060D0), tc),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _metricCard(L.get('screens.stats.avgDeviation'), fmtDev(avgDev), avgDev.abs() < 0.5 ? const Color(0xFF4A9068) : const Color(0xFFE07040), tc),
            const SizedBox(width: 8),
            _metricCard(L.get('screens.stats.maxDelay'), fmtDev(maxLate), const Color(0xFFE07040), tc),
            const SizedBox(width: 8),
            _metricCard(L.get('screens.stats.maxAhead'), fmtDev(maxEarly), const Color(0xFF5060D0), tc),
          ]),
          const SizedBox(height: 14),

          // 偏差分布柱状图
          _sectionLabel(L.get('screens.stats.deviationDistribution'), tc),
          const SizedBox(height: 8),
          _buildBucketBar(buckets, taskData.length, tc),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(L.get('screens.stats.ahead6'), style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
              Text(L.get('screens.stats.onTime0'), style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
              Text(L.get('screens.stats.delayed6'), style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
            ]),
          ),
          const SizedBox(height: 14),

          // 各时段完成率
          _sectionLabel(L.get('screens.stats.blockPlanVsActual'), tc),
          const SizedBox(height: 8),
          _buildBlockBreakdown(taskData, tc),
          const SizedBox(height: 14),

          // ── 新增：按日期分组偏差明细 ────────────────────────────────────
          _sectionLabel(L.get('screens.stats.dailyDeviationSource'), tc),
          const SizedBox(height: 6),
          ..._buildDailyGroups(taskData, fmtDev, tc),
          const SizedBox(height: 14),

          // ── 新增：各标签偏差曲线 ─────────────────────────────────────────
          ..._buildTagDeviationCharts(taskData, tc),
        ],
      ),
    );
  }

  // ─── 每日偏差数据源（按日期分组，可展开看每条任务）────────────────────────
  List<Widget> _buildDailyGroups(List<_DevEntry> taskData,
      String Function(double) fmtDev, ThemeConfig tc) {
    if (taskData.isEmpty) {
      return [Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(L.get('screens.stats.noData'), style: TextStyle(color: Color(tc.tm)))),
      )];
    }
    // 按 doneAt 分组
    final groups = <String, List<_DevEntry>>{};
    for (final e in taskData) {
      final key = e.task.doneAt ?? '未知日期';
      groups.putIfAbsent(key, () => []).add(e);
    }
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final blockNames = {L.get('screens.stats.morning'): '上午', L.get('screens.stats.afternoon'): '下午', L.get('screens.stats.evening'): '晚上'};

    return sortedDates.map((date) {
      final entries = groups[date]!;
      final avgDevDay = entries.map((e) => e.dev).reduce((a, b) => a + b) / entries.length;
      Color dayColor;
      if (avgDevDay.abs() < 0.5) dayColor = const Color(0xFF4A9068);
      else if (avgDevDay > 0)    dayColor = const Color(0xFFE07040);
      else                       dayColor = const Color(0xFF5060D0);

      return _DayDevGroup(
        date: date, entries: entries, avgDev: avgDevDay,
        dayColor: dayColor, fmtDev: fmtDev, blockNames: blockNames, tc: tc,
      );
    }).toList();
  }

  // ─── 各标签偏差随时间变化曲线 ─────────────────────────────────────────────
  List<Widget> _buildTagDeviationCharts(
      List<_DevEntry> taskData, ThemeConfig tc) {
    // 收集所有标签
    final allTags = <String>{};
    for (final e in taskData) allTags.addAll(e.task.tags);
    if (allTags.isEmpty) return [];

    // 按日期+标签计算平均偏差
    final tagDayDev = <String, Map<String, List<double>>>{};
    for (final e in taskData) {
      final date = e.task.doneAt ?? '';
      if (date.isEmpty) continue;
      for (final tag in e.task.tags) {
        tagDayDev.putIfAbsent(tag, () => {});
        tagDayDev[tag]!.putIfAbsent(date, () => []).add(e.dev);
      }
    }

    // 找时间范围
    final allDates = taskData
        .where((e) => e.task.doneAt != null)
        .map((e) => e.task.doneAt!)
        .toSet()
        .toList()..sort();
    if (allDates.length < 2) return [];

    // 每个标签生成折线值（以 allDates 为 X 轴）
    final seriesData = <String, List<double>>{};
    for (final tag in allTags) {
      final dayMap = tagDayDev[tag] ?? {};
      seriesData[tag] = allDates.map((d) {
        final devs = dayMap[d];
        return devs != null
            ? devs.reduce((a, b) => a + b) / devs.length
            : double.nan;
      }).toList();
    }

    // 去掉全 NaN 的标签
    seriesData.removeWhere((_, v) => v.every((x) => x.isNaN));
    if (seriesData.isEmpty) return [];

    final tagColorMap = <String, Color>{};
    final palette = [
      const Color(0xFFE07040), const Color(0xFF5060D0), const Color(0xFF4A9068),
      const Color(0xFFD070C0), const Color(0xFFDAA520), const Color(0xFF3A90C0),
    ];
    int ci = 0;
    for (final tag in seriesData.keys) {
      tagColorMap[tag] = palette[ci % palette.length];
      ci++;
    }

    return [
      _sectionLabel(L.get('screens.stats.tagDeviationOverTime'), tc),
      const SizedBox(height: 8),
      _TagDeviationChart(
        dates: allDates, series: seriesData,
        colors: tagColorMap, tc: tc),
      const SizedBox(height: 14),
      // 各标签当前平均偏差汇总
      _sectionLabel(L.get('screens.stats.tagDeviationSummary'), tc),
      const SizedBox(height: 6),
      ...seriesData.keys.map((tag) {
        final validDevs = seriesData[tag]!.where((v) => !v.isNaN).toList();
        if (validDevs.isEmpty) return const SizedBox.shrink();
        final avg = validDevs.reduce((a, b) => a + b) / validDevs.length;
        Color c;
        if (avg.abs() < 0.5)   c = const Color(0xFF4A9068);
        else if (avg > 0)       c = const Color(0xFFE07040);
        else                    c = const Color(0xFF5060D0);
        return Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: state.cardColor, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(width: 10, height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: tagColorMap[tag] ?? Color(tc.tm))),
            const SizedBox(width: 8),
            Expanded(child: Text(tag,
              style: TextStyle(fontSize: 12, color: Color(tc.tx),
                  fontWeight: FontWeight.w500))),
            Text(avg.abs() < 0.5 ? L.get('screens.stats.onTime')
                : avg > 0 ? L.get('screens.stats.avgDelayValue', {'value': avg.toStringAsFixed(1)})
                          : L.get('screens.stats.avgAheadValue', {'value': avg.abs().toStringAsFixed(1)}),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
          ]),
        );
      }),
    ];
  }

  Widget _sectionLabel(String text, ThemeConfig tc) => Text(
    text,
    style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts)),
  );

  Widget _metricCard(String label, String value, Color c, ThemeConfig tc) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: state.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c)),
      ]),
    ),
  );

  Widget _buildBucketBar(Map<int, int> buckets, int total, ThemeConfig tc) {
    if (total == 0) return const SizedBox.shrink();
    final maxCount = buckets.values.isEmpty ? 1 : buckets.values.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: 80,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(13, (i) {
            final slot = i - 6; // -6 to +6
            final count = buckets[slot] ?? 0;
            final ratio = maxCount > 0 ? count / maxCount : 0.0;
            Color barColor;
            if (slot < -0) barColor = const Color(0xFF5060D0);
            else if (slot > 0) barColor = const Color(0xFFE07040);
            else barColor = const Color(0xFF4A9068);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (count > 0)
                      Text('$count', style: TextStyle(fontSize: 7, color: barColor)),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: (ratio * 60).clamp(2.0, 60.0),
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(slot == 0 ? 0.85 : 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBlockBreakdown(List<_DevEntry> taskData, ThemeConfig tc) {
    final blocks = ['morning', 'afternoon', 'evening'];
    final blockNames = {'morning': '🌅 ${L.get("screens.stats.morning")}', 'afternoon': '☀️ ${L.get("screens.stats.afternoon")}', 'evening': '🌙 ${L.get("screens.stats.evening")}'};
    final blockColors = {
      'morning': const Color(0xFFe8982a),
      'afternoon': const Color(0xFF3a90c0),
      'evening': const Color(0xFF7a5ab8),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: blocks.map((blk) {
          final planned = taskData.where((e) => e.task.originalTimeBlock == blk).length;
          final doneInBlk = taskData.where((e) => e.actualBlk == blk).length;
          final onTime = taskData.where((e) =>
            e.task.originalTimeBlock == blk && e.actualBlk == blk).length;
          final c = blockColors[blk]!;
          final rate = planned > 0 ? onTime / planned : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(blockNames[blk]!, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(L.get('screens.stats.plannedCount', {'count': planned}) + ' · ' + L.get('screens.stats.actualDoneCount', {'count': doneInBlk}) + ' · ' + L.get('screens.stats.onTimeRate', {'rate': (rate * 100).round()}),
                    style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: rate,
                    backgroundColor: Color(tc.brd),
                    color: c,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskRow(_DevEntry e, String Function(double) fmtDev, ThemeConfig tc) {
    final dev = e.dev;
    Color c;
    if (dev.abs() < 0.5) c = const Color(0xFF4A9068);
    else if (dev > 0) c = const Color(0xFFE07040);
    else c = const Color(0xFF5060D0);

    final blockNames = {'morning': L.get('screens.stats.morning'), 'afternoon': L.get('screens.stats.afternoon'), 'evening': L.get('screens.stats.evening'), 'unassigned': L.get('screens.today.unassigned')};

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: state.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Container(width: 4, height: 32, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.task.text,
              style: TextStyle(fontSize: 12, color: Color(tc.tx), fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              L.get('screens.stats.planned', {'value': blockNames[e.task.originalTimeBlock] ?? e.task.originalTimeBlock}) + L.get('screens.stats.actual', {'value': blockNames[e.actualBlk] ?? e.actualBlk}),
              style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
          ]),
        ),
        Text(fmtDev(dev),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

// 辅助：计算绝对时段号（供详情页使用）
int _absSlotDetail(String dateStr, String blk) {
  int blockIdx;
  switch (blk) {
    case 'morning':   blockIdx = 0; break;
    case 'afternoon': blockIdx = 1; break;
    case 'evening':   blockIdx = 2; break;
    default:          blockIdx = 1;
  }
  final d = DateTime.parse('${dateStr}T12:00:00');
  final epoch = DateTime(d.year, 1, 1);
  return d.difference(epoch).inDays * 3 + blockIdx;
}

class _DevEntry {
  final TaskModel task;
  final double dev;
  final String actualBlk;
  const _DevEntry({required this.task, required this.dev, required this.actualBlk});
}

// ═══════════════════════════════════════════════════════════════════════════
// 任务完成时间分布详情页
// ═══════════════════════════════════════════════════════════════════════════
class _CompletionTimelineDetailPage extends StatelessWidget {
  final List<String> days;
  final AppState state;
  final ThemeConfig tc;
  final String pLbl;
  const _CompletionTimelineDetailPage(
      {required this.days, required this.state, required this.tc, required this.pLbl});

  @override
  Widget build(BuildContext context) {
    final daySet = days.toSet();
    final hourCount = List<int>.filled(24, 0);
    final hourTasks = List<List<TaskModel>>.generate(24, (_) => []);

    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null || !daySet.contains(t.doneAt)) continue;
      if (t.doneHour == null) continue;
      hourCount[t.doneHour!]++;
      hourTasks[t.doneHour!].add(t);
    }
    final total = hourCount.fold(0, (a, b) => a + b);
    final maxH = hourCount.reduce((a, b) => a > b ? a : b).clamp(1, 999);

    // 按每日统计完成数（折线数据）
    final dailyCounts = days.map((d) =>
        state.tasks.where((t) => t.done && t.doneAt == d).length).toList();

    String _fmtH(int h) => '${h.toString().padLeft(2,'0')}:xx';
    Color _blkColor(int h) => h >= 5 && h < 13
        ? const Color(0xFFe8982a)
        : h >= 13 && h < 18
            ? const Color(0xFF3a90c0)
            : const Color(0xFF7a5ab8);

    return Scaffold(
      backgroundColor: Color(tc.bg),
      appBar: AppBar(
        backgroundColor: Color(tc.bg), elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context)),
        title: Text(L.get('screens.stats.completionTimelineDetails'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          // 汇总
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              _InfoCard(label: L.get('screens.stats.totalDone'), value: L.get('screens.stats.itemCount', {'count': total}), color: Color(tc.acc), tc: tc),
              const SizedBox(width: 8),
              _InfoCard(label: L.get('screens.stats.morningDone'), value: L.get('screens.stats.itemCount', {'count': hourCount.sublist(5,13).fold(0,(a,b)=>a+b)}),
                  color: const Color(0xFFe8982a), tc: tc),
              const SizedBox(width: 8),
              _InfoCard(label: L.get('screens.stats.afternoonDone'), value: L.get('screens.stats.itemCount', {'count': hourCount.sublist(13,18).fold(0,(a,b)=>a+b)}),
                  color: const Color(0xFF3a90c0), tc: tc),
              const SizedBox(width: 8),
              _InfoCard(label: L.get('screens.stats.nightDone'), value: L.get('screens.stats.itemCount', {'count': (hourCount.sublist(0,5)+hourCount.sublist(18)).fold(0,(a,b)=>a+b)}),
                  color: const Color(0xFF7a5ab8), tc: tc),
            ]),
          ),
          const SizedBox(height: 14),
          // 每日完成数折线
          _SectionLabel(text: L.get('screens.stats.dailyCompletionCount', {'period': pLbl}), tc: tc),
          const SizedBox(height: 8),
          _DailyLineChart(days: days, values: dailyCounts.map((v)=>v.toDouble()).toList(), tc: tc,
            color: Color(tc.acc), yLabel: L.get('screens.stats.itemCount', {'count': ''})),
          const SizedBox(height: 14),
          // 各小时明细
          _SectionLabel(text: L.get('screens.stats.hourlyCompletionDetails'), tc: tc),
          const SizedBox(height: 8),
          ...List.generate(24, (h) {
            final tasks = hourTasks[h];
            if (tasks.isEmpty) return const SizedBox.shrink();
            return _HourTaskGroup(
              hour: h, tasks: tasks, color: _blkColor(h), tc: tc);
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 专注统计详情页（各标签各项目 + 日专注曲线）
// ═══════════════════════════════════════════════════════════════════════════
class FocusDetailPage extends StatefulWidget {
  final List<String> days;
  final AppState state;
  final ThemeConfig tc;
  final String pLbl;
  const FocusDetailPage({super.key,
      required this.days, required this.state, required this.tc, required this.pLbl});
  @override
  State<FocusDetailPage> createState() => _FocusDetailPageState();
}

class _FocusDetailPageState extends State<FocusDetailPage> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tc = widget.tc;
    final days = widget.days;
    final daySet = days.toSet();

    // 日专注时长数据
    final dailyFocus = days.map((d) {
      final tf = state.tasks.where((t) => t.doneAt == d)
          .fold(0, (s, t) => s + t.focusSecs);
      final ub = state.settings.unboundFocusByDate[d] ?? 0;
      return (tf + ub).toDouble();
    }).toList();

    // 各标签日专注（多线）
    final tagColors = <String, Color>{};
    for (final tag in state.tags) tagColors[tag] = state.tagColor(tag);

    final tagDailyFocus = <String, List<double>>{};
    for (final tag in state.tags) {
      if (!state.tagCountsInStats(tag)) continue;
      tagDailyFocus[tag] = days.map((d) =>
        state.tasks.where((t) => t.tags.contains(tag) && t.doneAt == d)
          .fold(0.0, (s, t) => s + t.focusSecs)).toList();
    }

    // 各标签各项目列表
    final tagsSorted = state.tags
        .where((t) => state.tagCountsInStats(t) && state.tagFocusTime(t) > 0)
        .toList()
      ..sort((a, b) => state.tagFocusInPeriod(b, days)
          .compareTo(state.tagFocusInPeriod(a, days)));

    String fmt(int s) {
      if (s <= 0) return '—';
      if (s < 60) return '${s}秒';
      if (s < 3600) return '${s~/60}分';
      return '${s~/3600}h${s%3600~/60>0?"${s%3600~/60}m":""}';
    }

    return Scaffold(
      backgroundColor: Color(tc.bg),
      appBar: AppBar(
        backgroundColor: Color(tc.bg), elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context)),
        title: Text(L.get('screens.stats.focusStatsDetails'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          // 日专注总量曲线
          _SectionLabel(text: L.get('screens.stats.dailyFocusDurationPeriod', {'period': widget.pLbl}), tc: tc),
          const SizedBox(height: 8),
          _DailyLineChart(
            days: days,
            values: dailyFocus.map((v) => v / 60).toList(), // 转分钟显示
            tc: tc, color: Color(tc.acc), yLabel: L.get('screens.stats.minutes'),
          ),
          const SizedBox(height: 14),
          // 各标签日专注曲线
          if (tagDailyFocus.length >= 2) ...[
            _SectionLabel(text: L.get('screens.stats.tagDailyFocusCompare'), tc: tc),
            const SizedBox(height: 8),
            _MultiLineChart(
              days: days,
              series: tagDailyFocus.map((k, v) =>
                  MapEntry(k, v.map((s) => s / 60).toList())),
              colors: tagColors,
              tc: tc,
            ),
            const SizedBox(height: 14),
          ],
          // 各标签各项目明细
          _SectionLabel(text: L.get('screens.stats.tagFocusDetails'), tc: tc),
          const SizedBox(height: 8),
          ...tagsSorted.map((tag) {
            final c = state.tagColor(tag);
            final periodFocus = state.tagFocusInPeriod(tag, days);
            final totalFocus = state.tagFocusTime(tag);
            // BUG FIX: show tasks with focusSecs > 0 for this tag.
            // Period filter: tasks done in period OR created in period with focus time.
            // Fall back to ALL tasks with focusSecs > 0 for this tag if period empty.
            var tasks = state.tasks
                .where((t) => t.tags.contains(tag) && t.focusSecs > 0 &&
                    (daySet.contains(t.doneAt) || daySet.contains(t.createdAt)))
                .toList()..sort((a, b) => b.focusSecs.compareTo(a.focusSecs));
            // If still empty but totalFocus > 0, show all tasks with focus
            if (tasks.isEmpty && totalFocus > 0) {
              tasks = state.tasks
                  .where((t) => t.tags.contains(tag) && t.focusSecs > 0)
                  .toList()..sort((a, b) => b.focusSecs.compareTo(a.focusSecs));
            }
            final exp = _expanded.contains(tag);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: state.cardColor, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    if (exp) _expanded.remove(tag); else _expanded.add(tag);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                      const SizedBox(width: 8),
                      Flexible(child: Text(tag,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c))),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt(periodFocus),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(tc.acc))),
                        Text(L.get('screens.stats.totalFocusTime', {'value': fmt(totalFocus)}),
                          style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
                      ]),
                      const SizedBox(width: 6),
                      Icon(exp ? Icons.expand_less : Icons.expand_more,
                        size: 16, color: Color(tc.tm)),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  child: exp ? Column(
                    children: [
                      Divider(height: 1, color: Color(tc.brd)),
                      ...tasks.map((t) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.text,
                                style: TextStyle(fontSize: 11, color: Color(tc.tx)),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (t.doneAt != null)
                                Text(t.doneAt!,
                                  style: TextStyle(fontSize: 9, color: Color(tc.tm))),
                            ],
                          )),
                          Text(fmt(t.focusSecs),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: Color(tc.acc))),
                        ]),
                      )),
                    ],
                  ) : const SizedBox.shrink(),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─── 共用子组件 ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text; final ThemeConfig tc;
  const _SectionLabel({required this.text, required this.tc});
  @override
  Widget build(BuildContext context) =>
    Text(text, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts)));
}

class _InfoCard extends StatelessWidget {
  final String label, value; final Color color; final ThemeConfig tc;
  const _InfoCard({required this.label, required this.value,
      required this.color, required this.tc});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 8.5, color: Color(tc.ts)), textAlign: TextAlign.center),
    ]),
  ));
}

class _HourTaskGroup extends StatefulWidget {
  final int hour; final List<TaskModel> tasks; final Color color; final ThemeConfig tc;
  const _HourTaskGroup({required this.hour, required this.tasks,
      required this.color, required this.tc});
  @override
  State<_HourTaskGroup> createState() => _HourTaskGroupState();
}

class _HourTaskGroupState extends State<_HourTaskGroup> {
  bool _exp = false;
  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(color: Color(tc.card), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _exp = !_exp),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
              const SizedBox(width: 8),
              Text('${widget.hour.toString().padLeft(2,"0")}:00',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: widget.color, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Text(L.get('screens.stats.itemCount', {'count': widget.tasks.length}),
                style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              const Spacer(),
              Icon(_exp ? Icons.expand_less : Icons.expand_more,
                size: 14, color: Color(tc.tm)),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _exp ? Column(children: [
            Divider(height: 1, color: Color(tc.brd)),
            ...widget.tasks.map((t) => Padding(
              padding: const EdgeInsets.fromLTRB(28, 6, 12, 6),
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
  }
}

// 单条折线图（日维度）
class _DailyLineChart extends StatelessWidget {
  final List<String> days;
  final List<double> values;
  final ThemeConfig tc;
  final Color color;
  final String yLabel;
  const _DailyLineChart({required this.days, required this.values,
      required this.tc, required this.color, required this.yLabel});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((v) => v == 0)) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 100,
          child: CustomPaint(
            painter: _SingleLinePainter(
              values: values,
              color: color,
              gridColor: Color(tc.brd),
              yLabel: yLabel,
            ),
            size: const Size(double.infinity, 100),
          ),
        ),
        const SizedBox(height: 4),
        _buildDateLabels(days, tc),
      ]),
    );
  }

  Widget _buildDateLabels(List<String> days, ThemeConfig tc) {
    if (days.isEmpty) return const SizedBox.shrink();
    String fmt(String d) {
      final dt = DateTime.parse('${d}T00:00:00');
      return '${dt.month}/${dt.day}';
    }
    final mid = days.length > 2 ? days[days.length ~/ 2] : null;
    return Row(children: [
      Text(fmt(days.first), style: TextStyle(fontSize: 8, color: Color(tc.tm))),
      if (mid != null) ...[const Spacer(), Text(fmt(mid), style: TextStyle(fontSize: 8, color: Color(tc.tm)))],
      const Spacer(),
      Text(fmt(days.last), style: TextStyle(fontSize: 8, color: Color(tc.tm))),
    ]);
  }
}

// 多标签折线图
class _MultiLineChart extends StatelessWidget {
  final List<String> days;
  final Map<String, List<double>> series;
  final Map<String, Color> colors;
  final ThemeConfig tc;
  const _MultiLineChart({required this.days, required this.series,
      required this.colors, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _MultiLinePainter(
              series: series, colors: colors, gridColor: Color(tc.brd)),
            size: const Size(double.infinity, 120),
          ),
        ),
        const SizedBox(height: 8),
        // 图例
        Wrap(spacing: 10, runSpacing: 4,
          children: series.keys.map((tag) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 20, height: 2, color: colors[tag] ?? Color(tc.tm)),
            const SizedBox(width: 4),
            Text(tag, style: TextStyle(fontSize: 9.5, color: colors[tag] ?? Color(tc.tm))),
          ])).toList()),
      ]),
    );
  }
}

class _SingleLinePainter extends CustomPainter {
  final List<double> values;
  final Color color, gridColor;
  final String yLabel;
  const _SingleLinePainter({required this.values, required this.color,
      required this.gridColor, required this.yLabel});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const padL = 28.0, padR = 8.0, padT = 8.0, padB = 8.0;
    final W = size.width - padL - padR;
    final H = size.height - padT - padB;
    final maxV = values.reduce((a, b) => a > b ? a : b).clamp(1.0, 99999.0);

    // grid
    final gridP = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = padT + H * (1 - i / 4);
      canvas.drawLine(Offset(padL, y), Offset(padL + W, y), gridP);
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(text: '${(maxV * i / 4).round()}$yLabel',
            style: TextStyle(fontSize: 6.5, color: gridColor))
        ..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // line + fill
    final pts = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = padL + (values.length == 1 ? W / 2 : i * W / (values.length - 1));
      final y = padT + H * (1 - values[i] / maxV);
      pts.add(Offset(x, y.clamp(padT, padT + H)));
    }
    if (pts.length > 1) {
      final path = _smooth(pts);
      final fill = Path.from(path)
        ..lineTo(pts.last.dx, padT + H)
        ..lineTo(pts.first.dx, padT + H)..close();
      canvas.drawPath(fill, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.22), color.withOpacity(0.03)],
        ).createShader(Rect.fromLTWH(padL, padT, W, H))
        ..style = PaintingStyle.fill);
      canvas.drawPath(_smooth(pts), Paint()
        ..color = color..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
    for (final pt in pts) {
      canvas.drawCircle(pt, 3, Paint()..color = color);
      canvas.drawCircle(pt, 1.5, Paint()..color = Colors.white.withOpacity(0.7));
    }
  }

  Path _smooth(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i-1].dx + pts[i].dx) / 2;
      p.cubicTo(cx, pts[i-1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    return p;
  }

  @override
  bool shouldRepaint(_SingleLinePainter o) => o.values != values;
}

class _MultiLinePainter extends CustomPainter {
  final Map<String, List<double>> series;
  final Map<String, Color> colors;
  final Color gridColor;
  const _MultiLinePainter({required this.series, required this.colors,
      required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    const padL = 8.0, padR = 8.0, padT = 8.0, padB = 8.0;
    final W = size.width - padL - padR;
    final H = size.height - padT - padB;
    double maxV = 1.0;
    for (final v in series.values) {
      if (v.isNotEmpty) maxV = [maxV, ...v].reduce((a, b) => a > b ? a : b);
    }

    // grid
    for (int i = 0; i <= 3; i++) {
      final y = padT + H * (1 - i / 3);
      canvas.drawLine(Offset(padL, y), Offset(padL + W, y),
          Paint()..color = gridColor..strokeWidth = 0.5);
    }

    for (final entry in series.entries) {
      final vals = entry.value;
      final c = colors[entry.key] ?? gridColor;
      if (vals.length < 2) continue;
      final pts = <Offset>[];
      for (int i = 0; i < vals.length; i++) {
        final x = padL + i * W / (vals.length - 1);
        final y = padT + H * (1 - vals[i] / maxV);
        pts.add(Offset(x, y.clamp(padT, padT + H)));
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        final cx = (pts[i-1].dx + pts[i].dx) / 2;
        path.cubicTo(cx, pts[i-1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, Paint()
        ..color = c..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_MultiLinePainter o) => false;
}

// ─── 每日偏差折叠组件 ────────────────────────────────────────────────────────
class _DayDevGroup extends StatefulWidget {
  final String date;
  final List<_DevEntry> entries;
  final double avgDev;
  final Color dayColor;
  final String Function(double) fmtDev;
  final Map<String, String> blockNames;
  final ThemeConfig tc;
  const _DayDevGroup({required this.date, required this.entries,
      required this.avgDev, required this.dayColor, required this.fmtDev,
      required this.blockNames, required this.tc});
  @override
  State<_DayDevGroup> createState() => _DayDevGroupState();
}

class _DayDevGroupState extends State<_DayDevGroup> {
  bool _exp = false;

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final dt = DateTime.tryParse('${widget.date}T00:00:00');
    final dateLabel = dt != null
        ? '${dt.month}/${dt.day}（${["","周一","周二","周三","周四","周五","周六","周日"][dt.weekday]}）'
        : widget.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Color(tc.card), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _exp = !_exp),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(width: 4, height: 28,
                decoration: BoxDecoration(
                  color: widget.dayColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateLabel, style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600, color: Color(tc.tx))),
                  Text('${widget.entries.length} 件任务  均偏差 ${widget.fmtDev(widget.avgDev)}',
                    style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
                ])),
              Icon(_exp ? Icons.expand_less : Icons.expand_more,
                size: 16, color: Color(tc.tm)),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          child: _exp ? Column(children: [
            Divider(height: 1, color: Color(tc.brd)),
            ...widget.entries.map((e) {
              Color c;
              if (e.dev.abs() < 0.5)   c = const Color(0xFF4A9068);
              else if (e.dev > 0)       c = const Color(0xFFE07040);
              else                      c = const Color(0xFF5060D0);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.task.text, style: TextStyle(fontSize: 11, color: Color(tc.tx)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '规划 ${widget.blockNames[e.task.originalTimeBlock] ?? e.task.originalTimeBlock}'
                        ' → 实际 ${widget.blockNames[e.actualBlk] ?? e.actualBlk}',
                        style: TextStyle(fontSize: 9, color: Color(tc.tm))),
                    ],
                  )),
                  Text(widget.fmtDev(e.dev),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                ]),
              );
            }),
          ]) : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ─── 标签偏差随时间折线图 ────────────────────────────────────────────────────
class _TagDeviationChart extends StatelessWidget {
  final List<String> dates;
  final Map<String, List<double>> series;
  final Map<String, Color> colors;
  final ThemeConfig tc;
  const _TagDeviationChart({required this.dates, required this.series,
      required this.colors, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('纵轴：平均偏差时段数（正=推迟，负=提前）',
          style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _TagDevPainter(
              dates: dates, series: series, colors: colors,
              gridColor: Color(tc.brd)),
            size: const Size(double.infinity, 130),
          ),
        ),
        const SizedBox(height: 6),
        // X轴日期标签
        Row(children: [
          Text(_fmtDate(dates.first),
            style: TextStyle(fontSize: 8, color: Color(tc.tm))),
          if (dates.length > 2) ...[
            const Spacer(),
            Text(_fmtDate(dates[dates.length ~/ 2]),
              style: TextStyle(fontSize: 8, color: Color(tc.tm))),
          ],
          const Spacer(),
          Text(_fmtDate(dates.last),
            style: TextStyle(fontSize: 8, color: Color(tc.tm))),
        ]),
        const SizedBox(height: 8),
        // 图例
        Wrap(spacing: 10, runSpacing: 4,
          children: series.keys.map((tag) => Row(mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 18, height: 2, color: colors[tag]),
              const SizedBox(width: 4),
              Text(tag, style: TextStyle(fontSize: 9.5, color: colors[tag] ?? Color(tc.tm))),
            ])).toList()),
      ]),
    );
  }

  String _fmtDate(String d) {
    final dt = DateTime.tryParse('${d}T00:00:00');
    return dt != null ? '${dt.month}/${dt.day}' : d;
  }
}

class _TagDevPainter extends CustomPainter {
  final List<String> dates;
  final Map<String, List<double>> series;
  final Map<String, Color> colors;
  final Color gridColor;
  const _TagDevPainter({required this.dates, required this.series,
      required this.colors, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 28.0, padR = 8.0, padT = 8.0, padB = 8.0;
    final W = size.width - padL - padR;
    final H = size.height - padT - padB;
    final midY = padT + H / 2;

    // 找最大绝对值
    double maxAbs = 1.0;
    for (final v in series.values) {
      for (final x in v) {
        if (!x.isNaN && x.abs() > maxAbs) maxAbs = x.abs();
      }
    }
    maxAbs = maxAbs.clamp(1.0, 9.0);
    final yScale = (H / 2) / maxAbs;

    // 零线
    canvas.drawLine(Offset(padL, midY), Offset(padL + W, midY),
        Paint()..color = gridColor..strokeWidth = 1.2);
    // ±3 辅助线
    for (final v in [-3.0, 3.0]) {
      final y = midY - v * yScale;
      if (y >= padT && y <= padT + H) {
        canvas.drawLine(Offset(padL, y), Offset(padL + W, y),
            Paint()..color = gridColor..strokeWidth = 0.5);
      }
    }

    // Y轴标签
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String text, double y) {
      tp.text = TextSpan(text: text,
          style: TextStyle(fontSize: 7, color: gridColor));
      tp.layout();
      if (y >= padT - 2 && y <= padT + H + 2) {
        tp.paint(canvas, Offset(0, y - tp.height / 2));
      }
    }
    drawLabel('0', midY);
    drawLabel('+3', midY - 3 * yScale);
    drawLabel('-3', midY + 3 * yScale);

    // 每条标签折线
    for (final entry in series.entries) {
      final vals = entry.value;
      final c = colors[entry.key] ?? gridColor;
      final pts = <Offset?>[];

      for (int i = 0; i < vals.length && i < dates.length; i++) {
        if (vals[i].isNaN) {
          pts.add(null);
        } else {
          final x = padL + (dates.length == 1 ? W / 2 : i * W / (dates.length - 1));
          final y = (midY - vals[i] * yScale).clamp(padT, padT + H);
          pts.add(Offset(x, y));
        }
      }

      // 分段绘制（跳过 NaN 断点）
      final paint = Paint()
        ..color = c..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

      List<Offset> segment = [];
      for (final pt in pts) {
        if (pt != null) {
          segment.add(pt);
        } else {
          if (segment.length >= 2) canvas.drawPath(_smooth(segment), paint);
          else if (segment.length == 1) canvas.drawCircle(segment.first, 2.5, Paint()..color = c);
          segment = [];
        }
      }
      if (segment.length >= 2) canvas.drawPath(_smooth(segment), paint);
      else if (segment.length == 1) canvas.drawCircle(segment.first, 2.5, Paint()..color = c);

      // 数据点
      for (final pt in pts) {
        if (pt == null) continue;
        canvas.drawCircle(pt, 2.5, Paint()..color = c);
        canvas.drawCircle(pt, 1.2, Paint()..color = Colors.white.withOpacity(0.7));
      }
    }
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i-1].dx + pts[i].dx) / 2;
      path.cubicTo(cx, pts[i-1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_TagDevPainter o) => false;
}
