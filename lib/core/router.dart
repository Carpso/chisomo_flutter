import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/campaigns/campaign_detail_screen.dart';
import '../features/campaigns/campaign_list_screen.dart';
import '../features/donate/donate_screen.dart';
import '../features/donate/pledges_screen.dart';
import '../features/host/create_campaign_screen.dart';
import '../features/host/host_dashboard_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/admin/admin_ledger_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider).value;
      final loggedIn = auth?.loggedIn ?? false;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
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
        path: '/host',
        builder: (context, state) => const HostDashboardScreen(),
      ),
      GoRoute(
        path: '/host/create',
        builder: (context, state) => const CreateCampaignScreen(),
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
        path: '/admin/disbursements',
        builder: (context, state) {
          final isAdmin = ref.read(authControllerProvider).value?.isAdmin ?? false;
          if (!isAdmin) return const CampaignListScreen();
          return const AdminDisbursementsScreen();
        },
      ),
    ],
  );
});
