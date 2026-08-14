import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_client.dart';
import 'session_store.dart';
import '../firebase_options.dart';

/// Called when the user taps a push notification that carries a deep link.
/// Set from main.dart once the Riverpod container is available.
void Function(String route)? onNotificationOpen;

/// Called whenever a notification is received or opened (foreground, background
/// or tap). main.dart wires this to refresh the unread-count badge so the bell
/// updates live without waiting for a manual refresh.
void Function()? onNotificationReceived;

/// Emits every notification that arrives while the app is in the foreground so
/// the in-app banner overlay (main.dart) can slide it down on screen — the same
/// "smart pop-up" pattern ChurchOnApp uses, so alerts are never silent even
/// while the user is looking at the app.
void Function(String title, String body, String? route)? onInAppBanner;

/// Buffered route captured from a cold-start notification tap (getInitialMessage
/// / local-notification replay) that fires before main.dart has wired
/// [onNotificationOpen]. Flushed the moment the handler is assigned so the
/// deep link is never lost on a cold start.
String? _pendingInitialRoute;

void _deliver(String route) {
  final handler = onNotificationOpen;
  if (handler != null) {
    handler(route);
  } else {
    _pendingInitialRoute = route;
  }
  onNotificationReceived?.call();
}

/// Wires the notification-tap handler and flushes any route captured during
/// startup (before the Riverpod container existed).
void setNotificationOpenHandler(void Function(String route) handler) {
  onNotificationOpen = handler;
  final pending = _pendingInitialRoute;
  _pendingInitialRoute = null;
  if (pending != null) handler(pending);
}

/// Callback for the unread-count badge. main.dart assigns this so the bell
/// refreshes the moment a new notification lands in the foreground.
void Function()? notifyBadgeRefresh; // set by main.dart

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

bool _wired = false;

// ─── Notification channels (one per category — every one is Importance.max so
// a notification ALWAYS pops on the phone: heads-up banner, sound + vibration).
// The backend sends the matching `channelId` in the FCM payload (channelForType
// in firebase.ts); the manifest default is "giving_updates".
const _chGiving = 'giving_updates';
const _chEvents = 'events';
const _chSupport = 'support';
const _chPayments = 'payments';
const _chAdmin = 'admin';
const _chPromotions = 'promotions';
const _chSponsorDesk = 'sponsor_desk';
const _chChat = 'chat';
const _chBroadcast = 'broadcast';
const _chReferrals = 'referrals';
const _chHost = 'host';
const _chLinks = 'links';

class _ChannelSpec {
  final String id;
  final String name;
  final String description;
  const _ChannelSpec(this.id, this.name, this.description);
}

const _allChannels = [
  _ChannelSpec(_chGiving, 'Donations & campaigns',
      'Donation confirmations, receipts, milestones and campaign news'),
  _ChannelSpec(_chEvents, 'Events & tickets',
      'Event ticket sales, RSVPs and check-ins'),
  _ChannelSpec(_chSupport, 'Support',
      'Replies to your support requests and ticket updates'),
  _ChannelSpec(_chPayments, 'Payments & airtime',
      'Payouts, refunds and airtime order updates'),
  _ChannelSpec(_chAdmin, 'Admin alerts',
      'New users, host applications and admin notifications'),
  _ChannelSpec(_chPromotions, 'Promotions',
      'Promotion status: active, expired, refunded'),
  _ChannelSpec(_chSponsorDesk, 'Sponsor Desk',
      'Curated grant & empowerment opportunities'),
  _ChannelSpec(_chChat, 'Chat',
      'Messages in your campaign and event conversations'),
  _ChannelSpec(_chBroadcast, 'Broadcasts',
      'Messages from the Kingdom Sponsor team'),
  _ChannelSpec(_chReferrals, 'Referrals',
      'Referral rewards and referral updates'),
  _ChannelSpec(_chHost, 'Verified Host',
      'Verified Host Badge and account updates'),
  _ChannelSpec(_chLinks, 'Linked accounts',
      'Linked-account collaboration requests'),
];

/// Maps a Kingdom Sponsor notification `type` (from push data) to a channel.
/// Mirrors backend channelForType in firebase.ts.
String _channelForType(String? type) {
  switch (type) {
    case 'donation':
    case 'donation_received':
    case 'new_donor':
    case 'donation_confirmed':
    case 'new_campaign':
    case 'milestone':
    case 'campaign_ended':
    case 'campaign_ending':
    case 'campaign_updated':
    case 'campaign_deleted':
    case 'campaign_restored':
    case 'campaign_edit_approved':
    case 'campaign_edit_rejected':
    case 'campaign_edit_request':
    case 'delete_request':
    case 'delete_request_rejected':
    case 'announcement':
    case 'announcement_rejected':
      return _chGiving;
    case 'check_in':
    case 'rsvp':
    case 'ticket_oversold':
    case 'new_event':
    case 'ticket_confirmed':
    case 'ticket_sold':
    case 'event_reminder':
      return _chEvents;
    case 'ticket_created':
    case 'ticket_ack':
    case 'ticket_reply':
    case 'ticket_closed':
    case 'ticket_resolved':
      return _chSupport;
    case 'payout_started':
    case 'payout_failed':
    case 'payout_sent':
    case 'airtime_sent':
    case 'airtime_delivered':
    case 'airtime_failed':
    case 'airtime_refunded':
      return _chPayments;
    case 'new_user':
    case 'host_application':
    case 'admin_alert':
    case 'announcement_review':
      return _chAdmin;
    case 'promotion_active':
    case 'promotion_rejected':
    case 'promotion_refunded':
    case 'promotion_expired':
      return _chPromotions;
    case 'sponsor_desk':
      return _chSponsorDesk;
    case 'chat':
      return _chChat;
    case 'broadcast':
      return _chBroadcast;
    case 'referral_rewarded':
      return _chReferrals;
    case 'badge_activated':
    case 'host_verified':
      return _chHost;
    case 'link_request':
      return _chLinks;
    default:
      return _chGiving;
  }
}

/// Builds the Android notification details for a given channel. Every channel
/// is Importance.max with sound + vibration so alerts never sit silent.
/// The notification shows the app icon (launcher) and the brand orange colour
/// (#E65100, same as the app icon background) so it always matches the app.
NotificationDetails _notifDetails(String? type, {String? body}) {
  final channelId = _channelForType(type);
  final channel = _allChannels.firstWhere((c) => c.id == channelId,
      orElse: () => _allChannels.first);
  return NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFFE65100),
      icon: '@mipmap/ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      autoCancel: true,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction(
          'action_open',
          'Open',
          showsUserInterface: true,
        ),
      ],
      styleInformation: body != null
          ? BigTextStyleInformation(
              body,
              contentTitle: null,
              summaryText: 'Kingdom Sponsor',
            )
          : null,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}

/// Background message handler (must be a top-level function). Mirrors the
/// message as a local notification so OEMs that kill the FCM display path still
/// show it — the app channel mapping makes it pop with sound + vibration.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  developer.log('Background FCM message received: ${message.messageId}', name: 'PushService');
  final data = message.data;
  final title = data['title'] ?? message.notification?.title ?? 'Kingdom Sponsor';
  final body = data['body'] ?? message.notification?.body ?? '';
  if (title.toString().isEmpty && body.isEmpty) return;
  _showWithDedup(
    id: data['msgId'] != null && data['msgId'].toString().isNotEmpty
        ? data['msgId'].toString().hashCode
        : DateTime.now().millisecondsSinceEpoch % 100000,
    title: title.toString(),
    body: body.toString(),
    type: data['type'] as String?,
    route: _routeFromData(data),
  );
}

/// Initializes local notifications and Firebase Messaging. Safe to call once
/// at startup, and again after the user signs in via [ensurePushRegistered].
Future<void> initPushService() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_notification');
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: DarwinInitializationSettings(),
  );
  await _localNotifications.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        _deliver(payload);
      } else if (response.actionId == 'action_open') {
        // Fallback for the "Open" action button when no route was stored.
        _deliver('/notifications');
      }
    },
  );

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Create EVERY channel at Importance.max (heads-up banner + sound +
  // vibration + wake) so alerts are never silent — matching the backend.
  final androidImpl = _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  for (final ch in _allChannels) {
    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      ch.id,
      ch.name,
      description: ch.description,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));
  }

  // Self-heal: Android never raises an existing channel's importance, so if an
  // older build created a channel at a low level, banners stay silent forever
  // even after an update. Detect and recreate low-importance channels.
  try {
    final channels = await androidImpl?.getNotificationChannels();
    if (channels != null) {
      for (final existing in channels) {
        final known = _allChannels.any((c) => c.id == existing.id);
        if (known && existing.importance.index < Importance.max.index) {
          developer.log(
              'channel ${existing.id} at low importance (${existing.importance}) — recreating',
              name: 'PushService');
          await androidImpl?.deleteNotificationChannel(channelId: existing.id);
          final spec = _allChannels.firstWhere((c) => c.id == existing.id);
          await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
            spec.id,
            spec.name,
            description: spec.description,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ));
        }
      }
    }
  } catch (e) {
    developer.log('channel importance check failed: $e', name: 'PushService');
  }

  // Try to register token (will skip if no session yet)
  await _registerCurrentToken();

  // Ask for POST_NOTIFICATIONS on startup too: returning users who are already
  // signed in never hit the post-OTP prompt, so without this they'd stay
  // silent forever. Skip when nobody is signed in (the login flow prompts).
  final session = await SessionStore.read();
  if (session != null) {
    await _ensurePermission();
  }

  if (_wired) return;
  _wired = true;

  final messaging = FirebaseMessaging.instance;
  messaging.onTokenRefresh.listen((token) {
    unawaited(_registerToken(token));
  });

  // FCM does not show a system banner while the app is in the foreground,
  // so mirror the message as a local notification AND surface the in-app
  // banner so the user sees the alert immediately.
  FirebaseMessaging.onMessage.listen((message) {
    final data = message.data;
    final title = data['title'] ?? message.notification?.title ?? 'Kingdom Sponsor';
    final body = data['body'] ?? message.notification?.body ?? '';
    if (title.toString().isNotEmpty || body.isNotEmpty) {
      _showWithDedup(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title.toString(),
        body: body.toString(),
        type: data['type'] as String?,
        route: _routeFromData(data),
        inApp: true,
      );
      // A new notification just landed — refresh the bell badge live.
      notifyBadgeRefresh?.call();
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _open(message.data);
  });

  final initial = await messaging.getInitialMessage();
  if (initial != null) _open(initial.data);
}

void _open(Map<String, dynamic> data) {
  final route = _routeFromData(data);
  if (route != null) _deliver(route);
  // The tapped notification is usually still unread — refresh the badge.
  notifyBadgeRefresh?.call();
}

// ─── Content-keyed dedup + burst coalescing ────────────────────────────────
// The same event can arrive via multiple paths (FCM foreground stream, the
// in-app notifications table, or a mirrored local notification) — this makes
// sure the phone only ever shows ONE copy per event, while bursts of queued
// notifications collapse into a single summary instead of firing every one.

const _dedupWindow = Duration(seconds: 30);
final Map<String, DateTime> _recentlyShown = {};

String _contentKey(String title, String body) => '${title.trim()}|${body.trim()}';

bool _isDuplicate(String key) {
  final last = _recentlyShown[key];
  return last != null && DateTime.now().difference(last) < _dedupWindow;
}

void _markShown(String key) {
  _recentlyShown[key] = DateTime.now();
  if (_recentlyShown.length > 200) {
    final cutoff = DateTime.now().subtract(_dedupWindow * 4);
    _recentlyShown.removeWhere((_, t) => t.isBefore(cutoff));
  }
}

class _PendingNotification {
  final int id;
  final String title;
  final String body;
  final String? type;
  final String? route;
  _PendingNotification(this.id, this.title, this.body, this.type, this.route);
}

final Map<String, List<_PendingNotification>> _pending = {};
Timer? _flushTimer;
bool _flushScheduled = false;

const _flushInterval = Duration(milliseconds: 1200);

void _showWithDedup({
  required int id,
  required String title,
  required String body,
  String? type,
  String? route,
  bool inApp = false,
}) {
  final key = _contentKey(title, body);
  if (_isDuplicate(key)) return;
  _markShown(key);

  // Show the in-app banner immediately for foreground alerts.
  if (inApp) onInAppBanner?.call(title, body, route);

  _pending.putIfAbsent(_channelForType(type), () => []).add(
        _PendingNotification(id, title, body, type, route),
      );
  _scheduleFlush();
}

void _scheduleFlush() {
  if (_flushScheduled) return;
  _flushScheduled = true;
  _flushTimer ??= Timer.periodic(_flushInterval, (_) => _flush());
}

Future<void> _flush() async {
  if (_pending.isEmpty) {
    _flushScheduled = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    return;
  }
  final batch = Map<String, List<_PendingNotification>>.from(_pending);
  _pending.clear();

  for (final entry in batch.entries) {
    final items = entry.value;
    if (items.isEmpty) continue;
    final channelId = entry.key;
    if (items.length == 1) {
      final n = items.first;
      await _showNow(id: n.id, title: n.title, body: n.body, type: n.type, route: n.route);
    } else {
      // Burst detected: one summary per channel (stable ID so repeated
      // summaries replace each other rather than stacking).
      final last = items.last;
      await _showNow(
        id: channelId.hashCode,
        title: last.title,
        body: 'You have ${items.length} new updates.',
        type: last.type,
        route: last.route,
      );
    }
  }
}

Future<void> _showNow({
  required int id,
  required String title,
  required String body,
  String? type,
  String? route,
}) async {
  await _localNotifications.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: _notifDetails(type, body: body),
    payload: route,
  );
}

/// Requests the notification permission. On Android this prompts for the
/// POST_NOTIFICATIONS runtime permission (Android 13+). Returns true when the
/// user can receive notifications (granted or limited).
Future<bool> _ensurePermission() async {
  // Check if already granted
  var status = await Permission.notification.status;
  if (status.isGranted || status.isLimited) return true;

  // Request permission
  status = await Permission.notification.request();
  if (status.isGranted || status.isLimited) return true;

  // If permanently denied, we can't prompt again — the user must enable it in
  // system settings. We surface this through openAppSettings() (the caller
  // decides whether to show the settings screen).
  if (status.isPermanentlyDenied) {
    developer.log('Notification permission permanently denied — user must enable in settings', name: 'PushService');
  }
  return false;
}

/// Best-effort attempt to open the app's system settings screen (so a user who
/// permanently denied notifications can re-enable them).
Future<bool> requestNotificationsViaSettings() async {
  final ok = await _ensurePermission();
  if (ok) return true;
  // Try opening the OS notification settings so the user can flip it on.
  return openAppSettings();
}

Future<void> _registerCurrentToken({bool forceFresh = false}) async {
  try {
    if (forceFresh) {
      // A token FCM no longer accepts must be deleted first so getToken()
      // issues a brand-new one (fixes "registered but never delivered").
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        developer.log('deleteToken failed (ignored): $e', name: 'PushService');
      }
    }
    // Request a fresh token (FCM may have rotated it)
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      developer.log('FCM token: ${token.substring(0, 20)}...', name: 'PushService');
      await _registerToken(token);
    }
  } catch (e) {
    developer.log('Failed to get FCM token: $e', name: 'PushService');
  }
}

/// Registers a device token with the backend for the signed-in user. No-op
/// when nobody is signed in yet (the caller re-runs it after login).
Future<void> _registerToken(String token) async {
  final session = await SessionStore.read();
  if (session == null) {
    developer.log('No session, skipping token registration', name: 'PushService');
    return;
  }
  final api = ApiClient()..token = session;
  try {
    await api.post(
      '/api/device/token',
      {'token': token, 'platform': 'android'},
      auth: true,
    );
    developer.log('Token registered successfully', name: 'PushService');
  } catch (e) {
    developer.log('Token registration failed: $e', name: 'PushService');
  }
}

/// Re-registers the current FCM token after the user signs in, so devices
/// that started the app before login are still reachable for push.
/// Called after every successful OTP verification.
Future<void> ensurePushRegistered() async {
  if (!await _ensurePermission()) return;
  await _registerCurrentToken();
}

/// Deletes and re-issues the FCM token, then re-registers it. Use when a push
/// test reports the token is not being delivered (stale/rotated tokens get
/// replaced with a fresh one FCM accepts).
Future<void> refreshPushTokenForce() async {
  if (!await _ensurePermission()) return;
  await _registerCurrentToken(forceFresh: true);
}

/// Periodically re-register the token to handle silent token rotation by FCM.
/// Call this when the app resumes from background.
Future<void> refreshPushTokenIfNeeded() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      final session = await SessionStore.read();
      if (session == null) return;
      // Always re-register on resume — it's cheap and catches silent rotations
      await _registerToken(token);
    }
  } catch (e) {
    // Silently fail — not critical
  }
}

/// Maps push message data to an in-app route so EVERY notification has a proper
/// action link when tapped:
/// - campaignId -> the campaign/event page (donations, payouts, milestones, …)
/// - ticketId   -> the support screen (ticket replies, auto-acknowledgements)
/// - type       -> feature screens (airtime, sponsor desk, referrals, …)
String? _routeFromData(Map<String, dynamic> data) {
  final campaignId = data['campaignId'];
  if (campaignId != null && campaignId.toString().isNotEmpty) return '/campaign/$campaignId';
  final ticketId = data['ticketId'];
  if (ticketId != null && ticketId.toString().isNotEmpty) return '/settings/support';
  final type = data['type'];
  switch (type) {
    case 'referral_rewarded':
      return '/settings/referrals';
    case 'airtime_sent':
    case 'airtime_delivered':
    case 'airtime_failed':
    case 'airtime_refunded':
      return '/airtime';
    case 'badge_activated':
    case 'host_verified':
      return '/host/badge';
    case 'sponsor_desk':
      return '/sponsor-desk';
    case 'new_user':
    case 'host_application':
    case 'admin_alert':
    case 'announcement_review':
    case 'ticket_oversold':
      return '/admin';
    case 'broadcast':
      return '/notifications';
    case 'link_request':
      final linkId = data['linkId'];
      return (linkId != null && linkId.toString().isNotEmpty)
          ? '/settings/links/$linkId/accept'
          : '/settings';
    case 'donation':
    case 'donation_received':
    case 'new_donor':
    case 'donation_confirmed':
    case 'milestone':
    case 'campaign_ended':
    case 'campaign_ending':
    case 'campaign_updated':
    case 'campaign_deleted':
    case 'campaign_restored':
    case 'campaign_edit_approved':
    case 'campaign_edit_rejected':
    case 'campaign_edit_request':
    case 'delete_request':
    case 'delete_request_rejected':
    case 'announcement':
    case 'announcement_rejected':
    case 'payout_started':
    case 'payout_failed':
    case 'payout_sent':
    case 'check_in':
    case 'rsvp':
      // These always carry campaignId (handled above); fall through to home.
      return '/';
    case 'test':
      return null;
    default:
      return null;
  }
}
