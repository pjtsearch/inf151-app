import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/reminder_settings.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_reminder_service.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:inf151_app/widgets/reminder_settings_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reminders extends GoalReminderService {
  bool allowed = true;
  bool supported = true;
  bool failSave = false;
  int requests = 0;
  ReminderSettings settings = const ReminderSettings();
  final snapshots = <List<Goal>>[];
  @override
  bool get isSupported => supported;
  @override
  Future<ReminderSettings> loadSettings() async => settings;
  @override
  Future<void> saveSettings(ReminderSettings value) async {
    if (failSave) throw StateError('Storage unavailable');
    settings = value;
  }

  @override
  Future<bool> requestPermission() async {
    requests++;
    return allowed;
  }

  @override
  Future<void> sync(List<Goal> goals, List<Child> children) async {
    snapshots.add(List.of(goals));
  }
}

Future<void> _showApp(WidgetTester tester, _Reminders reminders) async {
  SharedPreferences.setMockInitialValues({'onboarding_seen': true});
  await ChildStorage().save([const Child(id: 'alex', name: 'Alex')]);
  await GoalStorage().save([
    for (final unit in [FrequencyUnit.day, FrequencyUnit.week])
      Goal(
        id: unit.name,
        childId: 'alex',
        title: unit.name,
        frequency: 2,
        frequencyUnit: unit,
        duration: 3,
        durationUnit: DurationUnit.week,
        startDate: DateUtils.dateOnly(DateTime.now()),
      ),
  ]);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(GoalApp(reminderService: reminders));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one global time can be chosen and applies to all goals', (
    tester,
  ) async {
    final reminders = _Reminders();
    await _showApp(tester, reminders);
    expect(reminders.requests, 0);
    await _open(tester);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(reminders.requests, 1);
    await tester.tap(find.text('Reminder time'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, '7');
    await tester.enterText(fields.last, '15');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(reminders.settings.enabled, isTrue);
    expect(reminders.settings.hour, 19);
    expect(reminders.settings.minute, 15);
    expect(reminders.snapshots.last, hasLength(2));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _open(tester);
    expect(find.text('7:15 PM'), findsOneWidget);
    expect(
      find.textContaining('This time applies to all goals'),
      findsOneWidget,
    );
  });

  testWidgets('denied permission leaves global reminders off', (tester) async {
    final reminders = _Reminders()..allowed = false;
    await _showApp(tester, reminders);
    await _open(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text('Reminder time'), findsNothing);
    expect(
      find.textContaining('Allow notifications in your device settings'),
      findsOneWidget,
    );
  });

  testWidgets(
    'canceling the time picker preserves the time and disabling saves automatically',
    (tester) async {
      final reminders = _Reminders()
        ..settings = const ReminderSettings(
          enabled: true,
          hour: 19,
          minute: 15,
        );
      await _showApp(tester, reminders);
      await _open(tester);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      await tester.tap(find.text('Reminder time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(reminders.settings.hour, 19);
      expect(reminders.settings.minute, 15);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(reminders.settings.enabled, isFalse);
      expect(reminders.settings.hour, 19);
      expect(reminders.settings.minute, 15);
    },
  );

  testWidgets(
    'unsupported platforms explain availability without requesting permission',
    (tester) async {
      final reminders = _Reminders()..supported = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderSettingsEditor(
              value: const ReminderSettings(),
              service: reminders,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(find.textContaining('Android and iOS'), findsOneWidget);
      expect(reminders.requests, 0);
    },
  );

  testWidgets('failed settings saves restore the previous value', (
    tester,
  ) async {
    final reminders = _Reminders()..failSave = true;
    await _showApp(tester, reminders);
    await _open(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(reminders.settings.enabled, isFalse);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(
      find.textContaining('Could not save reminder settings'),
      findsOneWidget,
    );
  });

  testWidgets(
    'settings and its time picker fit a small screen with large text',
    (tester) async {
      final reminders = _Reminders()
        ..settings = const ReminderSettings(enabled: true);
      await _showApp(tester, reminders);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.ensureVisible(find.text('Reminder time'));
      await tester.tap(find.text('Reminder time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
