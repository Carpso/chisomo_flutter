import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  await _setupFCM();
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://0fda6d4c7ee6f618a16817faf17325d3@o4511846985039872.ingest.us.sentry.io/4511846988709888';
      options.tracesSampleRate = 1.0;
      options.environment = 'production';
    },
    appRunner: () => runApp(const ProviderScope(child: KingdomSponsorApp())),
  );
}

Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
  if (settings.authorizationStatus != AuthorizationStatus.authorized) {
    return;
  }
  final token = await messaging.getToken();
  if (token != null) {
    _registerToken(token);
  }
  messaging.onTokenRefresh.listen((token) => _registerToken(token));
}

void _registerToken(String token) {
  ApiClient().post('/api/device/token', {'token': token, 'platform': 'android'}, auth: true)
      .then((_) => null)
      .catchError((_) => null);
}

class KingdomSponsorApp extends ConsumerWidget {
  const KingdomSponsorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Kingdom Sponsor',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
