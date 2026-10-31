import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:onboarding_overlay/onboarding_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _showApp(
  WidgetTester tester, {
  Size size = const Size(430, 1000),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const GoalApp());
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
    await tester.tap(find.byTooltip('Show onboarding guide (debug)'));
    await tester.pumpAndSettle();
    expect(find.text('Add your children'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
    await tester.tap(find.byTooltip('Show onboarding guide (debug)'));
    await tester.pumpAndSettle();
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
    'replay scrolls back and highlights a real goal without modifying it',
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
      await _showApp(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show onboarding guide (debug)'));
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
      expect(await GoalStorage().load(), hasLength(10));
      expect(find.text('Goal 0').hitTestable(), findsOneWidget);
    },
  );

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
