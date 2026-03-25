// lib/widgets/date_clock.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class DateClock extends StatefulWidget {
  const DateClock({super.key});
  @override
  State<DateClock> createState() => _DateClockState();
}

class _DateClockState extends State<DateClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update every minute is enough for date display
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Use app date (5am rollover)
    final appDateStr = AppState.appDateKey(_now);
    final d = DateTime.parse('${appDateStr}T12:00:00');
    const weekdays = ['', '一', '二', '三', '四', '五', '六', '日'];
    final weekday = weekdays[d.weekday];
    final dateLabel = '${d.year} 年 ${d.month} 月 ${d.day} 日';
    final timeLabel = AppState.fmt25h(_now.hour, _now.minute);

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(dateLabel,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
              letterSpacing: 0.3)),
          const SizedBox(width: 8),
          Text('星期$weekday',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const Spacer(),
          Text(timeLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
              fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}
