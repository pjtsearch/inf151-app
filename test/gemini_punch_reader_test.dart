import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inf151_app/services/gemini_punch_reader.dart';

void main() {
  late Directory directory;
  late File image;
  const imageBytes = [0xff, 0xd8, 0xff, 0xd9];

  setUp(() async {
    dotenv.loadFromString(envString: 'GEMINI_API_KEY=test-key');
    directory = await Directory.systemTemp.createTemp('goalpunch-reader-');
    image = await File('${directory.path}/card.jpg').writeAsBytes(imageBytes);
  });

  tearDown(() async {
    dotenv.clean();
    await directory.delete(recursive: true);
  });

  Future<int> readResponse(String response, {int originalHoleCount = 8}) {
    return http.runWithClient(
      () => readPunchCount(image.path, originalHoleCount: originalHoleCount),
      () => MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': response},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );
  }

  test(
    'sends the original count and distinguishes printed labels from punches',
    () async {
      await http.runWithClient(
        () => expectLater(
          readPunchCount(image.path, originalHoleCount: 8),
          completion(5),
        ),
        () => MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final parts = body['contents'][0]['parts'] as List<dynamic>;
          final prompt = parts[0]['text'] as String;
          expect(prompt, contains('originally had exactly 8'));
          expect(prompt, contains('physically hole-punched'));
          expect(prompt, contains('filled in black'));
          expect(prompt, contains('printed text'));
          expect(
            prompt,
            contains('Printed labels and circle outlines do not count'),
          );
          expect(prompt, contains('between 0 and 8 inclusive'));
          expect(parts[1]['inline_data']['data'], base64Encode(imageBytes));
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '5'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
    },
  );

  test(
    'accepts empty and fully completed cards, including partial cards',
    () async {
      expect(await readResponse('0'), 0);
      expect(await readResponse(' 8\n'), 8);
      expect(await readResponse('3', originalHoleCount: 3), 3);
    },
  );

  test(
    'rejects counts outside the original range and invalid responses',
    () async {
      for (final response in ['9', '-1', 'two', '2.5']) {
        await expectLater(readResponse(response), throwsFormatException);
      }
    },
  );

  test('requires a positive original hole count', () async {
    for (final count in [0, -1]) {
      await expectLater(
        readPunchCount(image.path, originalHoleCount: count),
        throwsArgumentError,
      );
    }
  });
}
