/// Date & time helpers — dependency-free replacements for the `intl` bits we
/// actually need, tuned for habit-tracking semantics.
library;

const List<String> _monthsShort = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdays = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

const List<String> _weekdaysShort = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

extension DateX on DateTime {
  /// Midnight of this day, in local time.
  DateTime get dayOnly => DateTime(year, month, day);

  bool get isToday {
    final DateTime now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final DateTime y = DateTime.now().dayOnly
        .subtract(const Duration(days: 1));
    return year == y.year && month == y.month && day == y.day;
  }

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Whole days from [other] to this date (calendar days, not 24h blocks).
  int daysSince(DateTime other) =>
      dayOnly.difference(other.dayOnly).inDays;

  /// Monday-based start of week.
  DateTime get startOfWeek =>
      dayOnly.subtract(Duration(days: weekday - DateTime.monday));

  /// ISO-8601 week number.
  int get isoWeek {
    final DateTime thursday = dayOnly
        .add(Duration(days: 4 - (weekday == 0 ? 7 : weekday)));
    final DateTime firstThursday = DateTime(thursday.year, 1, 4);
    final DateTime weekOneMonday = firstThursday.startOfWeek;
    return ((thursday.difference(weekOneMonday).inDays) ~/ 7) + 1;
  }

  /// `2026-09-14` — canonical day key used in check-ins and sync.
  String get isoDate =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  String get monthShort => _monthsShort[month - 1];

  String get weekdayShort => _weekdaysShort[weekday - 1];

  String get weekdayFull => _weekdays[weekday - 1];

  /// "14 Aug", "14 Aug 2026" when not the current year.
  String get medium {
    final String y = year == DateTime.now().year ? '' : ' $year';
    return '$day ${_monthsShort[month - 1]}$y';
  }

  /// "Today", "Tomorrow", "Yesterday", "Sat", or "14 Aug".
  String get friendly {
    final DateTime now = DateTime.now();
    final int diff = daysSince(now);
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return weekdayShort;
    return medium;
  }

  /// "14:30" style, 24h.
  String get hm => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Milliseconds since epoch; used in last-write-wins metadata.
  int get stamp => millisecondsSinceEpoch;
}

/// Parses `2026-09-14` back to local midnight.
DateTime fromIsoDate(String iso) {
  final List<String> p = iso.split('-');
  return DateTime(
      int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// hh:mm → minutes since midnight (reminder storage format).
int timeToMinutes(int hour, int minute) => hour * 60 + minute;

/// Compact duration: 4:07 or 1:02:33.
String formatDuration(Duration d) {
  final int h = d.inHours;
  final int m = d.inMinutes.remainder(60);
  final int s = d.inSeconds.remainder(60);
  final String mm = m.toString().padLeft(2, '0');
  final String ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

/// "3d 4h", "45m" — compact human durations for forfeits/challenges.
String formatSpan(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 48) {
    final int m = d.inMinutes.remainder(60);
    return m == 0 ? '${d.inHours}h' : '${d.inHours}h ${m}m';
  }
  final int days = d.inDays;
  return '${days}d';
}

/// Cadence labels for habit chips: "Mon · Wed · Fri", "Daily", "3×/week".
String describeWeekdays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.isEmpty) return 'No days set';
  if (days.length == 5 &&
      days.containsAll(
          <int>{DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday})) {
    return 'Weekdays';
  }
  if (days.length == 2 &&
      days.containsAll(<int>{DateTime.saturday, DateTime.sunday})) {
    return 'Weekends';
  }
  return days
      .map((int d) => _weekdaysShort[(d - 1) % 7])
      .join(' · ');
}
