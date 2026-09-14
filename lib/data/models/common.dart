import 'package:flutter/material.dart' show Color;

/// Contract for entities that participate in peer-to-peer sync.
///
/// Every shared entity is stamped with when it last changed and by which
/// device. Conflict resolution is deterministic last-write-wins: newer
/// timestamp wins, and a lexicographic device-id tiebreak guarantees all
/// peers converge to the same value even on identical timestamps.
///
/// (An interface, not a mixin: initializing formals may only target fields
/// declared in the same class, and every model owns its stamp fields.)
abstract interface class Synced {
  abstract int updatedAt;
  abstract String updatedBy;
}

extension SyncedX on Synced {
  /// True when [otherStamp]/[otherActor] should replace this record.
  bool supersedes(int otherStamp, String otherActor) {
    if (otherStamp != updatedAt) return otherStamp > updatedAt;
    return otherActor.compareTo(updatedBy) > 0;
  }
}

/// The fixed accent palette referenced by habits, tasks and profiles.
///
/// Stored as an index (not a raw color) so peers render identical semantic
/// colors on both light and dark themes.
class HabitPalette {
  const HabitPalette._();

  static const List<int> seeds = <int>[0, 1, 2, 3, 4, 5, 6, 7];

  /// Primary hue for [seed] — tuned to hold ≥4.5:1 contrast as an icon tint
  /// on both theme surfaces.
  static Color color(int seed) => const <Color>[
        Color(0xFF6366F1), // iris
        Color(0xFFEC6A45), // coral
        Color(0xFF2FA36B), // mint
        Color(0xFF3D9BE9), // sky
        Color(0xFF9F5DE2), // violet
        Color(0xFFE0518C), // rose
        Color(0xFFC9A227), // brass
        Color(0xFF12A5A5), // teal
      ][seed.clamp(0, 7)];

  /// Soft container hue for [seed], blended against the theme surface.
  static Color soft(int seed, bool dark) => Color.alphaBlend(
      color(seed).withValues(alpha: dark ? 0.24 : 0.13),
      dark ? const Color(0xFF16181F) : const Color(0xFFFFFFFF));

  static int clampSeed(int? seed) => (seed ?? 0).clamp(0, 7);
}
