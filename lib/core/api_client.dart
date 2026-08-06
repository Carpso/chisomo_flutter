import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'session_store.dart';

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

  /// Storage key where the session token is persisted (encrypted + fallback).
  static const tokenStorageKey = SessionStore.key;

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://10.0.2.2:8787';

  /// Public, QR/WhatsApp-friendly share page for a campaign.
  String shareUrl(int campaignId) => '$_baseUrl/share/$campaignId';

  /// Deep link that opens this campaign directly in the installed app.
  String deepLink(int campaignId) => 'kingdomsponsor://campaign/$campaignId';

  /// Play Store page for people who do not have the app installed.
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.kingdomsponsor.app';

  Map<String, String> _headers({bool auth = false}) => {
    'Content-Type': 'application/json',
    if (auth && token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> get(String path, {bool auth = false}) async {
    final res = await _send(
      () => _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
      ),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final res = await _send(
      () => _client.put(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  /// Deletes a resource (pledge cancellation).
  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) async {
    final res = await _send(
      () => _client.delete(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
      ),
    );
    return _decode(res);
  }

  /// Sends a link request to another account (family | couple | team).
  Future<Map<String, dynamic>> linkUser(String targetPhone, String linkType) {
    return post('/api/user/link', {
      'targetPhone': targetPhone,
      'linkType': linkType,
    }, auth: true);
  }

  /// Accepts a pending account link request sent to me.
  Future<Map<String, dynamic>> acceptLink(int linkId) {
    return post('/api/user/links/$linkId/accept', {}, auth: true);
  }

  /// Rejects a pending account link request sent to me.
  Future<Map<String, dynamic>> rejectLink(int linkId) {
    return post('/api/user/links/$linkId/reject', {}, auth: true);
  }

  /// Lists my account links (outgoing and incoming).
  Future<Map<String, dynamic>> getLinks() {
    return get('/api/user/links', auth: true);
  }

  /// Updates the signed-in user's display name and/or username.
  Future<Map<String, dynamic>> updateProfile({String? name, String? username}) {
    return post('/api/me', {
      if (name != null) 'name': name,
      if (username != null) 'username': username,
    }, auth: true);
  }

  /// Permanently deletes the signed-in account (Google Play compliance).
  Future<Map<String, dynamic>> deleteAccount() {
    return delete('/api/account', auth: true);
  }

  /// Subscribe to a host badge tier.
  Future<Map<String, dynamic>> subscribeBadge(String tier) {
    return post('/api/host/badge/subscribe', {'tier': tier}, auth: true);
  }

  /// Fetch the user's push notification toggle setting.
  Future<bool> getNotificationsEnabled() async {
    final res = await get('/api/user/notifications', auth: true);
    return res['enabled'] == true;
  }

  /// Update the user's push notification toggle.
  Future<bool> setNotificationsEnabled(bool enabled) async {
    final res = await put('/api/user/notifications', { 'enabled': enabled }, auth: true);
    return res['enabled'] == true;
  }

  /// Lists host announcements for a campaign (public).
  Future<List<dynamic>> getAnnouncements(int campaignId) async {
    final res = await get('/api/campaigns/$campaignId/announcements');
    return res['announcements'] as List<dynamic>? ?? [];
  }

  /// Posts a host announcement to a campaign.
  Future<Map<String, dynamic>> postAnnouncement(int campaignId, String body) {
    return post('/api/campaigns/$campaignId/announcements', {
      'body': body,
    }, auth: true);
  }

  /// Sets up (or updates) a monthly reminder pledge on a campaign.
  Future<Map<String, dynamic>> createPledge(
    int campaignId,
    int amountCents,
    int dayOfMonth,
  ) {
    return post('/api/campaigns/$campaignId/pledge', {
      'amountCents': amountCents,
      'dayOfMonth': dayOfMonth,
    }, auth: true);
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
  String receiptUrl(int contributionId) =>
      '$_baseUrl/api/contributions/$contributionId/receipt?token=$token';

  /// Uploads a campaign logo (multipart). [bytes] is the raw image data.
  Future<Map<String, dynamic>> uploadLogo(
    int campaignId,
    List<int> bytes,
    String filename,
  ) async {
    final ext = filename.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
    final req =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/api/campaigns/$campaignId/logo'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: mime,
            ),
          );
    final res = await _send(
      () => req.send().then((s) => http.Response.fromStream(s)),
    );
    return _decode(res);
  }

  /// Uploads the signed-in user's profile photo (multipart).
  Future<Map<String, dynamic>> uploadAvatar(
    List<int> bytes,
    String filename,
  ) async {
    final ext = filename.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
    final req =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/me/avatar'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: mime,
            ),
          );
    final res = await _send(
      () => req.send().then((s) => http.Response.fromStream(s)),
    );
    return _decode(res);
  }

  /// Admin: approve a paid promotion (goes live in the top-5 list).
  Future<Map<String, dynamic>> approvePromotion(int id) {
    return post('/api/admin/promotions/$id/approve', {}, auth: true);
  }

  /// Admin: reject a paid promotion (host is notified).
  Future<Map<String, dynamic>> rejectPromotion(int id) {
    return post('/api/admin/promotions/$id/reject', {}, auth: true);
  }

  /// Host: this account's own promotion purchases/history.
  Future<Map<String, dynamic>> getMyPromotions() {
    return get('/api/me/promotions', auth: true);
  }

  /// Admin: current promotion paywall settings.
  Future<Map<String, dynamic>> getPromotionConfig() {
    return get('/api/admin/promotion-config', auth: true);
  }

  /// Admin: set the promotion price (cents) and duration (days).
  Future<Map<String, dynamic>> setPromotionConfig(int priceCents, int days) {
    return post('/api/admin/promotion-config', {
      'priceCents': priceCents,
      'days': days,
    }, auth: true);
  }

  /// Host: request the admin to delete a campaign.
  Future<Map<String, dynamic>> requestCampaignDelete(
    int campaignId, {
    String reason = '',
  }) {
    return post('/api/campaigns/$campaignId/delete-request', {
      'reason': reason,
    }, auth: true);
  }

  /// Admin: pending campaign-delete requests.
  Future<List<dynamic>> getDeleteRequests() async {
    final res = await get('/api/admin/delete-requests', auth: true);
    return res['requests'] as List<dynamic>? ?? [];
  }

  /// Admin: approve a campaign-delete request (campaign removed).
  Future<Map<String, dynamic>> approveDeleteRequest(int id) {
    return post('/api/admin/delete-requests/$id/approve', {}, auth: true);
  }

  /// Admin: reject a campaign-delete request.
  Future<Map<String, dynamic>> rejectDeleteRequest(int id) {
    return post('/api/admin/delete-requests/$id/reject', {}, auth: true);
  }

  /// Admin: delete a campaign directly (host and donors are alerted).
  Future<Map<String, dynamic>> deleteCampaign(
    int campaignId, {
    String reason = '',
  }) {
    return post('/api/admin/campaigns/$campaignId/delete', {
      'reason': reason,
    }, auth: true);
  }

  /// Admin: update a campaign's title, description, goal, status, etc.
  Future<Map<String, dynamic>> updateCampaign(
    int campaignId,
    Map<String, dynamic> body,
  ) {
    return put('/api/admin/campaigns/$campaignId', body, auth: true);
  }

  /// Admin: get SMS network status text.
  Future<Map<String, dynamic>> getSmsStatus() async {
    final res = await get('/api/admin/sms-status');
    return res;
  }

  /// Admin: update SMS network status text.
  Future<Map<String, dynamic>> setSmsStatus(String text) {
    return put('/api/admin/sms-status', {'text': text}, auth: true);
  }

  /// Admin: get failed login attempts.
  Future<List<dynamic>> getFailedLogins() async {
    final res = await get('/api/admin/failed-logins', auth: true);
    return res['failedLogins'] as List<dynamic>? ?? [];
  }

  /// Admin: list active monthly reminder pledges (users' SMS reminders).
  Future<List<dynamic>> getAdminPledges() async {
    final res = await get('/api/admin/pledges', auth: true);
    return res['pledges'] as List<dynamic>? ?? [];
  }

  /// Admin: cancel a user's monthly SMS reminder pledge.
  Future<Map<String, dynamic>> cancelAdminPledge(int pledgeId) {
    return post('/api/admin/pledges/$pledgeId/cancel', {}, auth: true);
  }

  /// Admin: check if Telegram bot is configured.
  Future<Map<String, dynamic>> getTelegramConfig() async {
    final res = await get('/api/admin/telegram-config', auth: true);
    return res;
  }

  /// Admin: set Telegram bot token and chat ID.
  Future<Map<String, dynamic>> setTelegramConfig({
    String? token,
    String? chatId,
  }) {
    return put('/api/admin/telegram-config', {
      'token': token,
      'chatId': chatId,
    }, auth: true);
  }

  /// Admin: trigger a test intruder alert (Telegram + SMS).
  Future<Map<String, dynamic>> testIntruderAlert() {
    return post('/api/admin/intruder-alert/test', {}, auth: true);
  }

  /// Admin: is the intruder alert scan enabled?
  Future<Map<String, dynamic>> getIntruderAlert() async {
    final res = await get('/api/admin/intruder-alert', auth: true);
    return res;
  }

  /// Admin: turn the intruder alert scan on or off.
  Future<Map<String, dynamic>> setIntruderAlert(bool enabled) {
    return put('/api/admin/intruder-alert', {'enabled': enabled}, auth: true);
  }

  /// Admin: alert email configuration.
  Future<Map<String, dynamic>> getEmailConfig() async {
    final res = await get('/api/admin/email-config', auth: true);
    return res;
  }

  /// Admin: set the alert email address.
  Future<Map<String, dynamic>> setEmailConfig(String email) {
    return put('/api/admin/email-config', {'email': email}, auth: true);
  }

  /// Admin: export a full database snapshot (all tables as JSON).
  Future<Map<String, dynamic>> backupExport() {
    return get('/api/admin/backup/export', auth: true);
  }

  /// Admin: restore a previously exported snapshot (wipes listed tables first).
  Future<Map<String, dynamic>> backupRestore(Map<String, dynamic> tables) {
    return post('/api/admin/backup/restore', {
      'confirm': true,
      'tables': tables,
    }, auth: true);
  }

  /// Admin: short-link click stats (top 100 by clicks).
  Future<Map<String, dynamic>> getShortLinkStats() {
    return get('/api/admin/short-links', auth: true);
  }

  /// Admin: all campaigns (any status) with host and balance info.
  Future<List<dynamic>> getAdminCampaigns() async {
    final res = await get('/api/admin/campaigns', auth: true);
    return res['campaigns'] as List<dynamic>? ?? [];
  }

  /// Resend a Lipila collection prompt for a pending contribution.
  Future<Map<String, dynamic>> resendPrompt(String referenceId) {
    return post(
      '/api/contributions/$referenceId/resend-prompt',
      {},
      auth: true,
    );
  }

  /// Submits a support ticket to the superadmin.
  Future<Map<String, dynamic>> createSupportTicket(
    String subject,
    String message,
  ) {
    return post('/api/support/tickets', {
      'subject': subject,
      'message': message,
    }, auth: true);
  }

  /// Lists my support tickets.
  Future<List<dynamic>> getSupportTickets() async {
    final res = await get('/api/support/tickets', auth: true);
    return res['tickets'] as List<dynamic>? ?? [];
  }

  /// Replies to a support ticket (user or admin).
  Future<Map<String, dynamic>> replySupportTicket(int id, String message) {
    return post('/api/support/tickets/$id/reply', {
      'message': message,
    }, auth: true);
  }

  /// Admin: resolve a support ticket.
  Future<Map<String, dynamic>> resolveSupportTicket(int id) {
    return put('/api/admin/tickets/$id/resolve', {}, auth: true);
  }

  /// Admin: all support tickets (optionally filtered by status).
  Future<List<dynamic>> getAdminTickets({String status = ''}) async {
    final res = await get('/api/admin/tickets?status=$status', auth: true);
    return res['tickets'] as List<dynamic>? ?? [];
  }

  /// Admin: get push notification status (token counts, config).
  Future<Map<String, dynamic>> getPushStatus() async {
    return get('/api/admin/push-status', auth: true);
  }

  /// Admin: send a test push notification.
  Future<Map<String, dynamic>> sendTestPush({int? userId}) {
    return post('/api/admin/test-push', userId != null ? {'userId': userId} : {}, auth: true);
  }

  /// Admin: trigger auto-disburse for all campaigns or a specific campaign.
  Future<Map<String, dynamic>> triggerDisburse({int? campaignId}) {
    return post('/api/admin/disburse', campaignId != null ? {'campaignId': campaignId} : {}, auth: true);
  }

  /// Admin: get Lipila wallet balance.
  Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await get('/api/admin/wallet-balance', auth: true);
    return res;
  }

  /// Admin: manual withdrawal to a phone number.
  Future<Map<String, dynamic>> adminWithdraw(int amountCents, String phone) {
    return post('/api/admin/withdraw', {'amountCents': amountCents, 'phone': phone}, auth: true);
  }

  /// Get combined donations from a linked account.
  Future<Map<String, dynamic>> getLinkDonations(int linkId) async {
    return get('/api/user/links/$linkId/donations', auth: true);
  }

  /// Donor: this account's confirmed contributions (for receipts).
  Future<List<dynamic>> getMyReceipts() async {
    final res = await get('/api/me/receipts', auth: true);
    return res['receipts'] as List<dynamic>? ?? [];
  }

  /// My referral code + share link.
  Future<Map<String, dynamic>> getMyReferral() {
    return get('/api/me/referral', auth: true);
  }

  /// People I referred (username, phone, date) + totals.
  Future<Map<String, dynamic>> getMyReferrals() {
    return get('/api/me/referrals', auth: true);
  }

  /// Admin: refund a promotion fee back to the host's mobile money.
  Future<Map<String, dynamic>> refundPromotion(int id) {
    return post('/api/admin/promotions/$id/refund', {}, auth: true);
  }

  /// Admin: host payouts + sweeps ledger.
  Future<List<dynamic>> getAdminPayouts({
    int limit = 100,
    int offset = 0,
  }) async {
    final res = await get(
      '/api/admin/payouts?limit=$limit&offset=$offset',
      auth: true,
    );
    return res['payouts'] as List<dynamic>? ?? [];
  }

  /// Admin: paginated contribution ledger.
  Future<Map<String, dynamic>> getAdminTransactions({
    String status = '',
    int limit = 500,
    int offset = 0,
  }) {
    return get(
      '/api/admin/transactions?status=$status&limit=$limit&offset=$offset',
      auth: true,
    );
  }

  /// Checks the Lipila collection status for a contribution.
  Future<Map<String, dynamic>> checkContributionStatus(String referenceId) {
    return get('/api/contributions/status/$referenceId');
  }

  /// Runs a request with a timeout and surfaces network failures as [ApiException]
  /// so the UI can show a clear message instead of hanging or silently failing.
  /// Also picks up sliding-session refresh tokens issued by the server.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final res = await request().timeout(const Duration(seconds: 20));
      final fresh = res.headers['x-refresh-token'];
      if (fresh != null && fresh.isNotEmpty && fresh != token) {
        token = fresh;
        await SessionStore.write(fresh);
      }
      return res;
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
      if (res.statusCode >= 500) {
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'Server error ${res.statusCode}',
          category: 'api',
          data: {
            'url': res.request?.url.toString() ?? '',
            'statusCode': res.statusCode,
            'body': res.body.length > 400
                ? '${res.body.substring(0, 400)}…'
                : res.body,
          },
        ));
        final base = data['error'] is String
            ? data['error'] as String
            : 'Request failed (${res.statusCode}).';
        throw ApiException(
          '$base Check your connection, then pull to refresh and try again.',
          statusCode: res.statusCode,
        );
      }
      throw ApiException(message, statusCode: res.statusCode);
    }
    return data;
  }

  @visibleForTesting
  void debugSetBaseUrl(String url) {}
}
