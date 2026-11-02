import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/reminder_settings.dart';
import 'package:inf151_app/services/goal_reminder_service.dart';
import 'package:inf151_app/services/goal_reminder_schedule.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Goal _goal({FrequencyUnit unit = FrequencyUnit.day, int completed = 0}) => Goal(
  id: 'read',
  childId: 'alex',
  title: 'Read',
  frequency: 2,
  frequencyUnit: unit,
  duration: 3,
  durationUnit: unit == FrequencyUnit.day
      ? DurationUnit.day
      : unit == FrequencyUnit.week
      ? DurationUnit.week
      : DurationUnit.month,
  startDate: DateTime(2026, 1, 5),
  completedTasks: completed,
);

List<ScheduledGoalReminder> _plan(
  List<Goal> goals,
  tz.TZDateTime now, {
  int limit = 64,
  ReminderSettings settings = const ReminderSettings(
    enabled: true,
    hour: 20,
    minute: 30,
  ),
}) => planGoalReminders(goals, now, settings: settings, limit: limit);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  test('global reminder settings and real progress survive storage', () async {
    SharedPreferences.setMockInitialValues({});
    await GoalStorage().save([_goal(completed: 3)]);
    final restored = (await GoalStorage().load()).single;
    expect(restored.completedTasks, 3);
    final service = GoalReminderService();
    expect((await service.loadSettings()).enabled, isFalse);
    await service.saveSettings(
      const ReminderSettings(enabled: true, hour: 19, minute: 15),
    );
    final settings = await GoalReminderService().loadSettings();
    expect(settings.enabled, isTrue);
    expect(settings.hour, 19);
    expect(settings.minute, 15);
    expect(
      ReminderSettings.fromJson({'hour': 30, 'minute': 0}).enabled,
      isFalse,
    );
  });

  test(
    'daily reminders skip dates already covered by cumulative check-ins',
    () {
      final plan = _plan([
        _goal(completed: 2),
      ], tz.TZDateTime.utc(2026, 1, 5, 10));
      expect(plan.map((item) => item.date), [
        tz.TZDateTime.utc(2026, 1, 6, 20, 30),
        tz.TZDateTime.utc(2026, 1, 7, 20, 30),
      ]);
      expect(plan.map((item) => item.expectedTasks), [4, 6]);
    },
  );

  test(
    'weekly reminders repeat on the start weekday, beginning a week later',
    () {
      final plan = _plan([
        _goal(unit: FrequencyUnit.week),
      ], tz.TZDateTime.utc(2026, 1, 5));
      expect(plan.map((item) => item.date), [
        tz.TZDateTime.utc(2026, 1, 12, 20, 30),
        tz.TZDateTime.utc(2026, 1, 19, 20, 30),
        tz.TZDateTime.utc(2026, 1, 26, 20, 30),
      ]);
      expect(plan.map((item) => item.expectedTasks), [2, 4, 6]);
    },
  );

  test(
    'monthly reminders clamp month boundaries without drifting from the start day',
    () {
      final goal = _goal(
        unit: FrequencyUnit.month,
      ).copyWith(startDate: DateTime(2024, 1, 31));
      final plan = _plan([goal], tz.TZDateTime.utc(2024, 1, 1));
      expect(plan.map((item) => item.date), [
        tz.TZDateTime.utc(2024, 2, 29, 20, 30),
        tz.TZDateTime.utc(2024, 3, 31, 20, 30),
        tz.TZDateTime.utc(2024, 4, 30, 20, 30),
      ]);
    },
  );

  test(
    'weekly and monthly checks remain due until the chosen time on the boundary day',
    () {
      final weekly = _plan([
        _goal(unit: FrequencyUnit.week),
      ], tz.TZDateTime.utc(2026, 1, 12, 10));
      expect(weekly.first.date, tz.TZDateTime.utc(2026, 1, 12, 20, 30));
      final monthly = _plan([
        _goal(unit: FrequencyUnit.month),
      ], tz.TZDateTime.utc(2026, 2, 5, 10));
      expect(monthly.first.date, tz.TZDateTime.utc(2026, 2, 5, 20, 30));
    },
  );

  test(
    'a final partial period checks the remaining target on the last goal day',
    () {
      final goal = _goal(
        unit: FrequencyUnit.week,
      ).copyWith(duration: 10, durationUnit: DurationUnit.day);
      final plan = _plan([goal], tz.TZDateTime.utc(2026, 1, 5));
      expect(plan.map((item) => item.date.day), [12, 15]);
      expect(plan.map((item) => item.expectedTasks), [2, 4]);
    },
  );

  test('disabled, complete, ended and past-time reminders are excluded', () {
    final now = tz.TZDateTime.utc(2026, 1, 5, 21);
    expect(_plan([_goal()], now, settings: const ReminderSettings()), isEmpty);
    expect(_plan([_goal(completed: 6)], now), isEmpty);
    expect(_plan([_goal()], tz.TZDateTime.utc(2026, 2, 1)), isEmpty);
    expect(_plan([_goal()], now).first.date.day, 6);
  });

  test(
    'the chosen local time stays the same across both daylight-saving transitions',
    () {
      final location = tz.getLocation('America/Los_Angeles');
      for (final start in [DateTime(2026, 3, 7), DateTime(2026, 10, 31)]) {
        final plan = _plan([
          _goal().copyWith(startDate: start),
        ], tz.TZDateTime(location, start.year, start.month, start.day));
        expect(plan.map((item) => item.date.hour), everyElement(20));
        expect(plan.map((item) => item.date.minute), everyElement(30));
        expect(
          plan.first.date.timeZoneOffset,
          isNot(plan.last.date.timeZoneOffset),
        );
      }
    },
  );

  test('the queue keeps the earliest 64 notifications across all goals', () {
    final goal = _goal().copyWith(duration: 100);
    final plan = _plan([
      goal,
      goal.copyWith(id: 'second'),
    ], tz.TZDateTime.utc(2026, 1, 5));
    expect(plan, hasLength(64));
    expect(plan.where((item) => item.goal.id == 'read'), hasLength(32));
    expect(plan.last.date, tz.TZDateTime.utc(2026, 2, 5, 20, 30));
  });
}
