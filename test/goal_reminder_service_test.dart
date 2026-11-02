import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/reminder_settings.dart';
import 'package:inf151_app/services/goal_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Goal _goal() => Goal(
  id: 'read',
  childId: 'alex',
  title: 'Read',
  frequency: 2,
  frequencyUnit: FrequencyUnit.day,
  duration: 3,
  durationUnit: DurationUnit.day,
  startDate: DateTime(2099, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('flutter_timezone');
  late List<Map<String, Object?>> pending;
  late List<MethodCall> calls;
  late bool failSchedule;
  late GoalReminderService service;

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'goal_reminder_settings': jsonEncode(
        const ReminderSettings(enabled: true).toJson(),
      ),
    });
    service = GoalReminderService();
    pending = [];
    calls = [];
    failSchedule = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, (_) async => 'UTC');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'requestNotificationsPermission':
              return false;
            case 'pendingNotificationRequests':
              return pending.toList();
            case 'cancel':
              final args = call.arguments as Map;
              pending.removeWhere((item) => item['id'] == args['id']);
              return null;
            case 'zonedSchedule':
              if (failSchedule) {
                throw PlatformException(code: 'schedule_failed');
              }
              final args = Map<String, Object?>.from(call.arguments as Map);
              pending.add({
                'id': args['id'],
                'title': args['title'],
                'body': args['body'],
                'payload': args['payload'],
              });
              return null;
          }
          throw StateError('Unexpected method ${call.method}');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, null);
  });

  test(
    'reminders are opt-in and permission is requested only explicitly',
    () async {
      await service.saveSettings(const ReminderSettings());
      await service.sync([_goal()], []);
      expect(calls, isEmpty);
      expect(await service.requestPermission(), isFalse);
      expect(calls.map((call) => call.method), [
        'initialize',
        'requestNotificationsPermission',
      ]);
    },
  );

  test(
    'saving progress cancels covered reminders and completion cancels all',
    () async {
      pending.add({
        'id': 90,
        'title': 'Other',
        'body': '',
        'payload': 'unrelated',
      });
      const children = [Child(id: 'alex', name: 'Alex')];
      await service.sync([_goal()], children);
      expect(pending, hasLength(4));
      expect(pending.last['title'], 'Alex’s goal reminder');
      expect(pending.last['payload'], 'goal-reminder:read');
      expect(
        calls.any((call) => call.method == 'requestNotificationsPermission'),
        isFalse,
      );

      await service.sync([_goal().copyWith(completedTasks: 2)], children);
      expect(pending, hasLength(3));
      final lastSchedules = calls
          .where((call) => call.method == 'zonedSchedule')
          .toList();
      expect(
        (lastSchedules.last.arguments as Map)['scheduledDateTime'],
        startsWith('2099-01-03T20:00'),
      );
      await service.sync([_goal().copyWith(completedTasks: 6)], children);
      expect(pending.single['id'], 90);
    },
  );

  test(
    'turning reminders off or deleting their goal removes pending notifications',
    () async {
      await service.sync([_goal()], []);
      await service.saveSettings(const ReminderSettings());
      await service.sync([_goal()], []);
      expect(pending, isEmpty);
      await service.saveSettings(const ReminderSettings(enabled: true));
      await service.sync([_goal()], []);
      expect(pending, hasLength(3));
      await service.sync([], []);
      expect(pending, isEmpty);
    },
  );

  test(
    'a failed update can be retried and updates use the device time zone',
    () async {
      failSchedule = true;
      await expectLater(
        service.sync([_goal()], []),
        throwsA(isA<PlatformException>()),
      );
      failSchedule = false;
      await service.sync([_goal()], []);
      expect(pending, hasLength(3));
      final scheduled = calls.lastWhere(
        (call) => call.method == 'zonedSchedule',
      );
      expect((scheduled.arguments as Map)['timeZoneName'], 'UTC');
    },
  );

  test(
    'changing the global time reschedules every goal at the same new time',
    () async {
      final goals = [
        _goal(),
        _goal().copyWith(id: 'weekly', frequencyUnit: FrequencyUnit.week),
      ];
      await service.sync(goals, []);
      calls.clear();
      await service.saveSettings(
        const ReminderSettings(enabled: true, hour: 19, minute: 15),
      );
      await service.sync(goals, []);
      final scheduled = calls.where((call) => call.method == 'zonedSchedule');
      expect(scheduled, isNotEmpty);
      expect(
        scheduled.map((call) => (call.arguments as Map)['payload']),
        containsAll(['goal-reminder:read', 'goal-reminder:weekly']),
      );
      for (final call in scheduled) {
        expect(
          (call.arguments as Map)['scheduledDateTime'],
          contains('T19:15'),
        );
      }
    },
  );
}
