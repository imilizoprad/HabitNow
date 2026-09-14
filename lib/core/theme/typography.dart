import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Type system.
///
/// Built on the platform font stack (SF Pro / Roboto) — crisp, zero-load
/// cost, and honest about being native. Display styles tighten tracking,
/// numerals use tabular figures so counters never jitter while animating.
abstract final class AppType {
  static const double _display = 30;
  static const double _titleL = 22;
  static const double _titleM = 17.5;
  static const double _body = 15.5;
  static const double _label = 13.5;
  static const double _caption = 12;
  static const double _micro = 10.5;

  static TextTheme textTheme(Color ink, Color inkMuted) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: _display + 4,
        height: 1.08,
        letterSpacing: -1.2,
        fontWeight: FontWeight.w800,
        color: ink,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      displayMedium: TextStyle(
        fontSize: _display,
        height: 1.1,
        letterSpacing: -1.0,
        fontWeight: FontWeight.w800,
        color: ink,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      displaySmall: TextStyle(
        fontSize: 26,
        height: 1.14,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w800,
        color: ink,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      headlineMedium: TextStyle(
        fontSize: _titleL,
        height: 1.2,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 19,
        height: 1.24,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: _titleM,
        height: 1.26,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: _label + 1.5,
        height: 1.3,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: _label,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: _body,
        height: 1.42,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: _label,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: inkMuted,
      ),
      bodySmall: TextStyle(
        fontSize: _caption,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: inkMuted,
      ),
      labelLarge: TextStyle(
        fontSize: _label + 1,
        height: 1.1,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w600,
        color: ink,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      labelMedium: TextStyle(
        fontSize: _caption,
        height: 1.1,
        fontWeight: FontWeight.w600,
        color: ink,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      labelSmall: TextStyle(
        fontSize: _micro,
        height: 1.2,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w700,
        color: inkMuted,
      ),
    );
  }

  /// Oversized stat numerals (leaderboard points, streak counts).
  static TextStyle statNum(AppColors c) => TextStyle(
        fontSize: 34,
        height: 1.0,
        letterSpacing: -1.4,
        fontWeight: FontWeight.w800,
        color: c.ink,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}
