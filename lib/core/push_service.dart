import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_client.dart';
import 'session_store.dart';

/// Called when the user taps a push notification that carries a deep link.
/// Set from main.dart once the Riverpod container is available.
void Function(String route)? onNotificationOpen;

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

bool _wired = false;

/// Background message handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  developer.log('Background FCM message received: ${message.messageId}', name: 'PushService');
}

/// Initializes local notifications and Firebase Messaging. Safe to call once
/// at startup, and again after the user signs in via [ensurePushRegistered].
Future<void> initPushService() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: DarwinInitializationSettings(),
  );
  await _localNotifications.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        final route = '/campaign/$payload';
        onNotificationOpen?.call(route);
      }
    },
  );

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Create notification channel with orange accent color
  const androidChannel = AndroidNotificationChannel(
    'giving_updates',
    'Giving updates',
    description: 'Donation confirmations, receipts, pledges and campaign news',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);

  if (!await _ensurePermission()) return;
  await _registerCurrentToken();

  if (_wired) return;
  _wired = true;

  final messaging = FirebaseMessaging.instance;
  messaging.onTokenRefresh.listen((token) {
    unawaited(_registerToken(token));
  });

  // FCM does not show a system banner while the app is in the foreground,
  // so mirror the message as a local notification.
  FirebaseMessaging.onMessage.listen((message) {
    _showLocal(message.notification, message.data['campaignId']);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _open(message.data['campaignId']);
  });

  final initial = await messaging.getInitialMessage();
  if (initial != null) _open(initial.data['campaignId']);
}

/// Requests the notification permission. On Android this prompts for the
/// POST_NOTIFICATIONS runtime permission (Android 13+), which the Firebase
/// messaging plugin never does by itself.
Future<bool> _ensurePermission() async {
  final status = await Permission.notification.request();
  return status.isGranted || status.isLimited;
}

Future<void> _registerCurrentToken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    developer.log('FCM token: ${token?.substring(0, 20)}...', name: 'PushService');
    if (token != null && token.isNotEmpty) {
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
Future<void> ensurePushRegistered() async {
  if (!await _ensurePermission()) return;
  await _registerCurrentToken();
}

void _showLocal(RemoteNotification? n, String? campaignId) {
  _localNotifications.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: n?.title ?? 'Kingdom Sponsor',
    body: n?.body ?? '',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'giving_updates',
        'Giving updates',
        channelDescription:
            'Donation confirmations, receipts, pledges and campaign news',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFE65100),
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: campaignId,
  );
}

void _open(String? campaignId) {
  final route = campaignId != null ? '/campaign/$campaignId' : null;
  if (route != null) onNotificationOpen?.call(route);
}
