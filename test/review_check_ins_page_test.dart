import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/punch_card_progress.dart';
import 'package:inf151_app/screens/review_check_ins_page.dart';

PunchCardProgress _scan({
  int detected = 10,
  GoalReward reward = const FreeTextReward(''),
}) => PunchCardProgress(
  goal: Goal(
    id: 'reading',
    childId: 'emma',
    title: 'Read for 20 minutes',
    frequency: 1,
    frequencyUnit: FrequencyUnit.day,
    duration: 14,
    durationUnit: DurationUnit.day,
    startDate: DateTime(2026, 10, 24),
    completedTasks: 8,
    reward: reward,
  ),
  cardStart: 0,
  cardEnd: 13,
  detectedCount: detected,
);

Future<void> _openReview(
  WidgetTester tester, {
  required PunchCardProgress progress,
  required ValueChanged<Goal?> onResult,
  Child? child = const Child(id: 'emma', name: 'Emma'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Goal>(
                MaterialPageRoute(
                  builder: (_) =>
                      ReviewCheckInsPage(progress: progress, child: child),
                ),
              );
              onResult(result);
            },
            child: const Text('Open review'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open review'));
  await tester.pumpAndSettle();
}

void main() {
  for (final reward in [
    const FreeTextReward('A trip to the park'),
    const FreeTextReward('A wooden puzzle'),
  ]) {
    testWidgets('shows ${reward.label} when the scan completes the goal', (
      tester,
    ) async {
      await _openReview(
        tester,
        progress: _scan(detected: 14, reward: reward),
        onResult: (_) {},
      );
      await tester.scrollUntilVisible(find.text('Goal complete!'), 150);
      expect(find.text('Goal complete!'), findsOneWidget);
      await tester.scrollUntilVisible(find.text(reward.label), 150);
      expect(find.text('Reward'), findsOneWidget);
      expect(find.text(reward.label), findsOneWidget);
    });
  }

  testWidgets('does not show a reward before the goal is complete', (
    tester,
  ) async {
    await _openReview(
      tester,
      progress: _scan(reward: const FreeTextReward('A trip to the park')),
      onResult: (_) {},
    );
    await tester.scrollUntilVisible(find.text('Confirm & Save Progress'), 150);
    expect(find.text('Goal complete!'), findsNothing);
    expect(find.text('Reward'), findsNothing);
    expect(find.text('A trip to the park'), findsNothing);
  });

  testWidgets('does not show an empty reward when the goal is complete', (
    tester,
  ) async {
    await _openReview(tester, progress: _scan(detected: 14), onResult: (_) {});
    await tester.scrollUntilVisible(find.text('Goal complete!'), 150);
    expect(find.text('Goal complete!'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Confirm & Save Progress'), 150);
    expect(find.text('Reward'), findsNothing);
  });

  testWidgets(
    'shows the match and proposed progress and confirms only on tap',
    (tester) async {
      final progress = _scan();
      Goal? result;
      var closed = false;
      await _openReview(
        tester,
        progress: progress,
        onResult: (value) {
          closed = true;
          result = value;
        },
      );
      expect(find.text('Matched to Emma'), findsOneWidget);
      expect(find.text('Read for 20 minutes'), findsOneWidget);
      expect(find.text('8 / 14 check-ins'), findsOneWidget);
      expect(find.text('10 / 14 check-ins'), findsOneWidget);
      expect(find.text('2 new check-ins'), findsOneWidget);
      expect(
        find.textContaining('The goal total becomes 10 / 14.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(10 / 14, 0.001),
      );
      expect(closed, isFalse);
      expect(progress.goal.completedTasks, 8);

      await tester.scrollUntilVisible(
        find.text('Confirm & Save Progress'),
        150,
      );
      await tester.tap(find.text('Confirm & Save Progress'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result?.completedTasks, 10);
      expect(result?.id, progress.goal.id);
      expect(result?.childId, progress.goal.childId);
    },
  );

  for (final action in ['Retake Photo', 'Back']) {
    testWidgets('$action returns to scanning without updating the goal', (
      tester,
    ) async {
      final progress = _scan();
      var closed = false;
      Goal? result;
      await _openReview(
        tester,
        progress: progress,
        onResult: (value) {
          closed = true;
          result = value;
        },
      );
      if (action == 'Retake Photo') {
        await tester.scrollUntilVisible(find.text(action), 150);
      }
      await tester.tap(
        action == 'Back' ? find.byType(BackButton) : find.text(action),
      );
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
      expect(progress.goal.completedTasks, 8);
      expect(find.text('Open review'), findsOneWidget);
    });
  }

  testWidgets(
    'a lower detection keeps saved progress and supports system back',
    (tester) async {
      var closed = false;
      await _openReview(
        tester,
        progress: _scan(detected: 3),
        child: null,
        onResult: (value) {
          closed = true;
          expect(value, isNull);
        },
      );
      expect(find.text('Matched goal'), findsOneWidget);
      expect(find.text('0 new check-ins'), findsOneWidget);
      expect(
        find.textContaining('The goal total becomes 8 / 14.'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    },
  );

  testWidgets('review stays usable on a small screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openReview(
      tester,
      progress: _scan(
        detected: 14,
        reward: const FreeTextReward('A family trip to the park and ice cream'),
      ),
      onResult: (_) {},
    );
    expect(tester.getBottomLeft(find.byType(ListView)).dy, 640);
    await tester.scrollUntilVisible(find.text('Retake Photo'), 150);
    await tester.pumpAndSettle();
    expect(find.text('Retake Photo').hitTestable(), findsOneWidget);
    expect(
      tester
          .getBottomLeft(find.widgetWithText(FilledButton, 'Retake Photo'))
          .dy,
      lessThanOrEqualTo(640 - 34),
    );
    expect(tester.takeException(), isNull);
  });
}
