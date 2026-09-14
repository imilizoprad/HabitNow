import 'package:flutter/material.dart' show Icons;

import 'common.dart';

/// Task priority — used for sort order and the color-coded flag.
enum Priority { none, low, medium, high }

extension PriorityX on Priority {
  int get rank => index;
  static Priority from(int v) =>
      Priority.values.firstWhere((Priority p) => p.index == v,
          orElse: () => Priority.none);
}

/// Recurrence rules for tasks (redesigned from the base repo's recurring
/// tasks: daily / chosen weekdays / every N days).
class Recurrence {
  const Recurrence.daily() : kind = 'daily', days = const <int>{}, n = 1;
  const Recurrence.weekdays(this.days)
      : kind = 'weekdays',
        n = 1;
  const Recurrence.everyN(this.n)
      : kind = 'everyN',
        days = const <int>{};

  final String kind; // daily | weekdays | everyN
  final Set<int> days; // for weekdays
  final int n; // for everyN

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'days': days.toList()..sort(),
        'n': n,
      };

  factory Recurrence.fromJson(Map<String, dynamic> j) {
    final String k = j['kind'] as String? ?? 'daily';
    final Set<int> d = ((j['days'] as List<dynamic>?) ?? <dynamic>[])
        .map((dynamic e) => (e as num).toInt())
        .toSet();
    final int nn = (j['n'] as num?)?.toInt() ?? 1;
    switch (k) {
      case 'weekdays':
        return Recurrence.weekdays(d);
      case 'everyN':
        return Recurrence.everyN(nn < 1 ? 1 : nn);
      default:
        return const Recurrence.daily();
    }
  }

  /// Next due date strictly after [from].
  DateTime nextAfter(DateTime from) {
    switch (kind) {
      case 'weekdays':
        if (days.isEmpty) return from.add(const Duration(days: 1));
        for (int i = 1; i <= 7; i++) {
          final DateTime cand = from.add(Duration(days: i));
          if (days.contains(cand.weekday)) return cand;
        }
        return from.add(const Duration(days: 7));
      case 'everyN':
        return from.add(Duration(days: n < 1 ? 1 : n));
      default:
        return from.add(const Duration(days: 1));
    }
  }

  String get label {
    switch (kind) {
      case 'weekdays':
        if (days.length == 7) return 'Every day';
        const List<String> names = <String>[
          'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
        ];
        return days.map((int d) => names[(d - 1) % 7]).join(' · ');
      case 'everyN':
        return 'Every $n ${n == 1 ? 'day' : 'days'}';
      default:
        return 'Daily';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence &&
      other.kind == kind &&
      other.n == n &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hash(kind, n, Object.hashAllUnordered(days));
}

/// Fixed, tasteful categories — less setup friction than free-form
/// categories, and they stay consistent between peers in exports.
enum TaskCategory { personal, work, home, health, learning }

extension TaskCategoryX on TaskCategory {
  String get label => switch (this) {
        TaskCategory.personal => 'Personal',
        TaskCategory.work => 'Work',
        TaskCategory.home => 'Home',
        TaskCategory.health => 'Health',
        TaskCategory.learning => 'Learning',
      };

  int get iconCode => switch (this) {
        TaskCategory.personal => Icons.person.codePoint,
        TaskCategory.work => Icons.work.codePoint,
        TaskCategory.home => Icons.home_rounded.codePoint,
        TaskCategory.health => Icons.favorite_border.codePoint,
        TaskCategory.learning => Icons.school.codePoint,
      };

  int get colorSeed => switch (this) {
        TaskCategory.personal => 4,
        TaskCategory.work => 3,
        TaskCategory.home => 6,
        TaskCategory.health => 2,
        TaskCategory.learning => 0,
      };

  static TaskCategory from(String v) => TaskCategory.values
      .firstWhere((TaskCategory c) => c.name == v, orElse: () => TaskCategory.personal);
}

/// A one-shot task, optionally recurring. Local-only — never synced.
class Task implements Synced {
  Task({
    required this.id,
    required this.title,
    this.note = '',
    this.priority = Priority.none,
    this.category = TaskCategory.personal,
    this.due,
    this.recurrence,
    this.done = false,
    this.doneAt,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  String title;
  String note;
  Priority priority;
  TaskCategory category;

  /// Due at a specific local date (null = someday).
  DateTime? due;
  Recurrence? recurrence;
  bool done;
  int? doneAt;
  final int createdAt;

  bool get isRecurring => recurrence != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'note': note,
        'priority': priority.index,
        'category': category.name,
        'due': due?.millisecondsSinceEpoch,
        'recurrence': recurrence?.toJson(),
        'done': done,
        'doneAt': doneAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        note: j['note'] as String? ?? '',
        priority: PriorityX.from((j['priority'] as num?)?.toInt() ?? 0),
        category:
            TaskCategoryX.from(j['category'] as String? ?? 'personal'),
        due: j['due'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['due'] as num).toInt()),
        recurrence: j['recurrence'] == null
            ? null
            : Recurrence.fromJson(
                (j['recurrence'] as Map).cast<String, dynamic>()),
        done: j['done'] as bool? ?? false,
        doneAt: (j['doneAt'] as num?)?.toInt(),
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        updatedBy: j['updatedBy'] as String? ?? '',
      );

  Task copyWith({
    String? title,
    String? note,
    Priority? priority,
    TaskCategory? category,
    DateTime? due,
    bool clearDue = false,
    Recurrence? recurrence,
    bool clearRecurrence = false,
    bool? done,
    int? doneAt,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        priority: priority ?? this.priority,
        category: category ?? this.category,
        due: clearDue ? null : (due ?? this.due),
        recurrence: clearRecurrence
            ? null
            : (recurrence ?? this.recurrence),
        done: done ?? this.done,
        doneAt: doneAt ?? this.doneAt,
        createdAt: createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        updatedBy: updatedBy,
      );

  @override
  bool operator ==(Object other) => other is Task && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
