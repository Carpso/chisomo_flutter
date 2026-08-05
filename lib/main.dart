import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  await _setupFCM();
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://0fda6d4c7ee6f618a16817faf17325d3@o4511846985039872.ingest.us.sentry.io/4511846988709888';
      options.tracesSampleRate = 0.2;
      options.environment = 'production';
    },
    appRunner: () => runApp(const ProviderScope(child: KingdomSponsorApp())),
  );
}

/// Bridges `kingdomsponsor://campaign/<id>` deep links (shared links, QR codes,
/// share-page "Open in app" buttons) into [pendingDeepLinkProvider]; the router
/// redirect picks it up once the user is signed in.
class DeepLinks {
  static final AppLinks _links = AppLinks();
  static bool _wired = false;

  static void init(void Function(Uri) onOpen) {
    if (_wired) return;
    _wired = true;
    _links.getInitialLink().then((uri) {
      if (uri != null) onOpen(uri);
    });
    _links.uriLinkStream.listen(onOpen);
  }
}

Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
  if (settings.authorizationStatus != AuthorizationStatus.authorized) {
    return;
  }
  final token = await messaging.getToken();
  if (token != null) {
    await _registerToken(token);
  }
  messaging.onTokenRefresh.listen((token) => _registerToken(token));
}

/// Registers this device for push notifications. Uses the stored session token
/// (a fresh ApiClient has no auth token, so the server would reject it and
/// donors would never receive campaign-update pushes).
Future<void> _registerToken(String token) async {
  final session =
      await const FlutterSecureStorage().read(key: AuthController.tokenStorageKey);
  if (session == null) return;
  final api = ApiClient()..token = session;
  await api
      .post('/api/device/token', {'token': token, 'platform': 'android'}, auth: true)
      .then((_) => null)
      .catchError((_) => null);
}

class KingdomSponsorApp extends ConsumerStatefulWidget {
  const KingdomSponsorApp({super.key});

  @override
  ConsumerState<KingdomSponsorApp> createState() => _KingdomSponsorAppState();
}

class _KingdomSponsorAppState extends ConsumerState<KingdomSponsorApp> {
  @override
  void initState() {
    super.initState();
    DeepLinks.init((uri) {
      if (uri.scheme != 'kingdomsponsor' || !mounted) return;
      final refCode = uri.queryParameters['ref'];
      if (refCode != null && refCode.trim().isNotEmpty) {
        ref.read(referralCodeProvider.notifier).set(refCode.trim().toUpperCase());
      }
      final parts = uri.pathSegments;
      if (parts.isNotEmpty && parts.first == 'campaign' && parts.length > 1) {
        final id = int.tryParse(parts[1]);
        if (id != null) {
          ref.read(pendingDeepLinkProvider.notifier).set('/campaign/$id');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Kingdom Sponsor',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
