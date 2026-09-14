import 'package:flutter/material.dart' show Icons;

import 'common.dart';

/// A competitive habit challenge between two or more friends.
///
/// Lifecycle: the creator picks a habit template + stake + length and sends
/// it over P2P as [statusPending]. The invitee's device shows an accept /
/// decline sheet. Accepting mirrors the challenge (and its habit) on both
/// devices and flips to [statusActive]. When the window ends, either peer
/// can settle; totals are recomputed identically on each device from the
/// merged check-in ledger, so the result always converges.
class Challenge implements Synced {
  @override
  int updatedAt;
  @override
  String updatedBy;

  Challenge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.habitName,
    required this.iconCode,
    required this.colorSeed,
    required this.weekdays,
    required this.stake,
    required this.durationDays,
    required this.startDay,
    required this.createdBy,
    required this.participants,
    required this.status,
    this.winnerId,
    this.margin = 0,
    required this.updatedAt,
    required this.updatedBy,
  });

  static const String statusPending = 'pending';
  static const String statusActive = 'active';
  static const String statusSettled = 'settled';
  static const String statusDeclined = 'declined';

  final String id;
  final String name;
  final String emoji;
  final String habitName;
  final int iconCode;
  final int colorSeed;
  final Set<int> weekdays;
  final int stake;
  final int durationDays;
  final String startDay; // isoDate
  final String createdBy;
  final List<String> participants;

  String status;

  /// Set at settlement. Null winner = draw.
  String? winnerId;
  int margin;

  /// Deterministic mirror-habit id — identical on every participant's
  /// device, which is what lets check-in records align without handshake.
  String get mirrorHabitId => 'cm_$id';

  DateTime get startDate => DateTime.parse(startDay);
  DateTime get endDate =>
      startDate.add(Duration(days: durationDays));

  bool isActiveDay(DateTime day) =>
      !day.isBefore(DateTime.parse(startDay)) &&
      day.isBefore(endDate.add(const Duration(days: 1)));

  bool involves(String profileId) => participants.contains(profileId);

  /// The opponent in a 1v1 — [me] excluded.
  String? opponentOf(String me) {
    for (final String p in participants) {
      if (p != me) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'emoji': emoji,
        'habitName': habitName,
        'iconCode': iconCode,
        'colorSeed': colorSeed,
        'weekdays': weekdays.toList()..sort(),
        'stake': stake,
        'durationDays': durationDays,
        'startDay': startDay,
        'createdBy': createdBy,
        'participants': participants,
        'status': status,
        'winnerId': winnerId,
        'margin': margin,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Challenge',
        emoji: j['emoji'] as String? ?? '⚔️',
        habitName: j['habitName'] as String? ?? 'Habit',
        iconCode: (j['iconCode'] as num?)?.toInt() ??
            Icons.task_alt.codePoint,
        colorSeed: (j['colorSeed'] as num?)?.toInt() ?? 0,
        weekdays: ((j['weekdays'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => (e as num).toInt())
            .toSet(),
        stake: (j['stake'] as num?)?.toInt() ?? 25,
        durationDays: (j['durationDays'] as num?)?.toInt() ?? 7,
        startDay: j['startDay'] as String,
        createdBy: j['createdBy'] as String? ?? '',
        participants: ((j['participants'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => e as String)
            .toList(),
        status: j['status'] as String? ?? statusActive,
        winnerId: j['winnerId'] as String?,
        margin: (j['margin'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        updatedBy: j['updatedBy'] as String? ?? '',
      );

  Challenge markUpdated(String actorId) {
    return Challenge(
      id: id,
      name: name,
      emoji: emoji,
      habitName: habitName,
      iconCode: iconCode,
      colorSeed: colorSeed,
      weekdays: weekdays,
      stake: stake,
      durationDays: durationDays,
      startDay: startDay,
      createdBy: createdBy,
      participants: participants,
      status: status,
      winnerId: winnerId,
      margin: margin,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      updatedBy: actorId,
    );
  }

  @override
  bool operator ==(Object other) => other is Challenge && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A dare assigned from one friend to another — the "punishment" layer.
class Forfeit implements Synced {
  @override
  int updatedAt;
  @override
  String updatedBy;

  Forfeit({
    required this.id,
    required this.text,
    required this.fromId,
    required this.toId,
    this.challengeId,
    required this.dueDay,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
    this.completedAt,
  });

  static const String statusPending = 'pending';
  static const String statusDone = 'done'; // bearer marked complete…
  static const String statusVerified = 'verified'; // …assigner confirmed
  static const String statusFailed = 'failed'; // deadline passed un-done

  final String id;
  final String text;
  final String fromId;
  final String toId;

  /// Set when the forfeit is the settlement punishment of a challenge.
  final String? challengeId;
  final String dueDay;

  String status;
  final int createdAt;
  int? completedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'fromId': fromId,
        'toId': toId,
        'challengeId': challengeId,
        'dueDay': dueDay,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
        'completedAt': completedAt,
      };

  factory Forfeit.fromJson(Map<String, dynamic> j) => Forfeit(
        id: j['id'] as String,
        text: j['text'] as String,
        fromId: j['fromId'] as String,
        toId: j['toId'] as String,
        challengeId: j['challengeId'] as String?,
        dueDay: j['dueDay'] as String,
        status: j['status'] as String? ?? statusPending,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        updatedBy: j['updatedBy'] as String? ?? '',
        completedAt: (j['completedAt'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) => other is Forfeit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Append-only scoring event. The union of both peers' ledgers is the
/// shared leaderboard input; entries are never mutated or deleted.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.profileId,
    required this.delta,
    required this.reason,
    required this.dateKey,
    required this.createdAt,
    this.challengeId,
  });

  final String id;
  final String profileId;
  final int delta;
  final String reason; // checkin | streak | perfectDay | win | loss | draw
                       // | forfeitDone | forfeitFailed
  final String dateKey;
  final int createdAt;
  final String? challengeId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'profileId': profileId,
        'delta': delta,
        'reason': reason,
        'dateKey': dateKey,
        'createdAt': createdAt,
        'challengeId': challengeId,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'] as String,
        profileId: j['profileId'] as String,
        delta: (j['delta'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String? ?? 'checkin',
        dateKey: j['dateKey'] as String,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        challengeId: j['challengeId'] as String?,
      );

  @override
  bool operator ==(Object other) => other is LedgerEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Deterministic scoring contract shared by every device — both peers must
/// derive byte-identical totals or settlement breaks. Change with care and
/// bump [version] when you do.
abstract final class Scoring {
  static const int version = 1;

  static const int checkin = 10;

  /// Consecutive-day bonus, capped so streaks reward but don't explode.
  static int streakBonus(int streak) => streak <= 0 ? 0 : (streak - 1).clamp(0, 7);

  static const int perfectDay = 5;
  static const int forfeitDone = 15;
  static const int forfeitFailed = -20;
}

/// Award definitions. Unlocks are stored per-device (they are personal
/// milestones, not shared state) in AwardBook.
class AwardDef {
  const AwardDef(this.id, this.title, this.description, this.emoji, this.tier);

  final String id;
  final String title;
  final String description;
  final String emoji;

  /// 0 = bronze, 1 = silver, 2 = gold.
  final int tier;
}

abstract final class Awards {
  static const List<AwardDef> all = <AwardDef>[
    AwardDef('first_step', 'First Step', 'Complete your very first check-in', '🌱', 0),
    AwardDef('perfect_day', 'Flawless', 'Complete every scheduled habit in a day', '✨', 0),
    AwardDef('week_warrior', 'Week Warrior', 'A perfect week — nothing skipped', '🗓️', 1),
    AwardDef('streak_14', 'Fortnight', 'Keep a 14-day streak on any habit', '🔥', 1),
    AwardDef('streak_30', 'Iron Month', 'Keep a 30-day streak on any habit', '🏅', 2),
    AwardDef('icebreaker', 'Icebreaker', 'Connect with your first friend', '🤝', 0),
    AwardDef('entourage', 'Entourage', 'Connect with three friends', '👥', 1),
    AwardDef('duelist', 'Duelist', 'Win your first challenge', '⚔️', 1),
    AwardDef('hat_trick', 'Hat-Trick', 'Win three challenges', '👑', 2),
    AwardDef('redeemer', 'Redeemed', 'Serve out a forfeit', '💪', 0),
    AwardDef('early_bird', 'Early Bird', 'Five check-ins before 8:00', '🌅', 1),
    AwardDef('deep_diver', 'Deep Diver', 'Five focus sessions of 25+ minutes', '🤿', 1),
  ];

  static AwardDef? byId(String id) {
    for (final AwardDef d in all) {
      if (d.id == id) return d;
    }
    return null;
  }
}
