import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/p2p/discovery.dart';
import '../core/p2p/protocol.dart';
import '../core/utils/date_x.dart';
import '../core/utils/ids.dart';
import '../data/local_db.dart';
import '../data/models/arena.dart';
import '../data/models/common.dart';
import '../data/models/habit.dart';
import '../data/models/profile.dart';
import '../data/score_engine.dart';
import 'app_store.dart';
import 'habit_store.dart';

/// A transient activity-line surfaced on the home banner (in-memory only).
@immutable
class ArenaEvent {
  const ArenaEvent(this.kind, this.emoji, this.title, {this.body});
  final String kind;
  final String emoji;
  final String title;
  final String? body;
}

/// A quick-line exchanged inside a challenge (ephemeral, not persisted).
@immutable
class ChatLine {
  const ChatLine(this.fromId, this.text, this.at);
  final String fromId;
  final String text;
  final DateTime at;
}

/// Friends, challenges, forfeits, scoring and awards.
///
/// This store is the app-side half of the P2P protocol: it builds
/// [collectSyncState] payloads, merges inbound messages with LWW rules,
/// and derives every competitive view (leaderboard, head-to-head,
/// settlement) with the shared [ScoreEngine] so both peers always agree.
class ArenaStore extends ChangeNotifier {
  ArenaStore(this._app);

  final AppStore _app;

  LocalDb get _db => _app.db;
  HabitStore get _habits => _app.habits;
  String get meId => _db.profile?.id ?? '';
  bool get hasProfile => _db.profile != null;

  // -- presence -------------------------------------------------------------
  Map<String, VisiblePeer> visible = <String, VisiblePeer>{};
  Set<String> connected = <String>{};
  final Map<String, ProfileWire> profiles = <String, ProfileWire>{};

  // -- feeds ----------------------------------------------------------------
  final List<ArenaEvent> events = <ArenaEvent>[];
  final Map<String, List<ChatLine>> chats = <String, List<ChatLine>>{};

  /// Unlocked awards awaiting their celebration overlay (UI drains these).
  final List<AwardDef> pendingCelebrations = <AwardDef>[];

  List<Challenge> get challenges => _db.challenges;
  List<Forfeit> get forfeits => _db.forfeits;
  UnmodifiableListView<FriendRecord> get friends =>
      UnmodifiableListView<FriendRecord>(_db.friends);

  List<Challenge> get pendingInvites => challenges
      .where((Challenge c) =>
          c.status == Challenge.statusPending && c.createdBy != meId)
      .toList();

  List<Challenge> get activeChallenges => challenges
      .where((Challenge c) => c.status == Challenge.statusActive)
      .toList()
    ..sort((Challenge a, Challenge b) => a.endDate
        .compareTo(b.endDate));

  List<Challenge> get pastChallenges => challenges
      .where((Challenge c) =>
          c.status == Challenge.statusSettled ||
          c.status == Challenge.statusDeclined)
      .toList()
    ..sort((Challenge a, Challenge b) => b.updatedAt.compareTo(a.updatedAt));

  FriendRecord? friendById(String id) {
    for (final FriendRecord f in _db.friends) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Display info for any known profile (friend record first, live wire
  /// fallback).
  (String, String, int) identityOf(String id) {
    if (id == meId && _db.profile != null) {
      return (_db.profile!.name, _db.profile!.emoji,
          _db.profile!.colorSeed);
    }
    final FriendRecord? f = friendById(id);
    if (f != null) return (f.name, f.emoji, f.colorSeed);
    final ProfileWire? w = profiles[id];
    return (w?.name ?? 'Friend', w?.emoji ?? '🙂', w?.colorSeed ?? 0);
  }

  void pushEvent(ArenaEvent e) {
    events.insert(0, e);
    if (events.length > 6) events.removeLast();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Presence & auto-connect policy
  // --------------------------------------------------------------------------

  void refreshPresence() {
    visible = <String, VisiblePeer>{
      for (final VisiblePeer vp in _app.engine!.discovery.snapshot())
        vp.wire.id: vp,
    };
    connected = _app.engine?.connectedPeers ?? <String>{};
    for (final ProfileWire w in <ProfileWire>[
      ...visible.values.map((VisiblePeer v) => v.wire),
    ]) {
      _upsertFriend(w, visible[w.id]?.address);
    }
    notifyListeners();
  }

  void notePeerProfile(ProfileWire w, String? address) {
    _upsertFriend(w, address);
    // A sync.state means a genuine session happened — this is "meeting".
    final FriendRecord? f = friendById(w.id);
    if (f != null && f.metAt == null) {
      f.metAt = DateTime.now().millisecondsSinceEpoch;
      _db.dirtyFriends();
      _evaluateAwards();
    }
    notifyListeners();
  }

  void _upsertFriend(ProfileWire w, String? address) {
    if (w.id == meId) return;
    final FriendRecord? existing = friendById(w.id);
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      _db.friends.add(FriendRecord(
        id: w.id,
        name: w.name,
        emoji: w.emoji,
        colorSeed: w.colorSeed,
        firstSeen: now,
        lastSeen: now,
        lastAddress: address,
      ));
      _db.dirtyFriends();
      profiles[w.id] = w;
      pushEvent(const ArenaEvent('friend', '👋', 'Someone new is nearby'));
    } else {
      if (address != null) existing.lastAddress = address;
      existing
        ..name = w.name
        ..emoji = w.emoji
        ..colorSeed = w.colorSeed
        ..lastSeen = now;
      _db.dirtyFriends();
      profiles[w.id] = w;
    }
  }

  /// Auto-connect to peers we share pending/active business with, or
  /// already know. Strangers stay strangers until you tap them.
  bool shouldAutoConnect(String peerId) {
    for (final Challenge c in challenges) {
      if (c.involves(peerId) &&
          (c.status == Challenge.statusPending ||
              c.status == Challenge.statusActive)) {
        return true;
      }
    }
    for (final Forfeit f in forfeits) {
      if ((f.fromId == peerId || f.toId == peerId) &&
          f.status != Forfeit.statusVerified &&
          f.status != Forfeit.statusFailed) {
        return true;
      }
    }
    return friendById(peerId) != null;
  }

  Future<void> connectManual(VisiblePeer vp) async {
    await _app.engine?.connect(vp.address, vp.wire.id);
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Scoring ledger
  // --------------------------------------------------------------------------

  /// Called on every local check-in flip. Ledger mirrors current truth:
  /// undoing a check-in removes its entries, so toggling can never farm.
  void onLocalCheckin(Habit habit, DateTime day, bool nowDone) {
    final String dateKey = day.isoDate;
    if (nowDone) {
      final Set<String> keys = _habits.myDoneKeys();
      final int streak = ScoreEngine.streakToday(habit, keys, actor: meId);
      _addEntry(meId, Scoring.checkin, 'checkin', dateKey, habit.id);
      final int bonus = Scoring.streakBonus(streak);
      if (bonus > 0) {
        _addEntry(meId, bonus, 'streak', dateKey, habit.id);
      }
      if (_habits.isDoneOnToday(DateTime.now())) {
        _addEntry(meId, Scoring.perfectDay, 'perfectDay', dateKey, null);
      }
      // Morning check-ins: award fuel.
      if (DateTime.now().hour < 8) _evaluateAwards();
      _evaluateAwards();
    } else {
      _removeEntries(meId, dateKey, habit.id, <String>['checkin', 'streak']);
      _removeEntries(meId, dateKey, null, <String>['perfectDay']);
    }
  }

  void _addEntry(String profileId, int delta, String reason, String dateKey,
      String? challengeId) {
    // Idempotency: one entry per (profile, reason, day, scope).
    final bool exists = _db.ledger.any((LedgerEntry e) =>
        e.profileId == profileId &&
        e.reason == reason &&
        e.dateKey == dateKey &&
        e.challengeId == challengeId);
    if (exists) return;
    _db.ledger.add(LedgerEntry(
      id: newId('lg'),
      profileId: profileId,
      delta: delta,
      reason: reason,
      dateKey: dateKey,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      challengeId: challengeId,
    ));
    _db.dirtyLedger();
    notifyListeners();
  }

  void _removeEntries(String profileId, String dateKey, String? habitId,
      List<String> reasons) {
    final int before = _db.ledger.length;
    _db.ledger.removeWhere((LedgerEntry e) =>
        e.profileId == profileId &&
        e.dateKey == dateKey &&
        reasons.contains(e.reason) &&
        (habitId == null || e.challengeId == habitId));
    if (_db.ledger.length != before) {
      _db.dirtyLedger();
      notifyListeners();
    }
  }

  int get totalPoints => _db.ledger
      .where((LedgerEntry e) => e.profileId == meId)
      .fold(0, (int a, LedgerEntry e) => a + e.delta);

  /// This ISO week's leaderboard across me + everyone we've synced with.
  List<({String id, String name, String emoji, int seed, int points, int rank})>
      weeklyLeaderboard() {
    final String weekStart = DateTime.now().startOfWeek.isoDate;
    final Map<String, int> scores = <String, int>{};
    for (final LedgerEntry e in _db.ledger) {
      if (e.dateKey.compareTo(weekStart) < 0) continue;
      scores[e.profileId] = (scores[e.profileId] ?? 0) + e.delta;
    }
    final List<String> ids = <String>{meId, ...scores.keys}.toList();
    final List<({String id, String name, String emoji, int seed, int points})>
        rows = <({String id, String name, String emoji, int seed, int points})>[
      for (final String id in ids)
        (
          id: id,
          name: identityOf(id).$1,
          emoji: identityOf(id).$2,
          seed: identityOf(id).$3,
          points: scores[id] ?? 0,
        ),
    ]..sort((a, b) => b.points.compareTo(a.points));
    return <({String id, String name, String emoji, int seed, int points, int rank})>[
      for (int i = 0; i < rows.length; i++)
        (
          id: rows[i].id,
          name: rows[i].name,
          emoji: rows[i].emoji,
          seed: rows[i].seed,
          points: rows[i].points,
          rank: i + 1,
        ),
    ];
  }

  // --------------------------------------------------------------------------
  // Challenges
  // --------------------------------------------------------------------------

  Challenge createChallenge({
    required String friendId,
    required String name,
    required String emoji,
    required String habitName,
    required int iconCode,
    required int colorSeed,
    required Set<int> weekdays,
    required int stake,
    required int durationDays,
    DateTime? start,
  }) {
    final Challenge c = Challenge(
      id: newId('ch'),
      name: name,
      emoji: emoji,
      habitName: habitName,
      iconCode: iconCode,
      colorSeed: colorSeed,
      weekdays: weekdays,
      stake: stake,
      durationDays: durationDays,
      startDay: (start ?? _nextMondayish()).isoDate,
      createdBy: meId,
      participants: <String>[meId, friendId],
      status: Challenge.statusPending,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      updatedBy: meId,
    );
    _db.challenges.add(c);
    _db.dirtyChallenges();
    _sendTo(friendId, <String, dynamic>{
      't': 'challenge.offer',
      'challenge': c.toJson(),
    });
    notifyListeners();
    return c;
  }

  /// Challenges start "next morning" so both peers begin on the same day.
  DateTime _nextMondayish() {
    final DateTime now = DateTime.now().dayOnly;
    if (now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday) {
      return now.startOfWeek.add(const Duration(days: 7));
    }
    return now.add(const Duration(days: 1));
  }

  void respondInvite(String challengeId, bool accept) {
    final Challenge? c = _byId(challengeId);
    if (c == null || c.status != Challenge.statusPending) return;
    if (accept) {
      c
        ..status = Challenge.statusActive
        ..updatedAt = DateTime.now().millisecondsSinceEpoch
        ..updatedBy = meId;
      _ensureMirrorHabit(c);
      _db.dirtyChallenges();
      _sendTo(c.createdBy, <String, dynamic>{
        't': 'challenge.response',
        'challengeId': c.id,
        'accept': true,
      });
      pushEvent(ArenaEvent('challenge', c.emoji, 'Challenge on!', body: c.name));
    } else {
      _db.challenges.remove(c);
      _db.dirtyChallenges();
      _sendTo(c.createdBy, <String, dynamic>{
        't': 'challenge.response',
        'challengeId': c.id,
        'accept': false,
      });
    }
    notifyListeners();
  }

  /// Both sides create the same deterministic mirror habit — that shared
  /// id is the only "coordination" the protocol needs.
  void _ensureMirrorHabit(Challenge c) {
    if (_habits.byId(c.mirrorHabitId) != null) return;
    _habits.addHabit(
      name: c.habitName,
      iconCode: c.iconCode,
      colorSeed: c.colorSeed,
      weekdays: c.weekdays,
      challengeId: c.id,
    );
  }

  void cancelChallenge(String challengeId) {
    final Challenge? c = _byId(challengeId);
    if (c == null || c.status != Challenge.statusPending) return;
    _db.challenges.remove(c);
    _db.dirtyChallenges();
    for (final String p in c.participants) {
      if (p != meId) {
        _sendTo(p, <String, dynamic>{
          't': 'challenge.response',
          'challengeId': c.id,
          'accept': false,
        });
      }
    }
    notifyListeners();
  }

  Map<String, int> progressOf(Challenge c) =>
      ScoreEngine.challengeTotals(c, _db.checkins);

  /// Daily completion map for the challenge detail timeline:
  /// `isoDate → participantId → done`.
  Map<String, Map<String, bool>> dayMapOf(Challenge c) {
    final Map<String, Map<String, bool>> out = <String, Map<String, bool>>{};
    final DateTime today = DateTime.now().dayOnly;
    for (int i = 0; i < c.durationDays; i++) {
      final DateTime day = c.startDate.add(Duration(days: i));
      if (day.isAfter(today)) break;
      final String key = day.isoDate;
      out[key] = <String, bool>{
        for (final String p in c.participants)
          p: (_db.checkins['${c.mirrorHabitId}|$key|$p']?.done ?? false),
      };
    }
    return out;
  }

  void maybeSettleChallenges() {
    final DateTime now = DateTime.now().dayOnly;
    bool changed = false;
    for (final Challenge c in List<Challenge>.of(_db.challenges)) {
      if (c.status != Challenge.statusActive) continue;
      if (!now.isAfter(c.endDate)) continue;
      final Map<String, int> totals = progressOf(c);
      final (String?, int) result = ScoreEngine.settle(c, totals);
      c
        ..status = Challenge.statusSettled
        ..winnerId = result.$1
        ..margin = result.$2
        ..updatedAt = DateTime.now().millisecondsSinceEpoch
        ..updatedBy = meId;
      _db.dirtyChallenges();
      changed = true;
      // Each device writes only its own ledger entries; the union is the
      // shared scoreboard. That's what keeps settlement serverless yet safe.
      final String today = now.isoDate;
      if (result.$1 == null) {
        // draw — stakes stay with their owners, nothing to book
      } else if (result.$1 == meId) {
        _addEntry(meId, c.stake, 'win', today, c.id);
      } else {
        _addEntry(meId, -c.stake, 'loss', today, c.id);
      }
      if (result.$1 == meId) {
        pushEvent(ArenaEvent('win', '🏆',
            'You won "${c.name}"', body: '+${c.stake} points'));
      } else if (result.$1 == null) {
        pushEvent(ArenaEvent('draw', '🤝',
            '"${c.name}" ended in a draw'));
      } else {
        pushEvent(ArenaEvent('loss', '🎯',
            '"${c.name}" went to ${identityOf(result.$1!).$1}',
            body: 'Stake settled'));
      }
      _evaluateAwards();
    }
    if (changed) {
      _db.dirtyChallenges();
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Forfeits
  // --------------------------------------------------------------------------

  Forfeit assignForfeit({
    required String toId,
    required String text,
    required int days,
    String? challengeId,
  }) {
    final Forfeit f = Forfeit(
      id: newId('ff'),
      text: text,
      fromId: meId,
      toId: toId,
      challengeId: challengeId,
      dueDay: DateTime.now()
          .dayOnly
          .add(Duration(days: days))
          .isoDate,
      status: Forfeit.statusPending,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      updatedBy: meId,
    );
    _db.forfeits.add(f);
    _db.dirtyForfeits();
    _sendTo(toId, <String, dynamic>{'t': 'forfeit.offer', 'forfeit': f.toJson()});
    notifyListeners();
    return f;
  }

  List<Forfeit> get forfeitsAssignedToMe => forfeits
      .where((Forfeit f) => f.toId == meId)
      .toList()
    ..sort((Forfeit a, Forfeit b) => a.dueDay.compareTo(b.dueDay));

  List<Forfeit> get forfeitsAssignedByMe => forfeits
      .where((Forfeit f) => f.fromId == meId)
      .toList()
    ..sort((Forfeit a, Forfeit b) => a.dueDay.compareTo(b.dueDay));

  /// Already assigned a forfeit as settlement of this challenge?
  bool forfeitAssignedFor(String challengeId) => forfeits.any(
      (Forfeit f) => f.challengeId == challengeId && f.fromId == meId);

  void markForfeitDone(Forfeit f) {
    if (f.toId != meId || f.status != Forfeit.statusPending) return;
    f
      ..status = Forfeit.statusDone
      ..completedAt = DateTime.now().millisecondsSinceEpoch
      ..updatedAt = DateTime.now().millisecondsSinceEpoch
      ..updatedBy = meId;
    _db.dirtyForfeits();
    _addEntry(meId, Scoring.forfeitDone, 'forfeitDone', f.dueDay, null);
    _sendTo(f.fromId, <String, dynamic>{
      't': 'forfeit.status',
      'id': f.id,
      'status': Forfeit.statusDone,
      'completedAt': f.completedAt,
    });
    pushEvent(const ArenaEvent('forfeit', '💪', 'Forfeit served!'));
    _evaluateAwards();
    notifyListeners();
  }

  void verifyForfeit(Forfeit f, bool ok) {
    if (f.fromId != meId || f.status != Forfeit.statusDone) return;
    f
      ..status = ok ? Forfeit.statusVerified : Forfeit.statusPending
      ..updatedAt = DateTime.now().millisecondsSinceEpoch
      ..updatedBy = meId;
    if (!ok) f.completedAt = null;
    _db.dirtyForfeits();
    _sendTo(f.toId, <String, dynamic>{
      't': 'forfeit.status',
      'id': f.id,
      'status': f.status,
    });
    notifyListeners();
  }

  /// Deterministic rollover run on startup/resume: pending forfeits past
  /// their due day fail everywhere (each device books its own side).
  void rollOverdueForfeits() {
    final String today = DateTime.now().dayOnly.isoDate;
    bool changed = false;
    for (final Forfeit f in _db.forfeits) {
      if (f.status == Forfeit.statusPending && f.dueDay.compareTo(today) < 0) {
        f
          ..status = Forfeit.statusFailed
          ..updatedAt = DateTime.now().millisecondsSinceEpoch
          ..updatedBy = meId;
        if (f.toId == meId) {
          _addEntry(meId, Scoring.forfeitFailed, 'forfeitFailed', today, null);
        }
        changed = true;
      }
    }
    if (changed) {
      _db.dirtyForfeits();
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Chat quick-lines
  // --------------------------------------------------------------------------

  void sendChat(String challengeId, String toId, String text) {
    _sendTo(toId, <String, dynamic>{
      't': 'chat',
      'challengeId': challengeId,
      'from': meId,
      'text': text,
    });
    _appendChat(challengeId, meId, text);
  }

  void _appendChat(String challengeId, String fromId, String text) {
    final List<ChatLine> list =
        chats.putIfAbsent(challengeId, () => <ChatLine>[]);
    list.add(ChatLine(fromId, text, DateTime.now()));
    if (list.length > 30) list.removeAt(0);
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Sync payloads & merging
  // --------------------------------------------------------------------------

  Map<String, dynamic> collectSyncState(String forPeerId) {
    final Set<String> mirrorIds = <String>{
      for (final Habit h in _db.habits)
        if (h.challengeId != null) h.challengeId!,
    };
    final Map<String, dynamic> checkinJson = <String, dynamic>{
      for (final MapEntry<String, HabitCheckin> e
          in _db.checkins.entries)
        if (mirrorIds.contains(e.value.habitId)) e.key: e.value.toJson(),
    };
    return <String, dynamic>{
      't': 'sync.state',
      'profile': ProfileWire(
        meId,
        _db.profile!.name,
        _db.profile!.emoji,
        _db.profile!.colorSeed,
      ).toJson(),
      'habits': <Map<String, dynamic>>[
        for (final Habit h in _db.habits)
          if (h.challengeId != null) h.toJson(),
      ],
      'checkins': checkinJson,
      'challenges': <Map<String, dynamic>>[
        for (final Challenge c in _db.challenges)
          if (c.involves(forPeerId)) c.toJson(),
      ],
      'forfeits': <Map<String, dynamic>>[
        for (final Forfeit f in _db.forfeits)
          if (f.fromId == forPeerId || f.toId == forPeerId) f.toJson(),
      ],
      'ledger': <Map<String, dynamic>>[
        for (final LedgerEntry e in _db.ledger)
          if (e.profileId == meId) e.toJson(),
      ],
    };
  }

  void mergeSyncState(Map<String, dynamic> msg, String fromPeerId) {
    final dynamic p = msg['profile'];
    if (p is Map<String, dynamic>) {
      notePeerProfile(ProfileWire.fromJson(p), null);
    }
    for (final Map<String, dynamic> h
        in _castList(msg['habits'])) {
      _habits.mergeMirrorHabit(h);
    }
    final dynamic cks = msg['checkins'];
    if (cks is Map<String, dynamic>) {
      for (final dynamic v in cks.values) {
        if (v is Map<String, dynamic>) _habits.mergeCheckin(v);
      }
    }
    for (final Map<String, dynamic> cj in _castList(msg['challenges'])) {
      final Challenge incoming = Challenge.fromJson(cj);
      if (!incoming.involves(meId)) continue; // trust boundary
      mergeChallenge(incoming);
    }
    for (final Map<String, dynamic> fj in _castList(msg['forfeits'])) {
      final Forfeit incoming = Forfeit.fromJson(fj);
      if (incoming.fromId != meId && incoming.toId != meId) continue;
      mergeForfeit(incoming);
    }
    for (final Map<String, dynamic> lj in _castList(msg['ledger'])) {
      final LedgerEntry e = LedgerEntry.fromJson(lj);
      if (!_db.ledger.any((LedgerEntry x) => x.id == e.id)) {
        _db.ledger.add(e);
      }
    }
    _db.dirtyLedger();
    rollOverdueForfeits();
    maybeSettleChallenges();
    _evaluateAwards();
    notifyListeners();
  }

  static List<Map<String, dynamic>> _castList(dynamic v) {
    if (v is! List<dynamic>) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final dynamic e in v)
        if (e is Map<String, dynamic>) e,
    ];
  }

  // -- inbound message entry points (wired from AppStore.applyRemote) -------

  void mergeChallenge(Challenge incoming) {
    final int i = _db.challenges
        .indexWhere((Challenge c) => c.id == incoming.id);
    if (i == -1) {
      _db.challenges.add(incoming);
      _db.dirtyChallenges();
      if (incoming.createdBy != meId &&
          incoming.status == Challenge.statusPending) {
        pushEvent(ArenaEvent(
            'invite', incoming.emoji,
            '${identityOf(incoming.createdBy).$1} challenged you!',
            body: incoming.name));
      }
      if (incoming.status == Challenge.statusActive) {
        _ensureMirrorHabit(incoming);
      }
    } else {
      final Challenge existing = _db.challenges[i];
      if (existing.supersedes(incoming.updatedAt, incoming.updatedBy)) {
        _db.challenges[i] = incoming;
        _db.dirtyChallenges();
        if (incoming.status == Challenge.statusActive) {
          _ensureMirrorHabit(incoming);
        }
      }
    }
    notifyListeners();
  }

  void mergeChallengeResponse(Map<String, dynamic> msg) {
    final String? id = msg['challengeId'] as String?;
    final bool accept = msg['accept'] as bool? ?? false;
    final Challenge? c = _byId(id ?? '');
    if (c == null) return;
    if (c.createdBy != meId) return;
    if (accept) {
      c
        ..status = Challenge.statusActive
        ..updatedAt = DateTime.now().millisecondsSinceEpoch
        ..updatedBy = meId;
      _ensureMirrorHabit(c);
      _db.dirtyChallenges();
      pushEvent(ArenaEvent('challenge', c.emoji,
          '${identityOf(c.participants.firstWhere((String p) => p != meId)).$1} accepted!',
          body: c.name));
    } else {
      _db.challenges.remove(c);
      _db.dirtyChallenges();
      pushEvent(ArenaEvent('declined', '🕊️',
          '${identityOf(c.participants.firstWhere((String p) => p != meId)).$1} passed this time',
          body: c.name));
    }
    notifyListeners();
  }

  void mergeForfeit(Forfeit incoming) {
    final int i =
        _db.forfeits.indexWhere((Forfeit f) => f.id == incoming.id);
    if (i == -1) {
      _db.forfeits.add(incoming);
      _db.dirtyForfeits();
      if (incoming.toId == meId &&
          incoming.status == Forfeit.statusPending) {
        pushEvent(ArenaEvent('forfeit', '😈',
            '${identityOf(incoming.fromId).$1} assigned you a forfeit',
            body: incoming.text));
      }
    } else if (_db.forfeits[i]
        .supersedes(incoming.updatedAt, incoming.updatedBy)) {
      _db.forfeits[i] = incoming;
      _db.dirtyForfeits();
    }
    notifyListeners();
  }

  void mergeForfeitStatus(Map<String, dynamic> msg) {
    final String? id = msg['id'] as String?;
    final String? status = msg['status'] as String?;
    Forfeit? f;
    for (final Forfeit x in _db.forfeits) {
      if (x.id == id) f = x;
    }
    if (f == null || status == null) return;
    f
      ..status = status
      ..completedAt = (msg['completedAt'] as num?)?.toInt() ?? f.completedAt
      ..updatedAt = DateTime.now().millisecondsSinceEpoch
      ..updatedBy = meId;
    _db.dirtyForfeits();
    if (status == Forfeit.statusDone && f.fromId == meId) {
      pushEvent(ArenaEvent('forfeit', '📣',
          '${identityOf(f.toId).$1} served their forfeit',
          body: f.text));
    }
    notifyListeners();
  }

  void onChat(Map<String, dynamic> msg) {
    final String? cid = msg['challengeId'] as String?;
    final String? from = msg['from'] as String?;
    final String? text = msg['text'] as String?;
    if (cid == null || from == null || text == null) return;
    _appendChat(cid, from, text);
    pushEvent(ArenaEvent('chat', '💬',
        '${identityOf(from).$1}: $text'));
  }

  // --------------------------------------------------------------------------
  // Awards
  // --------------------------------------------------------------------------

  /// Evaluates every award against current stats; returns newly unlocked
  /// definitions so the UI can celebrate.
  List<AwardDef> evaluateAwards() {
    final List<AwardDef> unlocked = _evaluateAwards();
    if (unlocked.isNotEmpty) notifyListeners();
    return unlocked;
  }

  List<AwardDef> _evaluateAwards() {
    final List<AwardDef> fresh = <AwardDef>[];
    final Set<String> keys = _habits.myDoneKeys();
    final List<Habit> habits = _habits.all
        .where((Habit h) => h.challengeId == null)
        .toList();
    for (final AwardDef d in Awards.all) {
      if (_db.awards.containsKey(d.id)) continue;
      if (_satisfies(d, habits, keys)) {
        _db.awards[d.id] = DateTime.now().millisecondsSinceEpoch;
        fresh.add(d);
      }
    }
    if (fresh.isNotEmpty) {
      _db.dirtyAwards();
      pendingCelebrations.addAll(fresh);
      for (final AwardDef d in fresh) {
        pushEvent(ArenaEvent('award', d.emoji, 'Award unlocked: ${d.title}'));
      }
    }
    return fresh;
  }

  bool _satisfies(AwardDef d, List<Habit> habits, Set<String> keys) {
    switch (d.id) {
      case 'first_step':
        return keys.isNotEmpty;
      case 'perfect_day':
        return _habits.isDoneOnToday(DateTime.now()) &&
            _habits.scheduledOn(DateTime.now()).isNotEmpty;
      case 'week_warrior':
        return habits.any((Habit h) =>
            ScoreEngine.streakToday(h, keys, actor: meId) >= 7);
      case 'streak_14':
        return habits.any((Habit h) =>
            ScoreEngine.bestStreak(h, keys) >= 14 ||
            ScoreEngine.streakToday(h, keys, actor: meId) >= 14);
      case 'streak_30':
        return habits.any((Habit h) =>
            ScoreEngine.bestStreak(h, keys) >= 30 ||
            ScoreEngine.streakToday(h, keys, actor: meId) >= 30);
      case 'icebreaker':
        return _db.friends.any((FriendRecord f) => f.metAt != null);
      case 'entourage':
        return _db.friends
                .where((FriendRecord f) => f.metAt != null)
                .length >=
            3;
      case 'duelist':
        return challenges
            .where((Challenge c) =>
                c.status == Challenge.statusSettled &&
                c.winnerId == meId)
            .isNotEmpty;
      case 'hat_trick':
        return challenges
                .where((Challenge c) =>
                    c.status == Challenge.statusSettled &&
                    c.winnerId == meId)
                .length >=
            3;
      case 'redeemer':
        return forfeits
            .where((Forfeit f) =>
                f.toId == meId && f.status == Forfeit.statusVerified)
            .isNotEmpty;
      case 'early_bird':
        return _db.checkins.values
            .where((HabitCheckin c) =>
                c.done &&
                c.updatedBy == meId &&
                DateTime.fromMillisecondsSinceEpoch(c.updatedAt).hour < 8)
            .length >=
            5;
      case 'deep_diver':
        return _db.sessions
                .where((FocusSession s) => s.seconds >= 25 * 60)
                .length >=
            5;
      default:
        return false;
    }
  }

  Map<String, int> get awardBook => _db.awards;

  // --------------------------------------------------------------------------
  // helpers
  // --------------------------------------------------------------------------

  Challenge? _byId(String id) {
    for (final Challenge c in _db.challenges) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _sendTo(String peerId, Map<String, dynamic> msg) {
    _app.engine?.sendTo(peerId, msg);
  }
}
