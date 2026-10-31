import 'dart:math' as math;
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as barcode;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/goal.dart';
import 'punch_card_background.dart';

const punchCardColumnsPerRow = 7;
const punchCardMaxRows = 2;
const _cardWidth = 85.6 * PdfPageFormat.mm;
const _cardHeight = 53.98 * PdfPageFormat.mm;
const _holeDiameter = 6.35 * PdfPageFormat.mm;
const _pageMargin = 10 * PdfPageFormat.mm;
const _cardSpacing = 8 * PdfPageFormat.mm;
const _cardRunSpacing = 6 * PdfPageFormat.mm;
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

class PunchCardPrintJob {
  const PunchCardPrintJob({required this.goal, this.childName});

  final Goal goal;
  final String? childName;
}

Future<Uint8List> buildPunchCardPdf(
  Goal goal, {
  String? childName,
  PdfPageFormat pageFormat = PdfPageFormat.letter,
}) => buildPunchCardsPdf([
  PunchCardPrintJob(goal: goal, childName: childName),
], pageFormat: pageFormat);

Future<Uint8List> buildPunchCardsPdf(
  List<PunchCardPrintJob> jobs, {
  PdfPageFormat pageFormat = PdfPageFormat.letter,
}) async {
  final cards = <pw.Widget>[];
  const holesPerCard = punchCardColumnsPerRow * punchCardMaxRows;
  for (final job in jobs) {
    final totalHoles = punchCountFor(job.goal);
    final cardCount = (totalHoles / holesPerCard).ceil();
    for (var cardIndex = 0; cardIndex < cardCount; cardIndex++) {
      cards.add(
        _buildCard(job.goal, totalHoles, cardIndex, cardCount, job.childName),
      );
    }
  }
  if (cards.isEmpty) return pw.Document().save();

  final availableWidth = pageFormat.width - 2 * _pageMargin;
  final availableHeight = pageFormat.height - 2 * _pageMargin;
  if (!availableWidth.isFinite ||
      !availableHeight.isFinite ||
      availableWidth < _cardWidth ||
      availableHeight < _cardHeight) {
    throw ArgumentError.value(pageFormat, 'pageFormat', 'Paper is too small');
  }
  final columns =
      ((availableWidth + _cardSpacing) / (_cardWidth + _cardSpacing)).floor();
  final rows =
      ((availableHeight + _cardRunSpacing) / (_cardHeight + _cardRunSpacing))
          .floor();
  final cardsPerPage = columns * rows;
  final document = pw.Document();

  for (var pageStart = 0; pageStart < cards.length; pageStart += cardsPerPage) {
    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(_pageMargin),
        build: (_) => pw.Wrap(
          spacing: _cardSpacing,
          runSpacing: _cardRunSpacing,
          children: cards.skip(pageStart).take(cardsPerPage).toList(),
        ),
      ),
    );
  }
  return document.save();
}

pw.Widget _buildCard(
  Goal goal,
  int totalHoles,
  int cardIndex,
  int cardCount,
  String? childName,
) {
  final holesPerCard = punchCardColumnsPerRow * punchCardMaxRows;
  final firstHole = cardIndex * holesPerCard;
  final holesOnCard = math.min(holesPerCard, totalHoles - firstHole);

  return pw.SizedBox(
    width: _cardWidth,
    height: _cardHeight,
    child: pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        pw.SvgImage(svg: punchCardBackgroundSvg, fit: pw.BoxFit.fill),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(
            4 * PdfPageFormat.mm,
            3 * PdfPageFormat.mm,
            4 * PdfPageFormat.mm,
            4 * PdfPageFormat.mm,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: pw.Transform.translate(
                  offset: const PdfPoint(0, -1 * PdfPageFormat.mm),
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(
                      left: 1 * PdfPageFormat.mm,
                    ),
                    child: _buildCardHeader(
                      goal,
                      childName,
                      firstHole,
                      holesOnCard,
                      cardIndex,
                      cardCount,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
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
        ),
      ],
    ),
  );
}

pw.Widget _buildCardHeader(
  Goal goal,
  String? childName,
  int firstHole,
  int holesOnCard,
  int cardIndex,
  int cardCount,
) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (childName != null) ...[
                pw.Text(
                  childName,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
              ],
              pw.Text(
                goal.title,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 2 * PdfPageFormat.mm),
        pw.BarcodeWidget(
          barcode: barcode.Barcode.dataMatrix(),
          data: '${goal.id}\t$firstHole\t${firstHole + holesOnCard - 1}',
          width: 11 * PdfPageFormat.mm,
          height: 11 * PdfPageFormat.mm,
          padding: const pw.EdgeInsets.all(0.5 * PdfPageFormat.mm),
          backgroundColor: PdfColors.white,
          drawText: false,
        ),
      ],
    ),
    pw.SizedBox(height: 0.75 * PdfPageFormat.mm),
    pw.Text(
      '${goal.frequencyDescription}  |  ${goal.duration} ${goal.durationUnit.name}${goal.duration == 1 ? '' : 's'}  |  Card ${cardIndex + 1} of $cardCount',
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
    ),
    if (goal.reward.label.isNotEmpty) ...[
      pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
      pw.Text(
        'Reward: ${goal.reward.label}',
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
      ),
    ],
  ],
);

pw.Widget _buildPunchRow(Goal goal, int firstHole, int holeCount) {
  return pw.Center(
    child: pw.SizedBox(
      width: _holeRowWidth,
      height: 12 * PdfPageFormat.mm,
      child: pw.Stack(
        children: [
          for (var hole = 0; hole < holeCount; hole++)
            pw.Positioned(
              left:
                  hole * _holeSlotWidth + (_holeCellWidth - _holeDiameter) / 2,
              top: 4.5 * PdfPageFormat.mm,
              child: _buildHole(
                punchCardLabelForHole(goal, firstHole + hole) ?? '-',
              ),
            ),
        ],
      ),
    ),
  );
}

pw.Widget _buildHole(String label) => pw.Container(
  width: _holeDiameter,
  height: _holeDiameter,
  alignment: pw.Alignment.center,
  padding: const pw.EdgeInsets.all(1.5),
  decoration: pw.BoxDecoration(
    color: PdfColors.white,
    shape: pw.BoxShape.circle,
    border: pw.Border.all(color: PdfColors.black, width: 0.8),
  ),
  child: pw.FittedBox(
    fit: pw.BoxFit.scaleDown,
    child: pw.Text(
      label,
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
    ),
  ),
);
