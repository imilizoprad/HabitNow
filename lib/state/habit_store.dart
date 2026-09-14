import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/utils/date_x.dart';
import '../core/utils/ids.dart';
import '../data/local_db.dart';
import '../data/models/common.dart';
import '../data/models/habit.dart';
import '../data/score_engine.dart';
import 'app_store.dart';
import 'arena_store.dart';

/// Habits + their check-in ledger. Also owns the *mirror* habits that make
/// cross-device challenges possible: when a challenge is accepted, both
/// devices create a habit with the same deterministic id
/// (`Challenge.mirrorHabitId`), so check-in records align without any
/// negotiation.
class HabitStore extends ChangeNotifier {
  HabitStore(this._app);

  final AppStore _app;

  LocalDb get _db => _app.db;
  ArenaStore get _arena => _app.arena;
  String get _me => _db.profile!.id;

  UnmodifiableListView<Habit> get all =>
      UnmodifiableListView<Habit>(_db.habits);

  List<Habit> get active =>
      _db.habits.where((Habit h) => !h.archived).toList();

  List<Habit> get archived =>
      _db.habits.where((Habit h) => h.archived).toList();

  Habit? byId(String id) {
    for (final Habit h in _db.habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  HabitCheckin? checkinOf(String habitId, DateTime day) =>
      _db.checkins['$habitId|${day.isoDate}|$_me'];

  bool isDoneOn(Habit h, DateTime day) =>
      checkinOf(h.id, day)?.done ?? false;

  bool get isDoneToday => isDoneOnToday(_today());
  bool isDoneOnToday(DateTime day) {
    for (final Habit h in scheduledOn(day)) {
      if (!isDoneOn(h, day)) return false;
    }
    return true;
  }

  DateTime _today() => DateTime.now();

  /// Habits scheduled for [day] (not archived, weekday matches).
  List<Habit> scheduledOn(DateTime day) => active
      .where((Habit h) => h.weekdays.contains(day.weekday))
      .toList();

  // --------------------------------------------------------------------------
  // Check-ins
  // --------------------------------------------------------------------------

  /// All done-check-in keys (`habitId|date|actor`). Actor-scoped so peer
  /// check-ins on shared challenge habits never pollute personal streaks.
  Set<String> myDoneKeys() {
    return <String>{
      for (final HabitCheckin c in _db.checkins.values)
        if (c.done && c.updatedBy == _me) c.key,
    };
  }

  /// Toggle today's check-in for [habit]. Returns true when now done.
  bool toggleToday(Habit habit, {DateTime? when}) {
    final DateTime day = (when ?? _today()).dayOnly;
    final HabitCheckin existing = checkinOf(habit.id, day) ??
        HabitCheckin(
          habitId: habit.id,
          dateKey: day.isoDate,
          done: false,
          updatedAt: 0,
          updatedBy: _me,
        );
    final bool nowDone = !existing.done;
    existing
      ..done = nowDone
      ..updatedAt = DateTime.now().millisecondsSinceEpoch
      ..updatedBy = _me;
    _db.checkins[existing.key] = existing;
    _db.dirtyCheckins();
    if (habit.challengeId != null) {
      // Real-time push to every connected peer; stragglers converge via
      // the next sync.state.
      _app.engine?.broadcast(<String, dynamic>{
        't': 'checkin.delta',
        'checkin': existing.toJson(),
      });
    }
    _arena.onLocalCheckin(habit, day, nowDone);
    notifyListeners();
    return nowDone;
  }

  // --------------------------------------------------------------------------
  // Queries for UI
  // --------------------------------------------------------------------------

  int completedTodayCount() {
    final List<Habit> today = scheduledOn(_today());
    int n = 0;
    for (final Habit h in today) {
      if (isDoneOn(h, _today())) n++;
    }
    return n;
  }

  int streakOf(Habit h) =>
      ScoreEngine.streakToday(h, myDoneKeys(), actor: _me);

  int bestStreakOf(Habit h) =>
      ScoreEngine.bestStreak(h, myDoneKeys());

  /// Consecutive days (ending today or yesterday) where every scheduled
  /// habit was completed — the headline "perfect days" flame.
  int perfectDayStreak() {
    int streak = 0;
    DateTime day = _today().dayOnly;
    if (!isDoneOnToday(day)) {
      day = day.subtract(const Duration(days: 1)); // today still open
      if (!_isPerfectDay(day)) return 0;
    }
    while (_isPerfectDay(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
      if (streak > 365) break;
    }
    return streak;
  }

  bool _isPerfectDay(DateTime day) {
    final List<Habit> scheduled = active
        .where((Habit h) =>
            h.weekdays.contains(day.weekday) &&
            !day.isBefore(DateTime.fromMillisecondsSinceEpoch(h.createdAt)))
        .toList();
    if (scheduled.isEmpty) return false;
    for (final Habit h in scheduled) {
      if (!isDoneOn(h, day)) return false;
    }
    return true;
  }

  /// Completion rate over the last [days] scheduled days.
  double completionRate(int days) {
    int scheduled = 0;
    int done = 0;
    final DateTime today = _today().dayOnly;
    for (int i = 0; i < days; i++) {
      final DateTime day = today.subtract(Duration(days: i));
      for (final Habit h in active) {
        if (!h.weekdays.contains(day.weekday)) continue;
        if (day.isBefore(
            DateTime.fromMillisecondsSinceEpoch(h.createdAt))) {
          continue;
        }
        scheduled++;
        if (isDoneOn(h, day)) done++;
      }
    }
    return scheduled == 0 ? 0 : done / scheduled;
  }

  // --------------------------------------------------------------------------
  // CRUD
  // --------------------------------------------------------------------------

  Habit addHabit({
    required String name,
    required int iconCode,
    required int colorSeed,
    required Set<int> weekdays,
    int? reminderMinutes,
    String? challengeId,
  }) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    // Mirror habits (challengeId != null) must derive their id exactly as
    // [Challenge.mirrorHabitId] does on every peer — that shared id is what
    // aligns check-in records without any negotiation.
    final Habit habit = Habit(
      id: challengeId != null ? 'cm_$challengeId' : newId('hb'),
      name: name,
      iconCode: iconCode,
      colorSeed: colorSeed,
      weekdays: weekdays,
      reminderMinutes: reminderMinutes,
      createdAt: now,
      updatedAt: now,
      updatedBy: _me,
      challengeId: challengeId,
    );
    _db.habits.add(habit);
    _db.dirtyHabits();
    notifyListeners();
    return habit;
  }

  void updateHabit(Habit updated) {
    final int i = _db.habits.indexWhere((Habit h) => h.id == updated.id);
    if (i == -1) return;
    _db.habits[i] = updated;
    _db.dirtyHabits();
    notifyListeners();
  }

  void setArchived(Habit h, bool archived) {
    updateHabit(h.copyWith(archived: archived));
  }

  void deleteHabit(String id) {
    _db.habits.removeWhere((Habit h) => h.id == id);
    _db.checkins.removeWhere(
        (String key, _) => key.startsWith('$id|'));
    _db
      ..dirtyHabits()
      ..dirtyCheckins();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Sync intake
  // --------------------------------------------------------------------------

  /// LWW-merge a peer's check-in. Actors never collide on a key, so this
  /// is union-by-actor with LWW inside each (habit, day, actor) slot.
  void mergeCheckin(Map<String, dynamic> json) {
    final HabitCheckin incoming = HabitCheckin.fromJson(json);
    if (incoming.updatedBy == _me) return; // never let a peer overwrite me
    final HabitCheckin? existing = _db.checkins[incoming.key];
    if (existing == null || existing.supersedes(
        incoming.updatedAt, incoming.updatedBy)) {
      _db.checkins[incoming.key] = incoming;
      _db.dirtyCheckins();
      notifyListeners();
    }
  }

  void mergeMirrorHabit(Map<String, dynamic> json) {
    final Habit incoming = Habit.fromJson(json);
    final Habit? existing = byId(incoming.id);
    if (existing == null) {
      _db.habits.add(incoming);
      _db.dirtyHabits();
      notifyListeners();
    } else if (!existing.archived && incoming.archived) {
      existing
        ..archived = true
        ..updatedAt = incoming.updatedAt
        ..updatedBy = incoming.updatedBy;
      _db.dirtyHabits();
      notifyListeners();
    }
  }
}
