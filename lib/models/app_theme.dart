import 'package:flutter/material.dart';

/// Theme identifier for the 4 gradient themes.
enum ThemeId {
  midnightBlue,
  sunrise,
  lavender,
  forestCalm,
}

/// Defines a gradient theme (colors for background and accents).
class AppTheme {
  final ThemeId id;
  final String displayName;
  final List<Color> gradientColors;
  final Color accentColor;

  const AppTheme({
    required this.id,
    required this.displayName,
    required this.gradientColors,
    required this.accentColor,
  });

  /// Linear gradient for scaffold/background.
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      );

  static const midnightBlue = AppTheme(
    id: ThemeId.midnightBlue,
    displayName: 'Midnight Blue',
    gradientColors: [
      Color(0xFF0f0c29),
      Color(0xFF302b63),
      Color(0xFF24243e),
    ],
    accentColor: Color(0xFF6b8cff),
  );

  static const sunrise = AppTheme(
    id: ThemeId.sunrise,
    displayName: 'Sunrise',
    gradientColors: [
      Color(0xFFff6b6b),
      Color(0xFFfeca57),
      Color(0xFFff9ff3),
    ],
    accentColor: Color(0xFFee5a24),
  );

  static const lavender = AppTheme(
    id: ThemeId.lavender,
    displayName: 'Lavender',
    gradientColors: [
      Color(0xFF667eea),
      Color(0xFF764ba2),
      Color(0xFFf093fb),
    ],
    accentColor: Color(0xFFa855f7),
  );

  static const forestCalm = AppTheme(
    id: ThemeId.forestCalm,
    displayName: 'Forest Calm',
    gradientColors: [
      Color(0xFF134e5e),
      Color(0xFF71b280),
      Color(0xFF2d5016),
    ],
    accentColor: Color(0xFF22c55e),
  );

  static const List<AppTheme> all = [
    midnightBlue,
    sunrise,
    lavender,
    forestCalm,
  ];

  static AppTheme fromId(ThemeId id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => midnightBlue,
    );
  }
}
