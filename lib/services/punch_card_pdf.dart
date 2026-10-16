import 'dart:math' as math;
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as barcode;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/goal.dart';

const punchCardColumnsPerRow = 7;
const punchCardMaxRows = 2;
const _cardWidth = 85.6 * PdfPageFormat.mm;
const _cardHeight = 53.98 * PdfPageFormat.mm;
const _holeDiameter = 6.35 * PdfPageFormat.mm;
const _cardsPerPage = 8;
const _holeCellWidth = 9 * PdfPageFormat.mm;
const _holeCellGap = 2 * PdfPageFormat.mm;
const _holeSlotWidth = _holeCellWidth + _holeCellGap;
const _holeRowWidth =
    punchCardColumnsPerRow * _holeCellWidth +
    (punchCardColumnsPerRow - 1) * _holeCellGap;

List<String> punchCardColumnLabels(Goal goal, {int periodOffset = 0}) =>
    List<String>.generate(punchCardColumnsPerRow, (index) {
      return _periodLabel(goal, periodOffset + index);
    });

String? punchCardLabelForHole(Goal goal, int holeIndex) {
  if (goal.frequency <= 0 || holeIndex < 0 || holeIndex % goal.frequency != 0) {
    return null;
  }
  return _periodLabel(goal, holeIndex ~/ goal.frequency);
}

String _periodLabel(Goal goal, int period) => switch (goal.frequencyUnit) {
  FrequencyUnit.day => _weekdayLabel(
    goal.startDate.add(Duration(days: period)).weekday,
  ),
  FrequencyUnit.week => 'W${period + 1}',
  FrequencyUnit.month => _monthLabel(goal.startDate, period),
};

String _weekdayLabel(int weekday) =>
    const ['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'][weekday - 1];

String _monthLabel(DateTime startDate, int offset) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[(startDate.month - 1 + offset) % months.length];
}

int punchCountFor(Goal goal) => goal.totalTasks;

Future<Uint8List> buildPunchCardPdf(Goal goal) async {
  final totalHoles = punchCountFor(goal);
  if (totalHoles == 0) return pw.Document().save();

  final holesPerCard = punchCardColumnsPerRow * punchCardMaxRows;
  final cardCount = (totalHoles / holesPerCard).ceil();
  final document = pw.Document();

  for (var pageStart = 0; pageStart < cardCount; pageStart += _cardsPerPage) {
    final cardsOnPage = math.min(_cardsPerPage, cardCount - pageStart);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (_) => pw.Wrap(
          spacing: 8 * PdfPageFormat.mm,
          runSpacing: 6 * PdfPageFormat.mm,
          children: [
            for (
              var cardIndex = pageStart;
              cardIndex < pageStart + cardsOnPage;
              cardIndex++
            )
              _buildCard(goal, totalHoles, cardIndex, cardCount),
          ],
        ),
      ),
    );
  }
  return document.save();
}

pw.Widget _buildCard(Goal goal, int totalHoles, int cardIndex, int cardCount) {
  final holesPerCard = punchCardColumnsPerRow * punchCardMaxRows;
  final firstHole = cardIndex * holesPerCard;
  final holesOnCard = math.min(holesPerCard, totalHoles - firstHole);

  return pw.Container(
    width: _cardWidth,
    height: _cardHeight,
    padding: const pw.EdgeInsets.fromLTRB(
      4 * PdfPageFormat.mm,
      3 * PdfPageFormat.mm,
      4 * PdfPageFormat.mm,
      4 * PdfPageFormat.mm,
    ),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey600, width: 0.7),
      borderRadius: pw.BorderRadius.circular(2 * PdfPageFormat.mm),
    ),
    child: pw.Stack(
      children: [
        pw.Positioned(
          top: 0,
          right: 0,
          child: pw.BarcodeWidget(
            barcode: barcode.Barcode.dataMatrix(),
            data: '${goal.id}\t$firstHole\t${firstHole + holesOnCard - 1}',
            width: 7 * PdfPageFormat.mm,
            height: 7 * PdfPageFormat.mm,
            drawText: false,
          ),
        ),
        pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              goal.title,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 1 * PdfPageFormat.mm),
            pw.Text(
              '${goal.frequencyDescription}  |  ${goal.duration} ${goal.durationUnit.name}${goal.duration == 1 ? '' : 's'}  |  Card ${cardIndex + 1} of $cardCount',
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            if (goal.reward.label.isNotEmpty) ...[
              pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
              pw.Text(
                'Reward: ${goal.reward.label}',
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
            pw.SizedBox(height: 2 * PdfPageFormat.mm),
            pw.Spacer(flex: 3),
            for (var row = 0; row < punchCardMaxRows; row++)
              if (row * punchCardColumnsPerRow < holesOnCard) ...[
                _buildPunchRow(
                  goal,
                  firstHole + row * punchCardColumnsPerRow,
                  math.min(
                    punchCardColumnsPerRow,
                    holesOnCard - row * punchCardColumnsPerRow,
                  ),
                ),
                if (row < punchCardMaxRows - 1 &&
                    holesOnCard > (row + 1) * punchCardColumnsPerRow)
                  pw.SizedBox(height: 1 * PdfPageFormat.mm),
              ],
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildPunchRow(Goal goal, int firstHole, int holeCount) {
  return pw.Center(
    child: pw.SizedBox(
      width: _holeRowWidth,
      height: 12 * PdfPageFormat.mm,
      child: pw.Stack(
        children: [
          for (var hole = 0; hole < holeCount; hole++)
            pw.Positioned(
              left: hole * _holeSlotWidth,
              top: 0,
              child: pw.SizedBox(
                width: _holeCellWidth,
                height: 6 * PdfPageFormat.mm,
                child: pw.Center(
                  child: pw.Text(
                      switch (punchCardLabelForHole(
                    goal,
                    firstHole + hole,
                  )) {
                    final label? => label,
                    null => "-",
                  }, style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
              ),
            ),
          for (var hole = 0; hole < holeCount; hole++)
            pw.Positioned(
              left:
                  hole * _holeSlotWidth + (_holeCellWidth - _holeDiameter) / 2,
              top: 5.5 * PdfPageFormat.mm,
              child: _buildHole(),
            ),
        ],
      ),
    ),
  );
}

pw.Widget _buildHole() => pw.Container(
  width: _holeDiameter,
  height: _holeDiameter,
  decoration: pw.BoxDecoration(
    shape: pw.BoxShape.circle,
    border: pw.Border.all(color: PdfColors.black, width: 0.8),
  ),
);
