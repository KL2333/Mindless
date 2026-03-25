// lib/beta/task_gravity.dart
// "Task Gravity" — tasks that are older, more rescheduled, or more urgent
// naturally sink to the top (high gravity = most visible).

import '../models/models.dart';
import '../providers/app_state.dart';

class TaskGravity {
  /// Compute gravity score (higher = more urgent = shown first).
  static double score(TaskModel t, AppState state) {
    if (t.done || t.ignored) return -1;

    double g = 0;
    final today = state.todayKey;
    final d = AppState.appDateKey(DateTime.now());

    // 1. Overdue days: each day overdue adds weight
    if (t.originalDate.compareTo(today) < 0) {
      final overdueDays = DateTime.parse('${today}T12:00:00')
          .difference(DateTime.parse('${t.originalDate}T12:00:00'))
          .inDays;
      g += overdueDays * 3.0;
    }

    // 2. Reschedule penalty: each reschedule doubles the urgency signal
    if (t.rescheduledTo != null) g += 5.0;

    // 3. Time of day alignment: tasks mismatched to current time get a nudge
    final hour = DateTime.now().hour;
    final currentBlk = AppState.hourToTimeBlock(hour, 0);
    if (t.timeBlock == currentBlk) g += 2.0; // currently due!

    // 4. Focus time already spent: sunk cost nudge
    if (t.focusSecs > 0) g += t.focusSecs / 1800.0; // 30min = +1

    // 5. Quadrant weight
    switch (t.quadrant) {
      case 1: g += 4.0; break; // urgent+important
      case 3: g += 2.0; break; // urgent
      case 2: g += 1.0; break; // important
      default: break;
    }

    return g;
  }

  /// Sort tasks by gravity descending (heaviest first = top of list).
  static List<TaskModel> sort(List<TaskModel> tasks, AppState state) {
    final scored = tasks.map((t) => (t, score(t, state))).toList();
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  static String gravityLabel(double g) {
    if (g <= 0) return '';
    if (g < 3) return '●';
    if (g < 7) return '●●';
    return '●●●';
  }

  static String gravityDescription(TaskModel t, AppState state) {
    final g = score(t, state);
    if (g <= 0) return '';
    if (g < 3) return '轻度延迟';
    if (g < 7) return '亟待处理';
    return '⚠ 严重滞后';
  }
}
