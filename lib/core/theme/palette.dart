import 'package:flutter/material.dart';

/// Semantic color system for HabitNow Arena.
///
/// Carried as a [ThemeExtension] so every color is theme-aware, typed and
/// reachable in one hop from any BuildContext. Surfaces are warm-tinted in
/// light mode and blue-shifted in dark mode for a calm, premium feel.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.scaffold,
    required this.surface,
    required this.surfaceAlt,
    required this.elevated,
    required this.overlayScrim,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.outline,
    required this.hairline,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.primaryDeep,
    required this.flame,
    required this.flameSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.gold,
    required this.goldSoft,
    required this.onAccent,
  });

  final Color scaffold;
  final Color surface;
  final Color surfaceAlt;
  final Color elevated;
  final Color overlayScrim;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  final Color outline;
  final Color hairline;

  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color primaryDeep;

  final Color flame;
  final Color flameSoft;

  final Color success;
  final Color successSoft;

  final Color warning;
  final Color warningSoft;

  final Color danger;
  final Color dangerSoft;

  final Color gold;
  final Color goldSoft;

  /// Text color guaranteed readable on [primary], [flame], [danger], etc.
  final Color onAccent;

  static const AppColors light = AppColors(
    scaffold: Color(0xFFF6F6F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F0EA),
    elevated: Color(0xFFFFFFFF),
    overlayScrim: Color(0x66191A20),
    ink: Color(0xFF191A20),
    inkMuted: Color(0xFF5B5F6E),
    inkFaint: Color(0xFF9A9DA9),
    outline: Color(0xFFE3E3DC),
    hairline: Color(0xFFECECE5),
    primary: Color(0xFF5454D4),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEAEAFB),
    primaryDeep: Color(0xFF3F3FB2),
    flame: Color(0xFFEF5A2A),
    flameSoft: Color(0xFFFCE9E1),
    success: Color(0xFF23885A),
    successSoft: Color(0xFFE1F3E9),
    warning: Color(0xFFA96D0B),
    warningSoft: Color(0xFFFAF0DB),
    danger: Color(0xFFCB3D2E),
    dangerSoft: Color(0xFFFAE6E2),
    gold: Color(0xFFA97C1F),
    goldSoft: Color(0xFFF6ECD3),
    onAccent: Color(0xFFFFFFFF),
  );

  static const AppColors dark = AppColors(
    scaffold: Color(0xFF0E0F14),
    surface: Color(0xFF16181F),
    surfaceAlt: Color(0xFF1D202B),
    elevated: Color(0xFF232734),
    overlayScrim: Color(0xA6000000),
    ink: Color(0xFFF3F4F8),
    inkMuted: Color(0xFFA7ABB9),
    inkFaint: Color(0xFF70747F),
    outline: Color(0xFF2A2E3B),
    hairline: Color(0xFF21242E),
    primary: Color(0xFF9797F5),
    onPrimary: Color(0xFF131331),
    primarySoft: Color(0xFF282A4E),
    primaryDeep: Color(0xFF6B6BE3),
    flame: Color(0xFFFF7E52),
    flameSoft: Color(0xFF3A2419),
    success: Color(0xFF57C489),
    successSoft: Color(0xFF182E23),
    warning: Color(0xFFE0A94F),
    warningSoft: Color(0xFF322811),
    danger: Color(0xFFF07E6E),
    dangerSoft: Color(0xFF39201C),
    gold: Color(0xFFE0B35E),
    goldSoft: Color(0xFF33280F),
    onAccent: Color(0xFF131331),
  );

  /// Given a brand hue, the soft container that pairs with it in [dark].
  static Color softFor(Color seed, bool dark) {
    return Color.alphaBlend(seed.withValues(alpha: dark ? 0.22 : 0.12),
        dark ? const Color(0xFF16181F) : const Color(0xFFFFFFFF));
  }

  @override
  AppColors copyWith({
    Color? scaffold,
    Color? surface,
    Color? surfaceAlt,
    Color? elevated,
    Color? overlayScrim,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? outline,
    Color? hairline,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? primaryDeep,
    Color? flame,
    Color? flameSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? gold,
    Color? goldSoft,
    Color? onAccent,
  }) {
    return AppColors(
      scaffold: scaffold ?? this.scaffold,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      elevated: elevated ?? this.elevated,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      outline: outline ?? this.outline,
      hairline: hairline ?? this.hairline,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      flame: flame ?? this.flame,
      flameSoft: flameSoft ?? this.flameSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      flame: Color.lerp(flame, other.flame, t)!,
      flameSoft: Color.lerp(flameSoft, other.flameSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  /// The resolved semantic palette for the current theme.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  /// Canonical dark-mode check — always correct, including mid-transition.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
