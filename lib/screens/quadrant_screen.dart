// lib/screens/quadrant_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

import '../l10n/l10n.dart';

List<Map<String, dynamic>> _qConf() => [
  {'q': 1, 'name': L.quadQ1Name, 'sub': L.quadQ1Sub, 'bg': const Color(0x1AC04040), 'hdr': const Color(0xD9C04040)},
  {'q': 2, 'name': L.quadQ2Name, 'sub': L.quadQ2Sub, 'bg': const Color(0x1A3A9060), 'hdr': const Color(0xD93A9060)},
  {'q': 3, 'name': L.quadQ3Name, 'sub': L.quadQ3Sub, 'bg': const Color(0x1A3A90C0), 'hdr': const Color(0xD93A90C0)},
  {'q': 4, 'name': L.quadQ4Name, 'sub': L.quadQ4Sub, 'bg': const Color(0x1A7A5AB8), 'hdr': const Color(0xD97A5AB8)},
];

class QuadrantScreen extends StatefulWidget {
  const QuadrantScreen({super.key});
  @override
  State<QuadrantScreen> createState() => _QuadrantScreenState();
}

class _QuadrantScreenState extends State<QuadrantScreen> {
  int? _hoveredQuad;
  bool _hoveringPool = false;
  bool _hoveringIgnore = false;

  void _move(AppState state, int taskId, int? quad) {
    state.setTaskQuadrant(taskId, quad);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final today = state.todayKey;
    final topPad = MediaQuery.of(context).padding.top;
    final showClock = state.settings.showTopClock;
    final appBarHeight = showClock ? 78.0 : 46.0;
    final topMargin = 8.0;
    final barBottom = topPad + appBarHeight + topMargin + 8 + state.settings.topBarOffset; // Precise spacing + Dynamic Offset

    // Unassigned: not done, not ignored, no quadrant
    final unassigned = state.tasks
        .where((t) => !t.done && !t.ignored && t.quadrant == null)
        .toList();

    // Auto-clean: remove from quadrant if done before today
    final toClean = state.tasks.where((t) =>
      t.quadrant != null && t.done &&
      (t.doneAt == null || t.doneAt!.compareTo(today) < 0)).toList();
    if (toClean.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final t in toClean) state.setTaskQuadrant(t.id, null);
      });
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // ── 横屏：左侧待分类 | 右侧2×2四象限 ──────────────────────────────
    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 左列：待分类池
          SizedBox(width: 160, child: _buildPoolColumn(state, tc, unassigned)),
          Container(width: 1, color: Color(tc.brd).withOpacity(0.4)),
          // 右区：2×2四象限
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Column(children: [
                Expanded(child: Row(children: [
                  Expanded(child: _QuadCell(q: 1, state: state, tc: tc,
                    hovering: _hoveredQuad == 1,
                    onHover: (v) => setState(() => _hoveredQuad = v ? 1 : null),
                    onDrop: (id) => _move(state, id, 1))),
                  const SizedBox(width: 8),
                  Expanded(child: _QuadCell(q: 2, state: state, tc: tc,
                    hovering: _hoveredQuad == 2,
                    onHover: (v) => setState(() => _hoveredQuad = v ? 2 : null),
                    onDrop: (id) => _move(state, id, 2))),
                ])),
                const SizedBox(height: 8),
                Expanded(child: Row(children: [
                  Expanded(child: _QuadCell(q: 3, state: state, tc: tc,
                    hovering: _hoveredQuad == 3,
                    onHover: (v) => setState(() => _hoveredQuad = v ? 3 : null),
                    onDrop: (id) => _move(state, id, 3))),
                  const SizedBox(width: 8),
                  Expanded(child: _QuadCell(q: 4, state: state, tc: tc,
                    hovering: _hoveredQuad == 4,
                    onHover: (v) => setState(() => _hoveredQuad = v ? 4 : null),
                    onDrop: (id) => _move(state, id, 4))),
                ])),
              ]),
            )),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.fromLTRB(0, barBottom, 0, 100), // Liquid Glass spacing
        child: Column(children: [
          _buildPoolRow(state, tc, unassigned),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Expanded(child: Row(children: [
                Expanded(child: _QuadCell(q: 1, state: state, tc: tc,
                  hovering: _hoveredQuad == 1,
                  onHover: (v) => setState(() => _hoveredQuad = v ? 1 : null),
                  onDrop: (id) => _move(state, id, 1))),
                const SizedBox(width: 8),
                Expanded(child: _QuadCell(q: 2, state: state, tc: tc,
                  hovering: _hoveredQuad == 2,
                  onHover: (v) => setState(() => _hoveredQuad = v ? 2 : null),
                  onDrop: (id) => _move(state, id, 2))),
              ])),
              const SizedBox(height: 8),
              Expanded(child: Row(children: [
                Expanded(child: _QuadCell(q: 3, state: state, tc: tc,
                  hovering: _hoveredQuad == 3,
                  onHover: (v) => setState(() => _hoveredQuad = v ? 3 : null),
                  onDrop: (id) => _move(state, id, 3))),
                const SizedBox(width: 8),
                Expanded(child: _QuadCell(q: 4, state: state, tc: tc,
                  hovering: _hoveredQuad == 4,
                  onHover: (v) => setState(() => _hoveredQuad = v ? 4 : null),
                  onDrop: (id) => _move(state, id, 4))),
              ])),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildPoolRow(AppState state, ThemeConfig tc, List<TaskModel> unassigned) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── 待分类区 ──────────────────────────────────────
          Expanded(
            flex: 3,
            child: DragTarget<int>(
              onWillAcceptWithDetails: (_) { setState(() => _hoveringPool = true); return true; },
              onLeave: (_) => setState(() => _hoveringPool = false),
              onAcceptWithDetails: (d) {
                setState(() => _hoveringPool = false);
                state.setTaskQuadrant(d.data, null);
                HapticFeedback.lightImpact();
              },
              builder: (_, candidateData, __) {
                final isOver = _hoveringPool || candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: state.cardColor,
                    borderRadius: BorderRadius.circular(13),
                    border: isOver ? Border.all(color: Color(tc.acc), width: 2) : null,
                    boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(L.quadUnassigned, style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.ts))),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(8)),
                        child: Text('${unassigned.length}', style: TextStyle(fontSize: 10, color: Color(tc.ts))),
                      ),
                      if (isOver) ...[
                        const Spacer(),
                        Text(L.quadDropBack, style: TextStyle(fontSize: 9, color: Color(tc.acc), fontStyle: FontStyle.italic)),
                      ],
                    ]),
                    const SizedBox(height: 7),
                    if (unassigned.isEmpty)
                      Center(child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(L.quadAllAssigned, style: TextStyle(fontSize: 10, color: Color(tc.tm))),
                      ))
                    else
                      Wrap(
                        spacing: 5, runSpacing: 5,
                        children: unassigned.map((t) {
                          final firstTag = t.tags.isNotEmpty ? t.tags.first : null;
                          final c = firstTag != null ? state.tagColor(firstTag) : Color(tc.ts);
                          return _DraggableChip(task: t, color: c, tc: tc, state: state);
                        }).toList(),
                      ),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // ── 忽略区 ────────────────────────────────────────
          SizedBox(
            width: 72,
            child: DragTarget<int>(
              onWillAcceptWithDetails: (_) { setState(() => _hoveringIgnore = true); return true; },
              onLeave: (_) => setState(() => _hoveringIgnore = false),
              onAcceptWithDetails: (d) {
                setState(() => _hoveringIgnore = false);
                state.ignoreTask(d.data);
                HapticFeedback.mediumImpact();
              },
              builder: (_, candidateData, __) {
                final isOver = _hoveringIgnore || candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isOver ? const Color(0x22c04040) : Color(tc.cb),
                    borderRadius: BorderRadius.circular(13),
                    border: isOver ? Border.all(color: const Color(0xFFc04040), width: 2) : null,
                    boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedScale(
                      scale: isOver ? 1.25 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 22,
                        color: isOver ? const Color(0xFFc04040) : Color(tc.tm),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(L.quadIgnore, style: TextStyle(
                      fontSize: 10,
                      color: isOver ? const Color(0xFFc04040) : Color(tc.tm),
                      fontWeight: isOver ? FontWeight.w600 : FontWeight.normal,
                    )),
                    if (isOver) ...[
                      const SizedBox(height: 3),
                      Text(L.quadDropToHide, style: const TextStyle(fontSize: 8, color: Color(0xFFc04040))),
                    ],
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// Draggable chip
  // 横屏左侧：待分类竖列
  Widget _buildPoolColumn(AppState state, ThemeConfig tc,
      List<TaskModel> unassigned) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
        child: Text(L.quadUnassigned,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: Color(tc.ts)))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(L.quadDragToQuad,
          style: TextStyle(fontSize: 9.5, color: Color(tc.tm)))),
      const SizedBox(height: 6),
      Expanded(child: unassigned.isEmpty
        ? Center(child: Text(L.quadNoUnassigned,
            style: TextStyle(fontSize: 11, color: Color(tc.tm))))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: unassigned.length,
            itemBuilder: (_, i) {
              final t = unassigned[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: LongPressDraggable<int>(
                  data: t.id,
                  hapticFeedbackOnStart: true,
                  feedback: Material(color: Colors.transparent,
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: state.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(
                          color: Color(0x22000000), blurRadius: 8)]),
                      child: Text(t.text, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Color(tc.tx))))),
                  childWhenDragging: Opacity(opacity: 0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: state.cardColor,
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(t.text, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Color(tc.tm))))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: state.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                        color: Color(0x08000000), blurRadius: 4)]),
                    child: Text(t.text, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Color(tc.tx))))));
            })),
    ]);
  }

class _DraggableChip extends StatelessWidget {
  final TaskModel task;
  final Color color;
  final ThemeConfig tc;
  final AppState state;
  const _DraggableChip({required this.task, required this.color, required this.tc, required this.state});

  @override
  Widget build(BuildContext context) {
    final label = task.text.length > 14 ? '${task.text.substring(0, 14)}…' : task.text;
    return LongPressDraggable<int>(
      data: task.id,
      hapticFeedbackOnStart: true,
      onDragStarted: () => HapticFeedback.mediumImpact(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.92),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'serif')),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: TextStyle(fontSize: 12, color: color)),
        )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(fontSize: 12, color: color)),
      ),
    );
  }
}

// Quadrant cell
class _QuadCell extends StatelessWidget {
  final int q;
  final AppState state;
  final ThemeConfig tc;
  final bool hovering;
  final ValueChanged<bool> onHover;
  final ValueChanged<int> onDrop;
  const _QuadCell({required this.q, required this.state, required this.tc,
    required this.hovering, required this.onHover, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final conf = _qConf()[q - 1];
    final today = state.todayKey;
    // Show all tasks in this quadrant that are visible (pending OR done today)
    // Keep original list order — no re-sort on completion
    final allTasks = state.tasks.where((t) =>
      t.quadrant == q && !t.ignored &&
      (!t.done || t.doneAt == today)).toList();
    final doneCount = allTasks.where((t) => t.done).length;
    final hdr = conf['hdr'] as Color;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) { onHover(true); return true; },
      onLeave: (_) => onHover(false),
      onAcceptWithDetails: (d) { onHover(false); onDrop(d.data); },
      builder: (_, candidateData, __) {
        final isOver = hovering || candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: conf['bg'] as Color,
            borderRadius: BorderRadius.circular(13),
            border: isOver ? Border.all(color: Color(tc.acc), width: 2.5) : null,
            boxShadow: isOver
              ? [BoxShadow(color: Color(tc.acc).withOpacity(0.3), blurRadius: 12)]
              : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(conf['name'] as String,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: hdr, letterSpacing: 0.3)),
                Text(conf['sub'] as String,
                  style: TextStyle(fontSize: 8.5, color: hdr.withOpacity(0.6))),
              ]),
            ),
            Divider(height: 6, thickness: 0.5, color: hdr.withOpacity(0.2)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                children: [
                  if (allTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: Text(L.quadDrop, style: TextStyle(fontSize: 11, color: hdr.withOpacity(0.3))))),
                  // Render in stable original order
                  ...allTasks.map((t) => _QuadTask(task: t, state: state, tc: tc, hdr: hdr, isDone: t.done)),
                  if (doneCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(L.quadDoneToday(doneCount),
                        style: TextStyle(fontSize: 8, color: hdr.withOpacity(0.5)))),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _QuadTask extends StatelessWidget {
  final TaskModel task;
  final AppState state;
  final ThemeConfig tc;
  final Color hdr;
  final bool isDone;
  const _QuadTask({required this.task, required this.state, required this.tc,
    required this.hdr, this.isDone = false});

  @override
  Widget build(BuildContext context) {
    final t = task;
    return LongPressDraggable<int>(
      data: t.id,
      hapticFeedbackOnStart: true,
      onDragStarted: () => HapticFeedback.mediumImpact(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          constraints: const BoxConstraints(maxWidth: 150),
          decoration: BoxDecoration(
            color: state.cardColor,
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Text(t.text,
            style: TextStyle(fontSize: 12, color: Color(tc.tx), fontFamily: 'serif'),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: _buildCard()),
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    final t = task;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: state.cardColor, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => state.toggleTask(t.id),
            child: Container(
              width: 15, height: 15,
              margin: const EdgeInsets.only(top: 1, right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: t.done ? null : Border.all(color: Color(tc.tm), width: 1.5),
                color: t.done ? Color(tc.na) : Colors.transparent,
              ),
              child: t.done ? Icon(Icons.check, size: 9, color: Color(tc.nt)) : null,
            ),
          ),
          Expanded(child: Text(t.text,
            style: TextStyle(
              fontSize: 12,
              color: t.done ? Color(tc.tm) : Color(tc.tx),
              decoration: t.done ? TextDecoration.lineThrough : null,
              fontFamily: 'serif',
            ),
            maxLines: 3, overflow: TextOverflow.ellipsis)),
        ]),
        if (t.tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 2, children: t.tags.map((tag) {
            final c = state.tagColor(tag);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
              child: Text(tag, style: TextStyle(fontSize: 8.5, color: c)),
            );
          }).toList()),
        ],
      ]),
    );
  }
}
