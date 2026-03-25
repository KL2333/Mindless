// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../models/models.dart';

class AppTheme {
  static ThemeData themeData(String themeName) {
    final t = kThemes[themeName] ?? kThemes['warm']!;
    // 注意：透明度由 main.dart 的 Opacity wrapper 统一控制
    // ThemeData 里的颜色保持不透明，由 Opacity 整体降低
    final acc  = Color(t.acc);
    final bg   = Color(t.bg);
    final card = Color(t.card);
    final tx   = Color(t.tx);
    final ts   = Color(t.ts);
    final brd  = Color(t.brd);
    final cb   = Color(t.cb);
    final nb   = Color(t.nb);
    final na   = Color(t.na);
    final nt   = Color(t.nt);

    final scheme = ColorScheme(
      brightness: bg.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
      primary: acc,
      onPrimary: nt,
      secondary: Color(t.acc2),
      onSecondary: nt,
      error: const Color(0xFFc04040),
      onError: Colors.white,
      surface: card,
      onSurface: tx,
      surfaceContainerHighest: cb,
      outline: brd,
      outlineVariant: brd,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'serif',
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: ts),
        titleTextStyle: TextStyle(fontFamily: 'serif', color: tx, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: nb,
        indicatorColor: na,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return IconThemeData(color: nt, size: 22);
          return IconThemeData(color: ts, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return TextStyle(color: nt, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'serif');
          return TextStyle(color: ts, fontSize: 11, fontFamily: 'serif');
        }),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: themeName == 'black_hole' ? 4 : 0,
        shadowColor: themeName == 'black_hole' ? acc.withOpacity(0.25) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: themeName == 'black_hole' 
            ? BorderSide(color: acc.withOpacity(0.15), width: 0.5)
            : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cb,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        hintStyle: TextStyle(color: Color(t.tm), fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cb,
        labelStyle: TextStyle(fontSize: 11, color: ts),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: brd, space: 1, thickness: 1),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: tx, fontSize: 14, fontFamily: 'serif'),
        bodySmall: TextStyle(color: ts, fontSize: 12, fontFamily: 'serif'),
        labelSmall: TextStyle(color: ts, fontSize: 10, fontFamily: 'serif'),
      ),
    );
  }

  static ThemeConfig of(String name) => kThemes[name] ?? kThemes['warm']!;
}

// Extension for quick color access
extension ThemeCtx on BuildContext {
  ThemeConfig get tc {
    final state = Theme.of(this);
    // find theme name from scaffold bg color
    for (final entry in kThemes.entries) {
      if (Color(entry.value.bg) == state.scaffoldBackgroundColor) return entry.value;
    }
    return kThemes['warm']!;
  }
}
