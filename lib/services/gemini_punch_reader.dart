import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<int> readPunchCount(String imagePath) async {
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
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'All of the holes on this punch card were originally white inside. '
                  'How many of the holes on this card have either been hole-punched or colored in black? '
                  'Make sure to look look carefully. Return just the number '
                  'by itself and nothing else.',
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
  if (count == null || count < 0) {
    throw const FormatException('Gemini did not return a valid number.');
  }
  return count;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
