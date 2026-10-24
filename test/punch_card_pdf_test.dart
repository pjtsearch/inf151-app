import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/services/punch_card_pdf.dart';

Goal _goal({
  int tasks = 14,
  GoalReward reward = const FreeTextReward('A trip to the park'),
}) => Goal(
  id: 'print-test',
  childId: 'alex',
  title: 'Brush teeth before bed',
  frequency: 1,
  frequencyUnit: FrequencyUnit.day,
  duration: tasks,
  durationUnit: DurationUnit.day,
  startDate: DateTime(2026, 10, 24),
  reward: reward,
);

String _pdfContents(Uint8List bytes) =>
    RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream')
        .allMatches(latin1.decode(bytes))
        .map((match) {
          final stream = match.group(1)!;
          try {
            return latin1.decode(zlib.decode(latin1.encode(stream)));
          } on FormatException {
            return stream;
          }
        })
        .join('\n');

int _printedHoles(Uint8List bytes) {
  // A stroked ellipse has a move followed by four cubic curves. Card borders
  // contain straight lines, so they are excluded from this count.
  const number = r'-?\d+(?:\.\d+)?\s+';
  return RegExp(
    '(?:$number){2}m\\s+(?:(?:$number){6}c\\s+){4}S',
  ).allMatches(_pdfContents(bytes)).length;
}

void main() {
  test(
    'a reward and child name leave room for all fourteen printed holes',
    () async {
      final bytes = await buildPunchCardPdf(_goal(), childName: 'Alex');
      expect(_printedHoles(bytes), 14);
      expect(_pdfContents(bytes), contains('(Reward:)'));
    },
  );

  test(
    'long titles, child names, and Etsy rewards keep both punch rows',
    () async {
      final goal =
          _goal(
            reward: const EtsyProductReward(
              listingId: '1',
              title:
                  'Personalized handmade wooden rainbow puzzle with custom engraving',
              url: 'https://example.com/reward',
            ),
          ).copyWith(
            title:
                'Put all of the toys away and tidy the bedroom before dinner',
          );
      final bytes = await buildPunchCardPdf(
        goal,
        childName: 'Alexandra Catherine Montgomery',
      );
      expect(_printedHoles(bytes), 14);
      expect(_pdfContents(bytes), contains('(Reward:)'));
    },
  );

  test(
    'full, partial, and multiple pages print the exact number of punches',
    () async {
      for (final tasks in [1, 7, 8, 14, 15, 113]) {
        final bytes = await buildPunchCardPdf(
          _goal(tasks: tasks),
          childName: 'Alex',
        );
        expect(_printedHoles(bytes), tasks, reason: '$tasks tasks');
      }
    },
  );

  test('cards without rewards or child names still print both rows', () async {
    final bytes = await buildPunchCardPdf(
      _goal(reward: const FreeTextReward('')),
    );
    expect(_printedHoles(bytes), 14);
  });
}
