// lib/widgets/calendar_widgets.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'golden_cell.dart';

// ── Gold count badge ─────────────────────────────────────────
Widget goldCountBadge(int count, ThemeConfig tc) {
  if (count == 0) return const SizedBox.shrink();
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 500),
    curve: Curves.elasticOut,
    builder: (_, v, child) => Transform.scale(scale: v, child: child),
    child: Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B6914), Color(0xFFDAA520), Color(0xFFFFF8DC), Color(0xFFDAA520), Color(0xFF8B6914)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🥇', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text('金牌总数 $count',
          style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x88000000), blurRadius: 3)],
          )),
      ]),
    ),
  );
}

// ── Legend ────────────────────────────────────────────────────
class CalColorLegend extends StatelessWidget {
  const CalColorLegend({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _leg(const Color(0xFFD64B41), '少'),
        _leg(const Color(0xFFDAA832), '中'),
        _leg(const Color(0xFF44A460), '多'),
        _lGold('金'),
        _leg(const Color(0xFFCCCCCC), '未来'),
      ]),
    );
  }
  Widget _leg(Color c, String lbl) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 3),
      Text(lbl, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
    ]));
  Widget _lGold(String lbl) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8B6914), Color(0xFFFFD700), Color(0xFF8B6914)]),
        borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 3),
      Text(lbl, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
    ]));
}

// ── Day view badges ───────────────────────────────────────────
class DayViewBadges extends StatelessWidget {
  final String dateStr;
  final AppState state;
  const DayViewBadges({super.key, required this.dateStr, required this.state});
  @override
  Widget build(BuildContext context) {
    final cnt = state.doneOnDay(dateStr);
    final today = state.todayKey;
    final isFut = dateStr.compareTo(today) > 0;
    final col = state.heatColor(cnt, isFut, dateStr);
    final sem = state.getSemInfo(dateStr);
    final tc = state.themeConfig;
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        _b('第 ${DateUtils2.dayOfYear(dateStr)} 天', Color(tc.cb), Color(tc.ts)),
        _b('第 ${DateUtils2.weekOfYear(dateStr)} 周', Color(tc.cb), Color(tc.ts)),
        _b('$cnt 件完成', isFut ? Color(tc.cb) : col, isFut ? Color(tc.ts) : Colors.white),
        if (sem != null) _b('第${sem.num}学期 第${sem.week}周', Color(tc.acc), Color(tc.nt)),
      ]));
  }
  Widget _b(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 11, color: fg)));
}

// ── Week calendar ─────────────────────────────────────────────
class WeekCalGrid extends StatelessWidget {
  final String anchor, selected;
  final AppState state;
  final ValueChanged<String> onSelect;
  const WeekCalGrid({super.key, required this.anchor, required this.selected, required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final days = DateUtils2.weekDays(anchor);
    const dn = ['一','二','三','四','五','六','日'];
    final today = state.todayKey;
    final tc = state.themeConfig;

    // Count gold days in this week
    final goldCount = days.where((day) {
      final cnt = state.doneOnDay(day);
      return state.isGoldDay(cnt) && day.compareTo(today) <= 0;
    }).length;

    return Column(children: [
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: List.generate(7, (i) {
          final day = days[i];
          final cnt = state.doneOnDay(day);
          final isFut = day.compareTo(today) > 0;
          final isSel = day == selected;
          final isGold = state.isGoldDay(cnt) && !isFut;
          final col = state.heatColor(cnt, isFut, day);
          final mg = state.tasks.where((t) => t.done && t.doneAt == day && t.timeBlock == 'morning').length;
          final af = state.tasks.where((t) => t.done && t.doneAt == day && t.timeBlock == 'afternoon').length;
          final ev = state.tasks.where((t) => t.done && t.doneAt == day && t.timeBlock == 'evening').length;
          final vtMax = max(mg, max(af, max(ev, 1)));
          if (isGold) {
            return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(children: [
                Text(dn[i], style: TextStyle(fontSize: 9, color: Color(tc.ts))),
                const SizedBox(height: 2),
                GoldenCalendarCell(day: DateUtils2.parse(day).day, isSelected: isSel, onTap: () => onSelect(day)),
                const SizedBox(height: 4),
                SizedBox(height: 12, child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (mg > 0) _vb(0xFFe8982a, mg / vtMax),
                  if (mg > 0 && (af > 0 || ev > 0)) const SizedBox(width: 1),
                  if (af > 0) _vb(0xFF3a90c0, af / vtMax),
                  if (af > 0 && ev > 0) const SizedBox(width: 1),
                  if (ev > 0) _vb(0xFF7a5ab8, ev / vtMax),
                ])),
              ])));
          }
          return Expanded(child: GestureDetector(onTap: () => onSelect(day),
            child: AnimatedContainer(duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(10),
                border: isSel ? Border.all(color: Color(tc.na), width: 2) : null),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(dn[i], style: TextStyle(fontSize: 9, color: isFut ? Color(tc.ts) : Colors.white.withOpacity(0.7))),
                const SizedBox(height: 2),
                Text('${DateUtils2.parse(day).day}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isFut ? Color(tc.ts) : Colors.white)),
                const SizedBox(height: 4),
                SizedBox(height: 12, child: !isFut && cnt > 0 ? Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (mg > 0) _vb(0xFFe8982a, mg / vtMax),
                  if (mg > 0 && (af > 0 || ev > 0)) const SizedBox(width: 1),
                  if (af > 0) _vb(0xFF3a90c0, af / vtMax),
                  if (af > 0 && ev > 0) const SizedBox(width: 1),
                  if (ev > 0) _vb(0xFF7a5ab8, ev / vtMax),
                ]) : const SizedBox.expand()),
              ]))));
        }))),
      // Gold count badge
      if (goldCount > 0) goldCountBadge(goldCount, tc),
    ]);
  }
  Widget _vb(int cv, double pct) => Container(
    width: 5, height: max(3.0, 11.0 * pct),
    decoration: BoxDecoration(color: Color(cv).withOpacity(0.75 + pct * 0.25),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(1))));
}

// ── Month calendar ────────────────────────────────────────────
class MonthCalGrid extends StatelessWidget {
  final String anchor, selected;
  final AppState state;
  final ValueChanged<String> onSelect;
  const MonthCalGrid({super.key, required this.anchor, required this.selected, required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final d = DateUtils2.parse(anchor); final y = d.year; final m = d.month;
    final firstDow = (DateTime(y, m, 1).weekday - 1) % 7;
    final nDays = DateTime(y, m + 1, 0).day;
    const dn = ['一','二','三','四','五','六','日'];
    final today = state.todayKey; final tc = state.themeConfig;

    // Count gold days in month
    int goldCount = 0;
    for (int d2 = 1; d2 <= nDays; d2++) {
      final ds = '$y-${m.toString().padLeft(2,'0')}-${d2.toString().padLeft(2,'0')}';
      final cnt = state.doneOnDay(ds);
      if (state.isGoldDay(cnt) && ds.compareTo(today) <= 0) goldCount++;
    }

    return Column(children: [
      Row(children: dn.map((n) => Expanded(child: Center(
        child: Text(n, style: TextStyle(fontSize: 9, color: Color(tc.ts)))))).toList()),
      const SizedBox(height: 3),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 3, mainAxisSpacing: 3),
        itemCount: firstDow + nDays,
        itemBuilder: (_, idx) {
          if (idx < firstDow) return const SizedBox.shrink();
          final day2 = idx - firstDow + 1;
          final ds = '$y-${m.toString().padLeft(2,'0')}-${day2.toString().padLeft(2,'0')}';
          final cnt = state.doneOnDay(ds);
          final isFut = ds.compareTo(today) > 0;
          final isSel = ds == selected;
          final isGold = state.isGoldDay(cnt) && !isFut;
          if (isGold) return GoldenCalendarCell(day: day2, isSelected: isSel, onTap: () => onSelect(ds));
          final col = state.heatColor(cnt, isFut, ds);
          return GestureDetector(onTap: () => onSelect(ds),
            child: AnimatedContainer(duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(7),
                border: isSel ? Border.all(color: Color(tc.na), width: 2) : null),
              child: Center(child: Text('$day2', style: TextStyle(
                fontSize: 11.5,
                color: isFut ? Color(tc.ts) : Colors.white,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.normal)))));
        }),
      // Gold count badge
      if (goldCount > 0) goldCountBadge(goldCount, tc),
    ]);
  }
}

// ── Year calendar ─────────────────────────────────────────────
class YearCalGrid extends StatelessWidget {
  final String anchor;
  final AppState state;
  final ValueChanged<String> onDayTap;
  const YearCalGrid({super.key, required this.anchor, required this.state, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final year = DateUtils2.parse(anchor).year;
    final today = state.todayKey;
    final tc = state.themeConfig;
    const mNames = ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'];
    const dn = ['一','二','三','四','五','六','日'];

    // Total gold days in year
    int totalGold = 0;
    for (int m = 1; m <= 12; m++) {
      final nDays = DateTime(year, m + 1, 0).day;
      for (int d = 1; d <= nDays; d++) {
        final mStr = m.toString().padLeft(2,'0');
        final dStr = d.toString().padLeft(2,'0');
        final ds = '$year-$mStr-$dStr';
        if (ds.compareTo(today) > 0) continue;
        final cnt = state.doneOnDay(ds);
        if (state.isGoldDay(cnt)) totalGold++;
      }
    }

    return Column(children: [
      if (totalGold > 0) Padding(padding: const EdgeInsets.only(bottom: 10), child: goldCountBadge(totalGold, tc)),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.85),
        itemCount: 12,
        itemBuilder: (_, mi) {
          final m = mi + 1; final nDays = DateTime(year, m + 1, 0).day;
          final firstDow = (DateTime(year, m, 1).weekday - 1) % 7;
          final mStr = m.toString().padLeft(2, '0');

          // Per-month gold count
          int mGold = 0;
          for (int d = 1; d <= nDays; d++) {
            final ds = '$year-$mStr-${d.toString().padLeft(2,'0')}';
            if (ds.compareTo(today) <= 0 && state.isGoldDay(state.doneOnDay(ds))) mGold++;
          }

          return Container(
            decoration: BoxDecoration(color: Color(tc.cb), borderRadius: BorderRadius.circular(9)),
            padding: const EdgeInsets.all(6),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(mNames[mi], style: TextStyle(fontSize: 9, color: Color(tc.ts), fontWeight: FontWeight.w600)),
                if (mGold > 0) Text('🥇×$mGold', style: const TextStyle(fontSize: 8, color: Color(0xFFDAA520))),
              ]),
              const SizedBox(height: 3),
              GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5),
                itemCount: 7 + firstDow + nDays,
                itemBuilder: (_, idx) {
                  if (idx < 7) return Center(child: Text(dn[idx], style: TextStyle(fontSize: 5, color: Color(tc.tm))));
                  final gi = idx - 7;
                  if (gi < firstDow) return const SizedBox.shrink();
                  final d2 = gi - firstDow + 1;
                  final ds = '$year-$mStr-${d2.toString().padLeft(2,'0')}';
                  final cnt = state.doneOnDay(ds);
                  final isFut = ds.compareTo(today) > 0;
                  final isGold = state.isGoldDay(cnt) && !isFut;
                  if (isGold) return GoldenMiniCell(onTap: () => onDayTap(ds), tooltip: '$ds: $cnt件');
                  return GestureDetector(onTap: () => onDayTap(ds),
                    child: Container(decoration: BoxDecoration(
                      color: state.heatColor(cnt, isFut, ds), borderRadius: BorderRadius.circular(2))));
                }),
            ]),
          );
        }),
    ]);
  }
}
