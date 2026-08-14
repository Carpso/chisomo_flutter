import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/push_service.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/widgets/app_widgets.dart';
import 'core/widgets/notification_overlay.dart';
import 'core/fx_service.dart';
import 'core/l10n.dart';
import 'features/campaigns/campaigns_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Report any uncaught Flutter/zone errors to Sentry so production crashes
  // are never silent.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };
  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initPushService();
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://0fda6d4c7ee6f618a16817faf17325d3@o4511846985039872.ingest.us.sentry.io/4511846988709888';
      options.tracesSampleRate = 0.2;
      options.environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () async {
      // Restore persisted preferences before the first frame so the chosen
      // language and currency survive restarts (they are also used at build).
      final lang = await LanguageController.load();
      final currency = await CurrencyController.load();
      runApp(
        ProviderScope(
          overrides: [
            languageProvider.overrideWith(() => LanguageController(lang)),
            currencyPrefProvider.overrideWith(() => CurrencyController(currency)),
          ],
          child: const KingdomSponsorApp(),
        ),
      );
    },
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
    setNotificationOpenHandler((route) {
      if (mounted) ref.read(pendingDeepLinkProvider.notifier).set(route);
    });
    // Refresh the bell badge the moment a notification arrives so the unread
    // count is always live (not just after a manual pull-to-refresh).
    notifyBadgeRefresh = () {
      if (mounted) ref.invalidate(unreadNotificationsProvider);
    };
    DeepLinks.init((uri) {
      if (uri.scheme != 'kingdomsponsor' || !mounted) return;
      final refCode = uri.queryParameters['ref'];
      if (refCode != null && refCode.trim().isNotEmpty) {
        ref.read(referralCodeProvider.notifier).set(refCode.trim().toUpperCase());
      }
      // Convert the custom-scheme URI to a safe in-app path (single source of
      // truth in the router). pendingDeepLinkProvider only ever holds a path.
      final route = deepLinkToRoute(uri.toString());
      if (route != null) {
        ref.read(pendingDeepLinkProvider.notifier).set(route);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh campaigns when the app comes back to the foreground.
      ref.invalidate(campaignsProvider);
      // Re-register push token to handle silent FCM token rotation.
      refreshPushTokenIfNeeded();
      // Fresh unread count so the bell badge is correct after a background
      // notification was delivered while the app was away.
      ref.invalidate(unreadNotificationsProvider);
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
        // Never show a blank white screen on a build error — render a friendly
        // fallback with a retry instead (older/slower phones can hit this).
        ErrorWidget.builder = (details) => _FriendlyErrorWidget(details: details);
        // Clamp system text scaling so very large accessibility fonts don't
        // overflow the app's dense layouts (keeps content readable + intact).
        final media = MediaQuery.of(context);
        final clamped = media.copyWith(
          textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
        );
        return MediaQuery(
          data: clamped,
          child: Column(
            children: [
              if (isTestMode) const TestModeBanner(),
              Expanded(child: NotificationOverlay(child: child ?? const SizedBox.shrink())),
            ],
          ),
        );
      },
      routerConfig: router,
    );
  }
}

class _FriendlyErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;

  const _FriendlyErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertTriangle, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong rendering this screen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pull to refresh or restart the app. If it keeps happening, tell us via Settings → Support.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                details.exceptionAsString().split('\n').first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
