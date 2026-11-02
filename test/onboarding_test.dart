import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:inf151_app/services/goal_reminder_service.dart';
import 'package:onboarding_overlay/onboarding_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reminders extends GoalReminderService {
  final snapshots = <List<Goal>>[];
  final childSnapshots = <List<Child>>[];

  @override
  Future<void> sync(List<Goal> goals, List<Child> children) async {
    snapshots.add(List.of(goals));
    childSnapshots.add(List.of(children));
  }
}

Future<void> _showApp(
  WidgetTester tester, {
  Size size = const Size(430, 1000),
  GoalReminderService? reminderService,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(GoalApp(reminderService: reminderService));
  await tester.pumpAndSettle();
}

bool _guideVisible(WidgetTester tester) =>
    tester.state<OnboardingState>(find.byType(Onboarding)).isVisible();

void main() {
  testWidgets('first launch shows four steps and remembers completion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _showApp(tester);
    expect(find.text('Add your children'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    for (final title in [
      'Create a goal',
      'Print cards together',
      'Scan your progress',
    ]) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('4 of 4'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_seen'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const GoalApp());
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
    expect(find.text('Add your children'), findsNothing);
  });

  testWidgets('debug button replays the guide and Skip dismisses it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await _showApp(tester);
    expect(_guideVisible(tester), isFalse);
    await tester.tap(
      find.byTooltip('Reset children and goals for onboarding (debug)'),
    );
    await tester.pumpAndSettle();
    expect(await GoalStorage().load(), hasLength(3));
    final children = await ChildStorage().load();
    expect(children, hasLength(2));
    expect(children.map((child) => child.color).toSet(), hasLength(2));
    expect(find.text('Add your children'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
    await tester.tap(
      find.byTooltip('Reset children and goals for onboarding (debug)'),
    );
    await tester.pumpAndSettle();
    expect(await GoalStorage().load(), hasLength(3));
    expect(
      (await ChildStorage().load()).map((child) => child.id),
      children.map((child) => child.id),
    );
    expect(find.text('1 of 4'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
    expect(find.text('Add goal'), findsOneWidget);
  });

  testWidgets('the guide fits a small screen in dark mode with large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _showApp(tester, size: const Size(320, 640));
    for (var step = 0; step < 3; step++) {
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
  });

  testWidgets(
    'debug replay replaces children and goals and refreshes reminders',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      await ChildStorage().save([const Child(id: 'alex', name: 'Alex')]);
      await GoalStorage().save([
        for (var index = 0; index < 10; index++)
          Goal(
            id: '$index',
            childId: 'alex',
            title: 'Goal $index',
            frequency: 1,
            frequencyUnit: FrequencyUnit.day,
            duration: 1,
            durationUnit: DurationUnit.week,
            startDate: DateUtils.dateOnly(DateTime.now()),
          ),
      ]);
      final reminders = _Reminders();
      await _showApp(tester, reminderService: reminders);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Reset children and goals for onboarding (debug)'),
      );
      await tester.pumpAndSettle();
      for (var step = 0; step < 2; step++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Print cards together'), findsOneWidget);
      final onboarding = tester.state<OnboardingState>(find.byType(Onboarding));
      expect(onboarding.controller.currentStep!.focusNode.context, isNotNull);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      final examples = await GoalStorage().load();
      expect(examples, hasLength(3));
      expect(examples.every((goal) => goal.id.startsWith('example-')), isTrue);
      final defaultChildren = await ChildStorage().load();
      expect(defaultChildren.map((child) => child.name), ['Alex', 'Sam']);
      expect(defaultChildren.any((child) => child.id == 'alex'), isFalse);
      expect(
        examples.every(
          (goal) => defaultChildren.any((child) => child.id == goal.childId),
        ),
        isTrue,
      );
      expect(
        examples.map((goal) => goal.childId).toSet(),
        defaultChildren.map((child) => child.id).toSet(),
      );
      expect(
        examples.map((goal) => goal.frequencyUnit).toSet(),
        FrequencyUnit.values.toSet(),
      );
      expect(
        examples.every(
          (goal) => goal.completedTasks > 0 && !goal.hasCompletedAllTasks,
        ),
        isTrue,
      );
      expect(
        reminders.snapshots.last.map((goal) => goal.id),
        examples.map((goal) => goal.id),
      );
      expect(
        reminders.childSnapshots.last.map((child) => child.id),
        defaultChildren.map((child) => child.id),
      );
      expect(find.text('Read for 20 minutes').hitTestable(), findsOneWidget);
      expect(find.text('Goal 0'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(GoalApp(reminderService: reminders));
      await tester.pumpAndSettle();
      expect(
        (await GoalStorage().load()).map((goal) => goal.id),
        examples.map((goal) => goal.id),
      );
      expect(_guideVisible(tester), isFalse);
      expect(
        (await ChildStorage().load()).map((child) => child.toJson()),
        defaultChildren.map((child) => child.toJson()),
      );
    },
  );

  testWidgets('automatic onboarding keeps existing goals', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ChildStorage().save([const Child(id: 'alex', name: 'Alex')]);
    final goal = Goal(
      id: 'original',
      childId: 'alex',
      title: 'Keep this goal',
      frequency: 1,
      frequencyUnit: FrequencyUnit.day,
      duration: 2,
      durationUnit: DurationUnit.week,
      startDate: DateUtils.dateOnly(DateTime.now()),
      completedTasks: 2,
    );
    await GoalStorage().save([goal]);
    await _showApp(tester);
    expect(_guideVisible(tester), isTrue);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect((await GoalStorage().load()).single.toJson(), goal.toJson());
  });

  testWidgets('removing the page during onboarding removes its overlay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _showApp(tester);
    expect(_guideVisible(tester), isTrue);
    await tester.pumpWidget(const MaterialApp(home: Text('Another screen')));
    await tester.pumpAndSettle();
    expect(find.text('Add your children'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
