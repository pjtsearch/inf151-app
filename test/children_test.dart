import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/goal_sort.dart';
import 'package:inf151_app/screens/manage_children_page.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:inf151_app/widgets/children_chips.dart';
import 'package:inf151_app/widgets/child_profile_card.dart';
import 'package:inf151_app/widgets/goal_card.dart';
import 'package:inf151_app/widgets/goal_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _alex = Child(id: 'alex', name: 'Alex');
const _sam = Child(id: 'sam', name: 'Sam');
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6XcAAAAASUVORK5CYII=',
);

Goal _goal(String id, String childId, {bool past = false}) => Goal(
  id: id,
  childId: childId,
  title: id,
  frequency: 1,
  frequencyUnit: FrequencyUnit.day,
  duration: 1,
  durationUnit: DurationUnit.week,
  startDate: DateUtils.dateOnly(
    DateTime.now(),
  ).subtract(Duration(days: past ? 30 : 0)),
);

Future<void> _seed({
  List<Child> children = const [_alex, _sam],
  List<Goal> goals = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  await ChildStorage().save(children);
  await GoalStorage().save(goals);
}

Future<void> _showApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const GoalApp());
  await tester.pumpAndSettle();
}

Finder _chip(String name) => find.widgetWithText(ChoiceChip, name);
Finder _profile(String name) => find.widgetWithText(ChildProfileCard, name);
Finder _formChip(String name) =>
    find.descendant(of: find.byType(GoalFormSheet), matching: _chip(name));

Future<void> _saveGoal(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save goal'));
  await tester.tap(find.text('Save goal'));
  await tester.pumpAndSettle();
}

Future<void> _chooseSort(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Sort goals'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckedPopupMenuItem<GoalSort>, label));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'sort menu changes the order and remembers the field and direction',
    (tester) async {
      await _seed(
        goals: [
          _goal(
            'A',
            'alex',
          ).copyWith(duration: 1, createdAt: DateTime(2025, 1, 3)),
          _goal(
            'B',
            'alex',
          ).copyWith(duration: 3, createdAt: DateTime(2025, 1, 1)),
          _goal(
            'C',
            'alex',
          ).copyWith(duration: 2, createdAt: DateTime(2025, 1, 2)),
        ],
      );
      await _showApp(tester);
      List<String> titles() => tester
          .widgetList<GoalCard>(find.byType(GoalCard))
          .map((card) => card.goal.title)
          .toList();
      expect(titles(), ['A', 'C', 'B']);
      await _chooseSort(tester, 'Descending · Latest first');
      expect(titles(), ['B', 'C', 'A']);
      await _chooseSort(tester, 'Creation date');
      expect(titles(), ['A', 'C', 'B']);
      await _chooseSort(tester, 'Ascending · Oldest first');
      expect(titles(), ['B', 'C', 'A']);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const GoalApp());
      await tester.pumpAndSettle();
      expect(titles(), ['B', 'C', 'A']);
      await _chooseSort(tester, 'Progress');
      await _chooseSort(tester, 'Descending · Highest progress first');
      final restored = await GoalStorage().loadSort();
      expect(restored.by, GoalSortBy.progress);
      expect(restored.descending, isTrue);
      await tester.tap(_chip('Alex'));
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sort goals'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckedPopupMenuItem<GoalSort>>(
              find.widgetWithText(CheckedPopupMenuItem<GoalSort>, 'Progress'),
            )
            .checked,
        isTrue,
      );
      expect(
        tester
            .widget<CheckedPopupMenuItem<GoalSort>>(
              find.widgetWithText(
                CheckedPopupMenuItem<GoalSort>,
                'Descending · Highest progress first',
              ),
            )
            .checked,
        isTrue,
      );
    },
  );

  testWidgets(
    'Goals app bar collapses and expands while its filters stay accessible',
    (tester) async {
      await _seed(
        goals: List.generate(12, (index) => _goal('Goal $index', 'alex')),
      );
      await _showApp(tester);
      final appBar = find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.byType(AppBar),
      );
      final expandedHeight = tester.getSize(appBar).height;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getSize(appBar).height, lessThan(expandedHeight));
      expect(find.byTooltip('Manage children').hitTestable(), findsOneWidget);
      expect(_chip('Alex').hitTestable(), findsOneWidget);
      expect(find.text('Past').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(TabBar)).dy,
        lessThanOrEqualTo(tester.getBottomLeft(appBar).dy),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(tester.getSize(appBar).height, expandedHeight);
    },
  );

  testWidgets('Children app bar collapses and expands with the grid', (
    tester,
  ) async {
    await _seed(
      children: List.generate(
        12,
        (index) => Child(id: '$index', name: 'Child $index'),
      ),
    );
    await _showApp(tester);
    await tester.tap(find.byTooltip('Manage children'));
    await tester.pumpAndSettle();
    final appBar = find.descendant(
      of: find.byType(SliverAppBar),
      matching: find.byType(AppBar),
    );
    final expandedHeight = tester.getSize(appBar).height;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getSize(appBar).height, lessThan(expandedHeight));
    expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(tester.getSize(appBar).height, expandedHeight);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage children'), findsOneWidget);
  });

  for (final past in [false, true]) {
    testWidgets(
      'swiping a ${past ? 'past' : 'active'} goal can be canceled or confirmed without deleting other goals',
      (tester) async {
        await _seed(
          goals: [
            _goal('Read together', 'alex', past: past),
            _goal('Sam’s goal', 'sam', past: past),
            _goal('Keep this goal', 'alex', past: past),
          ],
        );
        await _showApp(tester);
        await tester.tap(_chip('Alex'));
        if (past) await tester.tap(find.text('Past'));
        await tester.pumpAndSettle();

        final card = find.widgetWithText(GoalCard, 'Read together');
        await tester.drag(card, const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(find.text('Delete this goal?'), findsOneWidget);
        expect(await GoalStorage().load(), hasLength(3));
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        expect(await GoalStorage().load(), hasLength(3));

        await tester.drag(card, const Offset(-500, 0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Delete'),
          ),
        );
        await tester.pumpAndSettle();
        expect(card, findsNothing);
        expect(find.text('Keep this goal'), findsOneWidget);
        expect(tester.widget<ChoiceChip>(_chip('Alex')).selected, isTrue);
        expect((await GoalStorage().load()).map((goal) => goal.id), [
          'Sam’s goal',
          'Keep this goal',
        ]);
        expect(await ChildStorage().load(), hasLength(2));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(const GoalApp());
        await tester.pumpAndSettle();
        if (past) {
          await tester.tap(find.text('Past'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Read together'), findsNothing);
        expect(find.text('Sam’s goal'), findsOneWidget);
        expect(find.text('Keep this goal'), findsOneWidget);
      },
    );
  }

  test('child names and optional photos survive a storage reload', () async {
    await _seed(
      children: [
        _alex,
        Child(id: 'sam', name: 'Sam', photoBytes: _photo),
      ],
    );

    final children = await ChildStorage().load();
    expect(children.map((child) => child.name), ['Alex', 'Sam']);
    expect(children.first.photoBytes, isNull);
    expect(children.last.photoBytes, _photo);
  });

  testWidgets(
    'child filters combine with Active and Past and show names on cards',
    (tester) async {
      await _seed(
        goals: [
          _goal('Alex active', 'alex'),
          _goal('Sam active', 'sam'),
          _goal('Alex past', 'alex', past: true),
          _goal('Sam past', 'sam', past: true),
        ],
      );
      await _showApp(tester);
      expect(tester.widget<ChoiceChip>(_chip('All children')).selected, isTrue);
      expect(find.byType(GoalCard), findsNWidgets(2));
      expect(
        find.descendant(of: find.byType(GoalCard), matching: find.text('Alex')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(GoalCard), matching: find.text('Sam')),
        findsOneWidget,
      );

      await tester.tap(_chip('Alex'));
      await tester.pumpAndSettle();
      expect(find.text('Alex active'), findsOneWidget);
      expect(find.text('Sam active'), findsNothing);

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      expect(find.text('Alex past'), findsOneWidget);
      expect(find.text('Sam past'), findsNothing);
      await tester.tap(_chip('Sam'));
      await tester.pumpAndSettle();
      expect(find.text('Alex past'), findsNothing);
      expect(find.text('Sam past'), findsOneWidget);

      await tester.tap(_chip('All children'));
      await tester.pumpAndSettle();
      expect(find.byType(GoalCard), findsNWidgets(2));
    },
  );

  testWidgets(
    'adding a goal defaults to the filtered child and allows changing it',
    (tester) async {
      await _seed();
      await _showApp(tester);
      await tester.tap(_chip('Sam'));
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_formChip('Sam')).selected, isTrue);
      expect(_formChip('All children'), findsNothing);

      await tester.tap(_formChip('Alex'));
      await tester.enterText(find.byType(TextFormField).first, 'Read a story');
      await _saveGoal(tester);
      expect((await GoalStorage().load()).single.childId, 'alex');
      expect(find.text('Read a story'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(_chip('Alex')).selected, isTrue);
    },
  );

  testWidgets(
    'All children requires a single child selection before saving a goal',
    (tester) async {
      await _seed();
      await _showApp(tester);
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_formChip('Alex')).selected, isFalse);
      expect(tester.widget<ChoiceChip>(_formChip('Sam')).selected, isFalse);
      await tester.enterText(find.byType(TextFormField).first, 'Tidy up');
      await _saveGoal(tester);
      expect(find.text('Select a child for this goal'), findsOneWidget);
      expect(await GoalStorage().load(), isEmpty);

      await tester.ensureVisible(_formChip('Sam'));
      await tester.tap(_formChip('Sam'));
      await _saveGoal(tester);
      expect((await GoalStorage().load()).single.childId, 'sam');
    },
  );

  testWidgets(
    'copying defaults to the filtered child and can assign the copy to another child',
    (tester) async {
      await _seed(goals: [_goal('Read a book', 'sam', past: true)]);
      await _showApp(tester);
      await tester.tap(_chip('Sam'));
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Make a copy'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_formChip('Sam')).selected, isTrue);
      await tester.tap(_formChip('Alex'));
      await _saveGoal(tester);

      final goals = await GoalStorage().load();
      expect(goals, hasLength(2));
      expect(goals.first.childId, 'sam');
      expect(goals.first.completedTasks, 0);
      expect(goals.last.childId, 'alex');
      expect(goals.last.id, isNot(goals.first.id));
      expect(goals.last.completedTasks, 0);
      expect(goals.last.createdAt.isAfter(goals.first.createdAt), isTrue);
      expect(find.text('Read a book'), findsOneWidget);
    },
  );

  testWidgets(
    'a first child can be added inside a goal form without losing its draft',
    (tester) async {
      await _seed(children: []);
      await _showApp(tester);
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Brush teeth');
      await tester.tap(
        find.descendant(
          of: find.byType(GoalFormSheet),
          matching: find.widgetWithText(ActionChip, 'Add child'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Taylor');
      await tester.tap(find.text('Save child'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_formChip('Taylor')).selected, isTrue);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Brush teeth',
      );
      await _saveGoal(tester);
      final child = (await ChildStorage().load()).single;
      expect((await GoalStorage().load()).single.childId, child.id);
    },
  );

  testWidgets(
    'a picked photo is stored independently of the temporary source file and appears on the chip',
    (tester) async {
      await _seed(children: []);
      final file = (await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'child-photo-test-',
        );
        final file = File('${directory.path}/photo.png');
        await file.writeAsBytes(_photo);
        return file;
      }))!;
      addTearDown(() => file.parent.delete(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'pickImage');
        return file.path;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await _showApp(tester);
      await tester.tap(find.text('Add child'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Alex');
      await tester.runAsync(() async {
        await tester.tap(find.text('Add photo (optional)'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Change photo'), findsOneWidget);
      await tester.tap(find.text('Save child'));
      await tester.pumpAndSettle();
      await tester.runAsync(file.delete);

      expect((await ChildStorage().load()).single.photoBytes, _photo);
      expect(
        find.descendant(of: _chip('Alex'), matching: find.byType(Image)),
        findsOneWidget,
      );
    },
  );

  testWidgets('the children bar scrolls horizontally to Add child', (
    tester,
  ) async {
    await _seed(
      children: List.generate(
        12,
        (index) => Child(id: '$index', name: 'Child $index'),
      ),
    );
    await _showApp(tester);
    final bar = find.byType(ChildrenChips);
    await tester.drag(bar, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Add child'));
    await tester.pumpAndSettle();
    expect(find.text('Save child'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await ChildStorage().load(), hasLength(12));
  });

  testWidgets(
    'editing a child updates their profile everywhere and keeps their goals and filter',
    (tester) async {
      await _seed(
        children: [
          Child(id: 'alex', name: 'Alex', photoBytes: _photo),
          _sam,
        ],
        goals: [_goal('Read together', 'alex')],
      );
      await _showApp(tester);
      await tester.tap(_chip('Alex'));
      await tester.tap(find.byTooltip('Manage children'));
      await tester.pumpAndSettle();
      expect(_profile('Alex'), findsOneWidget);
      expect(_profile('Sam'), findsOneWidget);
      expect(find.byType(GoalCard), findsNothing);

      await tester.tap(_profile('Alex'));
      await tester.pumpAndSettle();
      expect(find.text('Edit child'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Alex',
      );
      expect(find.text('Change photo'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  Alexandra  ');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(_profile('Alexandra'), findsOneWidget);

      final children = await ChildStorage().load();
      expect(children, hasLength(2));
      expect(children.first.id, 'alex');
      expect(children.first.name, 'Alexandra');
      expect(children.first.photoBytes, _photo);
      expect(children.last.name, 'Sam');
      expect((await GoalStorage().load()).single.childId, 'alex');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_chip('Alexandra')).selected, isTrue);
      expect(
        find.descendant(
          of: find.byType(GoalCard),
          matching: find.text('Alexandra'),
        ),
        findsOneWidget,
      );
      expect(find.text('Read together'), findsOneWidget);
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(_formChip('Alexandra')).selected,
        isTrue,
      );
    },
  );

  testWidgets('a child can be added from the empty management page', (
    tester,
  ) async {
    await _seed(children: []);
    await _showApp(tester);
    await tester.tap(find.byTooltip('Manage children'));
    await tester.pumpAndSettle();
    expect(find.byType(ChildProfileCard), findsNothing);
    await tester.tap(find.text('Add child'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Taylor');
    await tester.tap(find.text('Save child'));
    await tester.pumpAndSettle();
    expect(_profile('Taylor'), findsOneWidget);
    expect(find.byType(ChildProfileCard), findsOneWidget);
    expect((await ChildStorage().load()).single.name, 'Taylor');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_chip('Taylor'), findsOneWidget);
    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(_formChip('Taylor')).selected, isTrue);
  });

  testWidgets(
    'an edited photo can be removed and canceled edits leave the saved profile intact',
    (tester) async {
      await _seed(
        children: [Child(id: 'alex', name: 'Alex', photoBytes: _photo)],
      );
      await _showApp(tester);
      await tester.tap(find.byTooltip('Manage children'));
      await tester.pumpAndSettle();
      await tester.tap(_profile('Alex'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  ');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Discarded name');
      await tester.tap(find.text('Remove photo'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      var child = (await ChildStorage().load()).single;
      expect(child.name, 'Alex');
      expect(child.photoBytes, _photo);

      await tester.tap(_profile('Alex'));
      await tester.pumpAndSettle();
      expect(find.text('Change photo'), findsOneWidget);
      await tester.tap(find.text('Remove photo'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      child = (await ChildStorage().load()).single;
      expect(child.id, 'alex');
      expect(child.name, 'Alex');
      expect(child.photoBytes, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _chip('Alex'), matching: find.byType(Image)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the grid shows photos and active goal counts and saves a dragged order everywhere',
    (tester) async {
      const taylor = Child(id: 'taylor', name: 'Taylor');
      await _seed(
        children: [
          Child(id: 'alex', name: 'Alex', photoBytes: _photo),
          _sam,
          taylor,
        ],
        goals: [
          _goal('Read', 'alex'),
          _goal('Walk', 'alex'),
          _goal('Old', 'alex', past: true),
        ],
      );
      await _showApp(tester);
      await tester.tap(_chip('Sam'));
      await tester.tap(find.byTooltip('Manage children'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _profile('Alex'), matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _profile('Alex'),
          matching: find.text('2 active goals'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _profile('Sam'),
          matching: find.text('0 active goals'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(_profile('Alex')).dy,
        tester.getTopLeft(_profile('Sam')).dy,
      );
      expect(
        tester.getTopLeft(_profile('Taylor')).dy,
        greaterThan(tester.getTopLeft(_profile('Alex')).dy),
      );

      final target = tester.getCenter(_profile('Alex'));
      final gesture = await tester.startGesture(
        tester.getCenter(_profile('Taylor')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect((await ChildStorage().load()).map((child) => child.id), [
        'taylor',
        'alex',
        'sam',
      ]);
      expect(
        tester
            .widgetList<ChildProfileCard>(find.byType(ChildProfileCard))
            .map((card) => card.child.id),
        ['taylor', 'alex', 'sam'],
      );

      // Editing after a reorder keeps that order and the stable goal ownership.
      await tester.tap(_profile('Alex'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Alexandra');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect((await ChildStorage().load()).map((child) => child.id), [
        'taylor',
        'alex',
        'sam',
      ]);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_chip('Sam')).selected, isTrue);
      expect(
        tester
            .widget<ChildrenChips>(find.byType(ChildrenChips))
            .children
            .map((child) => child.id),
        ['taylor', 'alex', 'sam'],
      );
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      final formBar = find.descendant(
        of: find.byType(GoalFormSheet),
        matching: find.byType(ChildrenChips),
      );
      expect(
        tester.widget<ChildrenChips>(formBar).children.map((child) => child.id),
        ['taylor', 'alex', 'sam'],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const GoalApp());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChildrenChips>(find.byType(ChildrenChips))
            .children
            .map((child) => child.name),
        ['Taylor', 'Alexandra', 'Sam'],
      );
    },
  );

  testWidgets('a failed reorder restores the grid order', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageChildrenPage(
          children: const [_alex, _sam],
          onSave: (_) async {},
          onReorder: (_) async => throw StateError('Storage unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = tester.getCenter(_profile('Sam'));
    final gesture = await tester.startGesture(
      tester.getCenter(_profile('Alex')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save child order. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<ChildProfileCard>(find.byType(ChildProfileCard))
          .map((card) => card.child.id),
      ['alex', 'sam'],
    );
  });
}
