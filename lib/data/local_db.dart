import 'dart:async';
import 'dart:convert';

import '../core/storage/json_store.dart';
import 'models/arena.dart';
import 'models/habit.dart';
import 'models/profile.dart';
import 'models/task.dart';

/// Everything the app persists, held hot in memory and mirrored to
/// per-collection JSON files with a short debounced write.
///
/// The whole working set is small (a personal habit tracker), so full-file
/// writes on change are simpler and safer than incremental journalling.
class LocalDb {
  Profile? profile;
  final List<FriendRecord> friends = <FriendRecord>[];
  final List<Habit> habits = <Habit>[];
  final Map<String, HabitCheckin> checkins = <String, HabitCheckin>{};
  final List<Task> tasks = <Task>[];
  final List<FocusSession> sessions = <FocusSession>[];
  final List<Challenge> challenges = <Challenge>[];
  final List<Forfeit> forfeits = <Forfeit>[];
  final List<LedgerEntry> ledger = <LedgerEntry>[];

  /// Award id → unlock timestamp (ms).
  final Map<String, int> awards = <String, int>{};

  /// Lightweight prefs (theme mode, haptics…).
  Map<String, dynamic> prefs = <String, dynamic>{};

  Timer? _flushTimer;

  Future<void> load() async {
    final List<Map<String, dynamic>> files =
        await Future.wait(<Future<Map<String, dynamic>>>[
      JsonStore.readJson('profile'),
      JsonStore.readJson('friends'),
      JsonStore.readJson('habits'),
      JsonStore.readJson('checkins'),
      JsonStore.readJson('tasks'),
      JsonStore.readJson('sessions'),
      JsonStore.readJson('challenges'),
      JsonStore.readJson('forfeits'),
      JsonStore.readJson('ledger'),
      JsonStore.readJson('awards'),
      JsonStore.readJson('prefs'),
    ]);

    final Map<String, dynamic> pj = files[0];
    if (pj['id'] != null) profile = Profile.fromJson(pj);

    friends.addAll((files[1]['friends'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) =>
            FriendRecord.fromJson((e as Map).cast<String, dynamic>()))
        .toList());
    habits.addAll((files[2]['habits'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) =>
            Habit.fromJson((e as Map).cast<String, dynamic>()))
        .toList());
    (files[3]['checkins'] as Map<String, dynamic>? ??
            const <String, dynamic>{})
        .forEach((String k, dynamic v) {
      checkins[k] =
          HabitCheckin.fromJson((v as Map).cast<String, dynamic>());
    });
    tasks.addAll((files[4]['tasks'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => Task.fromJson((e as Map).cast<String, dynamic>()))
        .toList());
    sessions.addAll((files[5]['sessions'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) =>
            FocusSession.fromJson((e as Map).cast<String, dynamic>()))
        .toList());
    challenges.addAll((files[6]['challenges'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) =>
            Challenge.fromJson((e as Map).cast<String, dynamic>()))
        .toList());
    forfeits.addAll((files[7]['forfeits'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) =>
            Forfeit.fromJson((e as Map).cast<String, dynamic>()))
        .toList());
    ledger.addAll((files[8]['entries'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) =>
            LedgerEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList());
    (files[9]['awards'] as Map<String, dynamic>? ??
            const <String, dynamic>{})
        .forEach((String k, dynamic v) {
      awards[k] = (v as num).toInt();
    });
    prefs = files[10];
  }

  // -- Dirty flags: one typed method per collection. Writes coalesce
  //    within ~350ms; call flush() on app pause.
  void dirtyProfile() => _mark(_Collection.profile);
  void dirtyFriends() => _mark(_Collection.friends);
  void dirtyHabits() => _mark(_Collection.habits);
  void dirtyCheckins() => _mark(_Collection.checkins);
  void dirtyTasks() => _mark(_Collection.tasks);
  void dirtySessions() => _mark(_Collection.sessions);
  void dirtyChallenges() => _mark(_Collection.challenges);
  void dirtyForfeits() => _mark(_Collection.forfeits);
  void dirtyLedger() => _mark(_Collection.ledger);
  void dirtyAwards() => _mark(_Collection.awards);
  void dirtyPrefs() => _mark(_Collection.prefs);

  void _mark(_Collection c) {
    _pending.add(c);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 350), flush);
  }

  final Set<_Collection> _pending = <_Collection>{};

  /// Writes every dirty collection now. Call on app pause.
  Future<void> flush() async {
    _flushTimer?.cancel();
    final Set<_Collection> todo = _pending.toSet();
    _pending.clear();
    for (final _Collection c in todo) {
      await _write(c);
    }
  }

  Future<void> flushAll() async {
    for (final _Collection c in _Collection.values) {
      await _write(c);
    }
  }

  Future<void> _write(_Collection c) async {
    switch (c) {
      case _Collection.profile:
        if (profile != null) {
          await JsonStore.writeJson('profile', profile!.toJson());
        }
      case _Collection.friends:
        await JsonStore.writeJson('friends', <String, dynamic>{
          'friends': friends.map((FriendRecord f) => f.toJson()).toList(),
        });
      case _Collection.habits:
        await JsonStore.writeJson('habits', <String, dynamic>{
          'habits': habits.map((Habit h) => h.toJson()).toList(),
        });
      case _Collection.checkins:
        await JsonStore.writeJson('checkins', <String, dynamic>{
          'checkins': checkins
              .map((String k, HabitCheckin v) =>
                  MapEntry<String, dynamic>(k, v.toJson())),
        });
      case _Collection.tasks:
        await JsonStore.writeJson('tasks', <String, dynamic>{
          'tasks': tasks.map((Task t) => t.toJson()).toList(),
        });
      case _Collection.sessions:
        await JsonStore.writeJson('sessions', <String, dynamic>{
          'sessions': sessions.map((FocusSession s) => s.toJson()).toList(),
        });
      case _Collection.challenges:
        await JsonStore.writeJson('challenges', <String, dynamic>{
          'challenges':
              challenges.map((Challenge ch) => ch.toJson()).toList(),
        });
      case _Collection.forfeits:
        await JsonStore.writeJson('forfeits', <String, dynamic>{
          'forfeits': forfeits.map((Forfeit f) => f.toJson()).toList(),
        });
      case _Collection.ledger:
        await JsonStore.writeJson('ledger', <String, dynamic>{
          'entries': ledger.map((LedgerEntry e) => e.toJson()).toList(),
        });
      case _Collection.awards:
        await JsonStore.writeJson('awards', awards);
      case _Collection.prefs:
        await JsonStore.writeJson('prefs', prefs);
    }
  }

  /// Export a portable snapshot (settings → "share my data").
  Future<String> exportJson() async {
    final Map<String, dynamic> bundle = <String, dynamic>{
      'v': 1,
      'profile': profile?.toJson(),
      'habits': habits.map((Habit h) => h.toJson()).toList(),
      'challenges': challenges.map((Challenge c) => c.toJson()).toList(),
      'ledger': ledger.map((LedgerEntry e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  /// Full flush for hot-restart/tests.
  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flushAll();
  }
}

enum _Collection {
  profile,
  friends,
  habits,
  checkins,
  tasks,
  sessions,
  challenges,
  forfeits,
  ledger,
  awards,
  prefs,
}
