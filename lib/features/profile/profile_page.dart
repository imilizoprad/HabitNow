import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/arena.dart';
import '../../data/models/common.dart';
import '../../state/app_store.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/habit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final profile = app.db.profile;
    if (profile == null) return const SizedBox.shrink();

    final int points = app.arena.totalPoints;
    final int unlocked = app.arena.awardBook.length;
    final int wins = app.arena.challenges
        .where((Challenge ch) =>
            ch.status == Challenge.statusSettled && ch.winnerId == profile.id)
        .length;
    final int bestStreak = app.habits.active.fold(
        0,
        (int a, Habit h) =>
            app.habits.bestStreakOf(h) > a ? app.habits.bestStreakOf(h) : a);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: <Widget>[
          const SizedBox(height: Sp.xl),
          Center(
            child: Entrance(
              index: 0,
              child: Column(
                children: <Widget>[
                  EmojiAvatar(profile.emoji,
                      seed: profile.colorSeed, size: 96, ring: true),
                  const SizedBox(height: Sp.lg),
                  Text(profile.name,
                      style: Theme.of(context).textTheme.headlineMedium),
                  TextButton(
                    onPressed: () => _editProfile(context, app),
                    child: Text('Edit profile',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: c.primaryDeep)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Sp.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
            child: Entrance(
              index: 1,
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    _Stat(value: points, label: 'points', color: c.gold),
                    _VLine(),
                    _Stat(value: wins, label: 'duels won', color: c.success),
                    _VLine(),
                    _Stat(value: bestStreak, label: 'best streak', color: c.flame),
                    _VLine(),
                    _Stat(
                        value: unlocked,
                        label: 'awards',
                        color: c.primary),
                  ],
                ),
              ),
            ),
          ),
          const SectionHeader('Award shelf', eyebrow: 'Milestones'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
            child: Entrance(
              index: 2,
              child: AppCard(
                child: Column(
                  children: <Widget>[
                    for (int row = 0; row < (Awards.all.length / 3).ceil(); row++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.lg),
                        child: Row(
                          children: <Widget>[
                            for (int col = 0; col < 3; col++) ...<Widget>[
                              if (col > 0) const SizedBox(width: Sp.md),
                              Expanded(
                                child: Builder(builder: (BuildContext ctx) {
                                  final int idx = row * 3 + col;
                                  if (idx >= Awards.all.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final AwardDef d = Awards.all[idx];
                                  final int? at = app.arena.awardBook[d.id];
                                  return _AwardTile(def: d, unlockedAt: at);
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SectionHeader('Settings', eyebrow: 'Preferences'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
            child: Entrance(
              index: 3,
              child: AppCard(
                child: Column(
                  children: <Widget>[
                    _SettingRow(
                      icon: Icons.brightness_6_outlined,
                      label: 'Theme',
                      child: SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                              value: 'light', icon: Icon(Icons.light_mode, size: 16)),
                          ButtonSegment<String>(
                              value: 'system', icon: Icon(Icons.brightness_auto, size: 16)),
                          ButtonSegment<String>(
                              value: 'dark', icon: Icon(Icons.dark_mode, size: 16)),
                        ],
                        selected: <String>{switch (app.themeMode) {
                          ThemeMode.light => 'light',
                          ThemeMode.dark => 'dark',
                          _ => 'system',
                        }},
                        onSelectionChanged: (Set<String> s) =>
                            app.setThemeMode(switch (s.first) {
                          'light' => ThemeMode.light,
                          'dark' => ThemeMode.dark,
                          _ => ThemeMode.system,
                        }),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          side: WidgetStateBorderSide.resolveWith(
                              (Set<WidgetState> _) => BorderSide.none),
                        ),
                        showSelectedIcon: false,
                      ),
                    ),
                    const Divider(),
                    _SettingRow(
                      icon: Icons.vibration_outlined,
                      label: 'Haptics',
                      child: Switch(
                        value: app.hapticsEnabled,
                        onChanged: (bool v) => app.setHapticsEnabled(v),
                      ),
                    ),
                    const Divider(),
                    _SettingRow(
                      icon: Icons.wifi,
                      label: 'Network status',
                      child: Text(
                        app.arena.connected.isEmpty
                            ? 'listening…'
                            : '${app.arena.connected.length} connected',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.inkMuted),
                      ),
                    ),
                    const Divider(),
                    _SettingRow(
                      icon: Icons.fingerprint,
                      label: 'Your device id',
                      child: Text(
                        profile.id.substring(0, 10),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.inkFaint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Sp.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
            child: Center(
              child: Text(
                'HabitNow Arena · peer-to-peer, no servers\nv1.0.0 — built for Android (arm64)',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.inkFaint, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppStore app) async {
    final profile = app.db.profile!;
    final TextEditingController name = TextEditingController(text: profile.name);
    String emoji = profile.emoji;
    int seed = profile.colorSeed;
    await showAppSheet<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setSheetState) {
          final AppColors cc = context.colors;
          return SheetScaffold(
            title: 'Edit profile',
            bottomActions: <Widget>[
              AppButton.primary('Save', expanded: true, onTap: () {
                Haptics.medium();
                app.updateProfile(
                    name: name.text, emoji: emoji, colorSeed: seed);
                Navigator.of(ctx).pop(true);
                AppToast.show(context, message: 'Profile updated', emoji: '✨');
              }),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: EmojiAvatar(emoji, seed: seed, size: 92, ring: true),
                ),
                const SizedBox(height: Sp.xl),
                AppTextField(controller: name, hint: 'Name', maxLength: 24),
                const SizedBox(height: Sp.xl),
                Wrap(
                  spacing: Sp.sm,
                  runSpacing: Sp.sm,
                  children: <Widget>[
                    for (final String e in const <String>[
                      '🦁', '🐯', '🐻', '🐼', '🦊', '🐨', '🐸', '🦉',
                      '🐙', '🦄', '🐺', '🦖', '🐝', '🦋', '🐢', '🦩',
                      '🐳', '🌟',
                    ])
                      Pressable(
                        onTap: () =>
                            setSheetState(() => emoji = e),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: e == emoji
                                ? cc.primarySoft
                                : cc.surfaceAlt,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: e == emoji
                                    ? cc.primary
                                    : Colors.transparent,
                                width: 1.6),
                          ),
                          alignment: Alignment.center,
                          child: Text(e,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Sp.xl),
                Row(
                  children: <Widget>[
                    for (int i = 0; i < 8; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: Sp.md),
                      Pressable(
                        onTap: () => setSheetState(() => seed = i),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: HabitPalette.color(i),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: i == seed
                                    ? cc.ink
                                    : Colors.transparent,
                                width: 2.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    name.dispose();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Motion.emphasized,
            builder: (BuildContext context, double v, _) => Text(
              v.round().toString(),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                      color: color,
                      fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ]),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: context.colors.inkMuted)),
        ],
      ),
    );
  }
}

class _VLine extends StatelessWidget {
  const _VLine();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      width: 1,
      height: 30,
      color: c.hairline,
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({required this.def, required this.unlockedAt});

  final AwardDef def;
  final int? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool unlocked = unlockedAt != null;
    final Color ring = switch (def.tier) {
      2 => c.gold,
      1 => HabitPalette.color(3),
      _ => HabitPalette.color(2),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: unlocked ? c.goldSoft : c.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(
                    color: unlocked
                        ? ring.withValues(alpha: 0.7)
                        : c.hairline,
                    width: 1.6),
              ),
              alignment: Alignment.center,
              child: Text(
                unlocked ? def.emoji : '🔒',
                style: TextStyle(
                    fontSize: 26,
                    color: unlocked ? null : c.inkFaint),
              ),
            ),
          ),
          const SizedBox(height: Sp.sm),
          Text(
            def.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: unlocked ? c.ink : c.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: c.inkMuted),
          const SizedBox(width: Sp.lg),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          child,
        ],
      ),
    );
  }
}
