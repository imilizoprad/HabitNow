import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/palette.dart';

/// Circular progress ring with an animated sweep. Used for the daily
/// completion dial and the focus timer.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.size = 96,
    this.stroke = 9,
    this.child,
    this.capRound = true,
    this.animateFrom,
  });

  final double progress; // 0..1
  final Color color;
  final Color trackColor;
  final double size;
  final double stroke;
  final Widget? child;
  final bool capRound;

  /// When provided, the ring tweens from this value on first build.
  final double? animateFrom;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animateFrom ?? 0, end: progress.clamp(0, 1)),
      duration: Motion.leisure,
      curve: Motion.emphasized,
      builder: (BuildContext context, double value, Widget? _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: color,
              trackColor: trackColor,
              stroke: stroke,
              capRound: capRound,
            ),
            child: Center(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.stroke,
    required this.capRound,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double stroke;
  final bool capRound;

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = stroke / 2 + 1;
    final Rect rect = Offset.infinite & size;
    final Rect arc = rect.deflate(inset);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor
      ..strokeCap = capRound ? StrokeCap.round : StrokeCap.butt;
    canvas.drawArc(arc, 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..strokeCap = capRound ? StrokeCap.round : StrokeCap.butt;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * progress, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.stroke != stroke;
}

/// Slim animated linear bar.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.trackColor,
    this.radius,
  });

  /// 0..1
  final double value;
  final Color color;
  final double height;
  final Color? trackColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: Motion.leisure,
      curve: Motion.emphasized,
      builder: (BuildContext context, double v, _) {
        return LayoutBuilder(builder:
            (BuildContext context, BoxConstraints constraints) {
          final double w = constraints.maxWidth * v;
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: trackColor ?? c.surfaceAlt,
              borderRadius: BorderRadius.circular(radius ?? height / 2),
            ),
            alignment: Alignment.centerLeft,
            child: w <= 0
                ? const SizedBox.shrink()
                : Container(
                    width: w,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(radius ?? height / 2),
                    ),
                  ),
          );
        });
      },
    );
  }
}

/// Head-to-head bar: two fills growing from opposite ends — the signature
/// visual of a duel.
class DuelBar extends StatelessWidget {
  const DuelBar({
    super.key,
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    this.height = 12,
  });

  final double a;
  final double b;
  final Color colorA;
  final Color colorB;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double total = (a + b) == 0 ? 1 : (a + b);
    final double target = (a / total).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: Motion.leisure,
      curve: Motion.emphasized,
      builder: (BuildContext context, double v, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints cons) {
                final double w = cons.maxWidth;
                return Row(
                  children: <Widget>[
                    SizedBox(
                      width: w * v,
                      child:
                          ColoredBox(color: colorA, child: SizedBox.expand()),
                    ),
                    Expanded(
                      child:
                          ColoredBox(color: colorB, child: SizedBox.expand()),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
