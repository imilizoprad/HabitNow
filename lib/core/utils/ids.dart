import 'dart:math';

/// Compact, collision-unlikely ids without pulling in a package.
///
/// Format: `h_` + 18 chars of cryptographically-secure base36 — plenty for a
/// P2P app where ids must be unique across devices that never talk to a
/// central issuer.
String newId([String prefix = 'h']) {
  final Random rng = Random.secure();
  const String alphabet =
      '0123456789abcdefghijklmnopqrstuvwxyz';
  final StringBuffer sb = StringBuffer(prefix)..write('_');
  for (int i = 0; i < 18; i++) {
    sb.write(alphabet[rng.nextInt(alphabet.length)]);
  }
  return sb.toString();
}

/// Stable 31-bit hash for a string — unlike [String.hashCode], this is
/// deterministic across app restarts (reminder ids depend on it).
int stableHash(String s) {
  int h = 0;
  for (final int c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}
