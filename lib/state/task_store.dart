import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/utils/date_x.dart';
import '../core/utils/ids.dart';
import '../data/models/habit.dart' show FocusSession;
import '../data/models/task.dart';
import 'app_store.dart';

/// Tasks (one-shot + recurring) and focus sessions from the stopwatch.
/// All local-only by design — peers never see your task list.
class TaskStore extends ChangeNotifier {
  TaskStore(this._app);

  final AppStore _app;

  UnmodifiableListView<Task> get all =>
      UnmodifiableListView<Task>(_app.db.tasks);

  Task? byId(String id) {
    for (final Task t in _app.db.tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Open (not done / not yet due-advanced) tasks, soonest+important first.
  List<Task> get open {
    final List<Task> out = _app.db.tasks.where(_isOpen).toList()
      ..sort(_byUrgency);
    return out;
  }

  /// Tasks due today or earlier, still open.
  List<Task> get dueTodayOrOverdue =>
      open.where((Task t) => t.due == null || !t.due!.isAfter(
          DateTime.now().dayOnly.add(const Duration(days: 1)))).toList();

  /// Done today (one-shot completions + recurring check-offs).
  List<Task> get doneToday => _app.db.tasks
      .where((Task t) =>
          t.done &&
          t.doneAt != null &&
          DateTime.fromMillisecondsSinceEpoch(t.doneAt!).isSameDayAs(
              DateTime.now()))
      .toList()
    ..sort((Task a, Task b) =>
        (b.doneAt ?? 0).compareTo(a.doneAt ?? 0));

  bool _isOpen(Task t) {
    if (!t.done) return true;
    // Recurring tasks stay "open" once their next due date arrives.
    if (t.isRecurring && t.due != null) {
      return !t.due!.isAfter(DateTime.now().dayOnly);
    }
    return false;
  }

  int _byUrgency(Task a, Task b) {
    final int p = b.priority.rank.compareTo(a.priority.rank);
    if (p != 0) return p;
    final DateTime? ad = a.due;
    final DateTime? bd = b.due;
    if (ad == null && bd == null) return b.createdAt.compareTo(a.createdAt);
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  // --------------------------------------------------------------------------
  // CRUD
  // --------------------------------------------------------------------------

  Task addTask({
    required String title,
    String note = '',
    Priority priority = Priority.none,
    TaskCategory category = TaskCategory.personal,
    DateTime? due,
    Recurrence? recurrence,
  }) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Task t = Task(
      id: newId('tk'),
      title: title,
      note: note,
      priority: priority,
      category: category,
      due: due,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
      updatedBy: _app.db.profile?.id ?? 'local',
    );
    _app.db.tasks.add(t);
    _app.db.dirtyTasks();
    notifyListeners();
    return t;
  }

  void updateTask(Task updated) {
    final int i = _app.db.tasks.indexWhere((Task t) => t.id == updated.id);
    if (i == -1) return;
    _app.db.tasks[i] = updated;
    _app.db.dirtyTasks();
    notifyListeners();
  }

  void deleteTask(String id) {
    _app.db.tasks.removeWhere((Task t) => t.id == id);
    _app.db.dirtyTasks();
    notifyListeners();
  }

  /// Undo support for deletes.
  void restoreTask(Task t) {
    if (byId(t.id) != null) return;
    _app.db.tasks.add(t);
    _app.db.dirtyTasks();
    notifyListeners();
  }

  /// Complete/uncomplete. Recurring tasks roll their due date forward on
  /// completion — they never leave the rotation.
  void toggleDone(Task t) {
    if (t.isRecurring) {
      if (!t.done) {
        t
          ..done = true
          ..doneAt = DateTime.now().millisecondsSinceEpoch
          ..due = t.recurrence!.nextAfter(t.due ?? DateTime.now());
      } else {
        // Undo pulls the schedule back one step.
        t
          ..done = false
          ..doneAt = null
          ..due = _previousDue(t);
      }
    } else {
      t
        ..done = !t.done
        ..doneAt = t.done ? DateTime.now().millisecondsSinceEpoch : null;
    }
    t.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _app.db.dirtyTasks();
    notifyListeners();
  }

  DateTime _previousDue(Task t) {
    final DateTime base = t.due ?? DateTime.now();
    switch (t.recurrence!.kind) {
      case 'everyN':
        return base.subtract(Duration(days: t.recurrence!.n));
      case 'weekdays':
        DateTime cand = base;
        for (int i = 0; i < 7; i++) {
          cand = cand.subtract(const Duration(days: 1));
          if (t.recurrence!.days.contains(cand.weekday)) return cand;
        }
        return base.subtract(const Duration(days: 7));
      default:
        return base.subtract(const Duration(days: 1));
    }
  }

  /// Safety net for recurring tasks whose due date fell behind while the
  /// app wasn't running (partial writes, clock jumps). Completion-time
  /// advancement is the normal path; this only repairs stragglers.
  void materializeRecurring() {
    final String today = DateTime.now().dayOnly.isoDate;
    bool changed = false;
    for (final Task t in _app.db.tasks) {
      if (!t.isRecurring || !t.done || t.due == null) continue;
      while (t.due!.dayOnly.isBefore(DateTime.now().dayOnly) &&
          t.due!.isoDate.compareTo(today) < 0) {
        t.due = t.recurrence!.nextAfter(t.due!);
        changed = true;
        if (t.due!.isoDate.compareTo(today) >= 0) break;
      }
    }
    if (changed) {
      _app.db.dirtyTasks();
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Focus sessions (timer)
  // --------------------------------------------------------------------------

  UnmodifiableListView<FocusSession> get sessions =>
      UnmodifiableListView<FocusSession>(_app.db.sessions);

  List<FocusSession> get sessionsToday => _app.db.sessions
      .where((FocusSession s) => DateTime.fromMillisecondsSinceEpoch(
          s.startedAt).isSameDayAs(DateTime.now()))
      .toList();

  int get focusSecondsToday =>
      sessionsToday.fold(0, (int a, FocusSession s) => a + s.seconds);

  void addSession(FocusSession session) {
    _app.db.sessions.add(session);
    _app.db.dirtySessions();
    notifyListeners();
  }

  int get sessionCount => _app.db.sessions.length;
}
