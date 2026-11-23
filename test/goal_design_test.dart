import 'package:flutter/material.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/widgets/goal_form_sheet.dart';
import 'package:inf151_app/widgets/goal_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/punch_card_design.dart';

void main() {
  final goal = Goal(
    id: 'test',
    childId: 'child',
    title: 'Read',
    frequency: 1,
    frequencyUnit: FrequencyUnit.day,
    duration: 7,
    durationUnit: DurationUnit.day,
    startDate: DateTime(2026, 11, 22),
  );

  test('all saved designs survive reload and progress updates', () {
    for (final design in PunchCardDesign.values) {
      final saved = Goal.fromJson(goal.copyWith(design: design).toJson());
      expect(saved.design, design);
      expect(saved.copyWith(completedTasks: 1).design, design);
    }
  });

  test('legacy and unknown themes fall back to classic', () {
    final json = goal.toJson()..remove('design');
    expect(Goal.fromJson(json).design, PunchCardDesign.classic);
    json['design'] = 'future-design';
    expect(Goal.fromJson(json).design, PunchCardDesign.classic);
  });
  testWidgets('creation saves the chosen theme', (tester) async {
    Goal? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<Goal>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => GoalFormSheet(
                    children: const [Child(id: 'child', name: 'Alex')],
                    onAddChild: () async => null,
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Read');
    final dropdown = find.byType(DropdownButtonFormField<PunchCardDesign>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean waves').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save goal'));
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(result?.design, PunchCardDesign.ocean);
  });

  testWidgets('dashboard shows every goal theme in light and dark modes', (
    tester,
  ) async {
    final backgrounds = <Color?>{};
    for (final brightness in Brightness.values) {
      backgrounds.clear();
      for (final design in PunchCardDesign.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: GoalCard(
                goal: goal.copyWith(design: design),
                isCreatedByMe: true,
                child: null,
                isPast: false,
                onCopy: () {},
                onDelete: () {},
                onPrint: () {},
              ),
            ),
          ),
        );
        expect(find.text(design.label), findsOneWidget);
        backgrounds.add(tester.widget<Card>(find.byType(Card)).color);
        expect(tester.takeException(), isNull);
      }
      expect(backgrounds.length, PunchCardDesign.values.length);
    }
  });
}
