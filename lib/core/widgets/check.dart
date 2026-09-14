import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/palette.dart';
import '../utils/haptics.dart';

/// The signature interaction: a circular target that springs to a filled
/// disc and draws its tick on completion. Semantic-checked, haptic-backed.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.done,
    required this.color,
    this.size = 34,
    this.onToggle,
    this.semanticLabel,
  });

  final bool done;
  final Color color;
  final double size;
  final VoidCallback? onToggle;
  final String? semanticLabel;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: widget.done ? 1 : 0,
  );

  @override
  void didUpdateWidget(AnimatedCheck old) {
    super.didUpdateWidget(old);
    if (old.done != widget.done) {
      if (widget.done) {
        Haptics.success();
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Semantics(
      button: true,
      checked: widget.done,
      label: widget.semanticLabel ?? 'Mark habit',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (BuildContext context, _) {
              final double t = CurvedAnimation(
                      parent: _ctrl, curve: Motion.emphasized)
                  .value;
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _CheckPainter(
                    progress: t,
                    color: widget.color,
                    ring: c.outline,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.progress,
    required this.color,
    required this.ring,
  });

  /// 0 → empty ring, 1 → filled disc with full tick.
  final double progress;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double r = size.shortestSide / 2;
    final double fillR = r * 1.02 * Curves.easeOutBack
        .transform((progress * 1.4).clamp(0.0, 1.0));

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = ring;
    canvas.drawCircle(center, r - 1.1, ringPaint);

    if (progress > 0) {
      final Paint fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawCircle(center, math.max(0, fillR), fill);
    }

    // Tick draws in the second half of the animation.
    final double tickT =
        ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    if (tickT > 0) {
      final Paint tick = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFFFFF);
      final Path p = Path()
        ..moveTo(center.dx - r * 0.42, center.dy + r * 0.02)
        ..lineTo(center.dx - r * 0.1, center.dy + r * 0.34)
        ..lineTo(center.dx + r * 0.46, center.dy - r * 0.3);
      final PathMetric metric =
          p.computeMetrics().isEmpty ? null : p.computeMetrics().first;
      if (metric != null) {
        canvas.drawPath(metric.extractPath(0, metric.length * tickT), tick);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
