import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../models/goal.dart';
import '../models/reminder_settings.dart';

class ScheduledGoalReminder {
  const ScheduledGoalReminder({
    required this.goal,
    required this.date,
    required this.expectedTasks,
  });

  final Goal goal;
  final tz.TZDateTime date;
  final int expectedTasks;
}

// One-off notifications can be canceled as soon as new check-ins are saved.
// Keep the nearest 64 across all goals to respect iOS's pending request limit.
List<ScheduledGoalReminder> planGoalReminders(
  List<Goal> goals,
  tz.TZDateTime now, {
  required ReminderSettings settings,
  int limit = 64,
}) {
  if (!settings.enabled) return [];
  final upcoming = <ScheduledGoalReminder>[];
  for (final goal in goals) {
    if (goal.totalTasks <= 0 || goal.hasCompletedAllTasks) {
      continue;
    }
    final start = goal.startDate;
    final end = goal.endDate;
    final endDay = DateTime.utc(end.year, end.month, end.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    final startDay = DateTime.utc(start.year, start.month, start.day);
    final elapsedDays = today.difference(startDay).inDays;
    var period = math.max(1, switch (goal.frequencyUnit) {
      FrequencyUnit.day => elapsedDays + 1,
      FrequencyUnit.week => (elapsedDays + 6) ~/ 7,
      FrequencyUnit.month =>
        (now.year - start.year) * 12 + now.month - start.month,
    });
    var added = 0;
    while (added < limit) {
      final nextPeriod = switch (goal.frequencyUnit) {
        FrequencyUnit.day => DateTime.utc(
          start.year,
          start.month,
          start.day + period,
        ),
        FrequencyUnit.week => DateTime.utc(
          start.year,
          start.month,
          start.day + period * 7,
        ),
        FrequencyUnit.month => _monthBoundary(start, period),
      };
      final finalPeriod = !nextPeriod.isBefore(endDay);
      final boundary = finalPeriod ? endDay : nextPeriod;
      final dueDay = goal.frequencyUnit == FrequencyUnit.day
          ? boundary.subtract(const Duration(days: 1))
          : boundary;
      final date = tz.TZDateTime(
        now.location,
        dueDay.year,
        dueDay.month,
        dueDay.day,
        settings.hour,
        settings.minute,
      );
      final expected = finalPeriod
          ? goal.totalTasks
          : math.min(goal.totalTasks, period * goal.frequency);
      if (date.isAfter(now) && goal.completedTasks < expected) {
        upcoming.add(
          ScheduledGoalReminder(
            goal: goal,
            date: date,
            expectedTasks: expected,
          ),
        );
        added++;
      }
      if (finalPeriod) break;
      period++;
    }
  }
  upcoming.sort((a, b) {
    final order = a.date.compareTo(b.date);
    return order != 0 ? order : a.goal.id.compareTo(b.goal.id);
  });
  return upcoming.take(limit).toList();
}

DateTime _monthBoundary(DateTime start, int offset) {
  final month = start.month + offset;
  final lastDay = DateTime.utc(start.year, month + 1, 0).day;
  return DateTime.utc(start.year, month, math.min(start.day, lastDay));
}
