import '../core/utils/date_x.dart';
import 'models/arena.dart';
import 'models/habit.dart';

/// Pure, deterministic scoring math.
///
/// Both peers in a challenge run these exact functions over their merged
/// check-in set; because the inputs converge (LWW sync) and the functions
/// are total and side-effect free, both devices derive identical totals —
/// that is what makes serverless settlement trustworthy.
abstract final class ScoreEngine {
  /// Consecutive scheduled days completed, counting back from [from]
  /// (exclusive). Days not scheduled are neutral (skipped, not broken).
  static int streakOf(Habit habit, Set<String> doneKeys, DateTime from,
      {String actor = 'me'}) {
    int streak = 0;
    DateTime day = from.dayOnly;
    // Walk back at most 400 days — long enough for any honest streak.
    for (int i = 0; i < 400; i++) {
      day = day.subtract(const Duration(days: 1));
      if (!habit.scheduledOn(day.weekday)) continue;
      if (doneKeys.contains('${habit.id}|${day.isoDate}|$actor')) {
        streak++;
      } else {
        // Missing (or pre-dating the habit) — the run ends here.
        break;
      }
    }
    return streak;
  }

  /// Streak including today (if today is done). Used for the flame UI.
  static int streakToday(Habit habit, Set<String> doneKeys,
      {String actor = 'me'}) {
    final DateTime now = DateTime.now();
    int streak = 0;
    if (habit.scheduledOn(now.weekday) &&
        doneKeys.contains('${habit.id}|${now.isoDate}|$actor')) {
      streak++;
    }
    return streak + streakOf(habit, doneKeys, now, actor: actor);
  }

  /// Longest run ever on [habit].
  static int bestStreak(Habit habit, Set<String> doneKeys, {int? sinceMs}) {
    final DateTime floor = DateTime.fromMillisecondsSinceEpoch(
        sinceMs ?? habit.createdAt);
    final Set<String> doneDays = doneKeys
        .where((String k) => k.startsWith('${habit.id}|'))
        .map((String k) => k.split('|')[1])
        .toSet();
    final List<DateTime> sorted = doneDays
        .map(fromIsoDate)
        .where((DateTime d) => !d.isBefore(floor))
        .toList()
      ..sort();
    int best = 0;
    int run = 0;
    DateTime? prev;
    for (final DateTime d in sorted) {
      if (prev == null || d.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      best = run > best ? run : best;
      prev = d;
    }
    return best;
  }

  /// Per-participant completion counts inside the challenge window.
  ///
  /// Counting rule (identical on both peers): every *scheduled* day within
  /// the window that has a `done` check-in for that participant adds 1.
  /// Unscheduled days are neutral; days after today earn no future credit.
  static Map<String, int> challengeTotals(
    Challenge challenge,
    Map<String, HabitCheckin> checkins,
  ) {
    final Map<String, int> totals = <String, int>{
      for (final String p in challenge.participants) p: 0,
    };
    final DateTime today = DateTime.now().dayOnly;
    final String mirror = challenge.mirrorHabitId;
    for (int i = 0; i < challenge.durationDays; i++) {
      final DateTime day = challenge.startDate.add(Duration(days: i));
      if (day.isAfter(today)) break;
      if (!challenge.weekdays.contains(day.weekday)) continue;
      final String key = day.isoDate;
      for (final String p in challenge.participants) {
        final HabitCheckin? c = checkins['$mirror|$key|$p'];
        if (c?.done ?? false) totals[p] = totals[p]! + 1;
      }
    }
    return totals;
  }

  /// Settlement outcome. Returns the winner id (null on a draw) and margin.
  static (String?, int) settle(Challenge c, Map<String, int> totals) {
    int best = -1;
    String? winner;
    bool tie = false;
    for (final MapEntry<String, int> e in totals.entries) {
      if (e.value > best) {
        best = e.value;
        winner = e.key;
        tie = false;
      } else if (e.value == best) {
        tie = true;
      }
    }
    if (tie) return (null, 0);
    final int runnerUp = totals.values
        .where((int v) => totals[winner] != v)
        .fold(0, (int a, int b) => a > b ? a : b);
    return (winner, best - runnerUp);
  }

  /// `2026-W37` — leaderboard bucket.
  static String weekKeyOf(DateTime d) =>
      '${d.year}-W${d.isoWeek.toString().padLeft(2, '0')}';
}
