import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<int> readPunchCount(
  String imagePath, {
  required int originalHoleCount,
}) async {
  if (originalHoleCount < 1) {
    throw ArgumentError.value(
      originalHoleCount,
      'originalHoleCount',
      'Must be at least 1',
    );
  }
  final apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    throw StateError('Set GEMINI_API_KEY in .env.local first.');
  }

  final bytes = await File(imagePath).readAsBytes();
  final uri = Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/models/gemini-3.5-flash-lite:generateContent',
  );
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'This card originally had exactly $originalHoleCount outlined punch positions. '
                  'Count how many of those positions have been physically hole-punched through the paper '
                  'or deliberately filled in black. Uncompleted positions may contain printed text, '
                  'numbers, day or month labels, or hyphens on a light background. '
                  'Ignore skipped holes; the holes should be punched out from left to right, top to bottom order. '
                  'Printed labels and circle outlines do not count as completed punches. '
                  'Ignore decorative background artwork and the barcode. '
                  'Account for all $originalHoleCount original positions, including any whose printed '
                  'outline was removed by hole-punching. Return only one integer between 0 and '
                  '$originalHoleCount inclusive, with no other text.',
            },
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Encode(bytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0},
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Gemini request failed (${response.statusCode}): ${response.body}',
    );
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final candidates = decoded['candidates'] as List<dynamic>?;
  final parts = candidates?.firstOrNull?['content']?['parts'] as List<dynamic>?;
  final text = parts?.firstOrNull?['text'] as String?;
  final count = text == null ? null : int.tryParse(text.trim());
  if (count == null || count < 0 || count > originalHoleCount) {
    throw FormatException(
      'Gemini did not return a valid punch count between 0 and $originalHoleCount.',
    );
  }
  return count;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
