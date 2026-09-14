import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Staggered entrance: children fade + rise in sequence. Wrap list items
/// with index-based delays for a choreographed first impression.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 40),
    this.distance = 14,
  });

  final Widget child;
  final int index;
  final Duration baseDelay;
  final double distance;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.slow + baseDelay * index.clamp(0, 12),
      curve: Interval(
        (index.clamp(0, 12) * 0.055).clamp(0.0, 0.6),
        1.0,
        curve: Motion.emphasized,
      ),
      builder: (BuildContext context, double t, _) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, distance * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Respects the OS reduced-motion setting — everything animation-driven
/// should route through this for its durations.
bool reducedMotion(BuildContext context) {
  return MediaQuery.of(context).disableAnimations;
}

/// Numbers that count up when they change — leaderboard points, streaks.
class CountUpText extends StatelessWidget {
  const CountUpText(
    this.value, {
    super.key,
    this.style,
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: Motion.leisure,
      curve: Motion.emphasized,
      builder: (BuildContext context, double v, _) {
        return Text(
          '${v.round()}$suffix',
          style: style,
        );
      },
    );
  }
}
