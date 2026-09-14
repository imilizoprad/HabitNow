import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/palette.dart';
import '../utils/haptics.dart';

/// Press feedback with a springy scale-down + fade. The default "tap"
/// wrapper for every custom touchable in the app.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.enabled = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = !widget.enabled || widget.onTap == null;
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled
            ? null
            : (_) {
                setState(() => _down = true);
                Haptics.select();
              },
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: disabled ? null : widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1.0,
          duration: Motion.fast,
          curve: Motion.emphasized,
          child: AnimatedOpacity(
            opacity: disabled ? 0.45 : 1.0,
            duration: Motion.base,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Section titles: small caps eyebrow + optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.eyebrow});

  final String title;
  final Widget? action;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.screenH, Sp.xl, Sp.screenH, Sp.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: c.inkFaint, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: Sp.xs),
                ],
                Text(title,
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Compact pill for stats ("🔥 12", "3 days left").
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.soft,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? soft;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color fg = color ?? c.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
      decoration: BoxDecoration(
        color: soft ?? c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Empty state: emoji in a soft ring, title, one-line nudge, optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: c.hairline),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: Sp.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Sp.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: Sp.xl),
              Pressable(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Sp.xl, vertical: Sp.md),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    actionLabel!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: c.onPrimary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft banner for contextual notices (network degraded, forfeit due…).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.tone = BannerTone.info,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final BannerTone tone;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final (Color fg, Color bg) = switch (tone) {
      BannerTone.info => (c.primaryDeep, c.primarySoft),
      BannerTone.warn => (c.warning, c.warningSoft),
      BannerTone.danger => (c.danger, c.dangerSoft),
      BannerTone.success => (c.success, c.successSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: fg),
            ),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Sp.sm),
                child: Text(
                  action!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum BannerTone { info, warn, danger, success }

/// The one true card surface: tint-first, hairline outline, gentle shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.lg),
    this.color,
    this.radius = Radii.l,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.hairline),
        boxShadow: Elev.shadow(1, dark: context.isDark),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}
