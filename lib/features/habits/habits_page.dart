import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/habit.dart';
import '../../state/app_store.dart';
import 'habit_editor.dart';
import 'habit_row.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key, required this.onCreateHabit});

  final VoidCallback onCreateHabit;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final List<Habit> active = app.habits.active;
    final List<Habit> archived = app.habits.archived;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Sp.screenH, Sp.xl, Sp.screenH, Sp.xs),
            child: Text('Habits',
                style: Theme.of(context).textTheme.displaySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.sm),
            child: Text(
              'Your garden — tap the circle to check in, tap a card to inspect.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.inkMuted),
            ),
          ),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                emoji: '🌱',
                title: 'No habits yet',
                message:
                    'Small daily reps, big streaks. Start with one habit you can win today.',
                actionLabel: 'Plant a habit',
                onAction: onCreateHabit,
              ),
            )
          else
            ...<Widget>[
              for (int i = 0; i < active.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Sp.screenH, 0, Sp.screenH, Sp.md),
                  child: Entrance(
                    index: i,
                    child: GestureDetector(
                      onLongPress: () => _habitMenu(context, app, active[i]),
                      child: HabitRow(
                        habit: active[i],
                        app: app,
                        showHeatmap: true,
                      ),
                    ),
                  ),
                ),
            ],
          if (archived.isNotEmpty) ...<Widget>[
            const SectionHeader('Archived'),
            for (final Habit h in archived)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
                child: AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.archive_outlined,
                          size: 20, color: c.inkFaint),
                      const SizedBox(width: Sp.md),
                      Expanded(
                        child: Text(h.name,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: c.inkMuted)),
                      ),
                      Pressable(
                        onTap: () =>
                            app.habits.setArchived(h, false),
                        child: Padding(
                          padding: const EdgeInsets.all(Sp.sm),
                          child: Text('Restore',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: c.primaryDeep)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _habitMenu(
      BuildContext context, AppStore app, Habit habit) async {
    final String? action = await showAppSheet<String>(
      context: context,
      builder: (BuildContext ctx) => _HabitActionSheet(habit: habit),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'open':
        if (!context.mounted) return;
        unawaited(Navigator.of(context).pushNamed(
            '/habit', arguments: HabitRouteArgs(habit.id)));
      case 'edit':
        await showHabitEditor(context, app, existing: habit);
      case 'archive':
        app.habits.setArchived(habit, true);
        AppToast.show(context, message: 'Archived — restore anytime', emoji: '📦');
      case 'delete':
        final bool ok = await confirmDialog(
          context,
          title: 'Delete "${habit.name}"?',
          message:
              'Removes the habit and its whole history. This can\'t be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok && context.mounted) {
          app.habits.deleteHabit(habit.id);
          AppToast.show(context, message: 'Deleted', emoji: '🗑️');
        }
    }
  }
}

class _HabitActionSheet extends StatelessWidget {
  const _HabitActionSheet({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool shared = habit.challengeId != null;
    final List<({String icon, String label, String value})> options =
        <({String icon, String label, String value})>[
      (
        icon: '✏️',
        label: 'Edit',
        value: 'edit',
      ),
      (
        icon: '📦',
        label: 'Archive',
        value: 'archive',
      ),
      (
        icon: '🗑️',
        label: 'Delete',
        value: 'delete',
      ),
      if (!shared)
        (
          icon: '📊',
          label: 'Open details',
          value: 'open',
        ),
    ];
    return SheetScaffold(
      title: habit.name,
      subtitle: shared
          ? 'Shared habit — managed by its challenge'
          : null,
      child: Column(
        children: <Widget>[
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: AppCard(
                onTap: () =>
                    Navigator.of(context).pop(o.value),
                padding:
                    const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
                child: Row(
                  children: <Widget>[
                    Text(o.icon, style: const TextStyle(fontSize: 19)),
                    const SizedBox(width: Sp.lg),
                    Expanded(
                      child: Text(o.label,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Icon(Icons.chevron_right, color: c.inkFaint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
