import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/bottom_nav_shell.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/referrals_screen.dart';
import '../features/auth/settings_screen.dart';
import '../features/auth/link_action_screen.dart';
import '../features/auth/linked_account_detail_screen.dart';
import '../features/auth/legal_screen.dart';
import '../features/campaigns/campaign_detail_screen.dart';
import '../features/campaigns/campaign_list_screen.dart';
import '../features/events/events_screen.dart';
import '../features/events/create_event_screen.dart';
import '../features/events/event_detail_screen.dart';
import '../features/events/buy_ticket_screen.dart';
import '../features/events/admin_events_screen.dart';
import '../features/admin/admin_announcements_screen.dart';
import '../features/admin/admin_emails_screen.dart';
import '../features/admin/admin_sample_images_screen.dart';
import '../features/admin/admin_event_commission_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/search/global_search_screen.dart';
import '../features/team/team_chat_screen.dart';
import '../features/qr/my_qr_screen.dart';
import '../features/qr/qr_scan_screen.dart';
import '../features/gamification/achievements_screen.dart';
import '../features/admin/tax_compliance_screen.dart';
import '../features/admin/admin_analytics_screen.dart';
import '../features/admin/recycle_bin_screen.dart';
import '../features/host/campaign_analytics_screen.dart';
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
import '../features/admin/admin_lipila_logs_screen.dart';
import '../features/admin/admin_edit_requests_screen.dart';
import '../features/admin/admin_staff_screen.dart';
import '../features/admin/admin_users_screen.dart';
import '../features/admin/transaction_detail_screen.dart';
import '../features/sponsor_desk/sponsor_desk_screen.dart';
import '../features/admin/admin_sponsor_desk_screen.dart';

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

/// Converts any deep-link value (a raw `kingdomsponsor://campaign/<id>?ref=...`
/// URI or a path like `/campaign/<id>`) into a safe in-app route. Returns null
/// when nothing matches, so the router never throws a "no routes" GoException.
String? deepLinkToRoute(String? value) {
  if (value == null || value.isEmpty) return null;
  String raw = value.trim();
  // A trailing slash must not break matching: kingdomsponsor://campaign/7/
  if (raw.endsWith('/')) raw = raw.substring(0, raw.length - 1);

  // Raw custom-scheme URI: kingdomsponsor://campaign/7?ref=CODE
  if (raw.contains('://')) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'kingdomsponsor') return null;
    final keyword = uri.host.toLowerCase();
    final idStr = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final id = int.tryParse(idStr);
    switch (keyword) {
      case 'campaign':
        return id == null ? null : '/campaign/$id';
      case 'event':
        if (id == null) return null;
        return uri.pathSegments.length >= 2 && uri.pathSegments[1].toLowerCase() == 'buy-ticket'
            ? '/event/$id/buy-ticket'
            : '/event/$id';
      case 'donate':
        return id == null ? null : '/donate/$id';
      case 'support':
        return '/settings/support';
      case 'accept-link':
        return id == null ? null : '/settings/links/$id/accept';
      case 'reject-link':
        return id == null ? null : '/settings/links/$id/reject';
      default:
        return null;
    }
  }

  // Already a path (query strings, if any, are dropped so the router never
  // sees a location it cannot match).
  if (!raw.startsWith('/')) return null;
  final path = raw.split('?').first.split('#').first;
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return null;
  const known = {
    'campaign', 'event', 'donate', 'pledges', 'settings', 'host', 'airtime', 'admin',
    'sponsor-desk',
  };
  if (!known.contains(segs.first)) return null;
  return path;
}

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
      final pending = deepLinkToRoute(ref.read(pendingDeepLinkProvider));
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
            path: '/event/:id',
            builder: (context, state) => EventDetailScreen(
              eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/event/:id/buy-ticket',
            builder: (context, state) => BuyTicketScreen(
              eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
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
            path: '/events',
            builder: (context, state) => const EventsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const GlobalSearchScreen(),
          ),
          GoRoute(
            path: '/team-chat',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final isTeam = authAsync.value?.isAdmin ?? false;
              if (!isTeam) return const CampaignListScreen();
              return const TeamChatScreen();
            },
          ),
          GoRoute(
            path: '/my-qr',
            builder: (context, state) => const MyQrScreen(),
          ),
          GoRoute(
            path: '/achievements',
            builder: (context, state) => const AchievementsScreen(),
          ),
          GoRoute(
            path: '/admin/tax',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canTax = authAsync.value?.canScope('finance') ?? false;
              if (!canTax) return const CampaignListScreen();
              return const TaxComplianceScreen();
            },
          ),
          GoRoute(
            path: '/admin/scan-qr',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final auth = authAsync.value;
              final allowed = (auth?.isAdmin ?? false) || (auth?.hostStatus == 'approved');
              if (!allowed) return const CampaignListScreen();
              return const QrScanScreen();
            },
          ),
          GoRoute(
            path: '/admin/recycle-bin',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canRestore = authAsync.value?.canScope('restore') ?? false;
              if (!canRestore) return const CampaignListScreen();
              return const RecycleBinScreen();
            },
          ),
          GoRoute(
            path: '/admin/analytics',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final isStaff = authAsync.value?.isStaff ?? false;
              if (!isStaff) return const CampaignListScreen();
              return const AdminAnalyticsScreen();
            },
          ),
          GoRoute(
            path: '/admin/events',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canEvents = authAsync.value?.canScope('campaigns') ?? false;
              if (!canEvents) return const CampaignListScreen();
              return const AdminEventsScreen();
            },
          ),
          GoRoute(
            path: '/admin/announcements',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canAnnounce = authAsync.value?.canScope('campaigns') ?? false;
              if (!canAnnounce) return const CampaignListScreen();
              return const AdminAnnouncementsScreen();
            },
          ),
          GoRoute(
            path: '/host/analytics/:id',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              if (!(authAsync.value?.loggedIn ?? false)) return const CampaignListScreen();
              return CampaignAnalyticsScreen(
                campaignId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                title: 'Campaign analytics',
              );
            },
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
             path: '/settings/legal',
             builder: (context, state) => const LegalScreen(),
           ),           GoRoute(
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
            builder: (context, state) => const CreateCampaignScreen(),
          ),
          GoRoute(
            path: '/host/create-event',
            builder: (context, state) => const CreateEventScreen(),
          ),
          GoRoute(
            path: '/host/edit/:id',
            builder: (context, state) {
              final auth = ref.read(authControllerProvider).value;
              // Hosts edit their own campaigns; admins can edit any.
              final canEdit = auth?.isAdmin == true || auth?.hostStatus == 'approved';
              if (!canEdit) return const CampaignListScreen();
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
            path: '/sponsor-desk',
            builder: (context, state) => const SponsorDeskScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final isStaff = authAsync.value?.isStaff ?? false;
              if (!isStaff) return const CampaignListScreen();
              return const AdminScreen();
            },
          ),
          GoRoute(
            path: '/admin/staff',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canRestore = authAsync.value?.canScope('restore') ?? false;
              if (!canRestore) return const CampaignListScreen();
              return const AdminStaffScreen();
            },
          ),
          GoRoute(
            path: '/admin/staff/add',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canRestore = authAsync.value?.canScope('restore') ?? false;
              if (!canRestore) return const CampaignListScreen();
              // Opens Staff & Restore already on the Add-assistant flow, so
              // team chat's "Add team member" adds an assistant (team member)
              // instead of landing on the wrong screen.
              return const AdminStaffScreen(startWithAdd: true);
            },
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canUsers = authAsync.value?.canScope('users') ?? false;
              if (!canUsers) return const CampaignListScreen();
              return const AdminUsersScreen();
            },
          ),
          GoRoute(
            path: '/admin/emails',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canDonations = authAsync.value?.canScope('donations') ?? false;
              if (!canDonations) return const CampaignListScreen();
              return const AdminEmailsScreen();
            },
          ),
          GoRoute(
            path: '/admin/sample-images',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canSettings = authAsync.value?.canScope('settings') ?? false;
              if (!canSettings) return const CampaignListScreen();
              return const AdminSampleImagesScreen();
            },
          ),
          GoRoute(
            path: '/admin/event-commission',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canSettings = authAsync.value?.canScope('settings') ?? false;
              if (!canSettings) return const CampaignListScreen();
              return const AdminEventCommissionScreen();
            },
          ),
          GoRoute(
            path: '/admin/edit-requests',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canCampaigns = authAsync.value?.canScope('campaigns') ?? false;
              if (!canCampaigns) return const CampaignListScreen();
              return const AdminEditRequestsScreen();
            },
          ),
          GoRoute(
            path: '/admin/sponsor-desk',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canSettings = authAsync.value?.canScope('settings') ?? false;
              if (!canSettings) return const CampaignListScreen();
              return const AdminSponsorDeskScreen();
            },
          ),
          GoRoute(
            path: '/admin/transactions',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canDonations = authAsync.value?.canScope('donations') ?? false;
              if (!canDonations) return const CampaignListScreen();
              return const AdminTransactionsScreen();
            },
          ),
          GoRoute(
            path: '/admin/transactions/:id',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canDonations = authAsync.value?.canScope('donations') ?? false;
              if (!canDonations) return const CampaignListScreen();
              return TransactionDetailScreen(
                transactionId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              );
            },
          ),
          GoRoute(
            path: '/admin/disbursements',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canDonations = authAsync.value?.canScope('donations') ?? false;
              if (!canDonations) return const CampaignListScreen();
              return const AdminDisbursementsScreen();
            },
          ),
          GoRoute(
            path: '/admin/campaigns',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canCampaigns = authAsync.value?.canScope('campaigns') ?? false;
              if (!canCampaigns) return const CampaignListScreen();
              return const AdminCampaignsScreen();
            },
          ),
          GoRoute(
            path: '/admin/lipila-logs',
            builder: (context, state) {
              final authAsync = ref.watch(authControllerProvider);
              if (authAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final canDonations = authAsync.value?.canScope('donations') ?? false;
              if (!canDonations) return const CampaignListScreen();
              return const LipilaLogsScreen();
            },
          ),
        ],
      ),
    ],
    debugLogDiagnostics: false,
    // Never crash on an unmatched location — fall back to the campaign list
    // instead of surfacing a GoException to the user.
    onException: (context, state, router) {
      if (state.uri.path == '/') return;
      router.go('/');
    },
  );

  // Deep links that arrive while the app is already open won't re-trigger the
  // router's redirect by themselves, so navigate explicitly once signed in.
  ref.listen(pendingDeepLinkProvider, (prev, next) {
    if (next == null) return;
    final loggedIn = ref.read(authControllerProvider).value?.loggedIn ?? false;
    if (!loggedIn) return;
    final route = deepLinkToRoute(next);
    if (route != null) {
      try {
        router.go(route);
      } catch (_) {
        router.go('/');
      }
    }
  });

  return router;
});
