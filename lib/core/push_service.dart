import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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

/// Shared high-priority Android notification details: heads-up banner, sound,
/// vibration and wake (matches the `giving_updates` channel created at startup).
NotificationDetails _notifDetails() => const NotificationDetails(
      android: AndroidNotificationDetails(
        'giving_updates',
        'Giving updates',
        channelDescription:
            'Donation confirmations, receipts, pledges and campaign news',
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFFE65100),
        icon: '@mipmap/ic_notification',
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
      ),
      iOS: DarwinNotificationDetails(),
    );

/// Background message handler (must be a top-level function). FCM shows
/// `notification`-type messages itself when the app is in the background, so
/// here we only mirror data-only messages as local notifications (Android
/// lets FCM handle the rest, but some OEMs kill that path too).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  developer.log('Background FCM message received: ${message.messageId}', name: 'PushService');
  if (message.notification == null) {
    if (message.data.isNotEmpty) {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: message.data['title'] ?? 'Kingdom Sponsor',
        body: message.data['body'] ?? '',
        notificationDetails: _notifDetails(),
        payload: _routeFromData(message.data),
      );
    }
  }
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
      }
    },
  );

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Create notification channel with max importance (heads-up banner + sound +
  // vibration + wake) so alerts are never silent.
  const androidChannel = AndroidNotificationChannel(
    'giving_updates',
    'Giving updates',
    description: 'Donation confirmations, receipts, pledges and campaign news',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  final androidImpl = _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(androidChannel);

  // Self-heal: Android never raises an existing channel's importance, so if an
  // older build created "giving_updates" at a low/important level, banners stay
  // silent forever even after an update. Detect a low-importance channel and
  // delete + recreate it so heads-up banners, sound and vibration actually work.
  try {
    final channels = await androidImpl?.getNotificationChannels();
    if (channels != null) {
      for (final c in channels) {
        if (c.id == 'giving_updates' && c.importance.index < Importance.max.index) {
          developer.log('giving_updates channel at low importance (${c.importance}) — recreating', name: 'PushService');
          await androidImpl?.deleteNotificationChannel(channelId: 'giving_updates');
          await androidImpl?.createNotificationChannel(androidChannel);
          break;
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
  // so mirror the message as a local notification.
  FirebaseMessaging.onMessage.listen((message) {
    _showLocal(message.notification, message.data);
    // A new notification just landed — refresh the bell badge live.
    notifyBadgeRefresh?.call();
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

Future<void> _registerCurrentToken() async {
  try {
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

/// Maps push message data to an in-app route.
/// - campaignId -> the campaign page (donation confirmations, new donors, …)
/// - ticketId   -> the support screen (ticket replies, auto-acknowledgements)
/// - type       -> feature screens that don't carry a campaign/ticket id
String? _routeFromData(Map<String, dynamic> data) {
  final campaignId = data['campaignId'];
  if (campaignId != null && campaignId.toString().isNotEmpty) return '/campaign/$campaignId';
  final ticketId = data['ticketId'];
  if (ticketId != null && ticketId.toString().isNotEmpty) return '/settings/support';
  final type = data['type'];
  switch (type) {
    case 'referral_rewarded':
      return '/settings/referrals';
    case 'airtime_delivered':
      return '/airtime';
    case 'badge_activated':
      return '/host/badge';
    case 'new_user':
      return '/admin';
    case 'link_request':
      final linkId = data['linkId'];
      return (linkId != null && linkId.toString().isNotEmpty)
          ? '/settings/links/$linkId/accept'
          : '/settings';
    default:
      return null;
  }
}

void _showLocal(RemoteNotification? n, Map<String, dynamic> data) {
  final route = _routeFromData(data);
  _localNotifications.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: n?.title ?? 'Kingdom Sponsor',
    body: n?.body ?? '',
    notificationDetails: _notifDetails(),
    payload: route,
  );
}
