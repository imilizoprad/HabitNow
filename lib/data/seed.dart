import 'package:flutter/material.dart' show Icons;

import '../core/utils/ids.dart';
import 'local_db.dart';
import 'models/habit.dart';
import 'models/task.dart';

/// First-run content. Deliberately minimal — three habits that demo the
/// streak/challenge loop without pretending to know the user's life.
void seedStarterContent(LocalDb db) {
  final String me = db.profile!.id;
  final int now = DateTime.now().millisecondsSinceEpoch;

  final List<({String name, int icon, int seed, Set<int> days})> starters =
      <({String name, int icon, int seed, Set<int> days})>[
    (
      name: 'Drink 2L water',
      icon: Icons.water_drop.codePoint,
      seed: 3,
      days: const <int>{1, 2, 3, 4, 5, 6, 7},
    ),
    (
      name: 'Read 20 minutes',
      icon: Icons.menu_book.codePoint,
      seed: 0,
      days: const <int>{1, 2, 3, 4, 5, 6, 7},
    ),
    (
      name: 'Move for 30 minutes',
      icon: Icons.directions_run.codePoint,
      seed: 1,
      days: const <int>{1, 3, 5},
    ),
  ];

  for (final (:String name, :int icon, :int seed, :Set<int> days)
      in starters) {
    db.habits.add(Habit(
      id: newId('hb'),
      name: name,
      iconCode: icon,
      colorSeed: seed,
      weekdays: days,
      createdAt: now,
      updatedAt: now,
      updatedBy: me,
    ));
  }

  db.tasks.add(Task(
    id: newId('tk'),
    title: 'Invite a friend to your first challenge',
    note: 'Open the Arena tab and pick someone nearby.',
    priority: Priority.medium,
    category: TaskCategory.personal,
    createdAt: now,
    updatedAt: now,
    updatedBy: me,
  ));
  db.dirtyHabits();
  db.dirtyTasks();
}
