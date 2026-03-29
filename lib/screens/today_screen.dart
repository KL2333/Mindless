// lib/screens/today_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/task_tile.dart';
import '../widgets/focus_pool.dart';
import '../widgets/shared_widgets.dart';
import '../beta/beta_flags.dart';
import '../beta/beta_panel.dart';
import '../services/crash_logger.dart';
import '../beta/smart_plan.dart';
import '../beta/usage_stats_service.dart';
import '../beta/task_gravity.dart';
import '../widgets/share_card.dart';
import '../services/environment_sound_service.dart';
import '../services/festival_calendar.dart';
import '../services/focus_quality_service.dart';
import '../l10n/l10n.dart';
import 'quadrant_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<String> _selTags = [];
  String? _selBlock; // null = 待分配，'morning'/'afternoon'/'evening' = 指定时段
  
  // View states unified: 0 = Today List, 1 = Tomorrow List, 2 = Quadrant View
  int _viewIndex = 0;
  
  late AnimationController _dayAnim;
  late Animation<double> _dayFade;

  // Which task is currently being dragged (to restrict drop targets)
  int? _draggingId;

  @override
  void initState() {
    super.initState();
    _dayAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _dayFade = CurvedAnimation(parent: _dayAnim, curve: Curves.easeInOut);
    _dayAnim.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _dayAnim.dispose();
    super.dispose();
  }

  bool get _showTomorrow => _viewIndex == 1;
  bool get _showQuadrant => _viewIndex == 2;

  String _displayDate(AppState state) =>
      _showTomorrow ? DateUtils2.addDays(state.todayKey, 1) : state.todayKey;

  void _switchView(int index) {
    if (_viewIndex == index) return;
    CrashLogger.tap('TodayScreen', 'switchView from $_viewIndex to $index');
    _dayAnim.reverse().then((_) {
      setState(() => _viewIndex = index);
      _dayAnim.forward();
    });
  }

  void _add(AppState state) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    CrashLogger.tap('TodayScreen', 'add task len=${text.length} tags=${_selTags.length} block=$_selBlock');
    // New tasks go to unassigned pool (timeBlock = 'unassigned')
    state.addTask(
        text: text,
        tags: List.from(_selTags),
        timeBlock: _selBlock ?? 'unassigned',
        forDate: _displayDate(state));
    _ctrl.clear();
    setState(() { _selTags = []; _selBlock = null; });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final displayDate = _displayDate(state);
    final today = state.todayKey;

    final unassigned = state.tasks
        .where((t) =>
            !t.done && !t.ignored && t.timeBlock == 'unassigned' &&
            t.createdAt == displayDate &&
            t.originalDate == displayDate)
        .toList();

    final overdue = state.tasks
        .where((t) =>
            !t.done && !t.ignored &&
            t.originalDate.compareTo(today) < 0 &&
            (t.rescheduledTo == null || t.rescheduledTo!.compareTo(today) < 0))
        .toList();

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final topPad = MediaQuery.of(context).padding.top;
    final showClock = state.settings.showTopClock;
    final appBarHeight = showClock ? 78.0 : 46.0;
    final topMargin = 8.0;
    final barBottom = topPad + appBarHeight + topMargin + 8 + state.settings.topBarOffset;

    // ── 横屏处理 (简单处理) ────────────────────────────────────
    if (isLandscape) {
      // Keep existing landscape Row structure but wrap in a column for the unified toggle
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            SizedBox(height: barBottom),
            _buildDayToggle(tc),
            Expanded(
              child: FadeTransition(
                opacity: _dayFade,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 24),
                    children: [
                      if (!_showTomorrow && !_showQuadrant) const FocusPoolWidget(),
                      if (_showQuadrant) 
                        QuadrantView(topPadding: 0, onSwitchBack: () => _switchView(0))
                      else ...[
                        _buildUnassignedPool(state, tc, unassigned, displayDate, today),
                        const SizedBox(height: 4),
                        for (final blk in ['morning', 'afternoon', 'evening'])
                          _buildTimeBlock(state, tc, blk, displayDate, today),
                        if (!_showTomorrow) _buildOverdueSection(state, tc, overdue, today),
                        if (!_showTomorrow && kBetaFeatures) const BetaTodayPanel(),
                      ],
                      const SizedBox(height: 16),
                    ])),
                  Container(width: 1, color: Color(tc.brd).withOpacity(0.4)),
                  Expanded(flex: 2, child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 24),
                    children: [
                      if (!_showQuadrant) _buildInputCard(state, tc, displayDate),
                      const SizedBox(height: 8),
                      if (!_showTomorrow && !_showQuadrant && kBetaFeatures) const _SmartPlanPanel(),
                    ])),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Fixed Header Space
          SizedBox(height: barBottom),
          _buildDayToggle(tc),
          
          // Scrollable Content
          Expanded(
            child: FadeTransition(
              opacity: _dayFade,
              child: _showQuadrant 
                ? QuadrantView(
                    topPadding: 0, 
                    onSwitchBack: () => _switchView(0),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(13, 0, 13, 110),
                    children: [
                      _buildInputCard(state, tc, displayDate),
                      const SizedBox(height: 8),
                      if (!_showTomorrow) const FocusPoolWidget(),
                      _buildUnassignedPool(state, tc, unassigned, displayDate, today),
                      const SizedBox(height: 6),
                      for (final blk in ['morning', 'afternoon', 'evening'])
                        _buildTimeBlock(state, tc, blk, displayDate, today),
                      if (!_showTomorrow) _buildOverdueSection(state, tc, overdue, today),
                      if (!_showTomorrow && kBetaFeatures) const _SmartPlanPanel(),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Day toggle ────────────────────────────────────────────
  Widget _buildDayToggle(ThemeConfig tc) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4, left: 16, right: 16),
      child: Row(
        children: [
          // Left Spacing to keep Segmented Control centered
          const Expanded(child: SizedBox()),
          
          // Centered day toggle pills - Liquid Glass Segmented Control
          LiquidSegmentedControl(
            labels: [L.today, L.tomorrow, L.quadrantTitle],
            currentIndex: _viewIndex,
            onValueChanged: _switchView,
            tc: tc,
            width: 240,
          ),
          
          // Action Button Area on the Right
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => showShareCardSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Color(tc.acc).withOpacity(0.20), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ios_share_rounded, 
                          size: 11, // Reduced 10-15% from original 12-14
                          color: Color(tc.acc)),
                      const SizedBox(width: 4),
                      Text(L.todayShare,
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(tc.acc),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input card ────────────────────────────────────────────
  Widget _buildInputCard(AppState state, ThemeConfig tc, String displayDate) {
    final acc = Color(tc.acc);
    return AnimatedBuilder(
      animation: _focus,
      builder: (_, child) {
        final focused = _focus.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
              color: state.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: focused ? acc.withOpacity(0.5) : Color(tc.brd).withOpacity(0.4),
                width: focused ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: focused ? acc.withOpacity(0.10) : Color(0x0A000000),
                  blurRadius: focused ? 16 : 8,
                  offset: const Offset(0, 3)),
              ]),
          padding: const EdgeInsets.all(13),
          child: child!,
        );
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: TextStyle(fontSize: 14, color: Color(tc.tx), fontFamily: 'serif'),
              decoration: InputDecoration(
                  hintText: _showTomorrow ? L.addTomorrow : L.addHint,
                  hintStyle: TextStyle(color: Color(tc.tm)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(state),
            ),
          ),
          _SpringAddBtn(
            tc: tc,
            onTap: () => _add(state),
          ),
        ]),
        const SizedBox(height: 8),
        // Block selector: 待分配 (default) + 上午/下午/晚上 (optional)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            // 待分配 chip (always visible, highlights when nothing selected)
            GestureDetector(
              onTap: () => setState(() => _selBlock = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _selBlock == null ? Color(tc.cb) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selBlock == null ? Color(tc.tm) : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Text(L.unassigned,
                    style: TextStyle(
                        fontSize: 11,
                        color: _selBlock == null ? Color(tc.ts) : Color(tc.tm))),
              ),
            ),
            // Time block chips
            ...['morning', 'afternoon', 'evening'].map((blk) {
              final b = kBlocksForTheme(state.settings.theme)[blk]!;
              final col = b['color'] as Color;
              final active = _selBlock == blk;
              return GestureDetector(
                // Tap to select; tap again to deselect back to unassigned
                onTap: () => setState(() => _selBlock = active ? null : blk),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? col.withOpacity(0.13) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? col : Color(tc.brd),
                      width: 1.2,
                    ),
                  ),
                  child: Text('${b['emoji']} ${b['name']}',
                      style: TextStyle(
                          fontSize: 11,
                          color: active ? col : Color(tc.tm))),
                ),
              );
            }),
          ]),
        ),
        const SizedBox(height: 8),
        // Tag selector — long-press to reorder
        _buildTagSelector(state, tc),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _selBlock == null ? L.selectingHint : L.targetPool(kBlocksForTheme(state.settings.theme)[_selBlock]!['emoji'], kBlocksForTheme(state.settings.theme)[_selBlock]!['name']),
            style: TextStyle(fontSize: 9.5, color: _selBlock == null ? Color(tc.tm) : kBlocksForTheme(state.settings.theme)[_selBlock]!['color'] as Color, fontStyle: FontStyle.italic),
          ),
        ),
      ]),
    );
  }

  Widget _buildTagSelector(AppState state, ThemeConfig tc) {
    return StatefulBuilder(
      builder: (ctx, setSt) {
        return Wrap(
          spacing: 5, runSpacing: 5,
          children: state.tags.asMap().entries.map((entry) {
            final i = entry.key;
            final tag = entry.value;
            final sel = _selTags.contains(tag);
            final c = state.tagColor(tag);
            return LongPressDraggable<int>(
              key: ValueKey('tag_$tag'),
              data: i,
              hapticFeedbackOnStart: true,
              onDragStarted: () { setSt(() {}); HapticFeedback.mediumImpact(); },
              onDragCompleted: () => setSt(() {}),
              onDraggableCanceled: (_, __) => setSt(() {}),
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))]),
                  child: Text(tag, style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _tagChip(tag, sel, c, tc, () {}),
              ),
              child: DragTarget<int>(
                onWillAcceptWithDetails: (d) => d.data != i,
                onAcceptWithDetails: (d) {
                  state.reorderTag(d.data, i > d.data ? i + 1 : i);
                  setSt(() {});
                },
                builder: (_, candidateData, __) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: candidateData.isNotEmpty
                        ? Border.all(color: c, width: 1.5)
                        : null,
                  ),
                  child: _tagChip(tag, sel, c, tc, () => setState(() {
                    if (sel) _selTags.remove(tag); else _selTags.add(tag);
                  })),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _tagChip(String tag, bool sel, Color c, ThemeConfig tc, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? c : Color(tc.cb),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(tag, style: TextStyle(fontSize: 11, color: sel ? Color(tc.nt) : Color(tc.ct))),
      ),
    );


  // ── Unassigned pool + ignore zone ───────────────────────────
  Widget _buildUnassignedPool(AppState state, ThemeConfig tc,
      List tasks, String displayDate, String today) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) {
        // Only accept tasks that belong to displayDate (not overdue originals)
        return state.tasks.any((t) =>
            t.id == d.data &&
            t.originalDate == displayDate);
      },
      onAcceptWithDetails: (d) {
        state.setTaskTimeBlock(d.data, 'unassigned');
        HapticFeedback.lightImpact();
        setState(() => _draggingId = null);
      },
      builder: (_, candidateData, __) {
        final isOver = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: state.cardColor,
            borderRadius: BorderRadius.circular(13),
            border: isOver ? Border.all(color: Color(tc.acc), width: 2) : null,
            boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(L.unassigned, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(8)),
                child: Text('${tasks.length}', style: TextStyle(fontSize: 10, color: Color(tc.ts)))),
              if (isOver) ...[
                const Spacer(),
                Text(L.cancelAssign, style: TextStyle(fontSize: 10, color: Color(tc.acc), fontStyle: FontStyle.italic)),
              ],
            ]),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(L.unassignedHint,
                    style: TextStyle(fontSize: 11, color: Color(tc.tm)))))
            else
              Wrap(
                spacing: 6, runSpacing: 6,
                children: (tasks).map<Widget>((t) {
                  final firstTag = (t.tags as List).isNotEmpty ? (t.tags as List).first as String : null;
                  final c = firstTag != null ? state.tagColor(firstTag) : Color(tc.ts);
                  return _DraggableChip(
                    task: t, color: c, tc: tc,
                    onDragStarted: () => setState(() => _draggingId = t.id),
                    onDragEnd: () => setState(() => _draggingId = null),
                  );
                }).toList(),
              ),
          ]),
        );
      },
    );
  }

  // ── Time block (morning / afternoon / evening) ────────────
  Widget _buildTimeBlock(AppState state, ThemeConfig tc, String blk,
      String displayDate, String today) {
    final b = kBlocksForTheme(state.settings.theme)[blk]!;
    final color = b['color'] as Color;
    final tasks = state.tasks
        .where((t) {
          if (t.timeBlock != blk || t.ignored) return false;
          // Pending: belongs to displayDate (created here or rescheduled here)
          if (!t.done) {
            return t.createdAt == displayDate || t.rescheduledTo == displayDate;
          }
          // Completed: show if completed today AND (originally today OR rescheduled to today)
          return t.doneAt == displayDate &&
              (t.originalDate == displayDate || t.rescheduledTo == displayDate);
        })
        .toList();
    // Keep original list order — do NOT re-sort pending-before-done
    // tasks list preserves insertion order (newest first from addTask)
    final pending = tasks.where((t) => !t.done).toList();

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) {
        // Overdue task dragged here: reschedule (sets rescheduledTo) + assign block
        final task = state.tasks.firstWhere((t) => t.id == d.data, orElse: () => state.tasks.first);
        if (state.isOverdue(task)) {
          state.rescheduleTask(d.data);
        }
        state.setTaskTimeBlock(d.data, blk);
        HapticFeedback.lightImpact();
        setState(() => _draggingId = null);
      },
      builder: (_, candidateData, __) {
        final isOver = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: state.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: isOver
                ? Border.all(color: color, width: 2)
                : Border.all(color: Color(tc.brd).withOpacity(0.35), width: 1),
            boxShadow: isOver
                ? [BoxShadow(color: color.withOpacity(0.22), blurRadius: 14)]
                : [BoxShadow(color: Color(0x0C000000), blurRadius: 8, offset: const Offset(0,2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header with left accent bar
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                color: color.withOpacity(0.06),
              ),
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              child: Row(children: [
                Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('${b['emoji']} ${b['name']}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const Spacer(),
                if (isOver)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(L.dropHere,
                        style: TextStyle(fontSize: 10, color: color,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 4),
                Text('${pending.length}/${tasks.length}',
                    style: TextStyle(fontSize: 10, color: Color(tc.ts))),
              ]),
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text(L.dragOrAdd,
                        style: TextStyle(fontSize: 11, color: Color(tc.tm)))),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Builder(builder: (context) {
                  // Apply gravity sort to pending tasks if enabled
                  final pendingTasks = tasks.where((t) => !t.done).toList();
                  final doneTasks = tasks.where((t) => t.done).toList();
                  final sortedPending = betaTaskGravity(state.settings)
                      ? TaskGravity.sort(List.from(pendingTasks), state)
                      : pendingTasks;
                  final allSorted = [...sortedPending, ...doneTasks];
                  return Column(children: allSorted.map((t) => t.done
                    ? _CompletedTaskRow(task: t, state: state, tc: tc)
                    : _SlidableTaskTile(
                        task: t, state: state, tc: tc,
                        onDragStarted: () => setState(() => _draggingId = t.id),
                        onDragEnd: () => setState(() => _draggingId = null),
                        onPlayTap: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            AppState.switchToPomodoroTab?.call();
                          });
                        },
                      )).toList());
                }),
              ),
          ]),
        );
      },
    );
  }

  // ── Overdue section ───────────────────────────────────────
  Widget _buildOverdueSection(
      AppState state, ThemeConfig tc, List overdue, String today) {

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFc04040))),
          const SizedBox(width: 8),
          Text(L.overdue,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFc04040))),
          const SizedBox(width: 6),
          Text(L.overdueItems(overdue.length), style: TextStyle(fontSize: 10, color: Color(tc.ts))),
          const Spacer(),
          Text(L.overdueHint, style: TextStyle(fontSize: 9.5, color: Color(tc.tm), fontStyle: FontStyle.italic)),
        ]),
      ),
      // Overdue list — drag target for rescheduled tasks coming back
      DragTarget<int>(
        onWillAcceptWithDetails: (d) => state.tasks.any((t) =>
            t.id == d.data &&
            t.originalDate.compareTo(today) < 0 &&
            t.rescheduledTo != null),
        onAcceptWithDetails: (d) {
          state.unrescheduleTask(d.data);
          state.setTaskTimeBlock(d.data, 'unassigned');
          HapticFeedback.lightImpact();
          setState(() => _draggingId = null);
        },
        builder: (_, candidateData, __) {
          final isOver = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: isOver
                ? BoxDecoration(
                    color: const Color(0x18c04040),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFc04040), width: 1.5))
                : null,
            child: Column(children: [
              if (overdue.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text(L.overdueFree,
                        style: TextStyle(fontSize: 12, color: Color(tc.tm)))))
              else
                ...overdue.map((t) => _buildOverdueItem(state, tc, t, today)),
            ]),
          );
        },
      ),
    ]);
  }

  Widget _buildOverdueItem(
      AppState state, ThemeConfig tc, dynamic task, String today) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LongPressDraggable<int>(
        data: task.id,
        hapticFeedbackOnStart: true,
        onDragStarted: () {
          setState(() => _draggingId = task.id);
          HapticFeedback.mediumImpact();
        },
        onDragEnd: (_) => setState(() => _draggingId = null),
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: state.cardColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 18,
                      offset: Offset(0, 6))
                ]),
            child: Text(task.text,
                style: TextStyle(
                    fontSize: 12,
                    color: Color(tc.tx),
                    fontFamily: 'serif'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: _overdueCard(state, tc, task, today)),
        child: _overdueCard(state, tc, task, today),
      ),
    );
  }

  Widget _overdueCard(AppState state, ThemeConfig tc, dynamic task, String today) {
    return Slidable(
      key: ValueKey('overdue_${task.id}'),
      // Right swipe (startActionPane in LTR) → reveal 忽略
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.30,
        dismissible: DismissiblePane(
          onDismissed: () {
            state.ignoreTask(task.id);
            HapticFeedback.lightImpact();
          },
          closeOnCancel: true,
        ),
        children: [
          SlidableAction(
            onPressed: (_) {
              state.ignoreTask(task.id);
              HapticFeedback.lightImpact();
            },
            backgroundColor: Color(tc.tm),
            foregroundColor: Colors.white,
            icon: Icons.visibility_off_outlined,
            label: L.ignore,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
            color: state.cardColor, borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(task.text,
                    style: TextStyle(
                        fontSize: 13, color: Color(tc.tx), fontFamily: 'serif'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(L.overdueSince(DateUtils2.fmtFull(task.originalDate)),
                    style: const TextStyle(
                        fontSize: 9.5, color: Color(0xFFc04040))),
              ])),
          const SizedBox(width: 8),
          Icon(Icons.drag_indicator, size: 16, color: Color(tc.tm)),
        ]),
      ),
    );
  }
}

// ── Draggable chip (unassigned pool) ──────────────────────────
class _DraggableChip extends StatelessWidget {
  final dynamic task;
  final Color color;
  final ThemeConfig tc;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const _DraggableChip(
      {required this.task,
      required this.color,
      required this.tc,
      required this.onDragStarted,
      required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    final label = (task.text as String).length > 14
        ? '${(task.text as String).substring(0, 14)}…'
        : task.text as String;
    return LongPressDraggable<int>(
      data: task.id as int,
      onDragStarted: () {
        onDragStarted();
        HapticFeedback.mediumImpact();
      },
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: color.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 16,
                    offset: Offset(0, 5))
              ]),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white, fontFamily: 'serif')),
        ),
      ),
      childWhenDragging: Opacity(
          opacity: 0.3,
          child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: color)))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(fontSize: 12, color: color)),
      ),
    );
  }
}


// ── Slidable wrapper — left swipe → red delete ────────────────
class _SlidableTaskTile extends StatelessWidget {
  final dynamic task;
  final AppState state;
  final ThemeConfig tc;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final VoidCallback? onPlayTap;

  const _SlidableTaskTile({
    required this.task, required this.state, required this.tc,
    required this.onDragStarted, required this.onDragEnd,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey('task_${task.id}'),
      // Left swipe (endActionPane in LTR) → red delete
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.28,
        dismissible: DismissiblePane(
          onDismissed: () {
            state.deleteTask(task.id as int);
            HapticFeedback.mediumImpact();
          },
          closeOnCancel: true,
        ),
        children: [
          SlidableAction(
            onPressed: (_) {
              state.deleteTask(task.id as int);
              HapticFeedback.mediumImpact();
            },
            backgroundColor: const Color(0xFFD93E3E),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: L.delete,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      child: _DraggableTaskTile(
        task: task, state: state, tc: tc,
        onDragStarted: onDragStarted, onDragEnd: onDragEnd,
        onPlayTap: onPlayTap,
      ),
    );
  }
}

// ── Draggable task tile (in time block) ───────────────────────
class _DraggableTaskTile extends StatelessWidget {
  final dynamic task;
  final AppState state;
  final ThemeConfig tc;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final VoidCallback? onPlayTap;

  const _DraggableTaskTile(
      {required this.task,
      required this.state,
      required this.tc,
      required this.onDragStarted,
      required this.onDragEnd,
      this.onPlayTap});

  @override
  Widget build(BuildContext context) {
    final t = task;
    return LongPressDraggable<int>(
      data: t.id as int,
      onDragStarted: () {
        onDragStarted();
        HapticFeedback.mediumImpact();
      },
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: state.cardColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 18,
                    offset: Offset(0, 6))
              ]),
          child: Text(t.text as String,
              style: TextStyle(
                  fontSize: 12, color: Color(tc.tx), fontFamily: 'serif'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(
          opacity: 0.25,
          child: TaskTile(task: t, compact: true)),
      child: Row(children: [
        Expanded(child: TaskTile(task: t, compact: true, onPlayTap: onPlayTap)),
        Icon(Icons.drag_indicator, size: 14, color: Color(tc.tm)),
        const SizedBox(width: 4),
      ]),
    );
  }
}

// ── Completed task with right-swipe completion-block override ─
class _CompletedTaskRow extends StatelessWidget {
  final TaskModel task;
  final AppState state;
  final ThemeConfig tc;
  const _CompletedTaskRow({required this.task, required this.state, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey('done_${task.id}'),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) => state.setTaskDoneTimeBlock(task.id, 'morning'),
            backgroundColor: const Color(0xFFe8982a),
            foregroundColor: Colors.white,
            icon: null,
            label: '🌅',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
          ),
          SlidableAction(
            onPressed: (_) => state.setTaskDoneTimeBlock(task.id, 'afternoon'),
            backgroundColor: const Color(0xFF3a90c0),
            foregroundColor: Colors.white,
            label: '☀️',
          ),
          SlidableAction(
            onPressed: (_) => state.setTaskDoneTimeBlock(task.id, 'evening'),
            backgroundColor: const Color(0xFF7a5ab8),
            foregroundColor: Colors.white,
            label: '🌙',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
          ),
        ],
      ),
      child: TaskTile(task: task, compact: true),
    );
  }
}

// ── Spring add button ────────────────────────────────────────────────────────
class _SpringAddBtn extends StatefulWidget {
  final ThemeConfig tc;
  final VoidCallback onTap;
  const _SpringAddBtn({required this.tc, required this.onTap});
  @override
  State<_SpringAddBtn> createState() => _SpringAddBtnState();
}
class _SpringAddBtnState extends State<_SpringAddBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _sc;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _sc = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _sc, curve: Curves.easeIn));
  }
  @override
  void dispose() { _sc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _sc.forward(),
    onTapUp: (_) { _sc.reverse(); widget.onTap(); },
    onTapCancel: () => _sc.reverse(),
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Color(widget.tc.na), shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: Color(widget.tc.na).withOpacity(0.35),
            blurRadius: 8, offset: const Offset(0, 3))]),
        child: Icon(Icons.add, color: Color(widget.tc.nt), size: 21)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 今日界面底部：智能建议迷你面板（只显示 smart plan，不含屏幕使用）
// ─────────────────────────────────────────────────────────────────────────────
class _SmartPlanPanel extends StatefulWidget {
  const _SmartPlanPanel();
  @override
  State<_SmartPlanPanel> createState() => _SmartPlanPanelState();
}

class _SmartPlanPanelState extends State<_SmartPlanPanel> {
  String? _noiseInsight;
  String? _flowInsight;
  late Map<UIField, String> _ui;

  @override
  void initState() {
    super.initState();
    _refreshUI();
    NoiseHistoryStore.buildInsight().then((s) {
      if (mounted && s != null) setState(() {
        _noiseInsight = s;
        _refreshUI();
      });
    });
    FocusQualityService.buildFlowInsight().then((s) {
      if (mounted && s != null) setState(() {
        _flowInsight = s;
        _refreshUI();
      });
    });
  }

  void _refreshUI() {
    _ui = DisplayAdapter.getDisplayData(SmartPlanPageState());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    if (!betaSmartPlan(state.settings)) return const SizedBox.shrink();

    final suggestion = SmartPlan.suggest(state, noiseInsight: _noiseInsight, flowInsight: _flowInsight);
    final acc = Color(tc.acc);
    _refreshUI(); // 确保 state 变化时 UI 映射同步更新

    void goDetail() => Navigator.push(context, PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => ChangeNotifierProvider.value(
        value: state,
        child: _SmartPlanDetailPage(state: state, tc: tc)),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim,
                curve: Curves.easeInOutCubic)),
        child: child)));

    // Key metrics chosen by smart plan
    final keyMetrics = _buildKeyMetrics(suggestion, state, tc, acc, _ui);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: goDetail,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        decoration: BoxDecoration(
          color: state.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Color(tc.acc).withOpacity(0.08), blurRadius: 12,
                offset: const Offset(0, 3)),
          ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── 顶部渐变栏：HPI仪表 + 标题 + 箭头 ─────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Color(tc.acc).withOpacity(0.08),
                  Color(tc.acc2).withOpacity(0.04),
                ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // HPI 圆弧仪表
              if (suggestion.hpi != null)
                _MiniHpi(hpi: suggestion.hpi!, tc: tc)
              else
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(tc.acc).withOpacity(0.10)),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 16)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(_ui[UIField.smartPlanTitle]!, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Color(tc.tx))),
                  const SizedBox(width: 8),
                  if (suggestion.moves.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(tc.acc).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(L.smartPlanItemsToSchedule(suggestion.moves.length),
                        style: TextStyle(fontSize: 10,
                            color: Color(tc.acc), fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 2),
                if (suggestion.hpiLabel != null)
                  Text(suggestion.hpiLabel!, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(tc.ts)))
                else
                  Text(_ui[UIField.smartPlanViewDetail]!,
                    style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              ])),
              Icon(Icons.chevron_right_rounded, size: 22, color: Color(tc.tm)),
            ])),

          // ── 指标 chips 横滚条 ──────────────────────────────────────────
          if (keyMetrics.isNotEmpty) ...[
            SizedBox(
              height: 70,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                scrollDirection: Axis.horizontal,
                itemCount: keyMetrics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _MetricChip(metric: keyMetrics[i], tc: tc))),
          ],

          // ── 任务建议列 ─────────────────────────────────────────────────
          if (suggestion.moves.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(children: suggestion.moves.take(3).map((m) {
                final task = state.tasks.firstWhere(
                    (t) => t.id.toString() == m.taskId,
                    orElse: () => state.tasks.first);
                final isBH = state.settings.theme == 'black_hole';
                final blkColor = isBH ? {
                  'morning': Color(tc.acc),
                  'afternoon': Color(tc.acc2),
                  'evening': Color(tc.ts),
                }[m.suggestedBlock] ?? Color(tc.acc) : {
                  'morning': const Color(0xFFe8982a),
                  'afternoon': const Color(0xFF3a90c0),
                  'evening': const Color(0xFF7a5ab8),
                }[m.suggestedBlock] ?? Color(tc.acc);
                final blkEmoji = isBH ? {
                  'morning': '🚀', 'afternoon': '🛰️', 'evening': '🛸',
                }[m.suggestedBlock] ?? '📌' : {
                  'morning': '🌅', 'afternoon': '☀️', 'evening': '🌙',
                }[m.suggestedBlock] ?? '📌';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Text(blkEmoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(task.text, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Color(tc.tx)))),
                    GestureDetector(
                      onTap: () {
                        state.setTaskTimeBlock(int.parse(m.taskId), m.suggestedBlock);
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: blkColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: blkColor.withOpacity(0.25))),
                        child: Text(_ui[UIField.smartPlanScheduleBtn]!, style: TextStyle(
                            fontSize: 10.5, color: blkColor,
                            fontWeight: FontWeight.w700)))),
                  ]));
              }).toList())),

            // 一键安排按钮
            if (suggestion.moves.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: GestureDetector(
                  onTap: () {
                    for (final m in suggestion.moves) {
                      state.setTaskTimeBlock(int.parse(m.taskId), m.suggestedBlock);
                    }
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(L.smartPlanAllScheduled(suggestion.moves.length)),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2)));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Color(tc.acc).withOpacity(0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Color(tc.acc).withOpacity(0.22))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.bolt_rounded, size: 15, color: Color(tc.acc)),
                      const SizedBox(width: 4),
                      Text(L.smartPlanScheduleAll(suggestion.moves.length),
                        style: TextStyle(fontSize: 12, color: Color(tc.acc),
                            fontWeight: FontWeight.w700)),
                    ])))),
          ],

          // ── 警告条 ────────────────────────────────────────────────────
          if (suggestion.loadWarning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFe8982a).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFe8982a).withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 14,
                      color: Color(0xFFe8982a)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(suggestion.loadWarning,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11,
                        color: Color(0xFFe8982a)))),
                ]))),

          // ── 底部：查看详细分析 ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              Text(_ui[UIField.smartPlanViewFullAnalysis]!, style: TextStyle(
                  fontSize: 11.5, color: Color(tc.acc),
                  fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 13, color: Color(tc.acc)),
            ])),
        ]),
      ));
  }

  // Build key metrics chosen by smart plan
  static List<_KeyMetric> _buildKeyMetrics(
      DaySuggestion s, AppState state, ThemeConfig tc, Color acc, Map<UIField, String> ui) {
    final metrics = <_KeyMetric>[];
    final today = state.todayKey;
    
    // 1. 今日完成率（如有数据）
    final todayDone = state.doneOnDay(today);
    final todayTotal = state.tasks.where((t) =>
        !t.ignored && t.createdAt == today).length;
    if (todayTotal > 0) {
      final pct = (todayDone / todayTotal * 100).round();
      metrics.add(_KeyMetric(
        icon: '✅', label: ui[UIField.smartPlanMetricTodayDone]!,
        value: '$todayDone/$todayTotal',
        sub: '$pct%',
        color: pct >= 70 ? const Color(0xFF4A9068) : const Color(0xFFe8982a)));
    }

    // 2. 负载预警
    if (s.loadWarning.isNotEmpty) {
      final isOver = s.loadWarning.contains('超出');
      metrics.add(_KeyMetric(
        icon: isOver ? '⚠️' : '✓',
        label: ui[UIField.smartPlanMetricLoad]!,
        value: isOver ? ui[UIField.smartPlanMetricOverload]! : ui[UIField.smartPlanMetricModerate]!,
        sub: '',
        color: isOver ? const Color(0xFFc04040) : const Color(0xFF4A9068)));
    }

    // 3. 效率趋势
    if (s.trendLabel.isNotEmpty) {
      metrics.add(_KeyMetric(
        icon: s.trendLabel.contains('上升') ? '📈' : '📉',
        label: ui[UIField.smartPlanMetricTrend]!,
        value: s.trendLabel.contains('上升') ? ui[UIField.smartPlanMetricTrendUp]! : ui[UIField.smartPlanMetricTrendDown]!,
        sub: '',
        color: s.trendLabel.contains('上升')
            ? const Color(0xFF4A9068) : const Color(0xFFe8982a)));
    }

    // 4. 待安排任务数
    if (s.moves.isNotEmpty) {
      metrics.add(_KeyMetric(
        icon: '📋', label: L.smartPlanMetricToSchedule,
        value: L.smartPlanMetricToScheduleValue(s.moves.length),
        sub: L.smartPlanMetricOptimizable,
        color: acc));
    }

    // 5. 习惯提醒（如果有习惯相关洞察）
    final habitInsight = s.insights
        .where((i) => i.icon == '🔥' || i.icon == '📅').firstOrNull;
    if (habitInsight != null) {
      metrics.add(_KeyMetric(
        icon: '🔥', label: L.smartPlanMetricHabit,
        value: L.smartPlanMetricReminder,
        sub: habitInsight.title.length > 6
            ? habitInsight.title.substring(0, 6) + '…'
            : habitInsight.title,
        color: const Color(0xFF7a5ab8)));
    }

    // 6. 心流指数（有 flowInsight 时显示）
    if (s.flowInsight != null) {
      final isHigh = s.flowInsight!.contains('上升') || s.flowInsight!.contains('增强');
      final isLow  = s.flowInsight!.contains('偏低') || s.flowInsight!.contains('下滑');
      metrics.add(_KeyMetric(
        icon: isHigh ? '🔥' : isLow ? '💧' : '✨',
        label: L.smartPlanMetricFlow,
        value: isHigh ? L.smartPlanMetricFlowUp : isLow ? L.smartPlanMetricFlowLow : L.smartPlanMetricFlowStable,
        sub: '',
        color: isHigh ? const Color(0xFFFFB300)
             : isLow  ? const Color(0xFF3a90c0)
             : const Color(0xFF4A9068)));
    }

    return metrics;
  }
}

class _KeyMetric {
  final String icon, label, value, sub;
  final Color color;
  const _KeyMetric({required this.icon, required this.label,
      required this.value, required this.sub, required this.color});
}

class _MetricChip extends StatelessWidget {
  final _KeyMetric metric;
  final ThemeConfig tc;
  const _MetricChip({required this.metric, required this.tc});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 72, maxWidth: 110),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: metric.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: metric.color.withOpacity(0.20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(metric.icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Flexible(child: Text(metric.label, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: Color(tc.tm)))),
        ]),
        const SizedBox(height: 2),
        Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: metric.color, height: 1.0)),
        if (metric.sub.isNotEmpty)
          Text(metric.sub, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8.5,
                color: metric.color.withOpacity(0.7))),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// 智能建议详情页 — 全量分析展示
// ─────────────────────────────────────────────────────────────────────────────
class _SmartPlanDetailPage extends StatefulWidget {
  final AppState state;
  final ThemeConfig tc;
  const _SmartPlanDetailPage({required this.state, required this.tc});
  @override State<_SmartPlanDetailPage> createState() => _SmartPlanDetailPageState();
}

class _SmartPlanDetailPageState extends State<_SmartPlanDetailPage> {
  UsageSummary? _usage;
  bool _loadingUsage = true;
  String? _noiseInsight;
  String? _flowInsight;
  String? _robotMessage;       // current displayed message
  bool _showingSoup = false;   // true = showing chicken soup

  static List<String> get _soupList => L.smartPlanSoups;
  static List<String> get _adviceList => L.smartPlanAdvice;

  /// 每日激励语个性化：融合时段、完成情况、HPI、任务量、专注时长、偏差习惯
  String _getRobotGreeting(DaySuggestion suggestion) {
    final state = context.read<AppState>();
    final today = state.todayKey;
    final hpi   = suggestion.hpi;

    // ── 基础数据 ─────────────────────────────────────────────────────────
    final todayTasks = state.tasks
        .where((t) => !t.ignored &&
            (t.createdAt == today || t.rescheduledTo == today))
        .toList();
    final totalCount    = todayTasks.length;
    final doneCount     = todayTasks.where((t) => t.done).length;
    final pendingCount  = totalCount - doneCount;
    final focusSecs     = state.todayFocusSecs();
    final focusMins     = focusSecs ~/ 60;

    // 时段
    final hour = DateTime.now().hour;
    final isMorning   = hour >= 5  && hour < 11;
    final isAfternoon = hour >= 11 && hour < 17;
    final isEvening   = hour >= 17 && hour < 22;

    // 连续活跃天数
    int streakDays = 0;
    for (int i = 0; i < 7; i++) {
      if (state.tasks.any((t) => t.doneAt == DateUtils2.addDays(today, -i))) streakDays++;
      else if (i > 0) break;
    }

    // ── 逻辑分支 ────────────────────────────────────────────────────────
    if (totalCount > 0 && doneCount == totalCount) {
      return L.smartPlanGreetingAllDone(totalCount, focusMins);
    }
    if (totalCount == 0) {
      if (isMorning) return L.smartPlanGreetingMorning(0);
      return L.smartPlanGreetingNight;
    }
    if (hpi != null && hpi >= 80) {
      return L.smartPlanGreetingMorning(totalCount);
    }
    if (streakDays >= 5) {
      return L.smartPlanGreetingStreak(streakDays);
    }
    if (isMorning) return L.smartPlanGreetingMorning(totalCount);
    if (isAfternoon) return L.smartPlanGreetingAfternoon(doneCount, totalCount);
    if (isEvening) return L.smartPlanGreetingEvening(pendingCount);
    
    return L.smartPlanGreetingNight;
  }

  String _w(String? prefix, String msg) =>
      prefix != null ? '$prefix\n$msg' : msg;

    /// 节日当天的专属问候前缀（一句话，带emoji）
  String _festivalGreeting(FestivalInfo festival) {
    switch (festival.id) {
      case 'dragon_boat':
        return L.smartPlanFestivalDragonBoat;
      case 'lunar_new_year':
        return L.smartPlanFestivalNewYear;
      case 'mid_autumn':
        return L.smartPlanFestivalMidAutumn;
      case 'world_water_day':
        return L.smartPlanFestivalWaterDay;
      default:
        return L.smartPlanFestivalDefault(festival.emoji, festival.name, festival.tagline);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final hasPerm = await UsageStatsService.hasPermission();
    if (hasPerm && mounted) {
      _usage = await UsageStatsService.getTodayUsage(
        userCategories: widget.state.settings.userAppCategories);
    }
    // Also load noise insight for smart plan
    final ni = await NoiseHistoryStore.buildInsight();
    final fi = await FocusQualityService.buildFlowInsight();
    if (mounted) {
      setState(() {
        _loadingUsage = false;
        _noiseInsight = ni;
        _flowInsight  = fi;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tc = widget.tc;
    final acc = Color(tc.acc);
    final suggestion = SmartPlan.suggest(state, usage: _usage, noiseInsight: _noiseInsight, flowInsight: _flowInsight);
    final psych = PsychAnalyzer.analyze(state);
    final estHours = SmartPlan.estimateDisposableHours(state, usage: _usage);
    final suggestedH = estHours['suggested'] as double;
    final currentH = state.settings.disposableHours;

    final taskIns = suggestion.insights
        .where((i) => i.source == InsightSource.task ||
                      i.source == InsightSource.crossTask ||
                      i.source == InsightSource.trend).toList();
    final crossIns = suggestion.insights
        .where((i) => i.source == InsightSource.crossScreen ||
                      i.source == InsightSource.screen).toList();

    final hpi = suggestion.hpi;
    final hpiColor = hpi == null ? Color(tc.ts)
        : hpi >= 80 ? const Color(0xFF4A9068)
        : hpi >= 65 ? const Color(0xFF3A90C0)
        : hpi >= 45 ? const Color(0xFFDAA520)
        : const Color(0xFFE07040);
    final procColor = psych.procrastinationIndex < 35
        ? const Color(0xFF4A9068)
        : psych.procrastinationIndex < 60
            ? const Color(0xFFe8982a)
            : const Color(0xFFc04040);

    return Scaffold(
      backgroundColor: Color(tc.bg),
      appBar: AppBar(
        backgroundColor: Color(tc.bg), elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context)),
        title: Text(L.smartPlanDetailTitle,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: Color(tc.tx))),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: acc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${L.get('screens.today.smartPlan.badgeV5')}${_usage != null ? L.get('screens.today.smartPlan.badgeScreenSuffix') : ''}',
                style: TextStyle(fontSize: 10, color: acc)))),
          IconButton(
            icon: Icon(Icons.ios_share_rounded, size: 19, color: acc),
            tooltip: L.shareTodaySummary,
            padding: const EdgeInsets.only(right: 12),
            onPressed: () => showShareCardSheet(context),
          ),
        ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        children: [

          // ════════════════════════════════════════════════════════════════
          // HERO: 机器人助手卡片
          // ════════════════════════════════════════════════════════════════
          StatefulBuilder(builder: (ctx, setSt) {
            final greeting = _getRobotGreeting(suggestion);
            final msg = _robotMessage ?? greeting;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    acc.withOpacity(0.12),
                    Color(tc.acc2).withOpacity(0.06),
                  ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: acc.withOpacity(0.20))),
              child: Column(children: [
                // 机器人头像区
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // 机器人大头像 (点击触发鸡汤彩蛋)
                    GestureDetector(
                      onTap: () {
                        final r = DateTime.now().millisecondsSinceEpoch;
                        final soup = _soupList[r % _soupList.length];
                        setState(() {
                          _robotMessage = soup;
                          _showingSoup = true;
                        });
                        HapticFeedback.mediumImpact();
                        Future.delayed(const Duration(seconds: 5), () {
                          if (mounted) setState(() {
                            _robotMessage = null;
                            _showingSoup = false;
                          });
                        });
                      },
                      child: Stack(alignment: Alignment.center, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _showingSoup
                                ? acc.withOpacity(0.20)
                                : acc.withOpacity(0.12),
                            border: Border.all(
                                color: acc.withOpacity(0.30), width: 2)),
                          child: Center(child: Text(
                            _showingSoup ? '💬' : '🤖',
                            style: const TextStyle(fontSize: 32)))),
                        if (!_showingSoup)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: acc,
                                border: Border.all(
                                    color: state.cardColor, width: 1.5)),
                              child: const Icon(Icons.touch_app_rounded,
                                  size: 10, color: Colors.white))),
                      ])),
                    const SizedBox(width: 14),
                    // 对话气泡
                    Expanded(child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: state.cardColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14))),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(msg,
                          key: ValueKey(msg),
                          style: TextStyle(
                            fontSize: 13,
                            color: _showingSoup ? acc : Color(tc.tx),
                            height: 1.55,
                            fontWeight: _showingSoup
                                ? FontWeight.w600 : FontWeight.normal)),
                      ))),
                  ])),
                if (_showingSoup)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(L.smartPlanClickRobot,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(tc.tm)))),
                // 操作按钮行
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(children: [
                    // 新建议按钮
                    Expanded(child: GestureDetector(
                      onTap: () {
                        final r = DateTime.now().millisecondsSinceEpoch;
                        final advice = _adviceList[r % _adviceList.length];
                        setState(() {
                          _robotMessage = advice;
                          _showingSoup = false;
                        });
                        HapticFeedback.lightImpact();
                        Future.delayed(const Duration(seconds: 8), () {
                          if (mounted) setState(() => _robotMessage = null);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: acc.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: acc.withOpacity(0.25))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              size: 14, color: acc),
                          const SizedBox(width: 6),
                          Text(L.smartPlanGiveAdvice, style: TextStyle(
                              fontSize: 12, color: acc,
                              fontWeight: FontWeight.w600)),
                        ])))),
                    const SizedBox(width: 10),
                    // 一键安排按钮
                    if (suggestion.moves.isNotEmpty)
                      Expanded(child: GestureDetector(
                        onTap: () {
                          for (final m in suggestion.moves) {
                            widget.state.setTaskTimeBlock(
                                int.parse(m.taskId), m.suggestedBlock);
                          }
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _robotMessage = L.smartPlanScheduledMsg(suggestion.moves.length);
                            _showingSoup = false;
                          });
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) setState(() => _robotMessage = null);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: acc,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(
                                color: acc.withOpacity(0.30),
                                blurRadius: 8, offset: const Offset(0, 3))]),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            const Icon(Icons.bolt_rounded, size: 14,
                                color: Colors.white),
                            const SizedBox(width: 6),
                            Text(L.smartPlanOneClickPlan, style: const TextStyle(
                                fontSize: 12, color: Colors.white,
                                fontWeight: FontWeight.w700)),
                          ])))),
                  ])),
              ]));
          }),

          // ── Row 1: HPI仪表 + 拖延指数 ──────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // HPI 圆弧仪表
            Expanded(flex: 3, child: _DetailBrick(tc: tc,
              accent: hpiColor,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  SizedBox(width: 72, height: 72,
                    child: CustomPaint(
                      painter: _DetailGaugePainter(
                          value: (hpi ?? 0) / 100.0,
                          color: hpiColor, bg: Color(tc.brd)),
                      child: Center(child: Column(
                        mainAxisSize: MainAxisSize.min, children: [
                        Text('${hpi ?? '--'}', style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: hpiColor, height: 1.0)),
                        Text('HPI', style: TextStyle(
                          fontSize: 8, color: Color(tc.tm),
                          letterSpacing: 1.0)),
                      ])))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(L.smartPlanEfficiencyIndex, style: TextStyle(
                        fontSize: 10, color: Color(tc.ts))),
                    const SizedBox(height: 3),
                    if (suggestion.hpiLabel != null)
                      Text(suggestion.hpiLabel!,
                        style: TextStyle(fontSize: 10.5,
                            color: hpiColor, height: 1.3)),
                  ])),
                ]),
                const SizedBox(height: 8),
                Text(suggestion.summary,
                  style: TextStyle(fontSize: 10.5, color: Color(tc.ts),
                      height: 1.45),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              ]))),
            const SizedBox(width: 8),
            // 拖延指数
            Expanded(flex: 2, child: _DetailBrick(tc: tc,
              accent: procColor,
              child: Column(crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 56, height: 56,
                  child: CustomPaint(
                    painter: _DetailGaugePainter(
                        value: psych.procrastinationIndex / 100.0,
                        color: procColor, bg: Color(tc.brd)),
                    child: Center(child: Text(
                      '${psych.procrastinationIndex}',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: procColor, height: 1.0))))),
                const SizedBox(height: 6),
                Text(L.smartPlanProcrastinationIndex, style: TextStyle(
                    fontSize: 9.5, color: Color(tc.ts))),
                const SizedBox(height: 2),
                Text(psych.cognitivePattern, style: TextStyle(
                    fontSize: 10, color: Color(tc.tx),
                    fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ]))),
          ]),
          const SizedBox(height: 8),

          // ── Row 2: 时段分布 + 可支配时长 ────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _DetailBrick(tc: tc,
              accent: const Color(0xFF3A90C0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _BrickLabel(icon: '📊', label: L.smartPlanBlockDistribution, tc: tc),
                const SizedBox(height: 8),
                _BlockBarChart(state: state, tc: tc, acc: acc),
              ]))),
            const SizedBox(width: 8),
            Expanded(child: _DetailBrick(tc: tc,
              accent: acc,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _BrickLabel(icon: '⏱', label: L.smartPlanDisposableTime, tc: tc),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${suggestedH.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                        color: acc, height: 1.0)),
                  Padding(padding: const EdgeInsets.only(bottom: 3),
                    child: Text('h', style: TextStyle(
                        fontSize: 12, color: Color(tc.ts)))),
                ]),
                Text(L.smartPlanMetricCurrentHours(currentH.toStringAsFixed(1)),
                  style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
                const SizedBox(height: 4),
                Text(estHours['reason'] as String,
                  style: TextStyle(fontSize: 9.5, color: Color(tc.ts),
                      height: 1.35),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
                if ((suggestedH - currentH).abs() > 0.4) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      state.setDisposableHours(suggestedH);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(L.smartPlanUpdatedHours(suggestedH.toStringAsFixed(1))),
                        behavior: SnackBarBehavior.floating));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: acc.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: acc.withOpacity(0.25))),
                      child: Text(L.smartPlanApplyAISuggestion,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, color: acc,
                            fontWeight: FontWeight.w600)))),
                ],
              ]))),
          ]),
          const SizedBox(height: 8),

          // ── 任务负载警告 ────────────────────────────────────────────────
          if (suggestion.loadWarning.isNotEmpty) ...[
            _DetailBrick(tc: tc,
              accent: suggestion.loadWarning.startsWith('⚠')
                  ? const Color(0xFFE07040) : const Color(0xFF4A9068),
              child: Row(children: [
                Icon(
                  suggestion.loadWarning.startsWith('⚠')
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 18,
                  color: suggestion.loadWarning.startsWith('⚠')
                      ? const Color(0xFFE07040) : const Color(0xFF4A9068)),
                const SizedBox(width: 10),
                Expanded(child: Text(suggestion.loadWarning,
                  style: TextStyle(fontSize: 11.5, color: Color(tc.ts),
                      height: 1.4))),
              ])),
            const SizedBox(height: 8),
          ],

          // ── 任务安排建议 ────────────────────────────────────────────────
          if (suggestion.moves.isNotEmpty) ...[
            _BrickSectionLabel(icon: '⚡', label: L.smartPlanTaskScheduleAdvice,
              sub: L.smartPlanTotalItems(suggestion.moves.length), tc: tc),
            _DetailBrick(tc: tc, accent: acc,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(children: [
                ...suggestion.moves.map((m) {
                  final task = state.tasks.firstWhere(
                      (t) => t.id.toString() == m.taskId,
                      orElse: () => state.tasks.first);
                  final isBH = state.settings.theme == 'black_hole';
                  final blkColor = isBH ? {
                    'morning': Color(tc.acc),
                    'afternoon': Color(tc.acc2),
                    'evening': Color(tc.ts),
                  }[m.suggestedBlock] ?? Color(tc.acc) : {
                    'morning': const Color(0xFFe8982a),
                    'afternoon': const Color(0xFF3a90c0),
                    'evening': const Color(0xFF7a5ab8),
                  }[m.suggestedBlock] ?? Color(tc.acc);
                  final blkEmoji = isBH ? {
                    'morning': '🚀', 'afternoon': '🛰️', 'evening': '🛸',
                  }[m.suggestedBlock] ?? '📌' : {
                    'morning': '🌅', 'afternoon': '☀️', 'evening': '🌙',
                  }[m.suggestedBlock] ?? '📌';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Text(blkEmoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(task.text, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5,
                              fontWeight: FontWeight.w600, color: Color(tc.tx))),
                        Text(m.reason, style: TextStyle(fontSize: 10,
                            color: Color(tc.ts), height: 1.3)),
                      ])),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          state.setTaskTimeBlock(int.parse(m.taskId), m.suggestedBlock);
                          HapticFeedback.lightImpact();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: blkColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(7)),
                          child: Text(L.smartPlanScheduleBtn, style: TextStyle(
                              fontSize: 10.5, color: blkColor,
                              fontWeight: FontWeight.w700)))),
                    ]));
                }),
                if (suggestion.moves.length > 1)
                  GestureDetector(
                    onTap: () {
                      for (final m in suggestion.moves) {
                        state.setTaskTimeBlock(int.parse(m.taskId), m.suggestedBlock);
                      }
                      HapticFeedback.mediumImpact();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(L.smartPlanAllScheduled(suggestion.moves.length)),
                        behavior: SnackBarBehavior.floating));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: acc.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: acc.withOpacity(0.22))),
                      child: Text('⚡ ' + L.smartPlanScheduleAll(suggestion.moves.length),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: acc,
                            fontWeight: FontWeight.w600)))),
              ])),
            const SizedBox(height: 8),
          ],

          // ── 心理学分析 ──────────────────────────────────────────────────
          _BrickSectionLabel(icon: '🧠', label: L.smartPlanPsychologyAnalysis, tc: tc),
          _DetailBrick(tc: tc, accent: const Color(0xFF7a5ab8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(psych.selfEfficacy,
              style: TextStyle(fontSize: 11, color: Color(tc.ts), height: 1.5)),
            const SizedBox(height: 10),
            ...psych.insights.map((ins) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 4, height: 4,
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF7a5ab8))),
                Expanded(child: Text(ins, style: TextStyle(
                    fontSize: 10.5, color: Color(tc.ts), height: 1.45))),
              ]))),
          ])),
          if (psych.recommendations.isNotEmpty) ...[
            const SizedBox(height: 6),
            _DetailBrick(tc: tc, accent: acc,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _BrickLabel(icon: '🎯', label: L.smartPlanImprovementAdvice, tc: tc),
              const SizedBox(height: 8),
              ...psych.recommendations.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: acc.withOpacity(0.12)),
                    child: Center(child: Text('${e.key + 1}',
                      style: TextStyle(fontSize: 9.5, color: acc,
                          fontWeight: FontWeight.w700)))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value,
                    style: TextStyle(fontSize: 11, color: Color(tc.ts),
                        height: 1.5))),
                ]))),
            ])),
          ],
          const SizedBox(height: 8),

          // ══════════════════════════════════════════════════════════════
          // 任务效率洞察 — 图表化展示
          // ══════════════════════════════════════════════════════════════
          if (taskIns.isNotEmpty) ...[
            _BrickSectionLabel(icon: '💡', label: L.smartPlanTaskEfficiencyInsight,
              sub: L.smartPlanFindings(taskIns.length), tc: tc),
            const SizedBox(height: 6),
            // ── 置信度分布饼图 + 洞察分布 ────────────────────────────────
            _DetailBrick(tc: tc, accent: acc,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _BrickLabel(icon: '📊', label: L.smartPlanInsightOverview, tc: tc),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Confidence pie
                  SizedBox(width: 80, height: 80,
                    child: CustomPaint(painter: _ConfidencePiePainter(
                      insights: taskIns,
                      highColor: const Color(0xFF4A9068),
                      medColor: const Color(0xFFDAA520),
                      lowColor: const Color(0xFF888888)))),
                  const SizedBox(width: 14),
                  // Legend + counts
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _ConfLegendRow(color: const Color(0xFF4A9068), label: L.smartPlanHighConfidence,
                      count: taskIns.where((i) => i.confidence == Confidence.high).length),
                    const SizedBox(height: 5),
                    _ConfLegendRow(color: const Color(0xFFDAA520), label: L.smartPlanMedConfidence,
                      count: taskIns.where((i) => i.confidence == Confidence.medium).length),
                    const SizedBox(height: 5),
                    _ConfLegendRow(color: const Color(0xFF888888), label: L.smartPlanLowConfidence,
                      count: taskIns.where((i) => i.confidence == Confidence.low).length),
                  ])),
                ]),
              ])),
            const SizedBox(height: 6),
            // ── 来源分布横向条形图 ───────────────────────────────────────
            _DetailBrick(tc: tc, accent: const Color(0xFF3A90C0),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _BrickLabel(icon: '🗂', label: L.smartPlanSourceDistribution, tc: tc),
                const SizedBox(height: 10),
                _InsightSourceBar(insights: taskIns, tc: tc),
              ])),
            const SizedBox(height: 6),
            // ── 各洞察卡片 (新美术) ──────────────────────────────────────
            ...taskIns.asMap().entries.map((e) {
              final idx = e.key; final ins = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _InsightChartCard(ins: ins, tc: tc, idx: idx));
            }),
            const SizedBox(height: 8),
          ],

          // ── 心流指数洞察卡 ────────────────────────────────────────────
          if (suggestion.flowInsight != null) ...[
            _BrickSectionLabel(icon: '🔥', label: L.smartPlanFlowAnalysis,
              sub: L.smartPlanFlowLast14Days, tc: tc),
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: state.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.25))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withOpacity(0.12),
                    shape: BoxShape.circle),
                  child: const Center(child: Text('🔥',
                      style: TextStyle(fontSize: 16)))),
                const SizedBox(width: 10),
                Expanded(child: Text(suggestion.flowInsight!,
                  style: TextStyle(fontSize: 12, color: Color(tc.ts),
                      height: 1.55))),
              ])),
            const SizedBox(height: 8),
          ],

          // ══════════════════════════════════════════════════════════════
          // 屏幕使用 × 任务交叉 — 图表化展示
          // ══════════════════════════════════════════════════════════════
          if (_loadingUsage)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: state.cardColor, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: const Color(0xFF3a90c0))),
                const SizedBox(width: 12),
                Text(L.smartPlanLoadingUsage,
                  style: TextStyle(fontSize: 11, color: Color(tc.ts))),
              ]))
          else if (crossIns.isNotEmpty) ...[
            _BrickSectionLabel(icon: '📱', label: L.smartPlanScreenCross,
              sub: L.smartPlanFindings(crossIns.length), tc: tc),
            const SizedBox(height: 6),
            // ── 屏幕使用时长分布 箱型图风格 ──────────────────────────────
            if (_usage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _ScreenUsageBoxCard(usage: _usage!, tc: tc,
                    focusSecs: widget.state.todayFocusSecs())),
            // ── 交叉洞察瀑布布局 ──────────────────────────────────────────
            _DetailBrick(tc: tc, accent: const Color(0xFF3a90c0),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _BrickLabel(icon: '🔍', label: L.smartPlanScreenTaskInsight, tc: tc),
                const SizedBox(height: 10),
                ...crossIns.asMap().entries.map((e) =>
                  _CrossInsightRow(ins: e.value, idx: e.key, tc: tc,
                    total: crossIns.length)),
              ])),
            const SizedBox(height: 8),
          ],

          // ── 趋势 ────────────────────────────────────────────────────────
          if (suggestion.trendLabel.isNotEmpty) ...[
            _DetailBrick(tc: tc, accent: acc,
              child: Row(children: [
                Text(suggestion.trendLabel.contains('📈') ? '📈' : '📉',
                  style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(suggestion.trendLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: acc))),
              ])),
            const SizedBox(height: 8),
          ],

          // 免责声明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(tc.brd).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10)),
            child: Text(L.smartPlanDisclaimer,
              style: TextStyle(fontSize: 10, color: Color(tc.tm), height: 1.5))),
        ]),
    );
  }
}

// ── Detail page sub-widgets ────────────────────────────────────────────────

class _DetailBrick extends StatelessWidget {
  final ThemeConfig tc;
  final Color accent;
  final Widget child;
  final EdgeInsets padding;
  const _DetailBrick({required this.tc, required this.accent,
      required this.child,
      this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Color(tc.card),
      borderRadius: BorderRadius.circular(14),
      border: Border(left: BorderSide(color: accent.withOpacity(0.5), width: 3)),
      boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 6)]),
    child: child);
}

class _BrickLabel extends StatelessWidget {
  final String icon, label;
  final ThemeConfig tc;
  const _BrickLabel({required this.icon, required this.label, required this.tc});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 11)),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
        color: Color(tc.ts), letterSpacing: 0.5)),
  ]);
}

class _BrickSectionLabel extends StatelessWidget {
  final String icon, label;
  final String? sub;
  final ThemeConfig tc;
  const _BrickSectionLabel({required this.icon, required this.label,
      required this.tc, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: Color(tc.ts))),
      if (sub != null) ...[
        const SizedBox(width: 6),
        Text(sub!, style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
      ],
    ]));
}


// ─────────────────────────────────────────────────────────────────────────────
// Confidence Pie Chart Painter
// ─────────────────────────────────────────────────────────────────────────────
class _ConfidencePiePainter extends CustomPainter {
  final List<Insight> insights;
  final Color highColor, medColor, lowColor;
  const _ConfidencePiePainter({required this.insights,
      required this.highColor, required this.medColor, required this.lowColor});
  @override
  void paint(Canvas canvas, Size size) {
    final total = insights.length;
    if (total == 0) return;
    final high = insights.where((i) => i.confidence == Confidence.high).length;
    final med  = insights.where((i) => i.confidence == Confidence.medium).length;
    final low  = total - high - med;
    final cx = size.width / 2; final cy = size.height / 2;
    final r = (size.width / 2 - 4).clamp(8.0, 40.0);
    final innerR = r * 0.52;
    final segs = [
      (high / total * 2 * 3.14159, highColor),
      (med  / total * 2 * 3.14159, medColor),
      (low  / total * 2 * 3.14159, lowColor),
    ];
    double startAngle = -1.5708; // -π/2
    for (final seg in segs) {
      if (seg.$1 < 0.001) continue;
      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r),
            startAngle, seg.$1, false)
        ..close();
      canvas.drawPath(path, Paint()..color = seg.$2.withOpacity(0.85)
          ..style = PaintingStyle.fill);
      startAngle += seg.$1;
    }
    // Donut hole
    canvas.drawCircle(Offset(cx, cy), innerR,
        Paint()..color = const Color(0x00000000)..blendMode = BlendMode.clear);
    canvas.drawCircle(Offset(cx, cy), innerR,
        Paint()..color = const Color(0x1A000000));
    // Center label
    final tp = TextPainter(
      text: TextSpan(text: '$total',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: Color(0xFF666666))),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx - tp.width/2, cy - tp.height/2));
  }
  @override bool shouldRepaint(_ConfidencePiePainter o) =>
      o.insights.length != insights.length;
}

class _ConfLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _ConfLegendRow({required this.color, required this.label,
      required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Expanded(child: Text(label, style: TextStyle(
        fontSize: 10, color: color))),
    Text('$count', style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Insight Source Horizontal Bar Chart
// ─────────────────────────────────────────────────────────────────────────────
class _InsightSourceBar extends StatelessWidget {
  final List<Insight> insights;
  final ThemeConfig tc;
  const _InsightSourceBar({required this.insights, required this.tc});
  @override
  Widget build(BuildContext context) {
    final sources = {
      InsightSource.task:        (L.smartPlanSourceTask, const Color(0xFF4A9068)),
      InsightSource.crossTask:   (L.smartPlanSourceCrossTask, const Color(0xFFe8982a)),
      InsightSource.trend:       (L.smartPlanSourceTrend, const Color(0xFF3A90C0)),
      InsightSource.screen:      (L.smartPlanSourceScreen, const Color(0xFF7a5ab8)),
      InsightSource.crossScreen: (L.smartPlanSourceScreenTask, const Color(0xFFc04040)),
    };
    final total = insights.length;
    if (total == 0) return const SizedBox.shrink();
    return Column(children: sources.entries.map((e) {
      final cnt = insights.where((i) => i.source == e.key).length;
      if (cnt == 0) return const SizedBox.shrink();
      final frac = cnt / total;
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          SizedBox(width: 52, child: Text(e.value.$1,
            style: TextStyle(fontSize: 9.5, color: Color(tc.ts)))),
          const SizedBox(width: 8),
          Expanded(child: Stack(children: [
            Container(height: 14,
              decoration: BoxDecoration(
                color: Color(tc.brd).withOpacity(0.4),
                borderRadius: BorderRadius.circular(3))),
            FractionallySizedBox(
              widthFactor: frac.clamp(0.0, 1.0),
              child: Container(height: 14,
                decoration: BoxDecoration(
                  color: e.value.$2.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(3)))),
          ])),
          const SizedBox(width: 8),
          Text('$cnt', style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.w700, color: e.value.$2)),
        ]));
    }).toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Insight Chart Card — rich layout with confidence bar
// ─────────────────────────────────────────────────────────────────────────────
class _InsightChartCard extends StatelessWidget {
  final Insight ins;
  final ThemeConfig tc;
  final int idx;
  const _InsightChartCard({required this.ins, required this.tc, required this.idx});
  @override
  Widget build(BuildContext context) {
    final conf = ins.confidence;
    final confColor = conf == Confidence.high ? const Color(0xFF4A9068)
        : conf == Confidence.medium ? const Color(0xFFDAA520)
        : const Color(0xFF888888);
    final confPct = conf == Confidence.high ? 0.85
        : conf == Confidence.medium ? 0.55 : 0.28;
    final confLabel = conf == Confidence.high
        ? L.smartPlanConfHigh
        : conf == Confidence.medium
            ? L.smartPlanConfMed
            : L.smartPlanConfLow;
    final srcLabel = const {
      InsightSource.task: 'sourceTask',
      InsightSource.screen: 'sourceScreen',
      InsightSource.crossTask: 'sourceCrossTask',
      InsightSource.crossScreen: 'sourceScreenTask',
      InsightSource.trend: 'sourceTrend',
    }[ins.source] ?? '';
    final localizedSrcLabel = srcLabel == 'sourceTask'
        ? L.smartPlanSourceTask
        : srcLabel == 'sourceScreen'
            ? L.smartPlanSourceScreen
            : srcLabel == 'sourceCrossTask'
                ? L.smartPlanSourceCrossTask
                : srcLabel == 'sourceScreenTask'
                    ? L.smartPlanSourceScreenTask
                    : srcLabel == 'sourceTrend'
                        ? L.smartPlanSourceTrend
                        : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Color(0x07000000), blurRadius: 5)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header bar with gradient
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [confColor.withOpacity(0.10), Colors.transparent]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: confColor.withOpacity(0.12),
                border: Border.all(color: confColor.withOpacity(0.30))),
              child: Center(child: Text(ins.icon,
                  style: const TextStyle(fontSize: 13)))),
            const SizedBox(width: 9),
            Expanded(child: Text(ins.title,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                  color: Color(tc.tx)))),
            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: confColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(5)),
              child: Text(localizedSrcLabel,
                style: TextStyle(fontSize: 8.5, color: confColor))),
          ])),
        // Body text
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(ins.body, style: TextStyle(
              fontSize: 10.5, color: Color(tc.ts), height: 1.5))),
        // Confidence bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(children: [
            Text('置信度', style: TextStyle(fontSize: 9, color: Color(tc.tm))),
            const SizedBox(width: 8),
            Expanded(child: Stack(children: [
              Container(height: 4,
                decoration: BoxDecoration(
                  color: Color(tc.brd).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2))),
              FractionallySizedBox(
                widthFactor: confPct,
                child: Container(height: 4,
                  decoration: BoxDecoration(
                    color: confColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(
                        color: confColor.withOpacity(0.5),
                        blurRadius: 3)]))),
            ])),
            const SizedBox(width: 8),
            Text(confLabel, style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w700,
                color: confColor)),
          ])),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen Usage Box-plot style card
// ─────────────────────────────────────────────────────────────────────────────
class _ScreenUsageBoxCard extends StatelessWidget {
  final dynamic usage;
  final ThemeConfig tc;
  final int focusSecs;
  const _ScreenUsageBoxCard({required this.usage, required this.tc,
      required this.focusSecs});
  @override
  Widget build(BuildContext context) {
    final entertainH = (usage.totalEntertainMs / 3600000.0);
    final workH = (usage.totalWorkMs / 3600000.0);
    final focusH = focusSecs / 3600.0;
    final totalH = entertainH + workH + 0.001;
    final effScore = usage.efficiencyScore(focusSecs) as int;
    final scoreColor = effScore >= 70 ? const Color(0xFF4A9068)
        : effScore >= 40 ? const Color(0xFFDAA520)
        : const Color(0xFFc04040);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Color(0x07000000), blurRadius: 5)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _BrickLabel(icon: '📱', label: L.smartPlanScreenTimeDistribution, tc: tc),
          const Spacer(),
          // Efficiency score badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scoreColor.withOpacity(0.30))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(L.smartPlanEfficiency, style: TextStyle(fontSize: 9, color: Color(tc.tm))),
              Text('$effScore', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: scoreColor, height: 1.0)),
              Text('/100', style: TextStyle(fontSize: 8, color: Color(tc.tm))),
            ])),
        ]),
        const SizedBox(height: 12),

        // Stacked horizontal bar (box-plot style)
        Row(children: [
          SizedBox(width: 44, child: Text(L.smartPlanSourceScreen,
            style: TextStyle(fontSize: 9, color: Color(tc.tm)))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Total bar divided into work/entertain
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(height: 18, child: Row(children: [
                if (workH > 0) Flexible(
                  flex: (workH / totalH * 100).round(),
                  child: Container(color: const Color(0xFF3A90C0).withOpacity(0.75),
                    child: Center(child: Text('${workH.toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 8, color: Colors.white,
                          fontWeight: FontWeight.w600))))),
                if (entertainH > 0) Flexible(
                  flex: (entertainH / totalH * 100).round(),
                  child: Container(color: const Color(0xFFe8982a).withOpacity(0.75),
                    child: Center(child: Text('${entertainH.toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 8, color: Colors.white,
                          fontWeight: FontWeight.w600))))),
              ]))),
            const SizedBox(height: 4),
            // Focus overlay bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(height: 12, child: Row(children: [
                Flexible(
                  flex: (focusH / (totalH + focusH + 0.001) * 100).round().clamp(1, 99),
                  child: Container(color: const Color(0xFF4A9068).withOpacity(0.70),
                    child: Center(child: Text(L.smartPlanFocusValue(focusH.toStringAsFixed(1)),
                      style: const TextStyle(fontSize: 7.5, color: Colors.white,
                          fontWeight: FontWeight.w600))))),
                Flexible(
                  flex: 100 - (focusH / (totalH + focusH + 0.001) * 100).round().clamp(1, 99),
                  child: Container(color: Color(0x0F000000))),
              ]))),
          ])),
        ]),
        const SizedBox(height: 10),
        // Legend row
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _SUsageLegend(color: const Color(0xFF3A90C0), label: L.smartPlanWorkStudy,
              value: '${workH.toStringAsFixed(1)}h'),
          _SUsageLegend(color: const Color(0xFFe8982a), label: L.smartPlanEntertainment,
              value: '${entertainH.toStringAsFixed(1)}h'),
          _SUsageLegend(color: const Color(0xFF4A9068), label: L.smartPlanFocus,
              value: '${focusH.toStringAsFixed(1)}h'),
        ]),
      ]));
  }
}

class _SUsageLegend extends StatelessWidget {
  final Color color;
  final String label, value;
  const _SUsageLegend({required this.color, required this.label,
      required this.value});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
      children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 8.5, color: color.withOpacity(0.8))),
      Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: color)),
    ]),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cross insight row — waterfall style with confidence gradient
// ─────────────────────────────────────────────────────────────────────────────
class _CrossInsightRow extends StatelessWidget {
  final Insight ins;
  final ThemeConfig tc;
  final int idx, total;
  const _CrossInsightRow({required this.ins, required this.tc,
      required this.idx, required this.total});
  @override
  Widget build(BuildContext context) {
    final conf = ins.confidence;
    final confPct = conf == Confidence.high ? 0.85
        : conf == Confidence.medium ? 0.55 : 0.28;
    final confColor = conf == Confidence.high ? const Color(0xFF4A9068)
        : conf == Confidence.medium ? const Color(0xFFDAA520)
        : const Color(0xFF888888);
    final isLast = idx == total - 1;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Vertical timeline track
        Column(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3a90c0).withOpacity(0.12 + idx * 0.04),
              border: Border.all(
                  color: const Color(0xFF3a90c0).withOpacity(0.35))),
            child: Center(child: Text(ins.icon,
                style: const TextStyle(fontSize: 13)))),
          if (!isLast)
            Expanded(child: Container(
              width: 1.5,
              color: const Color(0xFF3a90c0).withOpacity(0.20))),
        ]),
        const SizedBox(width: 10),
        // Content
        Expanded(child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ins.title, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: const Color(0xFF3a90c0))),
            const SizedBox(height: 3),
            Text(ins.body, style: TextStyle(
                fontSize: 10, color: const Color(0xFF666666), height: 1.45)),
            const SizedBox(height: 5),
            // Mini confidence bar
            Row(children: [
              Text('可信度', style: TextStyle(fontSize: 8.5,
                  color: const Color(0xFF888888))),
              const SizedBox(width: 6),
              Expanded(child: Stack(children: [
                Container(height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0x1A000000),
                    borderRadius: BorderRadius.circular(2))),
                FractionallySizedBox(widthFactor: confPct,
                  child: Container(height: 3,
                    decoration: BoxDecoration(
                      color: confColor,
                      borderRadius: BorderRadius.circular(2)))),
              ])),
            ]),
          ]))),
      ]));
  }
}

class _DetailInsightTile extends StatelessWidget {
  final Insight ins;
  final ThemeConfig tc;
  final Color? accentOverride;
  const _DetailInsightTile({required this.ins, required this.tc, this.accentOverride});
  @override
  Widget build(BuildContext context) {
    final conf = ins.confidence;
    final confColor = conf == Confidence.high ? const Color(0xFF4A9068)
        : conf == Confidence.medium ? const Color(0xFFDAA520)
        : Color(tc.tm);
    final accent = accentOverride ?? confColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Color(0x07000000), blurRadius: 4)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: accent.withOpacity(0.10)),
          child: Center(child: Text(ins.icon,
              style: const TextStyle(fontSize: 16)))),
        const SizedBox(width: 10),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(ins.title, style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700,
                color: Color(tc.tx)))),
            Container(width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: confColor.withOpacity(0.85))),
          ]),
          const SizedBox(height: 4),
          Text(ins.body, style: TextStyle(
              fontSize: 10.5, color: Color(tc.ts), height: 1.45)),
          const SizedBox(height: 4),
          Text({
            InsightSource.task: L.smartPlanSourceTask,
            InsightSource.screen: L.smartPlanSourceScreen,
            InsightSource.crossTask: L.smartPlanSourceCrossTask,
            InsightSource.crossScreen: L.smartPlanSourceScreenTask,
            InsightSource.trend: L.smartPlanSourceTrend,
          }[ins.source] ?? '',
          style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
        ])),
      ]));
  }
}

class _BlockBarChart extends StatelessWidget {
  final AppState state;
  final ThemeConfig tc;
  final Color acc;
  const _BlockBarChart({required this.state, required this.tc, required this.acc});
  @override
  Widget build(BuildContext context) {
    final today = state.todayKey;
    final blocks = ['morning', 'afternoon', 'evening'];
    final labels = [L.smartPlanMorning, L.smartPlanAfternoon, L.smartPlanEvening];
    final colors = [const Color(0xFFe8982a), const Color(0xFF3a90c0),
        const Color(0xFF7a5ab8)];
    final counts = blocks.map((b) => state.tasks
        .where((t) => t.createdAt == today && t.timeBlock == b).length).toList();
    final maxC = counts.reduce((a, b) => a > b ? a : b);
    if (maxC == 0) return Text(L.smartPlanNoData,
        style: TextStyle(fontSize: 10, color: Color(tc.tm)));
    return Row(crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      for (int i = 0; i < 3; i++)
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${counts[i]}', style: TextStyle(
              fontSize: 10, color: colors[i], fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 22,
            height: (counts[i] / maxC * 44).clamp(4.0, 44.0),
            decoration: BoxDecoration(
              color: colors[i].withOpacity(0.75),
              borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 3),
          Text(labels[i], style: TextStyle(fontSize: 9, color: Color(tc.ts))),
        ]),
    ]);
  }
}

class _DetailGaugePainter extends CustomPainter {
  final double value;
  final Color color, bg;
  const _DetailGaugePainter(
      {required this.value, required this.color, required this.bg});
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 5;
    const start = 2.356;
    const sweep = 4.712;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        start, sweep, false,
        Paint()..color = bg..style = PaintingStyle.stroke
            ..strokeWidth = 6..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        start, sweep * value.clamp(0.0, 1.0), false,
        Paint()..color = color..style = PaintingStyle.stroke
            ..strokeWidth = 6..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_DetailGaugePainter o) => o.value != value;
}



class _SectionHeader extends StatelessWidget {
  final ThemeConfig tc;
  final String icon, label;
  final String? sub;
  const _SectionHeader({required this.tc, required this.icon,
      required this.label, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.5, color: Color(tc.ts))),
      if (sub != null) ...[
        const SizedBox(width: 6),
        Text(sub!, style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
      ],
    ]));
}

class _InsightCard extends StatelessWidget {
  final ThemeConfig tc;
  final Widget child;
  final bool highlight;
  final Color? highlightColor;
  const _InsightCard({required this.tc, required this.child,
      this.highlight = false, this.highlightColor});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Color(tc.card),
      borderRadius: BorderRadius.circular(12),
      border: highlightColor != null
          ? Border.all(color: highlightColor!.withOpacity(0.25)) : null,
      boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 4)]),
    child: child);
}

// ── Mini HPI gauge for summary card ──────────────────────────────────────────
class _MiniHpi extends StatelessWidget {
  final int hpi;
  final ThemeConfig tc;
  const _MiniHpi({required this.hpi, required this.tc});
  @override
  Widget build(BuildContext context) {
    final color = hpi >= 80 ? const Color(0xFF4A9068)
        : hpi >= 65 ? const Color(0xFF3A90C0)
        : hpi >= 45 ? const Color(0xFFDAA520)
        : const Color(0xFFE07040);
    return SizedBox(width: 32, height: 32,
      child: CustomPaint(
        painter: _MiniGaugePainter(value: hpi / 100.0, color: color,
            bg: Color(tc.brd)),
        child: Center(child: Text('$hpi',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
              color: color, height: 1.0)))));
  }
}

class _MiniGaugePainter extends CustomPainter {
  final double value;
  final Color color, bg;
  const _MiniGaugePainter({required this.value, required this.color,
      required this.bg});
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 3;
    const start = 2.356; // 135°
    const sweep = 4.712; // 270°
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        start, sweep, false,
        Paint()..color = bg..style = PaintingStyle.stroke..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        start, sweep * value.clamp(0.0, 1.0), false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_) => false;
}
