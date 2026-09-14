import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/common.dart';
import '../../data/models/task.dart';
import '../../state/app_store.dart';
import 'task_editor.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key, required this.onCreateTask});

  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final List<Task> open = app.tasks.open;
    final List<Task> doneToday = app.tasks.doneToday;
    final bool dark = context.isDark;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Sp.screenH, Sp.xl, Sp.screenH, 2),
            child: Text('Tasks',
                style: Theme.of(context).textTheme.displaySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.lg),
            child: Row(
              children: <Widget>[
                Text(
                    '${open.length} open · ${doneToday.length} done today',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.inkMuted)),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.of(context).pushNamed('/focus',
                      arguments: const FocusRouteArgs(label: 'Focus')),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.timer_outlined,
                          size: 16, color: c.primaryDeep),
                      const SizedBox(width: 4),
                      Text('Focus timer',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: c.primaryDeep)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (open.isEmpty && doneToday.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                emoji: '🗂️',
                title: 'All clear',
                message:
                    'No tasks waiting. Add one, or start a focus session and knock something out.',
                actionLabel: 'Add a task',
                onAction: onCreateTask,
              ),
            )
          else ...<Widget>[
            for (int i = 0; i < open.length; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Sp.screenH, 0, Sp.screenH, Sp.md),
                child: Entrance(
                  index: i,
                  child: Dismissible(
                    key: ValueKey<String>(open[i].id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      Haptics.warning();
                      final Task removed = open[i];
                      app.tasks.deleteTask(removed.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted "${removed.title}"'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () =>
                                app.tasks.restoreTask(removed),
                          ),
                        ),
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding:
                          const EdgeInsets.only(right: Sp.xl),
                      decoration: BoxDecoration(
                        color: c.dangerSoft,
                        borderRadius: BorderRadius.circular(Radii.l),
                      ),
                      child: Icon(Icons.delete_outline, color: c.danger),
                    ),
                    child: _TaskCard(
                      task: open[i],
                      app: app,
                      dark: dark,
                    ),
                  ),
                ),
              ),
            if (doneToday.isNotEmpty) ...<Widget>[
              const SectionHeader('Done today', eyebrow: 'Wrapped up'),
              for (final Task t in doneToday)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Sp.screenH, 0, Sp.screenH, Sp.sm),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Sp.lg, vertical: Sp.md),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.check_circle,
                            size: 20, color: c.success),
                        const SizedBox(width: Sp.md),
                        Expanded(
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    color: c.inkMuted,
                                    decoration:
                                        TextDecoration.lineThrough,
                                    decorationColor: c.inkFaint),
                          ),
                        ),
                        Text('at ${_doneTime(t)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: c.inkFaint)),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  String _doneTime(Task t) {
    final DateTime d =
        DateTime.fromMillisecondsSinceEpoch(t.doneAt ?? 0);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.app,
    required this.dark,
  });

  final Task task;
  final AppStore app;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color hue =
        HabitPalette.color(HabitPalette.clampSeed(task.category.colorSeed));
    final bool overdue =
        task.due != null && task.due!.isBefore(DateTime.now().dayOnly);

    return AppCard(
      onTap: () => showTaskEditor(context, app, existing: task),
      padding: const EdgeInsets.all(Sp.md),
      child: Row(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.success();
              app.tasks.toggleDone(task);
              AppToast.show(context, message: 'Done — nice work', emoji: '✅');
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.springy,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: hue, width: 2),
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(
                      IconData(task.category.iconCode,
                          fontFamily: 'MaterialIcons'),
                      size: 13,
                      color: hue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.category.label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: c.inkMuted),
                    ),
                    if (task.isRecurring) ...<Widget>[
                      const SizedBox(width: Sp.sm),
                      Icon(Icons.event_repeat,
                          size: 13, color: c.inkMuted),
                      const SizedBox(width: 3),
                      Text(task.recurrence!.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: c.inkMuted)),
                    ],
                    if (task.due != null) ...<Widget>[
                      const SizedBox(width: Sp.sm),
                      Icon(Icons.schedule,
                          size: 13,
                          color: overdue ? c.danger : c.inkMuted),
                      const SizedBox(width: 3),
                      Text(
                        overdue
                            ? 'Overdue · ${task.due!.friendly}'
                            : 'Due ${task.due!.friendly}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color: overdue
                                    ? c.danger
                                    : c.inkMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (task.priority != Priority.none) ...<Widget>[
            const SizedBox(width: Sp.sm),
            _PriorityFlag(priority: task.priority),
          ],
        ],
      ),
    );
  }
}

class _PriorityFlag extends StatelessWidget {
  const _PriorityFlag({required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final (Color color, String letter) = switch (priority) {
      Priority.high => (c.danger, '!!!'),
      Priority.medium => (c.warning, '!!'),
      _ => (c.inkFaint, '!'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.s),
      ),
      child: Text(letter,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color, letterSpacing: 0.5)),
    );
  }
}
