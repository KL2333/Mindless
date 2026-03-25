// lib/screens/search_screen.dart
// 全局任务搜索 — SearchDelegate
// 实时过滤所有历史/当前任务，结果按日期分组，点击跳转到对应日期

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 入口：全屏搜索
// ─────────────────────────────────────────────────────────────────────────────

void showGlobalSearch(BuildContext context) {
  final state = context.read<AppState>();
  showSearch(
    context: context,
    delegate: _TaskSearchDelegate(state),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchDelegate 实现
// ─────────────────────────────────────────────────────────────────────────────

class _TaskSearchDelegate extends SearchDelegate<TaskModel?> {
  final AppState state;

  _TaskSearchDelegate(this.state)
      : super(
          searchFieldLabel: '搜索任务…',
          searchFieldStyle: const TextStyle(fontSize: 15),
        );

  @override
  String get searchFieldLabel => '搜索任务…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final tc = state.themeConfig;
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: state.bgColor,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(tc.ts)),
        titleTextStyle: TextStyle(
          fontSize: 15,
          color: Color(tc.tx),
          fontFamily: 'serif',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(tc.tm), fontSize: 15),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: Icon(Icons.clear_rounded, color: Color(state.themeConfig.ts)),
            onPressed: () {
              query = '';
              showSuggestions(context);
            },
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded,
            size: 18, color: Color(state.themeConfig.ts)),
        onPressed: () => close(context, null),
      );

  // ── Results ────────────────────────────────────────────────────────────────
  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final tc = state.themeConfig;
    final q = query.trim().toLowerCase();

    // Filter: match text OR any tag
    final all = state.tasks.where((t) {
      if (t.ignored) return false;
      if (q.isEmpty) return false;
      if (t.text.toLowerCase().contains(q)) return true;
      if (t.tags.any((tag) => tag.toLowerCase().contains(q))) return true;
      return false;
    }).toList();

    if (q.isEmpty) {
      return _EmptyHint(tc: tc,
          text: '输入关键词搜索任务\n支持任务名称和标签',
          icon: Icons.search_rounded);
    }

    if (all.isEmpty) {
      return _EmptyHint(tc: tc,
          text: '没有找到「$query」相关任务',
          icon: Icons.search_off_rounded);
    }

    // Sort: done tasks to bottom, then by date descending
    all.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final dateA = a.rescheduledTo ?? a.createdAt;
      final dateB = b.rescheduledTo ?? b.createdAt;
      return dateB.compareTo(dateA);
    });

    // Group by display date (rescheduledTo ?? createdAt)
    final groups = <String, List<TaskModel>>{};
    for (final t in all) {
      final dk = t.rescheduledTo ?? t.createdAt;
      (groups[dk] ??= []).add(t);
    }
    final sortedDates = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      itemCount: sortedDates.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('找到 ${all.length} 条',
                style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          );
        }
        final dk = sortedDates[i - 1];
        final items = groups[dk]!;
        return _DateGroup(
          dateKey: dk,
          tasks: items,
          tc: tc,
          query: query.trim(),
          state: state,
          onTap: (task) {
            close(context, task);
            _navigateToDate(context, dk, state);
          },
        );
      },
    );
  }

  void _navigateToDate(BuildContext context, String dateKey, AppState state) {
    final today = state.todayKey;
    final tomorrow = DateUtils2.addDays(today, 1);
    // If it's today or tomorrow, switch to today tab (tab 0)
    // Otherwise just pop back — user is informed of the date
    // We push a notification-style snack only for historical dates
    if (dateKey == today || dateKey == tomorrow) {
      // navigate to today tab
      final nav = Navigator.of(context);
      nav.popUntil((route) => route.isFirst);
    } else {
      // Historical: show snack and return to main
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('该任务属于 ${DateUtils2.fmtFull(dateKey)}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Color(state.themeConfig.card),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 日期分组标题 + 任务列表
// ─────────────────────────────────────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  final String dateKey;
  final List<TaskModel> tasks;
  final ThemeConfig tc;
  final String query;
  final AppState state;
  final void Function(TaskModel) onTap;

  const _DateGroup({
    required this.dateKey,
    required this.tasks,
    required this.tc,
    required this.query,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = state.todayKey;
    final tomorrow = DateUtils2.addDays(today, 1);
    final String label;
    if (dateKey == today) {
      label = '今天';
    } else if (dateKey == tomorrow) {
      label = '明天';
    } else {
      final d = DateUtils2.parse(dateKey);
      label = '${d.month}月${d.day}日';
    }
    final isToday = dateKey == today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isToday
                    ? Color(tc.acc).withOpacity(0.12)
                    : Color(tc.brd).withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isToday ? Color(tc.acc) : Color(tc.ts)),
              ),
            ),
            const SizedBox(width: 6),
            Text('${tasks.length} 条',
                style: TextStyle(fontSize: 10, color: Color(tc.tm))),
          ]),
        ),

        // Task items
        ...tasks.map((t) => _TaskResultTile(
              task: t,
              tc: tc,
              query: query,
              state: state,
              onTap: () => onTap(t),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 单条搜索结果卡片
// ─────────────────────────────────────────────────────────────────────────────

class _TaskResultTile extends StatelessWidget {
  final TaskModel task;
  final ThemeConfig tc;
  final String query;
  final AppState state;
  final VoidCallback onTap;

  const _TaskResultTile({
    required this.task,
    required this.tc,
    required this.query,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final blockLabel = _blockLabel(task.timeBlock);
    final blockColor = _blockColor(task.timeBlock);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          color: state.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: task.done
                  ? Color(tc.brd).withOpacity(0.25)
                  : Color(tc.brd).withOpacity(0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Done indicator
            Container(
              margin: const EdgeInsets.only(top: 2, right: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.done
                    ? Color(tc.acc).withOpacity(0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: task.done
                      ? Color(tc.acc)
                      : Color(tc.brd),
                  width: 1.5,
                ),
              ),
              child: task.done
                  ? Icon(Icons.check_rounded,
                      size: 10, color: Color(tc.acc))
                  : null,
            ),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Task text with query highlight
                  _HighlightText(
                    text: task.text,
                    query: query,
                    baseStyle: TextStyle(
                      fontSize: 13,
                      color: task.done
                          ? Color(tc.ts)
                          : Color(tc.tx),
                      decoration:
                          task.done ? TextDecoration.lineThrough : null,
                      fontFamily: 'serif',
                    ),
                    highlightColor: Color(tc.acc).withOpacity(0.25),
                    highlightStyle: TextStyle(
                      fontSize: 13,
                      color: Color(tc.acc),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'serif',
                    ),
                  ),

                  // Meta row
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      // Time block badge
                      if (task.timeBlock != 'unassigned')
                        _MetaBadge(
                          label: blockLabel,
                          color: blockColor,
                          tc: tc,
                        ),
                      // Focus time
                      if (task.focusSecs > 0)
                        _MetaBadge(
                          label: '⏱ ${_durStr(task.focusSecs)}',
                          color: Color(tc.ts),
                          tc: tc,
                        ),
                      // Tags
                      ...task.tags.map((tag) {
                        final c = state.tagColor(tag);
                        return _MetaBadge(
                          label: tag,
                          color: c,
                          tc: tc,
                          highlight: tag.toLowerCase().contains(query.toLowerCase()),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 11, color: Color(tc.tm)),
            ),
          ],
        ),
      ),
    );
  }

  String _blockLabel(String blk) {
    switch (blk) {
      case 'morning':   return '🌅 上午';
      case 'afternoon': return '☀️ 下午';
      case 'evening':   return '🌙 晚上';
      default:          return '📌 待分配';
    }
  }

  Color _blockColor(String blk) {
    switch (blk) {
      case 'morning':   return const Color(0xFFe8c84a);
      case 'afternoon': return const Color(0xFFe8982a);
      case 'evening':   return const Color(0xFF8060C0);
      default:          return const Color(0xFF888888);
    }
  }

  String _durStr(int secs) {
    if (secs >= 3600) return '${secs ~/ 3600}h${(secs % 3600) ~/ 60}m';
    return '${secs ~/ 60}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlight widget — 高亮关键词
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final Color highlightColor;
  final TextStyle highlightStyle;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightColor,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: baseStyle);

    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final spans = <InlineSpan>[];
    int start = 0;
    int idx;

    while ((idx = lower.indexOf(qLower, start)) != -1) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      // Highlight match with background color via TextStyle background
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: highlightStyle.copyWith(
          background: Paint()..color = highlightColor,
        ),
      ));
      start = idx + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meta badge chip
// ─────────────────────────────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  final ThemeConfig tc;
  final bool highlight;

  const _MetaBadge({
    required this.label,
    required this.color,
    required this.tc,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: highlight
              ? color.withOpacity(0.18)
              : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(6),
          border: highlight
              ? Border.all(color: color.withOpacity(0.45), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 9.5,
              color: highlight ? color : color.withOpacity(0.85),
              fontWeight:
                  highlight ? FontWeight.w700 : FontWeight.normal),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / hint state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final ThemeConfig tc;
  final String text;
  final IconData icon;

  const _EmptyHint({required this.tc, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: Color(tc.brd)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Color(tc.ts),
                  height: 1.6),
            ),
          ]),
        ),
      );
}
