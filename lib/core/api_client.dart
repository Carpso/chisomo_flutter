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

  /// Authenticated download URL for an admin export file (CSV/PDF/backup).
  String adminExportUrl(String path) => '$_baseUrl$path';

  /// Long, public, QR/WhatsApp-friendly share page for a campaign.
  String shareUrl(int campaignId) => '$_baseUrl/share/$campaignId';

  /// Records that the signed-in user opened a campaign, so a PRIVATE campaign
  /// reached via a shared invite link stays findable under "Recently opened".
  Future<Map<String, dynamic>> recordCampaignView(int campaignId) {
    return post('/api/campaigns/$campaignId/view', {}, auth: true);
  }

  /// Recently-opened campaigns for the signed-in user (incl. private ones they
  /// reached via a shared link).
  Future<List<dynamic>> getCampaignViews() async {
    final res = await get('/api/me/campaign-views', auth: true);
    return res['campaigns'] as List<dynamic>? ?? [];
  }

  /// In-app notifications history (donations, tickets, milestones, admin…).
  Future<List<dynamic>> getNotifications() async {
    final res = await get('/api/me/notifications', auth: true);
    return res['notifications'] as List<dynamic>? ?? [];
  }

  Future<int> getUnreadNotificationCount() async {
    final res = await get('/api/me/notifications/unread-count', auth: true);
    return (res['unread'] as int?) ?? 0;
  }

  Future<void> markNotificationRead(int id) {
    return post('/api/me/notifications/$id/read', {}, auth: true);
  }

  Future<void> markAllNotificationsRead() {
    return post('/api/me/notifications/read-all', {}, auth: true);
  }

  /// Admin analytics for charts (donations over time, conversion, top events).
  Future<Map<String, dynamic>> getAdminAnalytics() {
    return get('/api/admin/analytics', auth: true);
  }

  /// Per-campaign analytics for a host (views, conversion, share clicks).
  Future<Map<String, dynamic>> getCampaignAnalytics(int campaignId) {
    return get('/api/campaigns/$campaignId/analytics', auth: true);
  }

  /// Global search across campaigns + (admin) users/tickets/transactions.
  Future<Map<String, dynamic>> globalSearch(String q) {
    return get('/api/search?q=${Uri.encodeQueryComponent(q)}');
  }

  /// Admin bulk SMS groups available for group broadcasts.
  Future<Map<String, dynamic>> getSmsGroups() {
    return get('/api/admin/sms/groups', auth: true);
  }

  /// Admin: send an SMS to every user in a filtered group.
  Future<Map<String, dynamic>> sendGroupSms(String group, String message) {
    return post('/api/admin/sms/group', {
      'group': group,
      'message': message,
    }, auth: true);
  }

  /// Team chat: fetch recent messages.
  Future<List<dynamic>> getTeamMessages() async {
    final res = await get('/api/team/messages', auth: true);
    return res['messages'] as List<dynamic>? ?? [];
  }

  /// Team chat: post a text message (optionally with an image URL).
  Future<void> sendTeamMessage(String body, {String? imageUrl}) {
    return post('/api/team/messages', {
      'body': body,
      if (imageUrl != null) 'imageUrl': imageUrl,
    }, auth: true);
  }

  /// Team chat: upload an image attachment (returns media URL).
  Future<String> uploadTeamImage(List<int> bytes, String filename) async {
    final req =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/team/upload'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final res = await _send(() => req.send().then((s) => http.Response.fromStream(s)));
    final data = _decode(res);
    return data['url'] as String? ?? '';
  }

  /// Short, public-friendly share page (uses the self-hosted shortener).
  /// Prefer [Campaign.shareUrl] when available — it comes back from the API as
  /// an already-shortened link. This is a client-side fallback: it points at
  /// the long share page (which the backend shortens on first visit), so it
  /// always resolves even offline of the shortener.
  String shortUrl(int campaignId) => shareUrl(campaignId);

  /// Deep link that opens this campaign directly in the installed app.
  String deepLink(int campaignId) => 'kingdomsponsor://campaign/$campaignId';

  /// Deep link that opens an event's detail screen in the installed app.
  String eventDeepLink(int campaignId) => 'kingdomsponsor://event/$campaignId';

  /// Deep link that opens an event's ticket-buying screen in the installed app.
  String eventTicketDeepLink(int campaignId) => 'kingdomsponsor://event/$campaignId/buy-ticket';

  /// Deep link that opens the donate flow for this campaign in the app.
  String donateDeepLink(int campaignId) => 'kingdomsponsor://donate/$campaignId';

  /// Buys event tickets: picks a tier + quantity and pays (MoMo prompt or card).
  Future<Map<String, dynamic>> buyTickets(
    int campaignId, {
    required String tierName,
    required int ticketQty,
    required int amountCents,
    required String phone,
    String? donorName,
    bool anonymous = false,
    bool hideAmount = false,
  }) {
    return post('/api/campaigns/$campaignId/contribute', {
      'amountCents': amountCents,
      'tierName': tierName,
      'ticketQty': ticketQty,
      'phone': phone,
      'donorName': donorName,
      'isAnonymous': anonymous,
      'hideAmount': hideAmount,
    });
  }

  /// RSVP to a free event ("I'm going").
  Future<Map<String, dynamic>> rsvpEvent(int eventId, {String? name, String? phone}) {
    return post('/api/events/$eventId/rsvp', {
      if (name != null && name.isNotEmpty) 'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  /// Public RSVP count for an event.
  Future<int> getRsvpCount(int eventId) async {
    final res = await get('/api/events/$eventId/rsvp-count');
    return (res['rsvpCount'] as num?)?.toInt() ?? 0;
  }

  /// Admin: dedicated events analytics (tickets, revenue, sell-through).
  Future<Map<String, dynamic>> getAdminEventsStats() {
    return get('/api/admin/events/stats', auth: true);
  }

  /// Send a test push to the logged-in user's own devices (Settings → Test notification).
  Future<Map<String, dynamic>> sendMyTestPush() {
    return post('/api/user/push/test', {}, auth: true);
  }

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

  /// Lists host announcements for a campaign (public, approved only).
  Future<List<dynamic>> getAnnouncements(int campaignId) async {
    final res = await get('/api/campaigns/$campaignId/announcements');
    return res['announcements'] as List<dynamic>? ?? [];
  }

  /// Posts a host update. Host submissions go to the moderation queue; admin
  /// posts publish instantly.
  Future<Map<String, dynamic>> postAnnouncement(int campaignId, String body) {
    return post('/api/campaigns/$campaignId/announcements', {
      'body': body,
    }, auth: true);
  }

  /// Admin: list announcements for moderation (default: pending).
  Future<List<dynamic>> getAdminAnnouncements({String status = 'pending'}) async {
    final res = await get('/api/admin/announcements?status=$status', auth: true);
    return res['announcements'] as List<dynamic>? ?? [];
  }

  /// Admin: approve a pending host update (publishes + notifies donors).
  Future<Map<String, dynamic>> approveAnnouncement(int id) {
    return post('/api/admin/announcements/$id/approve', {}, auth: true);
  }

  /// Admin: reject a pending host update with a reason sent to the host.
  Future<Map<String, dynamic>> rejectAnnouncement(int id, {String reason = ''}) {
    return post('/api/admin/announcements/$id/reject', {'reason': reason}, auth: true);
  }

  /// User/host: export a personal backup of everything tied to this account.
  Future<Map<String, dynamic>> getMyBackup() {
    return get('/api/me/backup', auth: true);
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

  /// Admin: all host applications (approved/pending/rejected).
  Future<List<dynamic>> getAdminApplications() async {
    final res = await get('/api/admin/applications', auth: true);
    return res['applications'] as List<dynamic>? ?? [];
  }

  /// Admin: approve a pending host application.
  Future<Map<String, dynamic>> approveApplication(int userId) {
    return post('/api/admin/applications/$userId/approve', {}, auth: true);
  }

  /// Admin: reject a pending host application.
  Future<Map<String, dynamic>> rejectApplication(int userId, {String? reason}) {
    return post('/api/admin/applications/$userId/reject',
        reason != null ? {'reason': reason} : {}, auth: true);
  }

  /// Admin: promote a campaign directly (free; goes live immediately).
  Future<Map<String, dynamic>> adminPromoteCampaign(int campaignId, {int? days}) {
    return post('/api/admin/campaigns/$campaignId/promote',
        days != null ? {'days': days} : {}, auth: true);
  }

  /// Browser-openable PDF receipt URL for a contribution (needs auth token).
  String receiptUrl(int contributionId) =>
      '$_baseUrl/api/contributions/$contributionId/receipt?token=$token';

  /// Uploads a campaign logo (multipart). [bytes] is the raw image data.
  /// MIME is detected from the actual bytes (JPEG/PNG/WebP magic numbers) so
  /// bundled/gallery images upload with the right content type regardless of
  /// the filename extension.
  Future<Map<String, dynamic>> uploadLogo(
    int campaignId,
    List<int> bytes,
    String filename,
  ) async {
    final mime = _detectImageMime(bytes, filename);
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

  /// Detects the image content type from the leading magic bytes, falling back
  /// to the filename extension. Ensures JPEG/PNG/WebP upload correctly.
  static MediaType _detectImageMime(List<int> bytes, String filename) {
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return MediaType('image', 'jpeg');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  /// Host: upload a KYC document (NRC / NGO cert / endorsement) to R2.
  Future<Map<String, dynamic>> uploadKycDoc(List<int> bytes, String filename) async {
    final ext = filename.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
    final req =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/host/kyc-upload'))
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

  /// Admin: set the promotion price (cents), duration (days) and slot count.
  Future<Map<String, dynamic>> setPromotionConfig(int priceCents, int days, {int? slots}) {
    return post('/api/admin/promotion-config', {
      'priceCents': priceCents,
      'days': days,
      if (slots != null) 'slots': slots,
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

  /// Update a campaign's title, description, goal, category, visibility, etc.
  /// Hosts edit their own campaigns via this endpoint.
  Future<Map<String, dynamic>> updateCampaign(
    int campaignId,
    Map<String, dynamic> body,
  ) {
    return put('/api/campaigns/$campaignId', body, auth: true);
  }

  /// Admin: update any campaign (title, description, goal, status, …).
  Future<Map<String, dynamic>> adminUpdateCampaign(
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

  /// Admin: all support tickets (optionally filtered by status) plus the
  /// configured support assistant name used as the reply signature.
  Future<(List<dynamic> tickets, String assistantName)> getAdminTickets({String status = ''}) async {
    final res = await get('/api/admin/tickets?status=$status', auth: true);
    return (
      res['tickets'] as List<dynamic>? ?? [],
      res['assistantName'] as String? ?? 'Kingdom Sponsor Care Team',
    );
  }

  /// Admin: change the support assistant name (reply SMS signature).
  Future<Map<String, dynamic>> setSupportAssistantName(String name) {
    return put('/api/admin/support-config', {'assistantName': name}, auth: true);
  }

  /// Public: per-network SMS health (mtn/airtel/zamtel/zedmobile = ok|down).
  Future<Map<String, dynamic>> getNetworkStatus() async {
    return get('/api/networks/status');
  }

  /// Public: admin-set SMS announcement + per-network health for the sign-in
  /// screen, so users can be told about outages without burning SMS credits.
  Future<Map<String, dynamic>> getSmsNotice() async {
    return get('/api/sms/notice');
  }

  /// Admin: send an SMS to any number (in-app or out-of-app).
  Future<Map<String, dynamic>> sendAdminSms(String phones, String message) {
    return post('/api/admin/sms/send', {
      'phone': phones,
      'message': message,
    }, auth: true);
  }

  /// Admin: recent SMS delivery activity (AT callbacks + admin broadcasts).
  Future<List<dynamic>> getSmsActivity() async {
    final res = await get('/api/admin/sms/activity', auth: true);
    return res['events'] as List<dynamic>? ?? [];
  }

  /// Admin: airtime orders list for diagnosing stuck purchases.
  Future<List<dynamic>> getAirtimeOrders() async {
    final res = await get('/api/admin/airtime-orders', auth: true);
    return res['orders'] as List<dynamic>? ?? [];
  }

  /// Admin: retry a failed/stuck airtime order.
  Future<Map<String, dynamic>> retryAirtimeOrder(int orderId) {
    return post('/api/admin/airtime-orders/$orderId/retry', {}, auth: true);
  }

  /// Admin: refund a failed airtime order's cost to the buyer.
  Future<Map<String, dynamic>> refundAirtimeOrder(int orderId) {
    return post('/api/admin/airtime-orders/$orderId/refund', {}, auth: true);
  }

  /// Admin: edit an approved/pending host's application details.
  Future<Map<String, dynamic>> updateHostApplication(int userId, {String? org, String? role, String? reason, String? orgType}) {
    return put('/api/admin/hosts/$userId/application', {
      if (org != null) 'org': org,
      if (role != null) 'role': role,
      if (reason != null) 'reason': reason,
      if (orgType != null) 'orgType': orgType,
    }, auth: true);
  }

  /// Admin: test the configured Telegram team bots.
  Future<Map<String, dynamic>> testTelegramBots() {
    return post('/api/admin/telegram-config/test', {}, auth: true);
  }

  /// My gamification achievements + stats.
  Future<Map<String, dynamic>> getMyAchievements() {
    return get('/api/me/achievements', auth: true);
  }

  /// Host/admin: check an attendee in to an event by phone.
  Future<Map<String, dynamic>> checkInAttendee(int eventId, String phone) {
    return post('/api/events/$eventId/check-in', {'phone': phone}, auth: true);
  }

  /// Host/admin: attendees checked in to an event.
  Future<Map<String, dynamic>> getEventAttendees(int eventId) {
    return get('/api/events/$eventId/attendees', auth: true);
  }

  /// Live session status for a campaign/event.
  Future<bool> getLiveStatus(int id) async {
    final res = await get('/api/campaigns/$id/live');
    return res['live'] == true;
  }

  Future<Map<String, dynamic>> setLive(int id, bool live) {
    return post('/api/campaigns/$id/live', {'live': live}, auth: true);
  }

  /// Latest confirmed donations for the live donor feed.
  Future<List<dynamic>> getLiveDonations(int id) async {
    final res = await get('/api/campaigns/$id/live/donations');
    return res['donations'] as List<dynamic>? ?? [];
  }

  /// Admin push broadcast groups.
  Future<Map<String, dynamic>> getPushGroups() {
    return get('/api/admin/push/groups', auth: true);
  }

  /// Admin: send a broadcast push to all/hosts/donors.
  Future<Map<String, dynamic>> sendPushBroadcast(String group, String title, String message) {
    return post('/api/admin/push/broadcast', {
      'group': group,
      'title': title,
      'message': message,
    }, auth: true);
  }

  /// Team chat room name.
  Future<String> getTeamRoomName() async {
    final res = await get('/api/admin/team/room', auth: true);
    return res['name'] as String? ?? 'Team Chat';
  }

  Future<Map<String, dynamic>> renameTeamRoom(String name) {
    return post('/api/admin/team/room', {'name': name}, auth: true);
  }

  /// Admin: email the weekly report immediately.
  Future<Map<String, dynamic>> sendWeeklyReport() {
    return post('/api/admin/report/send', {}, auth: true);
  }

  /// Admin: tax & compliance dashboard.
  Future<Map<String, dynamic>> getTaxDashboard() {
    return get('/api/admin/tax', auth: true);
  }

  /// Admin: update tax settings (rate %, due day, TPIN).
  Future<Map<String, dynamic>> saveTaxSettings({double? ratePct, int? dueDay, String? tin}) {
    return post('/api/admin/tax', {
      if (ratePct != null) 'ratePct': ratePct,
      if (dueDay != null) 'dueDay': dueDay,
      if (tin != null) 'tin': tin,
    }, auth: true);
  }

  /// Admin: tax invoice PDF download URL for a month.
  String taxInvoiceUrl(String month) => '$_baseUrl/api/admin/tax/invoice?month=$month';

  /// Admin: set per-network SMS health.
  Future<Map<String, dynamic>> setNetworkStatus(Map<String, String> statuses) {
    return put('/api/admin/network-status', {'statuses': statuses}, auth: true);
  }

  Future<Map<String, dynamic>> getLipilaLogs({String? kind, String? status, int limit = 200}) {
    final q = <String>[];
    if (kind != null) q.add('kind=$kind');
    if (status != null) q.add('status=$status');
    q.add('limit=$limit');
    return get('/api/admin/lipila-logs?${q.join("&")}', auth: true);
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

  /// Admin: get campaigns eligible for disbursement (balance >= min_withdraw).
  Future<List<dynamic>> getEligiblePayouts() async {
    final res = await get('/api/admin/eligible-payouts', auth: true);
    return res['campaigns'] as List<dynamic>? ?? [];
  }

  /// Admin: disburse a specific campaign by ID.
  Future<Map<String, dynamic>> disburseCampaign(int campaignId) {
    return post('/api/admin/disburse', {'campaignId': campaignId}, auth: true);
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

  /// Admin: referrers who reached the reward threshold.
  Future<Map<String, dynamic>> getAdminReferrals() {
    return get('/api/admin/referrals', auth: true);
  }

  /// Admin: reward a qualified referrer.
  Future<Map<String, dynamic>> rewardReferral(int userId) {
    return post('/api/admin/referrals/$userId/reward', {}, auth: true);
  }

  /// Admin: refund a promotion fee back to the host's mobile money.
  Future<Map<String, dynamic>> refundPromotion(int id) {
    return post('/api/admin/promotions/$id/refund', {}, auth: true);
  }

  /// Admin: list current assistants and their permission scopes.
  Future<Map<String, dynamic>> getAdminAssistants() {
    return get('/api/admin/assistants', auth: true);
  }

  /// Admin: search users by phone/username to add as an assistant.
  Future<Map<String, dynamic>> searchUsers(String q) {
    return get('/api/admin/users/search?q=${Uri.encodeQueryComponent(q)}', auth: true);
  }

  /// Admin: list all users by name/phone with giving + invite details.
  Future<Map<String, dynamic>> getAdminUsers({
    String q = '',
    int limit = 200,
    int offset = 0,
  }) {
    final query = <String>['limit=$limit', 'offset=$offset'];
    if (q.trim().isNotEmpty) query.add('q=${Uri.encodeQueryComponent(q.trim())}');
    return get('/api/admin/users?${query.join('&')}', auth: true);
  }

  /// Admin: list donor emails captured on card contributions.
  Future<Map<String, dynamic>> getAdminEmails({
    String q = '',
    int limit = 200,
  }) {
    final query = <String>['limit=$limit'];
    if (q.trim().isNotEmpty) query.add('q=${Uri.encodeQueryComponent(q.trim())}');
    return get('/api/admin/emails?${query.join('&')}', auth: true);
  }

  /// Public: admin-uploaded sample images hosts/events can use as posters.
  Future<List<String>> getSampleImages() async {
    final res = await get('/api/sample-images');
    return (res['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
  }

  /// Admin: list uploaded sample images.
  Future<List<String>> getAdminSampleImages() async {
    final res = await get('/api/admin/sample-images', auth: true);
    return (res['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
  }

  /// Admin: upload a sample image hosts/events can reuse as a poster.
  Future<Map<String, dynamic>> uploadSampleImage(List<int> bytes, String filename) async {
    final mime = _detectImageMime(bytes, filename);
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/admin/sample-images'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: mime));
    final res = await _send(() => req.send().then((s) => http.Response.fromStream(s)));
    return _decode(res);
  }

  /// Admin: remove a sample image.
  Future<Map<String, dynamic>> deleteSampleImage(String url) {
    return delete('/api/admin/sample-images?url=${Uri.encodeQueryComponent(url)}', auth: true);
  }

  /// Public: active funding opportunities on the Sponsor Desk.
  Future<List<dynamic>> getSponsorDesk() async {
    final res = await get('/api/sponsor-desk');
    return res['opportunities'] as List<dynamic>? ?? [];
  }

  /// Admin: full Sponsor Desk list (drafts, published, archived).
  Future<List<dynamic>> getAdminSponsorDesk() async {
    final res = await get('/api/admin/sponsor-desk', auth: true);
    return res['opportunities'] as List<dynamic>? ?? [];
  }

  /// Admin: create or update an opportunity (draft by default).
  Future<Map<String, dynamic>> saveSponsorDesk(Map<String, dynamic> body) {
    return post('/api/admin/sponsor-desk', body, auth: true);
  }

  /// Admin: publish selected opportunities to active hosts (push + in-app).
  Future<Map<String, dynamic>> publishSponsorDesk(List<int> ids) {
    return post('/api/admin/sponsor-desk/publish', {'ids': ids}, auth: true);
  }

  /// Admin: set an opportunity's status (active | archived).
  Future<Map<String, dynamic>> setSponsorDeskStatus(int id, String status) {
    return post('/api/admin/sponsor-desk/$id/status', {'status': status}, auth: true);
  }

  /// Admin: delete an opportunity permanently.
  Future<Map<String, dynamic>> deleteSponsorDesk(int id) {
    return delete('/api/admin/sponsor-desk/$id', auth: true);
  }

  /// Admin: per-user push reachability (who has a registered device token).
  Future<Map<String, dynamic>> getPushUsers({String q = ''}) {
    final query = q.trim().isEmpty
        ? ''
        : '?q=${Uri.encodeQueryComponent(q.trim())}';
    return get('/api/admin/push-users$query', auth: true);
  }

  /// Admin: add or update an assistant's permission scopes.
  Future<Map<String, dynamic>> saveAssistant(
    int userId, {
    required List<String> permissions,
    String? phone,
  }) {
    return post('/api/admin/assistants', {
      'userId': userId,
      'permissions': permissions,
      if (phone != null) 'phone': phone,
    }, auth: true);
  }

  /// Admin: update an existing assistant's scopes.
  Future<Map<String, dynamic>> updateAssistant(int userId, List<String> permissions) {
    return put('/api/admin/assistants/$userId', {'permissions': permissions}, auth: true);
  }

  /// Admin: remove an assistant (revokes all limited access).
  Future<Map<String, dynamic>> removeAssistant(int userId) {
    return delete('/api/admin/assistants/$userId', auth: true);
  }

  /// Admin: list soft-deleted campaigns that can be restored.
  Future<Map<String, dynamic>> getDeletedCampaigns() {
    return get('/api/admin/campaigns/deleted', auth: true);
  }

  /// Admin: restore a soft-deleted campaign.
  Future<Map<String, dynamic>> restoreCampaign(int campaignId) {
    return post('/api/admin/campaigns/$campaignId/restore', {}, auth: true);
  }

  /// Admin: recent sensitive admin actions (audit log).
  Future<Map<String, dynamic>> getAdminActions() {
    return get('/api/admin/actions', auth: true);
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

  /// Admin: approve or reject a host's KYC submission.
  Future<Map<String, dynamic>> decideKyc(
    int userId, {
    required bool approve,
    String notes = '',
  }) {
    return post('/api/admin/hosts/$userId/kyc', {
      'approve': approve,
      'notes': notes,
    }, auth: true);
  }

  /// Admin: mark an approved host as independently verified (with private notes).
  Future<Map<String, dynamic>> verifyHost(
    int userId, {
    required bool verified,
    String notes = '',
  }) {
    return post('/api/admin/hosts/$userId/verify', {
      'verified': verified,
      'notes': notes,
    }, auth: true);
  }

  /// Admin: list host campaign-edit requests pending/approved/rejected.
  Future<Map<String, dynamic>> getEditRequests() {
    return get('/api/admin/edit-requests', auth: true);
  }

  /// Admin: approve a host's campaign-edit request (applies the changes).
  Future<Map<String, dynamic>> approveEditRequest(int id) {
    return post('/api/admin/edit-requests/$id/approve', {}, auth: true);
  }

  /// Admin: reject a host's campaign-edit request.
  Future<Map<String, dynamic>> rejectEditRequest(int id, {String notes = ''}) {
    return post('/api/admin/edit-requests/$id/reject', {'notes': notes}, auth: true);
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
