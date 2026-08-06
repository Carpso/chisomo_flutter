import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/bottom_nav_shell.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/referrals_screen.dart';
import '../features/auth/settings_screen.dart';
import '../features/auth/link_action_screen.dart';
import '../features/auth/linked_account_detail_screen.dart';
import '../features/campaigns/campaign_detail_screen.dart';
import '../features/campaigns/campaign_list_screen.dart';
import '../features/donate/donate_screen.dart';
import '../features/donate/my_receipts_screen.dart';
import '../features/airtime/airtime_screen.dart';
import '../features/donate/pledges_screen.dart';
import '../features/support/support_screen.dart';
import '../features/host/create_campaign_screen.dart';
import '../features/host/host_dashboard_screen.dart';
import '../features/host/host_badge_screen.dart';
import '../features/host/promote_screen.dart';
import '../features/admin/admin_campaigns_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/admin/admin_ledger_screen.dart';
import '../features/admin/transaction_detail_screen.dart';

/// A `kingdomsponsor://campaign/<id>` deep link waiting to be opened after
/// the user finishes signing in.
class PendingDeepLink extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? path) => state = path;
}

final pendingDeepLinkProvider = NotifierProvider<PendingDeepLink, String?>(PendingDeepLink.new);

/// Referral code captured from a `kingdomsponsor://campaign/<id>?ref=CODE`
/// deep link; the login screen passes it to OTP verification for new signups.
class ReferralCode extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

final referralCodeProvider = NotifierProvider<ReferralCode, String?>(ReferralCode.new);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authAsync = ref.read(authControllerProvider);
      // Wait for async auth validation to complete before deciding.
      // Redirecting during loading causes frequent sign-outs.
      if (authAsync is AsyncLoading) return null;
      final loggedIn = authAsync.asData?.value.loggedIn ?? false;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) {
        ref.read(authControllerProvider.notifier).setSignedOut();
        return '/login';
      }
      if (loggedIn && onLogin) return '/';
      final pending = ref.read(pendingDeepLinkProvider);
      if (loggedIn && pending != null) {
        ref.read(pendingDeepLinkProvider.notifier).set(null);
        return pending;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const CampaignListScreen(),
          ),
          GoRoute(
            path: '/campaign/:id',
            builder: (context, state) => CampaignDetailScreen(
              campaignId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/donate/:id',
            builder: (context, state) =>
                DonateScreen(campaignId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
          ),
          GoRoute(
            path: '/pledges',
            builder: (context, state) => const PledgesScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/receipts',
            builder: (context, state) => const MyReceiptsScreen(),
          ),
          GoRoute(
            path: '/settings/referrals',
            builder: (context, state) => const ReferralsScreen(),
          ),
           GoRoute(
             path: '/settings/support',
             builder: (context, state) => const SupportScreen(),
           ),
           GoRoute(
             path: '/settings/links/:id/accept',
             builder: (context, state) => const LinkActionScreen(),
           ),
            GoRoute(
              path: '/settings/links/:id/reject',
              builder: (context, state) => const LinkActionScreen(),
            ),
            GoRoute(
              path: '/settings/links/:id/detail',
              builder: (context, state) => LinkedAccountDetailScreen(
                linkId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          GoRoute(
            path: '/host',
            builder: (context, state) => const HostDashboardScreen(),
          ),
          GoRoute(
            path: '/host/create',
            builder: (context, state) {
              final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const CampaignListScreen();
              return const CreateCampaignScreen();
            },
          ),
          GoRoute(
            path: '/host/edit/:id',
            builder: (context, state) {
              final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const CampaignListScreen();
              final campaignId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CreateCampaignScreen(campaignId: campaignId);
            },
          ),
          GoRoute(
            path: '/host/promote',
            builder: (context, state) => const PromoteScreen(),
          ),
          GoRoute(
            path: '/airtime',
            builder: (context, state) => const AirtimeScreen(),
          ),
          GoRoute(
            path: '/host/badge',
            builder: (context, state) => const HostBadgeScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) {
              final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const CampaignListScreen();
              return const AdminScreen();
            },
          ),
          GoRoute(
            path: '/admin/transactions',
            builder: (context, state) {
              final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const CampaignListScreen();
              return const AdminTransactionsScreen();
            },
          ),
          GoRoute(
            path: '/admin/transactions/:id',
            builder: (context, state) {
              final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const CampaignListScreen();
              return TransactionDetailScreen(
                transactionId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              );
            },
          ),
          GoRoute(
            path: '/admin/disbursements',
            builder: (context, state) {
              final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const CampaignListScreen();
              return const AdminDisbursementsScreen();
            },
          ),
          GoRoute(
            path: '/admin/campaigns',
            builder: (context, state) {
              final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const CampaignListScreen();
              return const AdminCampaignsScreen();
            },
          ),
        ],
      ),
    ],
    debugLogDiagnostics: false,
  );

  // Deep links that arrive while the app is already open won't re-trigger the
  // router's redirect by themselves, so navigate explicitly once signed in.
  ref.listen(pendingDeepLinkProvider, (prev, next) {
    if (next == null) return;
    final loggedIn = ref.read(authControllerProvider).value?.loggedIn ?? false;
    if (loggedIn) router.go(next);
  });

  return router;
});
