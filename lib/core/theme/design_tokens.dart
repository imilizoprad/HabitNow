import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// ---------------------------------------------------------------------------
/// Motion — one source of truth for how the app moves.
/// ---------------------------------------------------------------------------
abstract final class Motion {
  /// Micro-feedback: presses, chips, checkbox ticks.
  static const Duration fast = Duration(milliseconds: 140);

  /// Standard element transitions: sheets, fades, color tweens.
  static const Duration base = Duration(milliseconds: 240);

  /// Route transitions and hero-ish movement.
  static const Duration slow = Duration(milliseconds: 340);

  /// Celebrations, radar sweeps, large surface changes.
  static const Duration leisure = Duration(milliseconds: 520);

  /// Material's emphasized curve — the default "go" curve.
  static const Cubic emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Symmetric ease for cross-fades and color tweens.
  static const Cubic standard = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Gentle exit curve — elements leave faster than they arrive.
  static const Cubic exit = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Controlled overshoot for playful moments (checks, badges, counts).
  static const Cubic springy = Cubic(0.34, 1.56, 0.64, 1.0);
}

/// ---------------------------------------------------------------------------
/// Spacing — a 4pt scale. Never hardcode a gap; compose from these.
/// ---------------------------------------------------------------------------
abstract final class Sp {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double vast = 48;

  /// Default horizontal screen padding.
  static const double screenH = 20;

  /// Minimum comfortable touch target (Material accessibility floor).
  static const double tapTarget = 48;
}

/// ---------------------------------------------------------------------------
/// Radii — four tiers cover every surface in the app.
/// ---------------------------------------------------------------------------
abstract final class Radii {
  static const double s = 10;
  static const double m = 14;
  static const double l = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// ---------------------------------------------------------------------------
/// Elevation — tint-first design: surfaces differ by tint, not by shadow.
/// Shadows are soft, directional and only used above the base surface.
/// ---------------------------------------------------------------------------
abstract final class Elev {
  static const double hairline = 1.0;

  static List<BoxShadow> shadow(
    double elevation, {
    required bool dark,
    double spread = 0,
  }) {
    if (elevation <= 0) return const <BoxShadow>[];
    final double opacity = dark ? 0.5 : 0.10;
    final int blur = (elevation * 14).round();
    final int dy = (elevation * 3).round();
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF14151A).withValues(alpha: opacity),
        blurRadius: blur.toDouble(),
        spreadRadius: spread,
        offset: Offset(0, dy.toDouble()),
      ),
    ];
  }
}
