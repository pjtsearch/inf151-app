import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';
import 'package:inf151_app/models/child.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/screens/print_preview_page.dart';
import 'package:inf151_app/services/child_storage.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:inf151_app/services/punch_card_pdf.dart';
import 'package:inf151_app/widgets/goal_card.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PreviewRaster extends PdfRaster {
  _PreviewRaster() : super(1, 1, Uint8List.fromList([255, 255, 255, 255]));

  @override
  Future<Uint8List> toPng() async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7WsAAAAASUVORK5CYII=',
  );
}

class _TestPrinting extends PrintingPlatform {
  final previewDocuments = <Uint8List>[];
  Uint8List? printedDocument;
  PdfPageFormat? printedFormat;
  bool? dynamicLayout;
  bool failPrint = false;

  @override
  Future<PrintingInfo> info() async =>
      const PrintingInfo(canPrint: true, canRaster: true);

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    previewDocuments.add(document);
    yield _PreviewRaster();
  }

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    if (failPrint) throw StateError('Printer unavailable');
    printedFormat = format;
    this.dynamicLayout = dynamicLayout;
    printedDocument = await onLayout(format);
    return false; // Simulate closing the system dialog without printing.
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Goal _goal() => Goal(
  id: 'reading',
  childId: 'emma',
  title: 'Read for 20 minutes',
  frequency: 1,
  frequencyUnit: FrequencyUnit.day,
  duration: 14,
  durationUnit: DurationUnit.day,
  startDate: DateUtils.dateOnly(DateTime.now()),
  reward: const FreeTextReward('A trip to the park'),
);

Future<void> _openPreview(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'onboarding_seen': true});
  await ChildStorage().save([const Child(id: 'emma', name: 'Emma')]);
  await GoalStorage().save([_goal()]);
  await tester.pumpWidget(const GoalApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Print punch card'));
  await tester.pumpAndSettle();
}

Future<void> _showSelectableGoals(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'onboarding_seen': true});
  await ChildStorage().save([
    const Child(id: 'emma', name: 'Emma'),
    const Child(id: 'alex', name: 'Alex'),
  ]);
  await GoalStorage().save([
    _goal(),
    _goal().copyWith(id: 'tidy', childId: 'alex', title: 'Tidy the room'),
    _goal().copyWith(id: 'walk', title: 'Take a walk'),
  ]);
  await tester.pumpWidget(const GoalApp());
  await tester.pumpAndSettle();
}

void main() {
  late _TestPrinting printing;

  setUp(() {
    final original = PrintingPlatform.instance;
    printing = _TestPrinting();
    PrintingPlatform.instance = printing;
    addTearDown(() => PrintingPlatform.instance = original);
  });

  testWidgets(
    'long press and tap select goals for a single shared print preview',
    (tester) async {
      await _showSelectableGoals(tester);
      await tester.longPress(find.text('Read for 20 minutes'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsWidgets);
      expect(find.text('Scan card'), findsNothing);
      expect(find.text('Add goal'), findsNothing);
      expect(find.byTooltip('Goal options'), findsNothing);

      await tester.tap(find.text('Tidy the room'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsWidgets);
      await tester.tap(find.text('Print selected (2)'));
      await tester.pumpAndSettle();
      final preview = tester.widget<PrintPreviewPage>(
        find.byType(PrintPreviewPage),
      );
      expect(
        preview.jobs.map((job) => job.goal.id),
        unorderedEquals(['reading', 'tidy']),
      );
      expect(
        {for (final job in preview.jobs) job.goal.id: job.childName},
        {'reading': 'Emma', 'tidy': 'Alex'},
      );
      final previewBytes = printing.previewDocuments.last;
      expect(
        RegExp(r'/MediaBox\b').allMatches(latin1.decode(previewBytes)),
        hasLength(1),
      );
      await tester.tap(find.text('Print'));
      await tester.pumpAndSettle();
      expect(printing.printedDocument, same(previewBytes));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsWidgets);
      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Scan card'), findsOneWidget);
      expect(find.text('Add goal'), findsOneWidget);
    },
  );

  testWidgets(
    'selection survives filters, can select all, and back cancels it',
    (tester) async {
      await _showSelectableGoals(tester);
      await tester.longPress(find.text('Read for 20 minutes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Alex'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsWidgets);
      expect(find.text('Read for 20 minutes'), findsNothing);
      await tester.tap(find.text('Tidy the room'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsWidgets);
      await tester.drag(
        find.widgetWithText(GoalCard, 'Tidy the room'),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this goal?'), findsNothing);
      expect(await GoalStorage().load(), hasLength(3));

      await tester.tap(find.widgetWithText(ChoiceChip, 'All children'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all visible goals'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Scan card'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    },
  );

  testWidgets('unchecking the last selected goal returns to the normal list', (
    tester,
  ) async {
    await _showSelectableGoals(tester);
    await tester.longPress(find.text('Read for 20 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(GoalCard, 'Read for 20 minutes'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Print selected (1)'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('Print punch card'), findsNWidgets(3));
  });

  testWidgets(
    'bulk delete can be canceled without changing goals or selection',
    (tester) async {
      await _showSelectableGoals(tester);
      expect(find.byTooltip('Delete selected goals'), findsNothing);
      await tester.longPress(find.text('Read for 20 minutes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tidy the room'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byTooltip('Delete selected goals')).dx,
        greaterThan(
          tester.getCenter(find.byTooltip('Select all visible goals')).dx,
        ),
      );
      await tester.tap(find.byTooltip('Delete selected goals'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 goals?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsWidgets);
      expect(await GoalStorage().load(), hasLength(3));
      expect(find.text('Read for 20 minutes'), findsOneWidget);
      expect(find.text('Tidy the room'), findsOneWidget);
    },
  );

  testWidgets(
    'bulk delete removes selected goals across filters and persists',
    (tester) async {
      await _showSelectableGoals(tester);
      await tester.longPress(find.text('Read for 20 minutes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Alex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tidy the room'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete selected goals'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect((await GoalStorage().load()).map((goal) => goal.id), ['walk']);
      expect(find.byTooltip('Delete selected goals'), findsNothing);
      expect(find.text('Add goal'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All children'));
      await tester.pumpAndSettle();
      expect(find.text('Take a walk'), findsOneWidget);
      expect(find.text('Read for 20 minutes'), findsNothing);
      expect(find.text('Tidy the room'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const GoalApp());
      await tester.pumpAndSettle();
      expect(find.text('Take a walk'), findsOneWidget);
      expect(find.byType(GoalCard), findsOneWidget);
    },
  );

  testWidgets('opens a preview before printing and uses the selected paper', (
    tester,
  ) async {
    await _openPreview(tester);
    expect(find.text('Print preview'), findsOneWidget);
    expect(find.text('Paper size'), findsOneWidget);
    expect(printing.printedDocument, isNull);
    expect(printing.previewDocuments, isNotEmpty);
    expect(
      tester.widget<PdfPreviewCustom>(find.byType(PdfPreviewCustom)).pageFormat,
      PdfPageFormat.letter,
    );
    final screen = tester.widget<PrintPreviewPage>(
      find.byType(PrintPreviewPage),
    );
    expect(screen.jobs.single.goal.id, 'reading');
    expect(screen.jobs.single.childName, 'Emma');

    for (final (label, format) in [
      ('A4 (210 × 297 mm)', PdfPageFormat.a4),
      ('Legal (8.5 × 14 in)', PdfPageFormat.legal),
      ('A5 (148 × 210 mm)', PdfPageFormat.a5),
    ]) {
      await tester.tap(find.textContaining('×').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PdfPreviewCustom>(find.byType(PdfPreviewCustom))
            .pageFormat,
        format,
      );
    }
    final previewBytes = printing.previewDocuments.last;
    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();
    expect(printing.printedFormat, PdfPageFormat.a5);
    expect(printing.printedDocument, same(previewBytes));
    expect(printing.dynamicLayout, isFalse);
    expect(find.text('Print preview'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Read for 20 minutes'), findsOneWidget);
  });

  testWidgets('print failures keep the preview available to retry', (
    tester,
  ) async {
    await _openPreview(tester);
    printing.failPrint = true;
    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();
    expect(find.text('Could not print. Please try again.'), findsOneWidget);
    expect(find.byType(PdfPreviewCustom), findsOneWidget);
    printing.failPrint = false;
    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();
    expect(printing.printedDocument, isNotNull);
  });

  testWidgets('preview controls fit a small screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: PrintPreviewPage(
          jobs: [PunchCardPrintJob(goal: _goal(), childName: 'Emma')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Print').hitTestable(), findsOneWidget);
    expect(find.text('Paper size'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
