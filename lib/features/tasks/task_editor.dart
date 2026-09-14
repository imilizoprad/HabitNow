import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/common.dart';
import '../../data/models/task.dart';
import '../../state/app_store.dart';

/// Create or edit a task, including recurrence rules.
Future<Task?> showTaskEditor(BuildContext context, AppStore app,
    {Task? existing}) {
  return showAppSheet<Task>(
    context: context,
    builder: (BuildContext ctx) => TaskEditorSheet(app: app, existing: existing),
  );
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, required this.app, this.existing});

  final AppStore app;
  final Task? existing;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late Priority _priority = widget.existing?.priority ?? Priority.none;
  late TaskCategory _category = widget.existing?.category ?? TaskCategory.personal;
  DateTime? _due = widget.existing?.due;
  late Recurrence? _recurrence = widget.existing?.recurrence;
  late Set<int> _recDays = _recurrence?.days.toSet() ?? const <int>{};
  late int _recN = _recurrence?.n ?? 2;

  bool get _canSave => _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().dayOnly,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: context.colors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _due = picked.dayOnly);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    Haptics.medium();
    if (widget.existing == null) {
      widget.app.tasks.addTask(
        title: _title.text.trim(),
        note: _note.text.trim(),
        priority: _priority,
        category: _category,
        due: _due,
        recurrence: _recurrence,
      );
    } else {
      final Task updated = widget.existing!.copyWith(
        title: _title.text.trim(),
        note: _note.text.trim(),
        priority: _priority,
        category: _category,
        due: _due,
        clearDue: _due == null,
        recurrence: _recurrence,
        clearRecurrence: _recurrence == null,
      );
      widget.app.tasks.updateTask(updated);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SheetScaffold(
      title: widget.existing == null ? 'New task' : 'Edit task',
      subtitle: widget.existing?.title,
      bottomActions: <Widget>[
        AppButton.ghost('Cancel', onTap: () => Navigator.of(context).pop()),
        AppButton.primary(
          widget.existing == null ? 'Add it' : 'Save',
          expanded: true,
          onTap: _canSave ? _save : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            controller: _title,
            hint: 'What needs doing?',
            maxLength: 80,
            autofocus: widget.existing == null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Sp.md),
          AppTextField(
            controller: _note,
            hint: 'Notes (optional)',
            maxLength: 240,
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: Sp.xl),
          _Label('CATEGORY'),
          const SizedBox(height: Sp.sm),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: <Widget>[
              for (final TaskCategory cat in TaskCategory.values)
                _ChoicePill(
                  label: cat.label,
                  icon: IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                  seed: cat.colorSeed,
                  selected: cat == _category,
                  onTap: () {
                    Haptics.select();
                    setState(() => _category = cat);
                  },
                ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          _Label('PRIORITY'),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              for (final Priority p in Priority.values) ...<Widget>[
                if (p != Priority.none) const SizedBox(width: Sp.sm),
                Expanded(
                  child: _ChoicePill(
                    label: switch (p) {
                      Priority.none => 'None',
                      Priority.low => 'Low',
                      Priority.medium => 'Med',
                      Priority.high => 'High',
                    },
                    selected: p == _priority,
                    onTap: () {
                      Haptics.select();
                      setState(() => _priority = p);
                    },
                    tone: switch (p) {
                      Priority.high => c.danger,
                      Priority.medium => c.warning,
                      _ => c.primary,
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Sp.xl),
          _Label('WHEN'),
          const SizedBox(height: Sp.sm),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
            child: Row(
              children: <Widget>[
                Icon(Icons.event_outlined, size: 20, color: c.inkMuted),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Text(
                    _due == null ? 'No date' : 'Due ${_due!.friendly}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_due != null)
                  Pressable(
                    onTap: () => setState(() => _due = null),
                    child: Padding(
                      padding: const EdgeInsets.all(Sp.sm),
                      child: Icon(Icons.close, size: 18, color: c.inkFaint),
                    ),
                  ),
                AppButton.soft('Pick', size: AppButtonSize.small, onTap: _pickDue),
              ],
            ),
          ),
          const SizedBox(height: Sp.xl),
          _Label('REPEATS'),
          const SizedBox(height: Sp.sm),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: <Widget>[
              _ChoicePill(
                label: 'Never',
                selected: _recurrence == null,
                onTap: () {
                  Haptics.select();
                  setState(() => _recurrence = null);
                },
              ),
              _ChoicePill(
                label: 'Daily',
                selected: _recurrence?.kind == 'daily',
                onTap: () {
                  Haptics.select();
                  setState(() => _recurrence = const Recurrence.daily());
                },
              ),
              _ChoicePill(
                label: 'Some days',
                selected: _recurrence?.kind == 'weekdays',
                onTap: () {
                  Haptics.select();
                  setState(() {
                    _recDays = _recDays.isEmpty
                        ? <int>{DateTime.monday, DateTime.wednesday, DateTime.friday}
                        : _recDays;
                    _recurrence = Recurrence.weekdays(_recDays);
                  });
                },
              ),
              _ChoicePill(
                label: 'Every N days',
                selected: _recurrence?.kind == 'everyN',
                onTap: () {
                  Haptics.select();
                  setState(() => _recurrence = Recurrence.everyN(_recN));
                },
              ),
            ],
          ),
          if (_recurrence?.kind == 'weekdays') ...<Widget>[
            const SizedBox(height: Sp.md),
            Row(
              children: <Widget>[
                for (int d = DateTime.monday; d <= DateTime.sunday; d++) ...<Widget>[
                  if (d > DateTime.monday) const SizedBox(width: 6),
                  Expanded(
                    child: _ChoicePill(
                      label: const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'][d - 1],
                      selected: _recDays.contains(d),
                      onTap: () {
                        Haptics.select();
                        setState(() {
                          if (_recDays.contains(d)) {
                            _recDays.remove(d);
                          } else {
                            _recDays.add(d);
                          }
                          _recurrence = Recurrence.weekdays(_recDays);
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (_recurrence?.kind == 'everyN') ...<Widget>[
            const SizedBox(height: Sp.md),
            Row(
              children: <Widget>[
                Text('Every',
                    style: Theme.of(context).textTheme.titleSmall),
                Expanded(
                  child: Slider(
                    value: _recN.toDouble(),
                    min: 2,
                    max: 14,
                    divisions: 12,
                    label: '$_recN',
                    onChanged: (double v) => setState(() {
                      _recN = v.round();
                      _recurrence = Recurrence.everyN(_recN);
                    }),
                  ),
                ),
                Text('${_recN}d',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ],
          if (widget.existing != null && widget.existing!.isRecurring) ...<Widget>[
            const SizedBox(height: Sp.lg),
            Text(
              'Recurring tasks roll forward when completed — they never pile up.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.inkFaint),
            ),
          ],
          const SizedBox(height: Sp.sm),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: c.inkFaint, letterSpacing: 1.2));
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.seed,
    this.tone,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? seed;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool dark = context.isDark;
    final Color accent = tone ??
        (seed != null
            ? HabitPalette.color(HabitPalette.clampSeed(seed))
            : c.primary);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding:
            const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: dark ? 0.22 : 0.13)
              : c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
              color: selected ? accent : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon,
                  size: 15,
                  color: selected ? accent : c.inkMuted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(
                      color: selected ? accent : c.inkMuted,
                      fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
