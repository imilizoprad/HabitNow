import 'package:flutter/services.dart';

/// Central haptic vocabulary so the whole app speaks one tactile language.
/// Users can silence everything from Settings ([enabled]).
abstract final class Haptics {
  static bool enabled = true;

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Success moments — a short double-tick pattern via two impacts.
  static Future<void> success() async {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    HapticFeedback.lightImpact();
  }

  static void warning() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
