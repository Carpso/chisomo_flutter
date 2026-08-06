import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/push_service.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/widgets/app_widgets.dart';
import 'features/campaigns/campaigns_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  await initPushService();
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://0fda6d4c7ee6f618a16817faf17325d3@o4511846985039872.ingest.us.sentry.io/4511846988709888';
      options.tracesSampleRate = 0.2;
      options.environment = kReleaseMode ? 'production' : 'development';
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

class KingdomSponsorApp extends ConsumerStatefulWidget {
  const KingdomSponsorApp({super.key});

  @override
  ConsumerState<KingdomSponsorApp> createState() => _KingdomSponsorAppState();
}

class _KingdomSponsorAppState extends ConsumerState<KingdomSponsorApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addObserver(this);
    });
    onNotificationOpen = (route) {
      if (mounted) ref.read(pendingDeepLinkProvider.notifier).set(route);
    };
    DeepLinks.init((uri) {
      if (uri.scheme != 'kingdomsponsor' || !mounted) return;
      final refCode = uri.queryParameters['ref'];
      if (refCode != null && refCode.trim().isNotEmpty) {
        ref.read(referralCodeProvider.notifier).set(refCode.trim().toUpperCase());
      }
      final parts = uri.pathSegments;
      if (parts.isNotEmpty) {
        if (parts.first == 'campaign' && parts.length > 1) {
          final id = int.tryParse(parts[1]);
          if (id != null) {
            ref.read(pendingDeepLinkProvider.notifier).set('/campaign/$id');
          }
        } else if (parts.first == 'accept-link' && parts.length > 1) {
          final id = int.tryParse(parts[1]);
          if (id != null) {
            ref.read(pendingDeepLinkProvider.notifier).set('/settings/links/$id/accept');
          }
        } else if (parts.first == 'reject-link' && parts.length > 1) {
          final id = int.tryParse(parts[1]);
          if (id != null) {
            ref.read(pendingDeepLinkProvider.notifier).set('/settings/links/$id/reject');
          }
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh campaigns when the app comes back to the foreground.
      ref.invalidate(campaignsProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isTestMode = dotenv.env['ENV'] == 'sandbox';
    return MaterialApp.router(
      title: 'Kingdom Sponsor',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) {
        return Column(
          children: [
            if (isTestMode) const TestModeBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      routerConfig: router,
    );
  }
}
