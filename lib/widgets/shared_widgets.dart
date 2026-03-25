// lib/widgets/shared_widgets.dart
import 'package:flutter/material.dart';
import '../models/models.dart';

/// Animated toggle switch matching app theme
class AppSwitch extends StatelessWidget {
  final bool value;
  final ThemeConfig tc;
  final ValueChanged<bool> onChanged;

  const AppSwitch({
    super.key,
    required this.value,
    required this.tc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: value ? Color(tc.acc) : Color(tc.brd),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}
