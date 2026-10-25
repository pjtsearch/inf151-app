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
  SharedPreferences.setMockInitialValues({});
  await ChildStorage().save([const Child(id: 'emma', name: 'Emma')]);
  await GoalStorage().save([_goal()]);
  await tester.pumpWidget(const GoalApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Print punch card'));
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
    expect(screen.goal.id, 'reading');
    expect(screen.childName, 'Emma');

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
        home: PrintPreviewPage(goal: _goal(), childName: 'Emma'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Print').hitTestable(), findsOneWidget);
    expect(find.text('Paper size'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
