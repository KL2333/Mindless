// lib/screens/pom_history_screen.dart
// 番茄钟历史记录详情页
// 展示所有 FocusQualityEntry：按日期分组，显示时长/任务/评分/效率/环境声

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/focus_quality_service.dart';
import '../l10n/l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 入口函数
// ─────────────────────────────────────────────────────────────────────────────
void showPomHistory(BuildContext context) {
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, _, __) => ChangeNotifierProvider.value(
        value: context.read<AppState>(),
        child: const PomHistoryScreen(),
      ),
      transitionsBuilder: (_, anim, __, child) {
        final cv = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
        return FadeTransition(
          opacity: cv,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(cv),
            child: child,
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class PomHistoryScreen extends StatefulWidget {
  const PomHistoryScreen({super.key});
  @override
  State<PomHistoryScreen> createState() => _PomHistoryScreenState();
}

class _PomHistoryScreenState extends State<PomHistoryScreen> {
  List<FocusQualityEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await FocusQualityService.getRecent(days: 90);
    entries.sort((a, b) {
      final dc = b.date.compareTo(a.date);
      if (dc != 0) return dc;
      return b.hour.compareTo(a.hour);
    });
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc    = state.themeConfig;
    final acc   = Color(tc.acc);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18,
              color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(L.get('screens.pomHistory.title'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: Color(tc.tx))),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: acc, strokeWidth: 2))
          : _entries.isEmpty
              ? _EmptyState(tc: tc)
              : _HistoryBody(entries: _entries, tc: tc, state: state),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body: summary header + grouped list
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryBody extends StatelessWidget {
  final List<FocusQualityEntry> entries;
  final ThemeConfig tc;
  final AppState state;
  const _HistoryBody({required this.entries, required this.tc, required this.state});

  @override
  Widget build(BuildContext context) {
    final acc = Color(tc.acc);

    // Summary
    final totalSessions = entries.length;
    final totalMins = entries.fold(0, (s, e) => s + e.sessionMins);
    final rated = entries.where((e) => e.subjectiveScore != null).toList();
    final avgQuality = entries.isEmpty ? 0
        : entries.fold(0, (s, e) => s + e.compositeScore) ~/ entries.length;

    // Group by date
    final grouped = <String, List<FocusQualityEntry>>{};
    for (final e in entries) {
      (grouped[e.date] ??= []).add(e);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return CustomScrollView(
      slivers: [

        // ── Summary strip ──────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(children: [
            _SumStat(icon: '🍅', value: '$totalSessions', label: L.get('screens.pomHistory.statSessions'),
                acc: acc, tc: tc),
            const SizedBox(width: 8),
            _SumStat(icon: '⏱', value: _fmtHM(totalMins), label: L.get('screens.pomHistory.statDuration'),
                acc: acc, tc: tc),
            const SizedBox(width: 8),
            _SumStat(
              icon: _qualityEmoji(avgQuality),
              value: '$avgQuality',
              label: L.get('screens.pomHistory.statAvgQuality'),
              acc: acc,
              tc: tc,
              sub: rated.isNotEmpty ? L.get('screens.pomHistory.statRatedCount', {'count': rated.length}) : L.get('screens.pomHistory.notRated'),
            ),
          ]),
        )),

        // ── Trend sparkline ────────────────────────────────────────────────
        if (entries.length >= 3)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: _TrendCard(entries: entries, tc: tc, acc: acc),
          )),

        // ── Grouped list ──────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final dk = sortedDates[i];
                final dayEntries = grouped[dk]!;
                final today = state.todayKey;
                final d = DateUtils2.parse(dk);
                final label = dk == today ? L.today
                    : '${d.month}/${d.day}';
                final dayMins = dayEntries.fold(0, (s, e) => s + e.sessionMins);
                return _DateSection(
                  label: label,
                  dateKey: dk,
                  totalMins: dayMins,
                  entries: dayEntries,
                  tc: tc,
                  state: state,
                  acc: acc,
                );
              },
              childCount: sortedDates.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend sparkline card (quality score over recent sessions)
// ─────────────────────────────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final List<FocusQualityEntry> entries;
  final ThemeConfig tc;
  final Color acc;
  const _TrendCard({required this.entries, required this.tc, required this.acc});

  @override
  Widget build(BuildContext context) {
    // Take up to last 20 sessions in chronological order
    final recent = entries.length > 20
        ? entries.sublist(0, 20).reversed.toList()
        : entries.reversed.toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(tc.brd).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(L.get('screens.pomHistory.trendTitle'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(tc.tx))),
            const Spacer(),
            Text(L.get('screens.pomHistory.trendRecentCount', {'count': recent.length}),
                style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: CustomPaint(
              painter: _SparkPainter(entries: recent, acc: acc, tc: tc),
              size: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [L.get('screens.pomHistory.levelLow'), L.get('screens.pomHistory.levelMid'), L.get('screens.pomHistory.levelHigh')].map((l) => Text(l,
                style: TextStyle(fontSize: 8, color: Color(tc.tm)))).toList()),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<FocusQualityEntry> entries;
  final Color acc;
  final ThemeConfig tc;
  const _SparkPainter({required this.entries, required this.acc, required this.tc});

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    final n = entries.length;
    final w = size.width;
    final h = size.height;

    // Fill path
    final fill = Path();
    fill.moveTo(0, h);
    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final y = h - (entries[i].compositeScore / 100) * (h - 4) - 2;
      if (i == 0) {
        fill.lineTo(x, y);
      } else {
        final px = (i - 1) / (n - 1) * w;
        final py = h - (entries[i - 1].compositeScore / 100) * (h - 4) - 2;
        fill.cubicTo((px + x) / 2, py, (px + x) / 2, y, x, y);
      }
    }
    fill.lineTo(w, h);
    fill.close();
    canvas.drawPath(fill, Paint()..color = acc.withOpacity(0.08));

    // Line
    final linePaint = Paint()
      ..color = acc.withOpacity(0.75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final y = h - (entries[i].compositeScore / 100) * (h - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = (i - 1) / (n - 1) * w;
        final py = h - (entries[i - 1].compositeScore / 100) * (h - 4) - 2;
        path.cubicTo((px + x) / 2, py, (px + x) / 2, y, x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Dots
    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final y = h - (entries[i].compositeScore / 100) * (h - 4) - 2;
      canvas.drawCircle(Offset(x, y), 2.5,
          Paint()..color = Color(tc.card));
      canvas.drawCircle(Offset(x, y), 1.8,
          Paint()..color = acc.withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Date section header + entries
// ─────────────────────────────────────────────────────────────────────────────
class _DateSection extends StatelessWidget {
  final String label, dateKey;
  final int totalMins;
  final List<FocusQualityEntry> entries;
  final ThemeConfig tc;
  final AppState state;
  final Color acc;
  const _DateSection({
    required this.label, required this.dateKey,
    required this.totalMins, required this.entries,
    required this.tc, required this.state, required this.acc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: dateKey == state.todayKey
                    ? acc.withOpacity(0.12)
                    : Color(tc.brd).withOpacity(0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: dateKey == state.todayKey
                          ? acc : Color(tc.ts))),
            ),
            const SizedBox(width: 8),
            Text('${entries.length} 次 · ${_fmtHM(totalMins)}',
                style: TextStyle(fontSize: 10, color: Color(tc.tm))),
          ]),
        ),
        // Entry cards
        ...entries.map((e) => _EntryCard(
            entry: e, tc: tc, state: state, acc: acc)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single session card
// ─────────────────────────────────────────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  final FocusQualityEntry entry;
  final ThemeConfig tc;
  final AppState state;
  final Color acc;
  const _EntryCard({required this.entry, required this.tc,
      required this.state, required this.acc});

  @override
  Widget build(BuildContext context) {
    // Look up task name from taskId
    String? taskName;
    if (entry.taskId != null) {
      final id = int.tryParse(entry.taskId!);
      if (id != null) {
        taskName = state.tasks
            .where((t) => t.id == id)
            .firstOrNull
            ?.text;
      }
    }

    final hourStr = entry.hour.toString().padLeft(2, '0');
    final qualScore = entry.compositeScore;
    final qualColor = qualScore >= 75
        ? const Color(0xFF4A9068)
        : qualScore >= 50
            ? acc
            : const Color(0xFFe8982a);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Color(tc.brd).withOpacity(0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: time + duration + quality score ─────────────────
          Row(children: [
            // Clock icon + time
            Icon(Icons.access_time_rounded, size: 12, color: Color(tc.tm)),
            const SizedBox(width: 4),
            Text('$hourStr:00',
                style: TextStyle(fontSize: 11, color: Color(tc.ts))),
            const SizedBox(width: 10),
            // Duration pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: acc.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('🍅',
                    style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Text('${entry.sessionMins}min',
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w600, color: acc)),
              ]),
            ),
            const Spacer(),
            // Composite quality score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: qualColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(L.get('screens.pomHistory.qualityScore', {'score': qualScore}),
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: qualColor)),
            ),
          ]),

          // ── Row 2: task name ───────────────────────────────────────
          if (taskName != null) ...[
            const SizedBox(height: 7),
            Row(children: [
              Icon(Icons.task_alt_rounded, size: 11, color: Color(tc.ts)),
              const SizedBox(width: 5),
              Expanded(child: Text(taskName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5,
                      color: Color(tc.tx), fontFamily: 'serif'))),
            ]),
          ],

          // ── Row 3: stars + objective bar + noise ───────────────────
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Subjective stars
            if (entry.subjectiveScore != null) ...[
              _StarRow(score: entry.subjectiveScore!, acc: acc, tc: tc),
              const SizedBox(width: 10),
            ] else ...[
              Text(L.get('screens.pomHistory.notRated'),
                  style: TextStyle(fontSize: 9.5, color: Color(tc.tm))),
              const SizedBox(width: 10),
            ],
            // Objective efficiency bar
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(L.get('screens.pomHistory.objectiveEfficiency'),
                    style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: entry.objectiveScore.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Color(tc.brd),
                    valueColor: AlwaysStoppedAnimation(
                      entry.objectiveScore >= 0.75
                          ? const Color(0xFF4A9068)
                          : entry.objectiveScore >= 0.5
                              ? acc
                              : const Color(0xFFe8982a),
                    ),
                  ),
                ),
              ],
            )),
            // Noise level badge
            if (entry.noiseLevel != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(tc.brd).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(entry.noiseLevel!,
                    style: TextStyle(fontSize: 9, color: Color(tc.ts))),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star row widget
// ─────────────────────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final int score;
  final Color acc;
  final ThemeConfig tc;
  const _StarRow({required this.score, required this.acc, required this.tc});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < score ? Icons.star_rounded : Icons.star_outline_rounded,
      size: 13,
      color: i < score ? const Color(0xFFFFB300) : Color(tc.brd),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary stat card
// ─────────────────────────────────────────────────────────────────────────────
class _SumStat extends StatelessWidget {
  final String icon, value, label;
  final Color acc;
  final ThemeConfig tc;
  final String? sub;
  const _SumStat({required this.icon, required this.value,
      required this.label, required this.acc, required this.tc, this.sub});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: Color(tc.card),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Color(tc.brd).withOpacity(0.4)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: acc,
          height: 1.1)),
      Text(label, style: TextStyle(
          fontSize: 9.5, color: Color(tc.ts))),
      if (sub != null)
        Text(sub!, style: TextStyle(fontSize: 8.5, color: Color(tc.tm))),
    ]),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ThemeConfig tc;
  const _EmptyState({required this.tc});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🍅', style: const TextStyle(fontSize: 52)),
      const SizedBox(height: 16),
      Text(L.get('screens.pomHistory.emptyTitle'),
          style: TextStyle(fontSize: 16, color: Color(tc.ts))),
      const SizedBox(height: 8),
      Text(L.get('screens.pomHistory.emptyDesc'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(tc.tm), height: 1.5)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmtHM(int totalMins) {
  if (totalMins >= 60) {
    return '${totalMins ~/ 60}h${totalMins % 60 == 0 ? '' : '${totalMins % 60}m'}';
  }
  return '${totalMins}m';
}

String _qualityEmoji(int score) {
  if (score >= 80) return '🔥';
  if (score >= 60) return '😊';
  if (score >= 40) return '😐';
  return '😕';
}
