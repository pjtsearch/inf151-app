import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/child_color.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:inf151_app/widgets/child_profile_card.dart';
import 'package:inf151_app/widgets/goal_card.dart';
import 'package:inf151_app/widgets/goal_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

Future<void> _showApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const GoalApp());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saved colors survive storage and older profiles receive a default',
    () async {
      SharedPreferences.setMockInitialValues({
        'children': jsonEncode([
          {'id': 'old', 'name': 'Old profile'},
          {'id': 'unknown', 'name': 'Unknown color', 'color': 'unknown'},
        ]),
      });
      final storage = ChildStorage();
      final legacy = await storage.load();
      expect(legacy, hasLength(2));
      expect(legacy.every((child) => child.color == ChildColor.blue), isTrue);

      await storage.save([
        for (final color in ChildColor.values)
          Child(id: color.name, name: color.label, color: color),
      ]);
      expect(
        (await storage.load()).map((child) => child.color),
        ChildColor.values,
      );
    },
  );

  testWidgets(
    'a new child can choose from eight colors and keeps it after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _showApp(tester);
      await tester.tap(find.text('Add child'));
      await tester.pumpAndSettle();
      expect(find.text('Chip color'), findsNothing);
      for (final color in ChildColor.values) {
        expect(find.byTooltip(color.label), findsOneWidget);
        expect(find.text(color.label), findsNothing);
      }
      await tester.enterText(find.byType(TextFormField), 'Alex');
      await tester.tap(find.byTooltip('Purple'));
      await tester.ensureVisible(find.text('Save child'));
      await tester.tap(find.text('Save child'));
      await tester.pumpAndSettle();
      expect((await ChildStorage().load()).single.color, ChildColor.purple);
      final chip = tester.widget<ChoiceChip>(_chip('Alex'));
      expect(chip.backgroundColor, ChildColor.purple.background);
      expect(chip.selectedColor, ChildColor.purple.background);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const GoalApp());
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(_chip('Alex')).backgroundColor,
        ChildColor.purple.background,
      );
    },
  );

  testWidgets('editing color updates filters, goal badges, and goal forms', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await ChildStorage().save([
      const Child(id: 'alex', name: 'Alex', color: ChildColor.green),
    ]);
    await GoalStorage().save([
      Goal(
        id: 'read',
        childId: 'alex',
        title: 'Read a book',
        frequency: 1,
        frequencyUnit: FrequencyUnit.day,
        duration: 1,
        durationUnit: DurationUnit.week,
        startDate: DateUtils.dateOnly(DateTime.now()),
      ),
    ]);
    await _showApp(tester);
    await tester.tap(find.byTooltip('Manage children'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChildProfileCard));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byTooltip('Green'),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(find.byTooltip('Pink'));
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    var chip = tester.widget<ChoiceChip>(_chip('Alex'));
    expect(chip.selected, isFalse);
    expect(chip.backgroundColor, ChildColor.pink.background);
    await tester.tap(_chip('Alex'));
    await tester.pumpAndSettle();
    chip = tester.widget<ChoiceChip>(_chip('Alex'));
    expect(chip.selected, isTrue);
    expect(chip.selectedColor, ChildColor.pink.background);
    expect(chip.showCheckmark, isTrue);
    expect(chip.side, BorderSide.none);

    final badge = find
        .ancestor(
          of: find.descendant(
            of: find.byType(GoalCard),
            matching: find.text('Alex'),
          ),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        )
        .first;
    expect(
      (tester.widget<Container>(badge).decoration! as BoxDecoration).color,
      ChildColor.pink.background,
    );
    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();
    final formChip = find.descendant(
      of: find.byType(GoalFormSheet),
      matching: _chip('Alex'),
    );
    expect(
      tester.widget<ChoiceChip>(formChip).selectedColor,
      ChildColor.pink.background,
    );
  });
}
