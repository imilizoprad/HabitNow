import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_x.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/check.dart';
import '../../core/widgets/heatmap.dart' show HabitHeatmap;
import '../../data/models/common.dart';
import '../../data/models/habit.dart';
import '../../state/app_store.dart';

/// The reusable habit row: icon tile, name, cadence, streak, check target.
class HabitRow extends StatelessWidget {
  const HabitRow({
    super.key,
    required this.habit,
    required this.app,
    this.showHeatmap = false,
    this.subtitle,
  });

  final Habit habit;
  final AppStore app;
  final bool showHeatmap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool dark = context.isDark;
    final Color hue = HabitPalette.color(HabitPalette.clampSeed(habit.colorSeed));
    final DateTime now = DateTime.now();
    final bool done = app.habits.isDoneOn(habit, now);
    final int streak = app.habits.streakOf(habit);

    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: done ? hue.withValues(alpha: 0.35) : c.hairline),
        boxShadow: Elev.shadow(1, dark: dark),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: HabitPalette.soft(
                      HabitPalette.clampSeed(habit.colorSeed), dark),
                  borderRadius: BorderRadius.circular(Radii.m),
                ),
                alignment: Alignment.center,
                child: Icon(
                  IconData(habit.iconCode, fontFamily: 'MaterialIcons'),
                  color: hue,
                  size: 23,
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                              decorationColor: c.inkFaint,
                              decorationThickness: 1.6),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            subtitle ??
                                (habit.challengeId != null
                                    ? 'Challenge · shared'
                                    : describeWeekdays(habit.weekdays)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: c.inkMuted),
                          ),
                        ),
                        if (streak > 1) ...<Widget>[
                          const SizedBox(width: Sp.sm),
                          Icon(Icons.local_fire_department,
                              size: 13,
                              color: done ? c.flame : c.inkFaint),
                          const SizedBox(width: 2),
                          Text(
                            '$streak',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color:
                                        done ? c.flame : c.inkMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.sm),
              AnimatedCheck(
                done: done,
                color: hue,
                onToggle: () =>
                    app.habits.toggleToday(habit, when: now),
                semanticLabel: 'Mark ${habit.name} done',
              ),
            ],
          ),
          if (showHeatmap) ...<Widget>[
            const SizedBox(height: Sp.md),
            Align(
              alignment: Alignment.centerLeft,
              child: HabitHeatmap(
                habitId: habit.id,
                doneKeys: app.habits.myDoneKeys(),
                createdAtMs: habit.createdAt,
                color: hue,
                weeks: 12,
                cellSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
