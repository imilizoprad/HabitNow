import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/p2p/protocol.dart';
import '../core/p2p/sync_engine.dart';
import '../core/utils/ids.dart';
import '../data/local_db.dart';
import '../data/models/arena.dart';
import '../data/models/profile.dart';
import '../data/seed.dart';
import 'arena_store.dart';
import 'habit_store.dart';
import 'task_store.dart';

/// Root store: owns persistence, the sync engine and the domain stores.
///
/// One [ChangeNotifier] per domain keeps widget rebuilds surgical; the UI
/// subscribes through [AppScope] selectors. Lifecycle pauses flush pending
/// writes and resume re-rolls day-sensitive state (settlements, forfeits).
class AppStore extends ChangeNotifier with WidgetsBindingObserver {
  AppStore() {
    WidgetsBinding.instance.addObserver(this);
  }

  final LocalDb db = LocalDb();

  late final HabitStore habits = HabitStore(this);
  late final TaskStore tasks = TaskStore(this);
  late final ArenaStore arena = ArenaStore(this);

  SyncEngine? engine;

  bool ready = false;

  /// True when discovery couldn't bind (dual instance / odd network).
  bool networkDegraded = false;

  // -- lifecycle -------------------------------------------------------------

  Future<void> init() async {
    await db.load();
    if (db.profile == null) {
      // First run: the onboarding flow calls completeOnboarding(), which
      // seeds content and boots the engine.
      ready = true;
      notifyListeners();
      return;
    }
    await _boot();
  }

  Future<void> completeOnboarding({
    required String name,
    required String emoji,
    required int colorSeed,
  }) async {
    final String deviceId = newId('dev');
    final int now = DateTime.now().millisecondsSinceEpoch;
    db.profile = Profile(
      id: deviceId,
      name: name.trim().isEmpty ? 'Me' : name.trim(),
      emoji: emoji,
      colorSeed: colorSeed,
      updatedAt: now,
      updatedBy: deviceId,
    );
    db.dirtyProfile();
    seedStarterContent(db);
    await _boot();
    notifyListeners();
  }

  Future<void> _boot() async {
    tasks.materializeRecurring();
    arena.rollOverdueForfeits();
    arena.maybeSettleChallenges();
    arena.evaluateAwards();
    await _startEngine();
    ready = true;
    notifyListeners();
  }

  Future<void> _startEngine() async {
    final Profile me = db.profile!;
    final SyncEngine e = SyncEngine(
      me: () => ProfileWire(me.id, me.name, me.emoji, me.colorSeed),
    );
    e.collectSyncState = arena.collectSyncState;
    e.applyRemote = applyRemote;
    e.shouldAutoConnect = arena.shouldAutoConnect;
    e.onPeersChanged = () {
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.idle) {
        arena.refreshPresence();
      } else {
        scheduleMicrotask(arena.refreshPresence);
      }
    };
    engine = e;
    await e.start();
    arena.refreshPresence();
  }

  /// Single entry point for every inbound P2P message.
  void applyRemote(Map<String, dynamic> msg, String fromPeerId) {
    switch (msg['t']) {
      case 'sync.state':
        final Map<String, dynamic> payload =
            Map<String, dynamic>.from(msg);
        final dynamic inner = payload['profile'];
        if (inner is Map<String, dynamic>) {
          arena.notePeerProfile(
              ProfileWire.fromJson(inner),
              engine?.discovery.peerById(fromPeerId)?.address);
        }
        arena.mergeSyncState(payload, fromPeerId);
      case 'checkin.delta':
        final dynamic c = msg['checkin'];
        if (c is Map<String, dynamic>) {
          final String habitId = (c['habitId'] as String?) ?? '';
          final String? text = _checkinEventText(habitId, fromPeerId);
          habits.mergeCheckin(c);
          if (text != null) {
            arena.pushEvent(
                ArenaEvent('checkin', '📣', text));
          }
        }
      case 'challenge.offer':
        final dynamic ch = msg['challenge'];
        if (ch is Map<String, dynamic>) {
          arena.mergeChallenge(_challengeFrom(ch));
        }
      case 'challenge.response':
        arena.mergeChallengeResponse(msg);
      case 'forfeit.offer':
        final dynamic f = msg['forfeit'];
        if (f is Map<String, dynamic>) {
          arena.mergeForfeit(
              Forfeit.fromJson(Map<String, dynamic>.from(f)));
        }
      case 'forfeit.status':
        arena.mergeForfeitStatus(msg);
      case 'chat':
        arena.onChat(msg);
    }
    notifyListeners();
  }

  Challenge _challengeFrom(Map<String, dynamic> json) =>
      Challenge.fromJson(json);

  String? _checkinEventText(String habitId, String fromPeerId) {
    for (final Challenge c in db.challenges) {
      if (c.mirrorHabitId == habitId &&
          c.status == Challenge.statusActive) {
        final String who = arena.identityOf(fromPeerId).$1;
        return '$who checked in — ${c.habitName}';
      }
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused ||
            AppLifecycleState.detached ||
            AppLifecycleState.hidden:
        unawaited(db.flush());
      case AppLifecycleState.resumed:
        if (!ready || db.profile == null) return;
        tasks.materializeRecurring();
        arena.rollOverdueForfeits();
        arena.maybeSettleChallenges();
        arena.evaluateAwards();
        notifyListeners();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> flushNow() => db.flush();

  // -- preferences ------------------------------------------------------------

  ThemeMode get themeMode {
    final String v = (db.prefs['themeMode'] as String?) ?? 'system';
    return switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setThemeMode(ThemeMode mode) {
    db.prefs['themeMode'] = mode.name;
    db.dirtyPrefs();
    notifyListeners();
  }

  bool get hapticsEnabled => (db.prefs['haptics'] as bool?) ?? true;

  void setHapticsEnabled(bool v) {
    db.prefs['haptics'] = v;
    db.dirtyPrefs();
    notifyListeners();
  }

  /// Profile edits propagate to peers on their next sync.
  void updateProfile({String? name, String? emoji, int? colorSeed}) {
    final Profile? me = db.profile;
    if (me == null) return;
    db.profile = me.copyWith(
        name: name, emoji: emoji, colorSeed: colorSeed);
    db.dirtyProfile();
    notifyListeners();
  }

  @override
  void dispose() {
    engine?.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
