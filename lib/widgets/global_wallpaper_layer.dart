// Global wallpaper + festival painter + weather — behind all Navigator routes.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/festival_bg_service.dart';
import 'black_hole_shader_widget.dart';

/// Wraps the entire app (MaterialApp child) when a custom background image is set.
class GlobalWallpaperLayer extends StatelessWidget {
  final Widget child;
  const GlobalWallpaperLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final shows = state.showsGlobalWallpaper;
    final themeId = state.settings.theme;
    final customPath = state.settings.customBgImagePath;

    if (!shows) return child;

    final Widget background = (customPath != null && customPath.isNotEmpty)
        ? Image.file(
            File(customPath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : themeId == 'black_hole'
            ? const BlackHoleShaderWidget()
            : themeId == 'dragon_boat'
                ? Stack(
                    children: [
                      Positioned.fill(child: Container(color: Color(state.themeConfig.bg))),
                      const Positioned.fill(
                        child: FestivalBgOverlay(forceFestivalId: 'dragon_boat'),
                      ),
                    ],
                  )
                : const SizedBox.shrink();

    if (background is SizedBox) return child;
    return Stack(children: [background, child]);
  }
}
