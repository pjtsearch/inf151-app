// Use FlutterFire's platform test APIs without adding runtime dependencies.
// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/screens/goals_page.dart';
import 'package:inf151_app/screens/tutorials_page.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:inf151_app/services/goal_reminder_service.dart';
import 'package:inf151_app/widgets/children_chips.dart';
import 'package:inf151_app/widgets/goal_card.dart';
import 'package:inf151_app/widgets/goal_form_sheet.dart';
import 'package:onboarding_overlay/onboarding_overlay.dart';

class _Auth extends FirebaseAuthPlatform {
  late final _user = _User(this);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform get currentUser => _user;
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'parent',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

// Field paths are normally decoded on the native side of the channel.
class _FirestoreCodec extends PigeonCodec {
  const _FirestoreCodec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    if (type == 192) {
      return List.generate(readSize(buffer), (_) => readValue(buffer));
    }
    return super.readValueOfType(type, buffer);
  }
}

/// Serve fixture reads and record every write made by the real storage services.
class _Firestore {
  final documents = <String, Map<String, Object?>>{
    'parents/parent': {'childIds': <String>[], 'onboardingSeen': false},
  };
  final writes = <String, List<List<Object?>>>{};
  final metadata = InternalSnapshotMetadata(
    hasPendingWrites: false,
    isFromCache: false,
  );

  InternalDocumentSnapshot snapshot(String path) => InternalDocumentSnapshot(
    path: path,
    data: documents[path],
    metadata: metadata,
  );

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final method in [
      'documentReferenceGet',
      'queryGet',
      'documentReferenceSet',
      'documentReferenceUpdate',
      'documentReferenceDelete',
      'writeBatchCommit',
    ]) {
      messenger.setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.$method',
          const _FirestoreCodec(),
        ),
        (message) async {
          final args = message! as List<Object?>;
          if (method == 'documentReferenceGet') {
            return [snapshot((args[1]! as DocumentReferenceRequest).path)];
          }
          if (method == 'queryGet') {
            final path = args[1]! as String;
            return [
              InternalQuerySnapshot(
                documents: [
                  for (final key in documents.keys)
                    if (key.startsWith('$path/')) snapshot(key),
                ],
                documentChanges: [],
                metadata: metadata,
              ),
            ];
          }
          writes.putIfAbsent(method, () => []).add(args);
          if (method == 'documentReferenceSet') {
            final request = args[1]! as DocumentReferenceRequest;
            documents
                .putIfAbsent(request.path, () => {})
                .addAll(request.data!.cast<String, Object?>());
          }
          return [null];
        },
      );
    }
  }

  void expectOnlyCompletionSaved() {
    expect(writes.keys, ['documentReferenceSet']);
    for (final args in writes['documentReferenceSet']!) {
      final request = args[1]! as DocumentReferenceRequest;
      expect(request.path, 'parents/parent');
      expect(request.data, {'onboardingSeen': true});
    }
  }
}

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
  await tester.pumpWidget(
    MaterialApp(home: GoalsPage(reminderService: reminderService)),
  );
  await tester.pumpAndSettle();
}

bool _guideVisible(WidgetTester tester) =>
    tester.state<OnboardingState>(find.byType(Onboarding)).isVisible();

Future<void> _replayOnboarding(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Help'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Onboarding'));
  await tester.pumpAndSettle();
  expect(find.byType(TutorialsPage), findsNothing);
}

void _expectExamples(WidgetTester tester) {
  final children = tester
      .widget<ChildrenChips>(find.byType(ChildrenChips))
      .children;
  expect(children.map((child) => child.name), ['Alex', 'Sam']);
  expect(children.map((child) => child.color).toSet(), hasLength(2));
  final goals = tester
      .widgetList<GoalCard>(find.byType(GoalCard))
      .map((card) => card.goal);
  expect(goals, isNotEmpty);
  expect(goals.every((goal) => goal.id.startsWith('example-')), isTrue);
  expect(find.text('Read for 20 minutes'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Firestore firestore;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _Auth();
  });

  setUp(() {
    firestore = _Firestore()..install();
  });

  testWidgets('first launch previews examples, then remembers completion', (
    tester,
  ) async {
    final reminders = _Reminders();
    await _showApp(tester, reminderService: reminders);
    expect(find.text('Add your children'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    _expectExamples(tester);
    expect(await ChildStorage().load(), isEmpty);
    expect(await GoalStorage().load(), isEmpty);
    expect(firestore.writes, isEmpty);
    expect(reminders.snapshots.single, isEmpty);
    expect(reminders.childSnapshots.single, isEmpty);
    // Preview card actions must also be inert when invoked by keyboard shortcuts.
    final card = tester.widgetList<GoalCard>(find.byType(GoalCard)).first;
    card.onCopy();
    card.onDelete();
    card.onPrint();
    card.onLongPress?.call();
    await tester.pumpAndSettle();
    expect(find.byType(GoalsPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(GoalFormSheet), findsNothing);
    expect(firestore.writes, isEmpty);
    for (final title in [
      'Create a goal',
      'Print cards together',
      'Scan your progress',
    ]) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
    expect(find.byType(GoalCard), findsNothing);
    expect(find.text('No goals yet'), findsOneWidget);
    expect(await ChildStorage().load(), isEmpty);
    expect(await GoalStorage().load(), isEmpty);
    expect(await GoalStorage().loadOnboardingSeen(), isTrue);
    firestore.expectOnlyCompletionSaved();
    await tester.pumpWidget(const SizedBox.shrink());
    await _showApp(tester);
    expect(_guideVisible(tester), isFalse);
    expect(find.byType(GoalCard), findsNothing);
  });

  testWidgets('the top-bar Help button replaces the Account tutorials link', (
    tester,
  ) async {
    firestore.documents['parents/parent']!['onboardingSeen'] = true;
    await _showApp(tester, reminderService: _Reminders());

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Account & Settings'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Tutorials'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialsPage), findsOneWidget);
    expect(find.text('Onboarding'), findsOneWidget);
    await tester.tap(find.text('Adding a goal'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tap “Add goal” at the bottom of the screen.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_guideVisible(tester), isFalse);
  });

  testWidgets('replay, Skip, and Back discard examples without writes', (
    tester,
  ) async {
    firestore.documents['parents/parent']!['onboardingSeen'] = true;
    await _showApp(tester);
    for (final useBack in [false, true]) {
      await _replayOnboarding(tester);
      _expectExamples(tester);
      expect(find.text('1 of 4'), findsOneWidget);
      if (useBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Skip'));
      }
      await tester.pumpAndSettle();
      expect(_guideVisible(tester), isFalse);
      expect(find.byType(GoalCard), findsNothing);
      expect(
        tester.widget<ChildrenChips>(find.byType(ChildrenChips)).children,
        isEmpty,
      );
      firestore.expectOnlyCompletionSaved();
    }
  });

  for (final replay in [false, true]) {
    testWidgets(
      '${replay ? 'replay' : 'automatic onboarding'} preserves real data, filters, and reminders',
      (tester) async {
        final child = const Child(id: 'real-child', name: 'Taylor');
        final goal = Goal(
          id: 'real-goal',
          childId: child.id,
          title: 'My real goal',
          frequency: 1,
          frequencyUnit: FrequencyUnit.day,
          duration: 2,
          durationUnit: DurationUnit.week,
          startDate: DateUtils.dateOnly(DateTime.now()),
          completedTasks: 2,
        );
        firestore.documents['parents/parent']!.addAll({
          'childIds': [child.id],
          'onboardingSeen': replay,
        });
        firestore.documents['children/${child.id}'] = {
          ...child.toJson(),
          'parentIds': ['parent'],
        };
        firestore.documents['goals/${goal.id}'] = goal.toJson();
        expect((await ChildStorage().load()).single.toJson(), child.toJson());
        expect((await GoalStorage().load()).single.toJson(), goal.toJson());
        final reminders = _Reminders();
        await _showApp(tester, reminderService: reminders);
        if (replay) {
          await tester.tap(find.text('Taylor').first);
          await tester.tap(find.text('Past'));
          await tester.pumpAndSettle();
          await _replayOnboarding(tester);
        }
        _expectExamples(tester);
        expect(find.text(goal.title), findsNothing);
        expect((await GoalStorage().load()).single.toJson(), goal.toJson());
        expect((await ChildStorage().load()).single.toJson(), child.toJson());
        expect(firestore.writes, isEmpty);
        for (var step = 0; step < 2; step++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
        final onboarding = tester.widget<Onboarding>(find.byType(Onboarding));
        expect(onboarding.steps[2].focusNode.debugLabel, 'Onboarding goals');
        expect(onboarding.steps[2].focusNode.context, isNotNull);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(_guideVisible(tester), isFalse);
        expect(find.text('Read for 20 minutes'), findsNothing);
        final chips = tester.widget<ChildrenChips>(find.byType(ChildrenChips));
        expect(chips.children.single.toJson(), child.toJson());
        expect(chips.selectedChildId, replay ? child.id : null);
        if (replay) {
          expect(find.text(goal.title), findsNothing);
          expect(
            tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
            1,
          );
          await tester.tap(find.text('Active'));
          await tester.pumpAndSettle();
        }
        expect(find.text(goal.title), findsOneWidget);
        expect((await GoalStorage().load()).single.toJson(), goal.toJson());
        expect(reminders.snapshots, isNotEmpty);
        for (final snapshot in reminders.snapshots) {
          expect(snapshot.single.toJson(), goal.toJson());
        }
        for (final snapshot in reminders.childSnapshots) {
          expect(snapshot.single.toJson(), child.toJson());
        }
        firestore.expectOnlyCompletionSaved();

        if (replay) {
          await tester.tap(find.byTooltip('Make a copy').hitTestable());
          await tester.pumpAndSettle();
          expect(find.widgetWithText(GoalFormSheet, 'Copy goal'), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'tapping the selected child clears the filter and form selection',
    (tester) async {
      const child = Child(id: 'taylor', name: 'Taylor');
      const sibling = Child(id: 'sam', name: 'Sam');
      final goal = Goal(
        id: 'sam-goal',
        childId: sibling.id,
        title: 'Read a book',
        frequency: 1,
        frequencyUnit: FrequencyUnit.day,
        duration: 1,
        durationUnit: DurationUnit.week,
        startDate: DateUtils.dateOnly(DateTime.now()),
      );
      firestore.documents['parents/parent']!.addAll({
        'childIds': [child.id, sibling.id],
        'onboardingSeen': true,
      });
      for (final item in [child, sibling]) {
        firestore.documents['children/${item.id}'] = {
          ...item.toJson(),
          'parentIds': ['parent'],
        };
      }
      firestore.documents['goals/${goal.id}'] = goal.toJson();
      await _showApp(tester, reminderService: _Reminders());

      final chip = find.widgetWithText(ChoiceChip, child.name);
      final goalCard = find.widgetWithText(GoalCard, goal.title);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      expect(goalCard, findsNothing);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isFalse);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All children'))
            .selected,
        isTrue,
      );
      expect(goalCard, findsWidgets);

      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      final formChip = find.descendant(
        of: find.byType(GoalFormSheet),
        matching: chip,
      );
      await tester.tap(formChip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(formChip).selected, isTrue);
      await tester.tap(formChip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(formChip).selected, isFalse);
      final save = find.text('Save goal');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Select a child for this goal'), findsOneWidget);
    },
  );

  testWidgets('bottom sheets can be dismissed by their drag handles', (
    tester,
  ) async {
    firestore.documents['parents/parent']!['onboardingSeen'] = true;
    await _showApp(tester, reminderService: _Reminders());

    final sheet = find.byType(BottomSheet);
    final handle = find.descendant(
      of: sheet,
      matching: find.bySemanticsLabel('Dismiss'),
    );

    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();
    expect(handle, findsOneWidget);
    await tester.fling(handle, const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);

    await tester.tap(find.byTooltip('Manage children'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add child'));
    await tester.pumpAndSettle();
    expect(handle, findsOneWidget);
    await tester.fling(handle, const Offset(0, 120), 1500);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('guide fits a small screen in dark mode with large text', (
    tester,
  ) async {
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

  testWidgets('removing the page during onboarding removes the overlay', (
    tester,
  ) async {
    await _showApp(tester);
    expect(_guideVisible(tester), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: Text('Another screen')));
    await tester.pumpAndSettle();
    expect(find.text('Add your children'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(firestore.writes, isEmpty);
  });
}
