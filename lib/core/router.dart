import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/bottom_nav_shell.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/referrals_screen.dart';
import '../features/auth/settings_screen.dart';
import '../features/campaigns/campaign_detail_screen.dart';
import '../features/campaigns/campaign_list_screen.dart';
import '../features/donate/donate_screen.dart';
import '../features/donate/my_receipts_screen.dart';
import '../features/donate/pledges_screen.dart';
import '../features/support/support_screen.dart';
import '../features/host/create_campaign_screen.dart';
import '../features/host/host_dashboard_screen.dart';
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
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider).value;
      final loggedIn = auth?.loggedIn ?? false;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
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
            builder: (context, state) =>
                CampaignDetailScreen(campaignId: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/donate/:id',
            builder: (context, state) =>
                DonateScreen(campaignId: int.parse(state.pathParameters['id']!)),
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
            path: '/host',
            builder: (context, state) => const HostDashboardScreen(),
          ),
          GoRoute(
            path: '/host/create',
            builder: (context, state) => const CreateCampaignScreen(),
          ),
          GoRoute(
            path: '/host/promote',
            builder: (context, state) => const PromoteScreen(),
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
                transactionId: int.parse(state.pathParameters['id']!),
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
});
