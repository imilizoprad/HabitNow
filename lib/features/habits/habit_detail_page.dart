import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/heatmap.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/progress.dart';
import '../../data/models/common.dart';
import '../../data/models/habit.dart';
import '../../data/score_engine.dart';
import '../../state/app_store.dart';
import 'habit_editor.dart';

class HabitDetailPage extends StatelessWidget {
  const HabitDetailPage({super.key, required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final Habit? habit = app.habits.byId(habitId);
    if (habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          emoji: '🫥',
          title: 'Habit not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final bool dark = context.isDark;
    final Color hue =
        HabitPalette.color(HabitPalette.clampSeed(habit.colorSeed));
    final Set<String> keys = app.habits.myDoneKeys();
    final int streak = app.habits.streakOf(habit);
    final int best = ScoreEngine.bestStreak(habit, keys);
    final double rate = app.habits.completionRate(30);
    final int totalDone = keys
        .where((String k) => k.startsWith('${habit.id}|'))
        .length;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        title: Text('Habit', style: Theme.of(context).textTheme.titleLarge),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: Sp.screenH),
            child: IconCapsule(
              Icons.edit,
              size: 38,
              tooltip: 'Edit habit',
              onTap: () => showHabitEditor(context, app, existing: habit),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, 110),
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: HabitPalette.soft(
                      HabitPalette.clampSeed(habit.colorSeed), dark),
                  borderRadius: BorderRadius.circular(Radii.l),
                ),
                alignment: Alignment.center,
                child: Icon(
                  IconData(habit.iconCode, fontFamily: 'MaterialIcons'),
                  color: hue,
                  size: 30,
                ),
              ),
              const SizedBox(width: Sp.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(habit.name,
                        style:
                            Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      habit.challengeId != null
                          ? 'Shared challenge habit'
                          : describeWeekdays(habit.weekdays),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  label: 'Current streak',
                  value: streak,
                  suffix: streak == 1 ? 'day' : 'days',
                  icon: Icons.local_fire_department,
                  iconColor: c.flame,
                  soft: c.flameSoft,
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: _StatTile(
                  label: 'Best ever',
                  value: best,
                  suffix: 'days',
                  icon: Icons.emoji_events_outlined,
                  iconColor: c.gold,
                  soft: c.goldSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  label: '30-day rate',
                  value: (rate * 100).round(),
                  suffix: '%',
                  icon: Icons.query_stats,
                  iconColor: c.primary,
                  soft: c.primarySoft,
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: _StatTile(
                  label: 'Total done',
                  value: totalDone,
                  suffix: 'times',
                  icon: Icons.done_all,
                  iconColor: c.success,
                  soft: c.successSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          Text('LAST 16 WEEKS',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.md),
          Center(
            child: AppCard(
              child: HabitHeatmap(
                habitId: habit.id,
                doneKeys: keys,
                createdAtMs: habit.createdAt,
                color: hue,
              ),
            ),
          ),
          const SizedBox(height: Sp.xl),
          Text('CONSISTENCY',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Last 30 days',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('${(rate * 100).round()}%',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: hue)),
                  ],
                ),
                const SizedBox(height: Sp.md),
                AnimatedBar(value: rate, color: hue),
              ],
            ),
          ),
          if (habit.challengeId != null) ...<Widget>[
            const SizedBox(height: Sp.lg),
            const InfoBanner(
              icon: Icons.handshake,
              text: 'This habit is shared — your friend sees every check-in.',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.iconColor,
    required this.soft,
  });

  final String label;
  final int value;
  final String suffix;
  final IconData icon;
  final Color iconColor;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: Sp.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value.toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Motion.emphasized,
                builder: (BuildContext context, double v, _) => Text(
                  v.round().toString(),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                          fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures()
                            ]),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(suffix,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.inkMuted)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}
