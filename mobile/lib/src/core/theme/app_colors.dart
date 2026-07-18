import 'package:flutter/material.dart';

/// Central brand palette. Keep every screen pulling from here instead of
/// hardcoding hex values so the app reads as one consistent system.
class AppColors {
  AppColors._();

  static const brandGreen = Color(0xFFACEC87);
  static const darkGreen = Color(0xFF1D3108);
  static const accentGreen = Color(0xFF5BA72D);
  static const paleGreen = Color(0xFFE8F6E0);
  static const seedGreen = Color(0xFFC8E6A0);

  static const background = Color(0xFFF9FBF8);
  static const surface = Colors.white;
  static const border = Color(0xFFE0E0E0);
  static const divider = Color(0xFFF3F4F6);

  static const textPrimary = darkGreen;
  static const textSecondary = Color(0xFF757575);
  static const textMuted = Color(0xFFBDBDBD);
  static const hint = Color(0xFF9CA3AF);

  static const info = Color(0xFF4A90E2);
  static const infoPale = Color(0xFFEAF2FF);
  static const warning = Color(0xFFF0916F);
  static const warningPale = Color(0xFFFFF2EC);
  static const danger = Color(0xFFE05C5C);
  static const dangerPale = Color(0xFFFCEAEA);
}

class AppRadius {
  AppRadius._();

  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Standard soft-shadow used for cards throughout the app.
List<BoxShadow> cardShadow({double opacity = 0.04}) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
