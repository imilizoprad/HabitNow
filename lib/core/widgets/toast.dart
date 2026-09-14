import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/palette.dart';
import 'avatar.dart';

/// In-app toasts — a floating capsule dropping from under the status bar.
/// Not a SnackBar: it never relayouts the page, and it can carry an avatar.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    String? emoji,
    (String, int)? identity,
  }) {
    _current?.remove();
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext ctx) => _ToastView(
        message: message,
        emoji: emoji,
        identity: identity,
        onDismiss: () => _current?.remove(),
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    this.emoji,
    this.identity,
    this.onDismiss,
  });

  final String message;
  final String? emoji;
  final (String, int)? identity;
  final VoidCallback? onDismiss;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Motion.base,
    reverseDuration: Motion.base,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future<void>.delayed(const Duration(milliseconds: 2600), () async {
      if (mounted) await _ctrl.reverse();
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Positioned(
      top: MediaQuery.of(context).padding.top + Sp.sm,
      left: Sp.xl,
      right: Sp.xl,
      child: IgnorePointer(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.6),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: _ctrl, curve: Motion.springy)),
          child: FadeTransition(
            opacity: _ctrl,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Sp.lg, vertical: Sp.md),
              decoration: BoxDecoration(
                color: c.ink,
                borderRadius: BorderRadius.circular(Radii.pill),
                boxShadow: Elev.shadow(3, dark: true),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.identity != null) ...<Widget>[
                    EmojiAvatar(widget.identity!.$1,
                        seed: widget.identity!.$2, size: 26),
                    const SizedBox(width: Sp.md),
                  ] else if (widget.emoji != null) ...<Widget>[
                    Text(widget.emoji!,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: Sp.sm),
                  ],
                  Flexible(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: c.scaffold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen award moment: dim scrim, trophy card scaling in, confetti.
class Celebration extends StatefulWidget {
  const Celebration({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.onDone,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback? onDone;

  /// Convenience: pushes itself and self-dismisses.
  static Future<void> celebrate(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (BuildContext ctx) => Celebration(
        emoji: emoji,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Motion.leisure,
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2100), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _ConfettiPainter(progress: _ctrl.value),
            ),
          ),
          ScaleTransition(
            scale: CurvedAnimation(
                    parent: _ctrl,
                    curve: Interval(0.1, 0.6, curve: Motion.springy))
                .drive(Tween<double>(begin: 0.6, end: 1)),
            child: Container(
              padding: const EdgeInsets.all(Sp.xxl),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: c.gold.withValues(alpha: 0.6)),
                boxShadow: Elev.shadow(4, dark: context.isDark),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: c.goldSoft,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: c.gold.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 44)),
                  ),
                  const SizedBox(height: Sp.lg),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight deterministic confetti — no assets, no package.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final math.Random rng = math.Random(7); // deterministic
    final Paint paint = Paint();
    final List<Color> palette = <Color>[
      const Color(0xFF6366F1),
      const Color(0xFFEC6A45),
      const Color(0xFF2FA36B),
      const Color(0xFFE0B35E),
      const Color(0xFF9F5DE2),
    ];
    const int count = 90;
    for (int i = 0; i < count; i++) {
      final double px = rng.nextDouble() * size.width;
      final double fall = rng.nextDouble() * 1.3 + 0.5;
      final double py =
          size.height * 0.28 + progress * size.height * 0.9 * fall;
      final double rot = progress * (rng.nextDouble() * 8 + 2);
      final double size2 = rng.nextDouble() * 5 + 3;
      paint.color = palette[i % palette.length]
          .withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: size2,
              height: size2 * (0.4 + progress)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
