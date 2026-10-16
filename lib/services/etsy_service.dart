import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EtsyListing {
  const EtsyListing({required this.id, required this.title, required this.description, required this.price, required this.url});
  final String id;
  final String title;
  final String description;
  final String price;
  final String url;
}

class EtsyService {
  static const _root = 'https://api.etsy.com/v3/application';
  static DateTime _nextRequest = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<void> _requestQueue = Future<void>.value();
  static Future<void> _waitTurn() {
    final turn = _requestQueue.then((_) async {
      final wait = _nextRequest.difference(DateTime.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _nextRequest = DateTime.now().add(const Duration(milliseconds: 220));
    });
    _requestQueue = turn;
    return turn;
  }

  Map<String, String> get _headers {
    final key = dotenv.env['ETSY_API_KEY']?.trim() ?? '';
    if (key.isEmpty) throw Exception('ETSY_API_KEY is missing from .env.local');
    return {'x-api-key': key};
  }

  Future<(List<EtsyListing>, bool)> search(String keyword, int offset) async {
    await _waitTurn();
    final uri = Uri.parse('$_root/listings/active').replace(queryParameters: {
      'keywords': keyword, 'is_safe': 'true', 'currency': 'USD',
      'buyer_country': 'US', 'sort_on': 'score', 'limit': '24', 'offset': '$offset',
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('Etsy search failed (${response.statusCode})');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final listings = results.map((item) {
      final rawPrice = item['price'];
      var price = rawPrice?.toString() ?? '';
      if (rawPrice is Map<String, dynamic>) {
        final amount = num.tryParse('${rawPrice['amount']}');
        final divisor = num.tryParse('${rawPrice['divisor']}') ?? 1;
        price = amount == null ? '' : (amount / divisor).toStringAsFixed(2);
      }
      return EtsyListing(
        id: item['listing_id'].toString(), title: item['title'] as String? ?? '',
        description: item['description'] as String? ?? '', price: price,
        url: item['url'] as String? ?? 'https://www.etsy.com/listing/${item['listing_id']}',
      );
    }).toList();
    return (listings, results.length == 24);
  }

  Future<String?> imageUrl(String listingId) async {
    await _waitTurn();
    final response = await http.get(Uri.parse('$_root/listings/$listingId/images'), headers: _headers);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final images = body['results'] as List<dynamic>? ?? [];
    if (images.isEmpty) return null;
    final image = images.first as Map<String, dynamic>;
    return image['url_fullxfull'] as String? ?? image['url_570xN'] as String? ?? image['url_170x135'] as String?;
  }
}
