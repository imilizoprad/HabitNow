import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';
import 'palette.dart';
import 'typography.dart';

/// Assembles the two [ThemeData] instances used across the app.
///
/// Component theming is deliberately done in our own widgets rather than
/// through ThemeData's `xTheme` parameters — that keeps styling co-located
/// with the design system and immune to Flutter's theme-type churn.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final bool dark = c == AppColors.dark;
    final ColorScheme scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: dark ? c.ink : c.primaryDeep,
      secondary: c.flame,
      onSecondary: c.onAccent,
      secondaryContainer: c.flameSoft,
      onSecondaryContainer: c.ink,
      tertiary: c.gold,
      onTertiary: c.onAccent,
      tertiaryContainer: c.goldSoft,
      onTertiaryContainer: c.ink,
      error: c.danger,
      onError: c.onAccent,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceAlt,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainerLowest: dark ? c.scaffold : c.scaffold,
      onSurfaceVariant: c.inkMuted,
      outline: c.outline,
      outlineVariant: c.hairline,
      inverseSurface: dark ? AppColors.light.surface : AppColors.dark.surface,
      onInverseSurface: dark ? AppColors.light.ink : AppColors.dark.ink,
      inversePrimary: dark ? AppColors.light.primary : AppColors.dark.primary,
      shadow: const Color(0xFF14151A),
      scrim: c.overlayScrim,
    );

    final SystemUiOverlayStyle overlayStyle = dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.scaffold,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.scaffold,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.scaffold,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: AppType.textTheme(c.ink, c.inkMuted),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Sp.screenH,
        iconTheme: IconThemeData(color: c.ink, size: 24),
        actionsIconTheme: IconThemeData(color: c.ink, size: 22),
        toolbarTextStyle: AppType.textTheme(c.ink, c.inkMuted).titleLarge,
        systemOverlayStyle: overlayStyle,
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      splashColor: c.primary.withValues(alpha: 0.08),
      highlightColor: c.primary.withValues(alpha: 0.05),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.22),
        selectionHandleColor: c.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.onPrimary : c.surface),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.primary : c.outline),
        trackOutlineColor:
            WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
                s.contains(WidgetState.selected) ? c.primary : c.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.primary : Colors.transparent),
        checkColor: WidgetStateProperty.all(c.onPrimary),
        side: BorderSide(color: c.outline, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceAlt,
        thumbColor: c.surface,
        overlayColor: c.primary.withValues(alpha: 0.12),
        valueIndicatorColor: c.elevated,
        valueIndicatorTextStyle: TextStyle(color: c.ink),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: c.surfaceAlt,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: TextStyle(color: c.scaffold, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      platform: TargetPlatform.android,
    );
  }
}
