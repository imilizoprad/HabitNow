import 'package:flutter/material.dart' show Icons;

import 'common.dart';

/// A repeatable habit. Days-of-week cadence with an optional reminder.
///
/// Habits are private by default; they only cross the network when attached
/// to a [Challenge] (see arena.dart), and then only their check-in ledger
/// for the challenge window is shared — never notes or reminders.
class Habit implements Synced {
  @override
  int updatedAt;
  @override
  String updatedBy;

  Habit({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorSeed,
    required this.weekdays,
    this.reminderMinutes,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
    this.challengeId,
  });

  final String id;

  /// Non-null when this habit is the shared mirror of a [Challenge]'s habit.
  final String? challengeId;
  String name;

  /// Material icon codepoint (IconData(…, fontFamily: 'MaterialIcons')).
  int iconCode;
  int colorSeed;

  /// DateTime.monday..DateTime.sunday. Empty means "no scheduled days".
  Set<int> weekdays;
  int? reminderMinutes;
  bool archived;
  final int createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'iconCode': iconCode,
        'colorSeed': colorSeed,
        'weekdays': weekdays.toList()..sort(),
        'reminderMinutes': reminderMinutes,
        'archived': archived,
        'challengeId': challengeId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        iconCode: (j['iconCode'] as num?)?.toInt() ??
            Icons.task_alt.codePoint,
        colorSeed: (j['colorSeed'] as num?)?.toInt() ?? 0,
        weekdays: ((j['weekdays'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => (e as num).toInt())
            .toSet(),
        reminderMinutes: (j['reminderMinutes'] as num?)?.toInt(),
        archived: j['archived'] as bool? ?? false,
        challengeId: j['challengeId'] as String?,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        updatedBy: j['updatedBy'] as String? ?? '',
      );

  /// Whether this habit is scheduled on [weekday] (1=Mon..7=Sun).
  bool scheduledOn(int weekday) => weekdays.isEmpty || weekdays.contains(weekday);

  Habit copyWith({
    String? name,
    int? iconCode,
    int? colorSeed,
    Set<int>? weekdays,
    int? reminderMinutes,
    bool clearReminder = false,
    bool? archived,
  }) =>
      Habit(
        id: id,
        name: name ?? this.name,
        iconCode: iconCode ?? this.iconCode,
        colorSeed: colorSeed ?? this.colorSeed,
        weekdays: weekdays ?? this.weekdays,
        reminderMinutes: clearReminder
            ? null
            : (reminderMinutes ?? this.reminderMinutes),
        archived: archived ?? this.archived,
        createdAt: createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        updatedBy: updatedBy,
        challengeId: challengeId,
      );

  @override
  bool operator ==(Object other) => other is Habit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One day's completion record for a habit. Keyed by (habitId, isoDate).
class HabitCheckin implements Synced {
  @override
  int updatedAt;
  @override
  String updatedBy;

  HabitCheckin({
    required this.habitId,
    required this.dateKey,
    required this.done,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String habitId;
  final String dateKey;
  bool done;

  /// Canonical storage/sync key: (habit, day, actor). The actor component
  /// means two peers can both check in the same shared challenge habit on
  /// the same day without ever colliding.
  String get key => '$habitId|$dateKey|${updatedBy.isEmpty ? 'me' : updatedBy}';

  /// (habit, day) key ignoring the actor — for "did anyone do it" queries.
  String get dayKey => '$habitId|$dateKey';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'habitId': habitId,
        'dateKey': dateKey,
        'done': done,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  factory HabitCheckin.fromJson(Map<String, dynamic> j) => HabitCheckin(
        habitId: j['habitId'] as String,
        dateKey: j['dateKey'] as String,
        done: j['done'] as bool? ?? false,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        updatedBy: j['updatedBy'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is HabitCheckin && other.key == key && other.done == done;

  @override
  int get hashCode => Object.hash(key, done);
}

/// A timed focus session from the stopwatch (ported & redesigned from the
/// original HabitNow timer).
class FocusSession {
  FocusSession({
    required this.id,
    required this.label,
    required this.startedAt,
    required this.seconds,
    this.habitId,
    this.taskId,
  });

  final String id;

  /// What the user was working on when the timer ran.
  String label;
  final int startedAt;
  final int seconds;
  final String? habitId;
  final String? taskId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'startedAt': startedAt,
        'seconds': seconds,
        'habitId': habitId,
        'taskId': taskId,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'] as String,
        label: j['label'] as String? ?? 'Focus',
        startedAt: (j['startedAt'] as num?)?.toInt() ?? 0,
        seconds: (j['seconds'] as num?)?.toInt() ?? 0,
        habitId: j['habitId'] as String?,
        taskId: j['taskId'] as String?,
      );
}
