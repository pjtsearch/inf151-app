import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/child.dart';
import '../models/goal.dart';
import '../models/reminder_settings.dart';
import 'goal_reminder_schedule.dart';

class GoalReminderService {
  static const _payloadPrefix = 'goal-reminder:';
  final _notifications = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  Future<void> _queue = Future.value();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<ReminderSettings> loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('A parent must be signed in.');
    final snapshot = await FirebaseFirestore.instance
        .collection('parents')
        .doc(user.uid)
        .get();
    return ReminderSettings.fromJson(snapshot.data()?['reminderSettings']);
  }

  Future<void> saveSettings(ReminderSettings settings) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('A parent must be signed in.');
    await FirebaseFirestore.instance
        .collection('parents')
        .doc(user.uid)
        .set({'reminderSettings': settings.toJson()}, SetOptions(merge: true));
  }

  Future<void> _initialize() async {
    _initialization ??= _initializePlugin();
    try {
      await _initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initializePlugin() async {
    tzdata.initializeTimeZones();
    final initialized = await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_goal_reminder'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    if (initialized != true) {
      throw StateError('Could not initialize reminders.');
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
  }

  // Serialize updates so an older progress snapshot cannot overwrite a newer one.
  Future<void> sync(List<Goal> goals, List<Child> children) {
    final snapshot = List<Goal>.of(goals);
    final childNames = {for (final child in children) child.id: child.name};
    final update = _queue.then((_) => _sync(snapshot, childNames));
    _queue = update.catchError((Object _) {});
    return update;
  }

  Future<void> _sync(List<Goal> goals, Map<String, String> childNames) async {
    if (!isSupported) return;
    final settings = await loadSettings();
    final enabled = settings.enabled;
    await _initialize();
    for (final pending in await _notifications.pendingNotificationRequests()) {
      if (pending.payload?.startsWith(_payloadPrefix) ?? false) {
        await _notifications.cancel(id: pending.id);
      }
    }
    if (!enabled) return;
    final timezone = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(timezone.identifier);
    final planned = planGoalReminders(
      goals,
      tz.TZDateTime.now(location),
      settings: settings,
    );
    for (final (index, reminder) in planned.indexed) {
      final childName = childNames[reminder.goal.childId] ?? 'Your child';
      await _notifications.zonedSchedule(
        id: 7000 + index,
        title: '$childName’s goal reminder',
        body:
            'Progress on “${reminder.goal.title}” is behind. Open GoalPunch to review check-ins.',
        scheduledDate: reminder.date,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'goal_progress',
            'Goal progress reminders',
            channelDescription:
                'Reminders when recorded goal progress is behind.',
          ),
          iOS: DarwinNotificationDetails(presentBadge: false),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix${reminder.goal.id}',
      );
    }
  }
}
