import 'package:flutter/material.dart';

import '../../core/native/bridge.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/common.dart';
import '../../data/models/habit.dart';
import '../../state/app_store.dart';

/// Curated icon palette for habits. Stored as codepoints so they persist.
const List<IconData> kHabitIcons = <IconData>[
  Icons.water_drop,
  Icons.directions_run,
  Icons.menu_book,
  Icons.self_improvement,
  Icons.bedtime,
  Icons.fitness_center,
  Icons.restaurant,
  Icons.coffee,
  Icons.brush,
  Icons.music_note,
  Icons.code,
  Icons.laptop,
  Icons.savings,
  Icons.sports_esports,
  Icons.pool,
  Icons.spa,
  Icons.psychology,
  Icons.favorite_border,
  Icons.sports_soccer,
  Icons.pets,
  Icons.cleaning_services,
  Icons.medication,
  Icons.wb_sunny,
  Icons.language,
];

/// Create or edit a habit. Returns the saved habit (or null if dismissed).
Future<Habit?> showHabitEditor(BuildContext context, AppStore app,
    {Habit? existing}) {
  return showAppSheet<Habit>(
    context: context,
    builder: (BuildContext ctx) =>
        HabitEditorSheet(app: app, existing: existing),
  );
}

class HabitEditorSheet extends StatefulWidget {
  const HabitEditorSheet({super.key, required this.app, this.existing});

  final AppStore app;
  final Habit? existing;

  @override
  State<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<HabitEditorSheet> {
  late final TextEditingController _name = TextEditingController(
      text: widget.existing?.name ?? '');
  late int _iconIndex = _indexOf(widget.existing?.iconCode);
  late int _seed = HabitPalette.clampSeed(widget.existing?.colorSeed);
  late Set<int> _days = widget.existing?.weekdays.toSet() ??
      const <int>{
        DateTime.monday, DateTime.tuesday, DateTime.wednesday,
        DateTime.thursday, DateTime.friday, DateTime.saturday,
        DateTime.sunday,
      };
  late int? _reminderMinutes = widget.existing?.reminderMinutes;

  static const List<String> _dayLabels = <String>[
    'M', 'T', 'W', 'T', 'F', 'S', 'S'
  ];

  int _indexOf(int? code) {
    if (code == null) return 0;
    for (int i = 0; i < kHabitIcons.length; i++) {
      if (kHabitIcons[i].codePoint == code) return i;
    }
    return 0;
  }

  bool get _canSave => _name.text.trim().isNotEmpty && _days.isNotEmpty;

  Future<void> _pickReminder() async {
    final TimeOfDay initial = _reminderMinutes == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay(
            hour: _reminderMinutes! ~/ 60, minute: _reminderMinutes! % 60);
    final TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => _reminderMinutes = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    Haptics.medium();
    final Habit saved;
    if (widget.existing == null) {
      saved = widget.app.habits.addHabit(
        name: _name.text.trim(),
        iconCode: kHabitIcons[_iconIndex].codePoint,
        colorSeed: _seed,
        weekdays: _days,
        reminderMinutes: _reminderMinutes,
      );
    } else {
      saved = widget.existing!.copyWith(
        name: _name.text.trim(),
        iconCode: kHabitIcons[_iconIndex].codePoint,
        colorSeed: _seed,
        weekdays: _days,
        reminderMinutes: _reminderMinutes,
      );
      widget.app.habits.updateHabit(saved);
    }
    // Sync the OS reminder with the final state.
    await NativeBridge.cancelReminder(stableHash(saved.id));
    if (_reminderMinutes != null && !saved.archived) {
      final DateTime now = DateTime.now();
      DateTime first = DateTime(now.year, now.month, now.day,
          _reminderMinutes! ~/ 60, _reminderMinutes! % 60);
      if (!first.isAfter(now)) {
        first = first.add(const Duration(days: 1));
        while (!_days.contains(first.weekday)) {
          first = first.add(const Duration(days: 1));
        }
      }
      await NativeBridge.scheduleReminder(
        id: stableHash(saved.id),
        title: saved.name,
        body: 'Time to keep the streak alive',
        atMs: first.millisecondsSinceEpoch,
        weekdays: _days.toList()..sort(),
      );
    }
    if (mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SheetScaffold(
      title: widget.existing == null ? 'New habit' : 'Edit habit',
      subtitle: widget.existing?.name,
      bottomActions: <Widget>[
        AppButton.ghost('Cancel', onTap: () => Navigator.of(context).pop()),
        AppButton.primary(
          widget.existing == null ? 'Plant it' : 'Save',
          expanded: true,
          onTap: _canSave ? _save : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            controller: _name,
            hint: 'e.g. Read before bed',
            maxLength: 40,
            autofocus: widget.existing == null,
            prefix: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: HabitPalette.soft(_seed, context.isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                kHabitIcons[_iconIndex],
                size: 16,
                color: HabitPalette.color(_seed),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Sp.xl),
          const _Label('COLOR'),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              for (int i = 0; i < HabitPalette.seeds.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: Sp.md),
                _ColorDot(
                  color: HabitPalette.color(i),
                  selected: i == _seed,
                  onTap: () {
                    Haptics.select();
                    setState(() => _seed = i);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: Sp.xl),
          const _Label('ICON'),
          const SizedBox(height: Sp.sm),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: <Widget>[
              for (int i = 0; i < kHabitIcons.length; i++)
                _IconChoice(
                  icon: kHabitIcons[i],
                  seed: _seed,
                  selected: i == _iconIndex,
                  onTap: () {
                    Haptics.select();
                    setState(() => _iconIndex = i);
                  },
                ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          const _Label('DAYS'),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              for (int d = DateTime.monday; d <= DateTime.sunday; d++) ...<Widget>[
                if (d > DateTime.monday) const SizedBox(width: 6),
                Expanded(child: _DayChip(
                  label: _dayLabels[d - 1],
                  selected: _days.contains(d),
                  seed: _seed,
                  onTap: () {
                    Haptics.select();
                    setState(() {
                      if (_days.contains(d)) {
                        _days.remove(d);
                      } else {
                        _days.add(d);
                      }
                    });
                  },
                )),
              ],
            ],
          ),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              Pressable(
                onTap: () => setState(() => _days = <int>{
                      DateTime.monday, DateTime.tuesday, DateTime.wednesday,
                      DateTime.thursday, DateTime.friday,
                    }),
                child: Text('Weekdays',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.primaryDeep)),
              ),
              const SizedBox(width: Sp.lg),
              Pressable(
                onTap: () => setState(() => _days = <int>{
                      DateTime.saturday, DateTime.sunday,
                    }),
                child: Text('Weekends',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.primaryDeep)),
              ),
              const SizedBox(width: Sp.lg),
              Pressable(
                onTap: () => setState(() => _days = <int>{
                      DateTime.monday, DateTime.tuesday, DateTime.wednesday,
                      DateTime.thursday, DateTime.friday,
                      DateTime.saturday, DateTime.sunday,
                    }),
                child: Text('Every day',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.primaryDeep)),
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          const _Label('REMINDER'),
          const SizedBox(height: Sp.sm),
          AppCard(
            padding:
                const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 6),
            child: Row(
              children: <Widget>[
                Icon(Icons.notifications_outlined,
                    size: 20, color: c.inkMuted),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Text(
                    _reminderMinutes == null
                        ? 'No reminder'
                        : 'Daily at ${(_reminderMinutes! ~/ 60).toString().padLeft(2, '0')}:${(_reminderMinutes! % 60).toString().padLeft(2, '0')} (on chosen days)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: _reminderMinutes != null,
                  onChanged: (bool v) async {
                    if (v) {
                      await _pickReminder();
                      if (_reminderMinutes == null) {
                        // picker dismissed without choosing
                        setState(() {});
                      }
                    } else {
                      setState(() => _reminderMinutes = null);
                    }
                  },
                ),
                if (_reminderMinutes != null)
                  Pressable(
                    onTap: _pickReminder,
                    child: Padding(
                      padding: const EdgeInsets.all(Sp.sm),
                      child: Text('Edit',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: c.primaryDeep)),
                    ),
                  ),
              ],
            ),
          ),
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

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.ink : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final int seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected
              ? HabitPalette.soft(seed, context.isDark)
              : c.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? HabitPalette.color(seed) : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? HabitPalette.color(seed) : c.inkMuted,
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.seed,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? HabitPalette.soft(seed, context.isDark)
              : c.surfaceAlt,
          border: Border.all(
            color: selected ? HabitPalette.color(seed) : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(Radii.s),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? HabitPalette.color(seed)
                  : c.inkMuted),
        ),
      ),
    );
  }
}
