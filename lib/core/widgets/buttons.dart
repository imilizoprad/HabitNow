import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/palette.dart';
import '../utils/haptics.dart';
import 'primitives.dart';

/// The button system: one widget, four intents, three sizes.
class AppButton extends StatelessWidget {
  const AppButton.primary(
    this.label, {
    super.key,
    this.onTap,
    this.size = AppButtonSize.regular,
    this.icon,
    this.expanded = false,
  })  : intent = _Intent.primary,
        trailing = null;

  const AppButton.soft(
    this.label, {
    super.key,
    this.onTap,
    this.size = AppButtonSize.regular,
    this.icon,
    this.expanded = false,
  })  : intent = _Intent.soft,
        trailing = null;

  const AppButton.ghost(
    this.label, {
    super.key,
    this.onTap,
    this.size = AppButtonSize.regular,
    this.icon,
    this.expanded = false,
  })  : intent = _Intent.ghost,
        trailing = null;

  const AppButton.danger(
    this.label, {
    super.key,
    this.onTap,
    this.size = AppButtonSize.regular,
    this.icon,
    this.expanded = false,
  })  : intent = _Intent.danger,
        trailing = null;

  final String label;
  final VoidCallback? onTap;
  final AppButtonSize size;
  final _Intent intent;
  final IconData? icon;
  final IconData? trailing;
  final bool expanded;


  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final (Color bg, Color fg, Color? outline) = switch (intent) {
      _Intent.primary => (c.primary, c.onPrimary, null),
      _Intent.soft => (c.primarySoft, c.primaryDeep, null),
      _Intent.ghost => (Colors.transparent, c.inkMuted, c.outline),
      _Intent.danger => (c.dangerSoft, c.danger, null),
    };
    final double h = switch (size) {
      AppButtonSize.small => 38.0,
      AppButtonSize.regular => 50.0,
      AppButtonSize.large => 56.0,
    };
    final TextStyle style = switch (size) {
      AppButtonSize.small =>
        (Theme.of(context).textTheme.labelMedium ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.w700),
      _ => (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
          .copyWith(fontSize: size == AppButtonSize.large ? 16 : null),
    };
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: size == AppButtonSize.small ? 16 : 19, color: fg),
          const SizedBox(width: Sp.sm),
        ],
        Text(label, style: style.copyWith(color: fg)),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: Sp.sm),
          Icon(trailing, size: 18, color: fg),
        ],
      ],
    );
    return Pressable(
      onTap: onTap,
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
        constraints:
            expanded ? BoxConstraints(minWidth: double.infinity) : null,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(switch (size) {
            AppButtonSize.small => Radii.s,
            _ => Radii.m,
          }),
          border: outline == null ? null : Border.all(color: outline),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

enum AppButtonSize { small, regular, large }

/// Unlabelled intents used by [AppButton].
enum _Intent { primary, soft, ghost, danger }

/// Circular icon action (app bars, cards).
class IconCapsule extends StatelessWidget {
  const IconCapsule(
    this.icon, {
    super.key,
    this.onTap,
    this.size = 42,
    this.color,
    this.iconColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Widget btn = Pressable(
      onTap: onTap,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.hairline),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: size * 0.48, color: iconColor ?? c.inkMuted),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}
