import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../utils/date_x.dart';

/// GitHub-style contribution grid for a habit: last [weeks] weeks, one row
/// per week, Monday-first. Pure CustomPainter — no assets, no packages.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    super.key,
    required this.habitId,
    required this.doneKeys,
    required this.createdAtMs,
    required this.color,
    this.weeks = 16,
    this.cellSize = 13,
    this.gap = 3,
  });

  final String habitId;

  /// Set of full check-in keys (`habitId|date|actor`), done only.
  final Set<String> doneKeys;
  final int createdAtMs;
  final Color color;
  final int weeks;
  final double cellSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SizedBox(
      width: weeks * (cellSize + gap) - gap,
      height: 7 * (cellSize + gap) - gap,
      child: CustomPaint(
        painter: _HeatPainter(
          habitId: habitId,
          doneKeys: doneKeys,
          createdAtMs: createdAtMs,
          color: color,
          weeks: weeks,
          cellSize: cellSize,
          gap: gap,
          track: c.surfaceAlt,
          todayOutline: c.inkFaint,
        ),
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  const _HeatPainter({
    required this.habitId,
    required this.doneKeys,
    required this.createdAtMs,
    required this.color,
    required this.weeks,
    required this.cellSize,
    required this.gap,
    required this.track,
    required this.todayOutline,
  });

  final String habitId;
  final Set<String> doneKeys;
  final int createdAtMs;
  final Color color;
  final int weeks;
  final double cellSize;
  final double gap;
  final Color track;
  final Color todayOutline;

  @override
  void paint(Canvas canvas, Size size) {
    final DateTime today = DateTime.now().dayOnly;
    // End on the current week so the last column is "now".
    final DateTime weekStart = today.startOfWeek;
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final DateTime created =
        DateTime.fromMillisecondsSinceEpoch(createdAtMs).dayOnly;

    for (int w = 0; w < weeks; w++) {
      for (int d = 0; d < 7; d++) {
        final DateTime day =
            weekStart.subtract(Duration(days: (weeks - 1 - w) * 7))
                .add(Duration(days: d));
        final double x = w * (cellSize + gap);
        final double y = d * (cellSize + gap);
        final Rect cell = Rect.fromLTWH(x, y, cellSize, cellSize);
        final RRect rrect = RRect.fromRectAndRadius(
            cell, const Radius.circular(3.5));

        if (day.isAfter(today)) continue; // future — leave blank
        if (day.isBefore(created)) continue;

        // doneKeys carry an actor suffix; match on (habit, day) prefix.
        final bool isDone = doneKeys.any((String k) =>
            k.startsWith('$habitId|${day.isoDate}|'));

        paint.color = isDone ? color : track;
        canvas.drawRRect(rrect, paint);

        if (day.isSameDayAs(today) && !isDone) {
          final Paint outline = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = todayOutline;
          canvas.drawRRect(rrect, outline);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      old.doneKeys != doneKeys || old.color != color;
}
