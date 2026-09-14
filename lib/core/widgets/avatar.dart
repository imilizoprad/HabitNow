import 'package:flutter/material.dart';

import '../../data/models/common.dart';
import '../theme/palette.dart';
import '../../data/models/common.dart';
import 'primitives.dart';

/// Emoji avatar with a color ring — the identity system of the app.
/// Emojis keep the P2P experience playful and need zero assets.
class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar(
    this.emoji, {
    super.key,
    required this.seed,
    this.size = 44,
    this.ring = false,
    this.online = false,
    this.onTap,
  });

  final String emoji;
  final int seed;
  final double size;
  final bool ring;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color hue = HabitPalette.color(HabitPalette.clampSeed(seed));
    final Widget core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HabitPalette.soft(HabitPalette.clampSeed(seed),
            context.isDark),
        shape: BoxShape.circle,
        border: ring
            ? Border.all(color: hue, width: 2)
            : Border.all(color: c.hairline),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
    if (!online) {
      final Widget w = ring
          ? Padding(padding: const EdgeInsets.all(3), child: core)
          : core;
      return onTap == null ? w : Pressable(onTap: onTap, child: w);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (ring)
          Padding(padding: const EdgeInsets.all(3), child: core)
        else
          core,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: c.success,
              shape: BoxShape.circle,
              border: Border.all(color: c.scaffold, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
