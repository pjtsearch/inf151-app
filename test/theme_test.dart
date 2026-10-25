import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/punch_card_progress.dart';
import 'package:inf151_app/screens/goals_page.dart';
import 'package:inf151_app/screens/review_check_ins_page.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:inf151_app/widgets/child_profile_card.dart';
import 'package:inf151_app/widgets/goal_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emma = Child(id: 'emma', name: 'Emma');

Goal _goal() => Goal(
  id: 'reading',
  childId: _emma.id,
  title: 'Read for 20 minutes',
  frequency: 1,
  frequencyUnit: FrequencyUnit.day,
  duration: 14,
  durationUnit: DurationUnit.day,
  startDate: DateUtils.dateOnly(DateTime.now()),
  reward: const FreeTextReward('A trip to the park'),
);

Future<void> _showApp(WidgetTester tester, Brightness brightness) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  SharedPreferences.setMockInitialValues({});
  await ChildStorage().save([_emma]);
  await GoalStorage().save([_goal()]);
  await tester.pumpWidget(const GoalApp());
  await tester.pumpAndSettle();
}

Color _cardBackground(WidgetTester tester, Finder card) => tester
    .widget<Material>(
      find.descendant(of: card, matching: find.byType(Material)).first,
    )
    .color!;

void main() {
  testWidgets(
    'follows system theme changes while retaining the current goals',
    (tester) async {
      await _showApp(tester, Brightness.light);
      ThemeData theme() => Theme.of(tester.element(find.byType(GoalsPage)));
      expect(theme().brightness, Brightness.light);
      expect(theme().colorScheme.primaryContainer, const Color(0xFFF5EF9F));
      expect(
        ThemeData.estimateBrightnessForColor(
          _cardBackground(tester, find.byType(GoalCard)),
        ),
        Brightness.light,
      );

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(theme().brightness, Brightness.dark);
      expect(
        ThemeData.estimateBrightnessForColor(theme().scaffoldBackgroundColor),
        Brightness.dark,
      );
      expect(
        ThemeData.estimateBrightnessForColor(
          _cardBackground(tester, find.byType(GoalCard)),
        ),
        Brightness.dark,
      );
      expect(tester.widget<GoalCard>(find.byType(GoalCard)).goal.id, 'reading');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(theme().brightness, Brightness.light);
      expect(find.text('Read for 20 minutes'), findsOneWidget);
    },
  );

  testWidgets('dark mode applies to children, forms, and scan reviews', (
    tester,
  ) async {
    await _showApp(tester, Brightness.dark);
    await tester.tap(find.byTooltip('Manage children'));
    await tester.pumpAndSettle();
    expect(
      ThemeData.estimateBrightnessForColor(
        _cardBackground(tester, find.byType(ChildProfileCard)),
      ),
      Brightness.dark,
    );
    await tester.tap(find.byType(ChildProfileCard));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(TextFormField))).brightness,
      Brightness.dark,
    );
    await tester.enterText(find.byType(TextFormField), 'Emma edited');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(TextFormField))).brightness,
      Brightness.light,
    );
    expect(find.text('Emma edited'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final context = tester.element(find.byType(GoalsPage));
    Navigator.of(context).push<Goal>(
      MaterialPageRoute(
        builder: (_) => ReviewCheckInsPage(
          child: _emma,
          progress: PunchCardProgress(
            goal: _goal().copyWith(completedTasks: 8),
            cardStart: 0,
            cardEnd: 13,
            detectedCount: 14,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ReviewCheckInsPage))).brightness,
      Brightness.dark,
    );
    await tester.scrollUntilVisible(find.text('A trip to the park'), 150);
    expect(find.text('Goal complete!'), findsOneWidget);
    expect(find.text('A trip to the park'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
