import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://10.0.2.2:8787';

  /// Public, QR/WhatsApp-friendly share page for a campaign.
  String shareUrl(int campaignId) => '$_baseUrl/share/$campaignId';

  Map<String, String> _headers({bool auth = false}) => {
        'Content-Type': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path, {bool auth = false}) async {
    final res = await _send(() =>
        _client.get(Uri.parse('$_baseUrl$path'), headers: _headers(auth: auth)));
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {bool auth = false}) async {
    final res = await _send(() =>
        _client.post(Uri.parse('$_baseUrl$path'),
            headers: _headers(auth: auth), body: jsonEncode(body)));
    return _decode(res);
  }

  /// Deletes a resource (pledge cancellation).
  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) async {
    final res = await _send(() =>
        _client.delete(Uri.parse('$_baseUrl$path'), headers: _headers(auth: auth)));
    return _decode(res);
  }

  /// Sets up (or updates) a monthly reminder pledge on a campaign.
  Future<Map<String, dynamic>> createPledge(
      int campaignId, int amountCents, int dayOfMonth) {
    return post('/api/campaigns/$campaignId/pledge',
        {'amountCents': amountCents, 'dayOfMonth': dayOfMonth},
        auth: true);
  }

  /// Cancels the monthly reminder on a campaign.
  Future<Map<String, dynamic>> cancelPledge(int campaignId) {
    return delete('/api/campaigns/$campaignId/pledge', auth: true);
  }

  /// Lists the current user's pledges.
  Future<List<dynamic>> getPledges() async {
    final res = await get('/api/pledges', auth: true);
    return res['pledges'] as List<dynamic>? ?? [];
  }

  /// Pays to promote a campaign to the top-5 (host only).
  Future<Map<String, dynamic>> promoteCampaign(int campaignId) {
    return post('/api/campaigns/$campaignId/promote', {}, auth: true);
  }

  /// Live state of the paid top-5 slots.
  Future<Map<String, dynamic>> getPromotionInfo() {
    return get('/api/promotions/info');
  }

  /// Admin view of promotion purchases.
  Future<List<dynamic>> getAdminPromotions() async {
    final res = await get('/api/admin/promotions', auth: true);
    return res['promotions'] as List<dynamic>? ?? [];
  }

  /// Browser-openable PDF receipt URL for a contribution (needs auth token).
  String receiptUrl(int contributionId) => '$_baseUrl/api/contributions/$contributionId/receipt?token=$token';

  /// Uploads a campaign logo (multipart). [bytes] is the raw image data.
  Future<Map<String, dynamic>> uploadLogo(
      int campaignId, List<int> bytes, String filename) async {
    final ext = filename.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
    final req = http.MultipartRequest(
        'POST', Uri.parse('$_baseUrl/api/campaigns/$campaignId/logo'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename, contentType: mime));
    final res = await _send(() =>
        req.send().then((s) => http.Response.fromStream(s)));
    return _decode(res);
  }

  /// Runs a request with a timeout and surfaces network failures as [ApiException]
  /// so the UI can show a clear message instead of hanging or silently failing.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 20));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Could not reach the server. Check your internet connection and try again.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 400) {
      final message = data['error'] is String
          ? data['error'] as String
          : 'Request failed (${res.statusCode}). Try again.';
      throw ApiException(message, statusCode: res.statusCode);
    }
    return data;
  }

  @visibleForTesting
  void debugSetBaseUrl(String url) {}
}
