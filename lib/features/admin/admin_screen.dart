import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_brand_icon.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/campaign_image.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/avatar.dart';
import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../airtime/airtime_screen.dart';
import '../auth/auth_controller.dart';
import '../host/host_badge_screen.dart';
import '../campaigns/campaigns_controller.dart';
import 'admin_tile_detail_screen.dart';
import '../campaigns/models.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

/// Draft SMS templates for warning threat actors / intruders. Every message is
/// kept <= 96 characters so it always bills as ONE SMS, and taps just fill the
/// message box (the admin edits the recipient + copy before sending).
class ThreatSmsTemplate {
  final String label;
  final String text;
  final IconData icon;

  const ThreatSmsTemplate({
    required this.label,
    required this.text,
    required this.icon,
  });
}

const kThreatSmsTemplates = <ThreatSmsTemplate>[
  ThreatSmsTemplate(
    label: 'Intruder warning',
    icon: LucideIcons.shieldAlert,
    text: 'KSPONSOR SECURITY: Failed logins using your number were blocked. If not you, contact support now.',
  ),
  ThreatSmsTemplate(
    label: 'Suspicious activity',
    icon: LucideIcons.eyeOff,
    text: 'KSPONSOR SECURITY: Suspicious activity on your number. Contact support if this was not you.',
  ),
  ThreatSmsTemplate(
    label: 'Account at risk',
    icon: LucideIcons.userX,
    text: 'KSPONSOR: Repeated attack attempts linked to your number. It may be suspended if they continue.',
  ),
  ThreatSmsTemplate(
    label: 'Content violation',
    icon: LucideIcons.alertTriangle,
    text: 'KSPONSOR: Your campaign breaks our rules and may be removed. Contact support to resolve it.',
  ),
  ThreatSmsTemplate(
    label: 'Harassment warning',
    icon: LucideIcons.ban,
    text: 'KSPONSOR: Harassment is not allowed. Continued abuse will lead to a permanent ban.',
  ),
  ThreatSmsTemplate(
    label: 'Final warning',
    icon: LucideIcons.gavel,
    text: 'KSPONSOR: Final warning for policy violations. Your account will be banned unless it stops now.',
  ),
];

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  String _tab = 'overview';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpTo(String id) {
    final key = _sectionKeys[id];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Key _newKey(String id) {
    final k = GlobalKey();
    _sectionKeys[id] = k;
    return k;
  }

  bool _can(String scope) {
    final auth = ref.read(authControllerProvider).value;
    return auth?.canScope(scope) ?? false;
  }

  String _scopeLabel(String scope) => switch (scope) {
    'campaigns' => 'Campaigns',
    'donations' => 'Donations & payouts',
    'tickets' => 'Support tickets',
    'users' => 'Users',
    'settings' => 'Settings',
    'finance' => 'Finance',
    'restore' => 'Restore',
    _ => scope,
  };

  static const _sectionLabels = <(String, String, IconData)>[
    ('stats', 'Stats', LucideIcons.barChart3),
    ('apps', 'Applications', LucideIcons.userCheck),
    ('top', 'Top campaigns', LucideIcons.trophy),
    ('users', 'New users', LucideIcons.userPlus),
    ('promos', 'Promotions', LucideIcons.star),
    ('tickets', 'Tickets', LucideIcons.headphones),
    ('deletes', 'Delete requests', LucideIcons.trash2),
  ];

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminDataProvider);
    final auth = ref.watch(authControllerProvider).value;
    final isAssistant = (auth?.isAdmin ?? false) == false && (auth?.assistantScopes.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(adminDataProvider),
          ),
        ],
      ),
       body: admin.when(
         loading: () => const Center(child: AppIconSpinner()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(friendlyError(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(adminDataProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'overview',
                    label: Text('Overview'),
                    icon: Icon(LucideIcons.layoutGrid, size: 16),
                  ),
                  ButtonSegment(
                    value: 'tools',
                    label: Text('Tools & settings'),
                    icon: Icon(LucideIcons.settings, size: 16),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStatePropertyAll(Color(0xFF151521)),
                  foregroundColor: WidgetStatePropertyAll(Colors.white),
                  side: WidgetStatePropertyAll(BorderSide(color: Color(0xFF2A2A3A))),
                ),
              ),
            ),
            if (isAssistant)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shield, size: 15, color: Color(0xFF8A6A00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You\'re an assistant. Access is limited to: '
                          '${(auth?.assistantScopes ?? const {}).map(_scopeLabel).join(', ')}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B5200), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminDataProvider),
                child: _tab == 'tools'
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const _BackupMenuSection(),
                          const SizedBox(height: 12),
                          const _SmsToolsSection(),
                          const SizedBox(height: 12),
                          const _PushBroadcastSection(),
                          const SizedBox(height: 12),
                          if (_can('settings'))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.image, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Sample images',
                                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                          Text('Upload posters hosts & events can reuse',
                                              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => context.push('/admin/sample-images'),
                                      icon: const Icon(LucideIcons.upload, size: 15),
                                      label: const Text('Manage'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (_can('settings'))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.ticket, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Fees & commissions',
                                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                          Text('Event finder\'s fee, platform %, minimums (MoMo + card)',
                                              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => context.push('/admin/event-commission'),
                                      icon: const Icon(LucideIcons.wallet, size: 15),
                                      label: const Text('Edit'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.barChart3, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Analytics & reports',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        Text('Donation trends, conversion, top events, weekly email report',
                                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => context.push('/admin/analytics'),
                                    icon: const Icon(LucideIcons.trendingUp, size: 15),
                                    label: const Text('Open'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.messageCircle, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Team Chat',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        Text('Private staff group chat with image sharing',
                                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => context.push('/team-chat'),
                                    icon: const Icon(LucideIcons.send, size: 15),
                                    label: const Text('Open'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.qrCode, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Confirm users by QR',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        Text('Scan a user\'s profile code to verify them',
                                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => context.push('/admin/scan-qr'),
                                    icon: const Icon(LucideIcons.scanLine, size: 15),
                                    label: const Text('Scan'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.receipt, color: AppColors.gold, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Tax & Compliance',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        Text('Turnover tax, invoices, due dates and compliance',
                                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => context.push('/admin/tax'),
                                    icon: const Icon(LucideIcons.banknote, size: 15),
                                    label: const Text('Open'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: _newKey('promos'),
                            child: _PromotionsSection(),
                          ),
                          const SizedBox(height: 12),
                          const _PromoConfigSection(),
                          const SizedBox(height: 12),
                          const AirtimeAdminConfig(),
                          const SizedBox(height: 12),
                          const BadgeAdminConfig(),
                          const SizedBox(height: 12),
                          const _MtnStatusSection(),
                          const SizedBox(height: 12),
                          const _FailedLoginsSection(),
                          const SizedBox(height: 12),
                          const _TelegramConfigSection(),
                          const SizedBox(height: 12),
                          const _BanSection(),
                          const SizedBox(height: 12),
                          const _PushStatusSection(),
                        ],
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 44,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final (id, label, icon) in _sectionLabels)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                                      child: ActionChip(
                                        avatar: Icon(icon, size: 14, color: AppColors.primary),
                                        label: Text(label),
                                        onPressed: () => _jumpTo(id),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: _newKey('stats'),
                              child: _StatGrid(stats: data.stats, auth: ref.watch(authControllerProvider).value),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (_can('donations'))
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () => context.push('/admin/transactions'),
                                      icon: const Icon(LucideIcons.receipt, size: 18),
                                      label: const Text('Transactions'),
                                    ),
                                  ),
                                if (_can('donations')) const SizedBox(width: 10),
                                if (_can('donations'))
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () => context.push('/admin/disbursements'),
                                      icon: const Icon(LucideIcons.send, size: 18),
                                      label: const Text('Payouts & sweeps'),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (_can('campaigns'))
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () => context.push('/admin/campaigns'),
                                      icon: const AppBrandIcon(size: 18),
                                      label: const Text('Campaigns'),
                                    ),
                                  ),
                                if (_can('campaigns')) const SizedBox(width: 10),
                                if (_can('donations'))
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () => context.push('/admin/lipila-logs'),
                                      icon: const Icon(LucideIcons.list, size: 18),
                                      label: const Text('Lipila logs'),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            KeyedSubtree(
                              key: _newKey('apps'),
                              child: _ApplicationsSection(applications: data.applications),
                            ),
                            const SizedBox(height: 20),
                            if (data.topCampaigns.isNotEmpty) ...[
                              KeyedSubtree(
                                key: _newKey('top'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionTitle(
                                      icon: LucideIcons.trophy,
                                      title: 'Top campaigns',
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _countBadge(data.topCampaigns.length),
                                          TextButton.icon(
                                            onPressed: () => context.push('/admin/campaigns'),
                                            icon: const Icon(LucideIcons.list, size: 14),
                                            label: const Text('View all'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Column(
                                        children: [
                                          for (final c in data.topCampaigns)
                                            ListTile(
                                              dense: true,
                                              leading: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: SizedBox(
                                                  width: 32,
                                                  height: 32,
                                                  child: CampaignImage(campaign: c, fit: BoxFit.cover),
                                                ),
                                              ),
                                              title: Text(c.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                                              subtitle: Text('${formatKwacha(c.raisedCents)} of ${c.goalLabel}'),
                                              trailing: Text(
                                                '${(c.progress * 100).round()}%',
                                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                                              ),
                                              onTap: () => context.push('/campaign/${c.id}'),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ],
                            if (data.topDonors.isNotEmpty) ...[
                              _SectionTitle(
                                icon: LucideIcons.users,
                                title: 'Top supporters',
                                trailing: _countBadge(data.topDonors.length),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                child: Column(
                                  children: [
                                    for (final d in data.topDonors)
                                      ListTile(
                                        dense: true,
                                        leading: Avatar(name: d.username, radius: 16),
                                        title: Text(d.username, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        trailing: Text(
                                          formatKwacha(d.totalCents),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (data.topReferrers.isNotEmpty) ...[
                              _SectionTitle(
                                icon: LucideIcons.userPlus,
                                title: 'Top referrers',
                                trailing: _countBadge(data.topReferrers.length),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                child: Column(
                                  children: [
                                    for (final r in data.topReferrers)
                                      ListTile(
                                        dense: true,
                                        leading: Avatar(name: r.username, radius: 16),
                                        title: Text(r.username,
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                        trailing: Text(
                                          '${r.invites} invites',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (data.recent.isNotEmpty) ...[
                              _SectionTitle(
                                icon: LucideIcons.receipt,
                                title: 'Recent contributions',
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _countBadge(data.recent.length),
                                    TextButton.icon(
                                      onPressed: () => context.push('/admin/transactions'),
                                      icon: const Icon(LucideIcons.list, size: 14),
                                      label: const Text('View all'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                child: Column(
                                  children: [
                                    for (final r in data.recent)
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(LucideIcons.coins, color: AppColors.primary, size: 20),
                                        title: Text('${r.username} • ${formatKwacha(r.amountCents)}',
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                        subtitle: Text('${r.campaignTitle}\n${r.date}'),
                                        isThreeLine: true,
                                        trailing: Text(
                                          '+${formatKwacha(r.platformFeeCents)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            if (data.recentUsers.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              KeyedSubtree(
                                key: _newKey('users'),
                                child: _SectionTitle(
                                  icon: LucideIcons.userPlus,
                                  title: 'New users',
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _countBadge(data.recentUsers.length),
                                      TextButton.icon(
                                        onPressed: () => context.push('/admin/users'),
                                        icon: const Icon(LucideIcons.list, size: 14),
                                        label: const Text('View all'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                child: Column(
                                  children: [
                                    for (final r in data.recentUsers)
                                      ListTile(
                                        dense: true,
                                        leading: Avatar(name: r.username, radius: 16),
                                        title: Text(
                                          r.displayName,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        subtitle: Text('${r.phone}\n${r.createdAt}'),
                                        isThreeLine: true,
                                        trailing: Text(
                                          _hostBadgeLabel(r.hostStatus),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: r.hostStatus == 'approved'
                                                ? AppColors.primary
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            KeyedSubtree(
                              key: _newKey('tickets'),
                              child: const _TicketsSection(),
                            ),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: _newKey('deletes'),
                              child: const _DeleteRequestsSection(),
                            ),
                          ],
                        ),
                      ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin: broadcast a push notification to all users / hosts / donors.
class _PushBroadcastSection extends ConsumerStatefulWidget {
  const _PushBroadcastSection();

  @override
  ConsumerState<_PushBroadcastSection> createState() => _PushBroadcastSectionState();
}

class _PushBroadcastSectionState extends ConsumerState<_PushBroadcastSection> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _group = 'all';
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a title and message.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send broadcast push?'),
        content: Text('Notify everyone in "${_group == 'all' ? 'All users' : _group == 'hosts' ? 'Approved hosts' : 'Donors'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      final res = await ref.read(apiClientProvider).sendPushBroadcast(_group, title, message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Broadcast sent')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.bellRing, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text('Push broadcast', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Send an urgent push to everyone, hosts, or donors (maintenance, updates).',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _group,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All users')),
                DropdownMenuItem(value: 'hosts', child: Text('Approved hosts')),
                DropdownMenuItem(value: 'donors', child: Text('Donors')),
              ],
              onChanged: (v) => setState(() => _group = v ?? 'all'),
              decoration: const InputDecoration(labelText: 'Audience', isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Title', isDense: true),
              initialValue: '',
              controller: _titleController,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Message', isDense: true),
              controller: _messageController,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.send, size: 16),
              label: Text(_sending ? 'Sending…' : 'Send broadcast'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One "Backup & export" card — the file type is chosen from a menu instead of
/// three separate buttons eating the whole dashboard.
class _BackupMenuSection extends ConsumerWidget {
  const _BackupMenuSection();

  Future<void> _download(BuildContext context, WidgetRef ref, String path, String fileName) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(apiClientProvider);
    final token = api.token;
    if (token == null) {
      messenger.showSnackBar(const SnackBar(content: Text('You are not signed in.')));
      return;
    }
    final snack = messenger.showSnackBar(const SnackBar(content: Text('Downloading…')));
    try {
      final res = await http.get(
        Uri.parse(api.adminExportUrl(path)),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) {
        throw Exception('Download failed (${res.statusCode})');
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved $fileName'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => OpenFile.open(file.path),
          ),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      snack.close();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.databaseBackup, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text('Backup & export',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Choose export type',
                  onSelected: (value) {
                    switch (value) {
                      case 'csv':
                        _download(context, ref, '/api/admin/stats/export.csv', 'kingdom_sponsor_stats.csv');
                      case 'pdf':
                        _download(context, ref, '/api/admin/stats/export.pdf', 'kingdom_sponsor_report.pdf');
                      case 'json':
                        _download(context, ref, '/api/admin/backup/export', 'kingdom_sponsor_backup.json');
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'csv',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(LucideIcons.fileSpreadsheet, size: 18, color: AppColors.primary),
                        title: Text('Stats CSV'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(LucideIcons.fileText, size: 18, color: AppColors.primary),
                        title: Text('PDF report'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'json',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(LucideIcons.database, size: 18, color: AppColors.primary),
                        title: Text('Full backup (JSON)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Stats CSV, PDF report and the full database backup are all inside the menu.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// SMS tools: send a broadcast to any number(s), edit the sign-in notice, and
/// inspect recent delivery activity (so MTN-style failures are visible).
class _SmsToolsSection extends ConsumerStatefulWidget {
  const _SmsToolsSection();

  @override
  ConsumerState<_SmsToolsSection> createState() => _SmsToolsSectionState();
}

class _SmsToolsSectionState extends ConsumerState<_SmsToolsSection> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  final _noticeController = TextEditingController();
  final _groupMessageController = TextEditingController();
  bool _sending = false;
  bool _savingNotice = false;
  bool _loadingActivity = false;
  bool _sendingGroup = false;
  String _group = 'all_users';
  final Map<String, String> _groupOptions = {
    'all_users': 'All users',
    'new_7d': 'New users (7 days)',
    'new_30d': 'New users (30 days)',
    'hosts': 'Approved hosts',
    'donors': 'Donors (made a gift)',
    'active_30d': 'Active last 30 days',
  };
  List<dynamic> _activity = [];
  Map<String, String> _netStatus = {};

  @override
  void initState() {
    super.initState();
    _loadNotice();
    _loadNetworkStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    _noticeController.dispose();
    _groupMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadNotice() async {
    try {
      final res = await ref.read(apiClientProvider).getSmsNotice();
      if (mounted) {
        _noticeController.text = (res['text'] as String? ?? '');
        final nets = res['networks'] as Map<String, dynamic>? ?? {};
        setState(() {
          _netStatus = nets.map((k, v) => MapEntry(k, v as String? ?? 'ok'));
        });
      }
    } catch (_) {}
  }

  Future<void> _loadNetworkStatus() async {
    try {
      final res = await ref.read(apiClientProvider).getNetworkStatus();
      if (mounted) {
        setState(() {
          _netStatus = (res['networks'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v as String? ?? 'ok'));
        });
      }
    } catch (_) {}
  }

  Future<void> _saveNotice() async {
    setState(() => _savingNotice = true);
    try {
      await ref.read(apiClientProvider).setSmsStatus(_noticeController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice saved — shown on the sign-in screen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _savingNotice = false);
    }
  }

  Future<void> _sendBroadcast() async {
    final phones = _phoneController.text.trim();
    final message = _messageController.text.trim();
    if (phones.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a phone number and a message.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await ref.read(apiClientProvider).sendAdminSms(phones, message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'SMS sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendGroup() async {
    final message = _groupMessageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a message for the group.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to group?'),
        content: Text(
          'Send to everyone in "${_groupOptions[_group] ?? _group}"? Each recipient gets one SMS from KSPONSOR.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sendingGroup = true);
    try {
      final res = await ref.read(apiClientProvider).sendGroupSms(_group, message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Group SMS sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sendingGroup = false);
    }
  }

  Future<void> _loadActivity() async {
    setState(() => _loadingActivity = true);
    try {
      final events = await ref.read(apiClientProvider).getSmsActivity();
      if (mounted) setState(() => _activity = events);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load SMS activity.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingActivity = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.messageSquare, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text('SMS tools', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Send an SMS to any number (in-app or outside).',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number(s)',
                hintText: '+260977123456 or comma-separated numbers',
                prefixIcon: Icon(LucideIcons.phone, size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Threat / intruder templates (tap to draft, then send)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in kThreatSmsTemplates)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(t.icon, size: 13, color: AppColors.danger),
                    label: Text(t.label, style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _messageController.text = t.text),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 96,
              decoration: const InputDecoration(
                labelText: 'Message (max 96 chars = one SMS)',
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _sending ? null : _sendBroadcast,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.send, size: 16),
              label: Text(_sending ? 'Sending…' : 'Send SMS'),
            ),
            const Divider(height: 28),
            const Text('Group broadcast (send to a filtered audience)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _group,
              items: [
                for (final e in _groupOptions.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _group = v ?? 'all_users'),
              decoration: const InputDecoration(
                labelText: 'Audience',
                prefixIcon: Icon(LucideIcons.users, size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupMessageController,
              maxLines: 3,
              maxLength: 96,
              decoration: const InputDecoration(
                labelText: 'Group message (max 96 chars)',
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _sendingGroup ? null : _sendGroup,
              icon: _sendingGroup
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.megaphone, size: 16),
              label: Text(_sendingGroup ? 'Sending to group…' : 'Send to group'),
            ),
            const Divider(height: 28),
            const Text('Sign-in notice (tells users about outages without burning SMS)',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _noticeController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Notice text',
                hintText: 'e.g. MTN SMS is temporarily down — you may not receive codes. Use WhatsApp instead.',
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final e in _netStatus.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        '${_networkLabel(e.key)}: ${e.value == 'down' ? 'DOWN' : 'OK'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: e.value == 'down' ? AppColors.danger : AppColors.primary,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: (e.value == 'down' ? AppColors.danger : AppColors.primary).withValues(alpha: 0.1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _savingNotice ? null : _saveNotice,
              icon: _savingNotice
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.save, size: 16),
              label: Text(_savingNotice ? 'Saving…' : 'Save notice'),
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Text('SMS delivery activity',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadingActivity ? null : _loadActivity,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_loadingActivity)
              const LinearProgressIndicator()
            else if (_activity.isEmpty)
              Text('Tap Refresh to see recent SMS delivery reports.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _activity.length,
                  itemBuilder: (context, i) {
                    final e = _activity[i];
                    final status = (e['status'] as String? ?? '').toString();
                    final isFail = status.toLowerCase().contains('fail') || status.toLowerCase().contains('reject');
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isFail ? LucideIcons.xCircle : LucideIcons.checkCircle,
                        size: 18,
                        color: isFail ? AppColors.danger : AppColors.primary,
                      ),
                      title: Text('${e['phone'] ?? ''} — $status',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${e['kind'] ?? ''} • ${e['receivedAt'] ?? ''}\n${(e['payload'] as String? ?? '').replaceAll('\n', ' ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PromoConfigSection extends ConsumerStatefulWidget {
  const _PromoConfigSection();

  @override
  ConsumerState<_PromoConfigSection> createState() => _PromoConfigSectionState();
}

class _PromoConfigSectionState extends ConsumerState<_PromoConfigSection> {
  int? _priceCents;
  int? _days;
  int? _slots;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).getPromotionConfig();
      if (mounted) {
        setState(() {
          _priceCents = res['priceCents'] as int?;
          _days = res['days'] as int?;
          _slots = res['slots'] as int? ?? 5;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final priceController =
        TextEditingController(text: ((_priceCents ?? 15000) / 100).toStringAsFixed(0));
    final daysController = TextEditingController(text: '${_days ?? 7}');
    final slotsController = TextEditingController(text: '${_slots ?? 5}');
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Promotion paywall'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (K)',
                      helperText: 'What hosts pay to reach the promoted slots',
                      prefixText: 'K ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Days (1-30)',
                      helperText: 'How long the promotion stays live',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slotsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Slots (1-20)',
                      helperText: 'How many campaigns can be promoted at once',
                    ),
                  ),
                ],
              ),
            ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final price = int.tryParse(priceController.text.trim());
                      final days = int.tryParse(daysController.text.trim());
                      final slots = int.tryParse(slotsController.text.trim());
                      if (price == null || days == null || slots == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter valid numbers')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(apiClientProvider)
                            .setPromotionConfig(price * 100, days, slots: slots);
                        if (ctx.mounted) {
                          Navigator.pop(ctx, true);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Promotion settings saved')),
                          );
                        }
                        await _load();
                      } on ApiException catch (e) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      } catch (_) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Could not save. Try again.')),
                          );
                        }
                      }
                    },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _load();
    priceController.dispose();
    daysController.dispose();
    slotsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.settings, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text('Promotion paywall', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _loading
                  ? 'Loading…'
                  : '${formatKwacha(_priceCents ?? 15000)} for ${_days ?? 7} days • ${_slots ?? 5} slots — Set by admin',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(LucideIcons.pencil, size: 14),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Push notification status + test for the admin dashboard.
class _PushStatusSection extends ConsumerStatefulWidget {
  const _PushStatusSection();

  @override
  ConsumerState<_PushStatusSection> createState() => _PushStatusSectionState();
}

class _PushStatusSectionState extends ConsumerState<_PushStatusSection> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).getPushStatus();
      if (mounted) setState(() { _status = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testPush() async {
    setState(() => _testing = true);
    try {
      final res = await ref.read(apiClientProvider).sendTestPush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Test push sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = _status?['pushConfigured'] == true;
    final totalTokens = _status?['totalTokens'] as int? ?? 0;
    final usersWithTokens = _status?['usersWithTokens'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.bellRing, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Push notifications', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const LinearProgressIndicator()
            else ...[
              Row(
                children: [
                  Icon(configured ? LucideIcons.checkCircle : LucideIcons.xCircle,
                      size: 16, color: configured ? AppColors.primary : AppColors.danger),
                  const SizedBox(width: 6),
                  Text(configured ? 'Firebase configured' : 'Firebase NOT configured',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: configured ? AppColors.primary : AppColors.danger,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
              const SizedBox(height: 4),
              _StatusRow(
                icon: _status?['firebaseEmailConfigured'] == true
                    ? LucideIcons.checkCircle
                    : LucideIcons.xCircle,
                ok: _status?['firebaseEmailConfigured'] == true,
                text: _status?['firebaseEmailConfigured'] == true
                    ? 'Service account email configured'
                    : 'Service account email missing',
              ),
              _StatusRow(
                icon: _status?['firebaseKeyConfigured'] == true
                    ? LucideIcons.checkCircle
                    : LucideIcons.xCircle,
                ok: _status?['firebaseKeyConfigured'] == true,
                text: _status?['firebaseKeyConfigured'] == true
                    ? 'Private key configured'
                    : 'Private key missing',
              ),
              const SizedBox(height: 4),
              Text('Device tokens: $totalTokens (users: $usersWithTokens)',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
              if ((_status?['pendingWithdrawals'] as int? ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.alertTriangle,
                        size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      '${_status?['pendingWithdrawals']} payout${_status?['pendingWithdrawals'] == 1 ? '' : 's'} waiting for confirmation',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
              if (!configured) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Set FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY secrets via wrangler to enable push.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testPush,
                    icon: _testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.send, size: 14),
                    label: Text(_testing ? 'Sending…' : 'Send Test Push'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _load, child: const Text('Refresh')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small check/cross row used in the push status card.
class _StatusRow extends StatelessWidget {
  final IconData icon;
  final bool ok;
  final String text;

  const _StatusRow({
    required this.icon,
    required this.ok,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ok ? AppColors.primary : AppColors.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ok ? AppColors.textMuted : AppColors.danger,
                fontWeight: ok ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketsSection extends ConsumerStatefulWidget {
  const _TicketsSection();

  @override
  ConsumerState<_TicketsSection> createState() => _TicketsSectionState();
}

class _TicketsSectionState extends ConsumerState<_TicketsSection> {
  List<dynamic> _tickets = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';
  String _assistantName = 'Kingdom Sponsor Care Team';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = _statusFilter == 'all' ? '' : _statusFilter;
      final (tickets, assistantName) =
          await ref.read(apiClientProvider).getAdminTickets(status: status);
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _assistantName = assistantName;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load tickets.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editAssistantName() async {
    final controller = TextEditingController(text: _assistantName);
    String? errorText;
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Support assistant'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The name is signed under automatic confirmations and '
                  'reply SMS texts sent to users.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Assistant name',
                    prefixIcon: Icon(LucideIcons.user, size: 18),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 4),
                  Text(errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Name is required.');
                  return;
                }
                try {
                  await ref.read(apiClientProvider).setSupportAssistantName(name);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Assistant name saved as "$name"')),
                    );
                  }
                } on ApiException catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => errorText = e.message);
                  }
                } catch (_) {
                  if (ctx.mounted) {
                    setDialogState(() => errorText = 'Could not save. Try again.');
                  }
                }
              },
              icon: const Icon(LucideIcons.save, size: 16),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (ok == true) await _load();
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'open' => 'Open',
      'answered' => 'Answered',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      _ => status ?? 'Unknown',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'open' => AppColors.danger,
      'answered' => AppColors.gold,
      'resolved' => AppColors.primary,
      'closed' => AppColors.textMuted,
      _ => AppColors.textMuted,
    };
  }

  Future<void> _resolve(Map<String, dynamic> ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve ticket?'),
        content: const Text('Mark this ticket as resolved. The user will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).resolveSupportTicket(ticket['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket resolved')),
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resolve ticket.')),
        );
      }
    }
  }

  Future<void> _viewDetails(Map<String, dynamic> ticket) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('#${ticket['id']} ${ticket['subject'] ?? 'No subject'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From: ${ticket['username'] ?? 'Giver'} • ${ticket['phone'] ?? ''}'),
              const SizedBox(height: 4),
              Text('Status: ${ticket['status'] ?? 'open'}'),
              const SizedBox(height: 4),
              Text('Date: ${safePrefix(ticket['createdAt'], 16)}'),
              const SizedBox(height: 12),
              const Text('Message:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(ticket['message'] ?? 'No message'),
              if (ticket['adminReply'] != null) ...[
                const SizedBox(height: 12),
                const Text('Admin reply:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(ticket['adminReply']?.toString() ?? ''),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if ((ticket['status'] ?? 'open') != 'resolved')
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _reply(ticket);
              },
              icon: const Icon(LucideIcons.reply, size: 15),
              label: const Text('Reply'),
            ),
        ],
      ),
    );
  }

  static const _quickReplies = <String>[
    'Hi, thank you for reaching out. We are looking into this and will update you soon.',
    'Thanks for your patience. Your payout has been processed and should reflect shortly.',
    'Sorry for the wait — this has been escalated and we will reply as soon as we have an update.',
    'Thank you for the report. This has been fixed on our end — please try again and let us know if it persists.',
  ];

  Future<void> _reply(Map<String, dynamic> ticket) async {
    final text = TextEditingController();
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Reply to #${ticket['id']}'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick replies',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final q in _quickReplies)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          q,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => setDialogState(() => text.text = q),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: text,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Reply (user is notified by push; SMS if no app)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ListenableBuilder(
              listenable: text,
              builder: (context, _) {
                final ready = text.text.trim().isNotEmpty;
                return FilledButton(
                  onPressed: saving || !ready
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            await ref.read(apiClientProvider).replySupportTicket(
                                ticket['id'] as int, text.text.trim());
                            if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Reply sent to the user')),
                              );
                            }
                          } on ApiException catch (e) {
                            setDialogState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx)
                                  .showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          } catch (_) {
                            setDialogState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Could not send. Try again.')),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                );
              },
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _load();
    text.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: LucideIcons.messageCircle,
          title: 'Support tickets',
          trailing: _loading
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_tickets.isNotEmpty) ...[
                      _countBadge(_tickets.length),
                      const SizedBox(width: 6),
                    ],
                    TextButton.icon(
                      onPressed: _editAssistantName,
                      icon: const Icon(LucideIcons.user, size: 14),
                      label: Text(
                        _assistantName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(onPressed: _load, child: const Text('Refresh')),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        // Status filter
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (value, label) in [('all', 'All'), ('open', 'Open'), ('answered', 'Answered'), ('resolved', 'Resolved')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _statusFilter == value,
                    onSelected: (selected) {
                      if (selected) setState(() => _statusFilter = value);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: AppIconSpinner())
        else if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$_error',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.danger)),
            ),
          )
        else if (_tickets.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No tickets found.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
          )
        else
          for (final t in _tickets)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _viewDetails(t),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${t['id']} ${t['subject'] ?? ''}',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(t['status']).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _statusLabel(t['status']),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(t['status']),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            safeDate(t['createdAt']),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${t['username'] ?? 'Giver'} • ${t['phone'] ?? ''}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(t['message'] ?? '',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (t['adminReply'] != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.cornerDownRight, size: 12, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t['adminReply'],
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(LucideIcons.hand, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('Tap to view details', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                          const Spacer(),
                          if ((t['status'] ?? 'open') != 'resolved') ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () => _resolve(t),
                              icon: const Icon(LucideIcons.check, size: 14),
                              label: const Text('Resolve'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _reply(t),
                            icon: const Icon(LucideIcons.reply, size: 15),
                            label: Text((t['adminReply'] != null) ? 'Reply again' : 'Reply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _DeleteRequestsSection extends ConsumerStatefulWidget {
  const _DeleteRequestsSection();

  @override
  ConsumerState<_DeleteRequestsSection> createState() =>
      _DeleteRequestsSectionState();
}

class _DeleteRequestsSectionState extends ConsumerState<_DeleteRequestsSection> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await ref.read(apiClientProvider).getDeleteRequests();
      if (mounted) setState(() => _requests = requests);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load delete requests.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> request, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Delete this campaign?' : 'Reject delete request?'),
        content: Text(
          approve
              ? 'The campaign and its public data will be removed, and the '
                  'host and all donors will be notified. This cannot be undone.'
              : 'The host will be notified that the campaign stays up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Delete campaign' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(request['id'] as int));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final id = request['id'] as int;
      if (approve) {
        await api.approveDeleteRequest(id);
      } else {
        await api.rejectDeleteRequest(id);
      }
      await _load();
      messenger.showSnackBar(SnackBar(
          content: Text(approve ? 'Campaign removed' : 'Request rejected')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Action failed. Try again.')));
    } finally {
      if (mounted) setState(() => _busy.remove(request['id'] as int));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: LucideIcons.trash2,
          title: 'Campaign delete requests',
          trailing: _loading
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_requests.isNotEmpty) ...[
                      _countBadge(_requests.length),
                      const SizedBox(width: 6),
                    ],
                    TextButton(onPressed: _load, child: const Text('Refresh')),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: AppIconSpinner())
        else if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$_error',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.danger)),
            ),
          )
        else if (_requests.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No delete requests.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
          )
        else
          for (final r in _requests)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['campaignTitle'] ?? 'Campaign',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('${r['hostUsername'] ?? 'Host'} • ${r['hostPhone'] ?? ''}',
                        style: theme.textTheme.bodySmall),
                    if (r['reason'] != null && (r['reason'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Reason: ${r['reason']}',
                            style: theme.textTheme.bodySmall),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_busy.contains(r['id']))
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _decide(r, true),
                              icon: const Icon(LucideIcons.trash, size: 15),
                              label: const Text('Delete'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _decide(r, false),
                              icon: const Icon(LucideIcons.x, size: 15),
                              label: const Text('Keep'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _PromotionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions = ref.watch(promotionsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _SectionTitle(icon: LucideIcons.star, title: 'Promoted campaigns (top 5)'),
        const SizedBox(height: 8),
        promotions.when(
          loading: () => const Center(child: AppIconSpinner()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(friendlyError(e), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          ),
          data: (items) => items.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No promotions yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                )
              : Card(
                  child: Column(
                    children: [
                      for (final p in items)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _statusColor(p.status).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    p.status == 'active'
                                        ? LucideIcons.star
                                        : p.status == 'pending_approval'
                                            ? LucideIcons.hourglass
                                            : LucideIcons.clock,
                                    size: 16,
                                    color: _statusColor(p.status),
                                  ),
                                ),
                                title: Text(p.campaignTitle,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Host: ${p.hostPhone}'),
                                    Text(
                                        '${formatKwacha(p.amountCents)} • ${p.days} days • ${p.status}'),
                                    if (p.expiresAt != null)
                                      Text(
                                          'Expires: ${safeDate(p.expiresAt)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Text(
                                  safeDate(p.createdAt),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ),
                              if (p.status == 'pending_approval') ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Approve promotion?'),
                                              content: Text(
                                                  'The campaign will be promoted to the top-5 '
                                                  'list for ${p.days} days and the host will be notified.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Approve'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true || !context.mounted) return;
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final res = await ref
                                              .read(promotionsProvider.notifier)
                                              .decide(p.id, approve: true);
                                          messenger.showSnackBar(SnackBar(
                                              content: Text(res['message']
                                                      as String? ??
                                                  'Promotion approved')));
                                        },
                                        icon: const Icon(LucideIcons.check, size: 15),
                                        label: const Text('Approve'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Reject promotion?'),
                                              content: Text(
                                                  'The host will be notified by SMS. Contact them to arrange a refund.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                      backgroundColor: AppColors.danger),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Reject'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true || !context.mounted) return;
                                          final messenger = ScaffoldMessenger.of(context);
                                          final res = await ref
                                              .read(promotionsProvider.notifier)
                                              .decide(p.id, approve: false);
                                          messenger.showSnackBar(SnackBar(
                                              content: Text(res['message']
                                                      as String? ??
                                                  'Promotion rejected')));
                                        },
                                        icon: const Icon(LucideIcons.x, size: 15),
                                        label: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (p.status == 'rejected' ||
                                  p.status == 'expired' ||
                                  p.status == 'active') ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      foregroundColor: AppColors.danger,
                                      side: const BorderSide(color: AppColors.danger),
                                    ),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Refund promotion fee?'),
                                          content: Text(
                                              '${formatKwacha(p.amountCents)} will be sent back to the host\'s mobile money (${p.hostPhone}).'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                  backgroundColor: AppColors.danger),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Refund'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true || !context.mounted) return;
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        final res = await ref
                                            .read(apiClientProvider)
                                            .refundPromotion(p.id);
                                        ref.invalidate(promotionsProvider);
                                        messenger.showSnackBar(SnackBar(
                                            content: Text(res['message']
                                                    as String? ??
                                                'Refund started')));
                                      } on ApiException catch (e) {
                                        messenger.showSnackBar(
                                            SnackBar(content: Text(e.message)));
                                      }
                                    },
                                    icon: const Icon(LucideIcons.rotateCcw, size: 15),
                                    label: const Text('Refund'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.primary;
      case 'pending':
        return AppColors.gold;
      case 'pending_approval':
        return AppColors.gold;
      case 'expired':
        return AppColors.textMuted;
      case 'rejected':
        return AppColors.danger;
      case 'refunded':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }
}

class _StatGrid extends StatelessWidget {
  final AdminStats stats;
  final AuthState? auth;

  const _StatGrid({required this.stats, this.auth});

  bool _can(String scope) => auth?.canScope(scope) ?? false;
  bool get _isAdmin => auth?.isAdmin ?? false;

  void _openTile(
    BuildContext context,
    AdminTileKind kind,
    String title,
    IconData icon,
    List<(String, String)> rows,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminTileDetailScreen(
          title: title,
          icon: icon,
          color: AppColors.primary,
          kind: kind,
          breakdown: rows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        if (_can('campaigns'))
          _StatCard(
            icon: LucideIcons.trophy,
            label: 'Active campaigns',
            value: '${stats.activeCampaigns}',
            color: AppColors.primaryLight,
            onTap: () => context.push('/admin/campaigns'),
            info: 'Fundraisers currently open for donations. Tap to manage campaigns.',
          ),
        _StatCard(
          icon: LucideIcons.walletCards,
          label: 'Total raised (active)',
          value: formatKwacha(stats.totalActiveRaisedCents),
          color: AppColors.primary,
          onTap: () => _openTile(
            context,
            AdminTileKind.campaigns,
            'Total raised',
            LucideIcons.walletCards,
            [
              ('Total raised (active campaigns)', formatKwacha(stats.totalActiveRaisedCents)),
              ('Total raised (all time)', formatKwacha(stats.totalRaisedCents)),
              ('Active campaigns', '${stats.activeCampaigns}'),
              ('Confirmed donations', '${stats.confirmedDonations}'),
            ],
          ),
          info: 'Total confirmed donations across all active campaigns. Tap for the per-campaign breakdown.',
        ),
        _StatCard(
          icon: LucideIcons.banknote,
          label: 'Total processed',
          value: formatKwacha(stats.totalProcessedCents),
          color: AppColors.primary,
          onTap: () => _openTile(
            context,
            AdminTileKind.campaigns,
            'Total processed',
            LucideIcons.banknote,
            [
              ('Total processed (all time)', formatKwacha(stats.totalProcessedCents)),
              ('Total raised (all time)', formatKwacha(stats.totalRaisedCents)),
              ('Confirmed donations', '${stats.confirmedDonations}'),
              ('Processing fees', formatKwacha(stats.platformFeesCents)),
            ],
          ),
          info: 'Every kwacha that moved through the platform — confirmed '
              'donations, successful payouts and fee sweeps — since launch.',
        ),
        _StatCard(
          icon: LucideIcons.users,
          label: 'Donors',
          value: '${stats.donors}',
          color: AppColors.gold,
          onTap: () => context.push('/admin/transactions'),
          info: 'Distinct people who completed at least one donation.',
        ),
        if (_can('donations'))
          _StatCard(
            icon: LucideIcons.mail,
            label: 'Donor emails',
            value: '${stats.cardEmails}',
            color: stats.cardEmails > 0 ? AppColors.primary : AppColors.primaryLight,
            onTap: () => context.push('/admin/emails'),
            info: 'Emails captured from card donors and card ticket buyers. '
                'Tap for the full list with giving totals — copy any email in one tap.',
          ),
        if (_can('users'))
          _StatCard(
            icon: LucideIcons.userPlus,
            label: 'Users',
            value: '${stats.usersTotal}',
            color: AppColors.gold,
            onTap: () => context.push('/admin/users'),
            info: 'Every phone number that verified with an SMS code. Tap for the full list by name & number.',
          ),
        _StatCard(
          icon: LucideIcons.coins,
          label: 'Processing fees',
          value: formatKwacha(stats.platformFeesCents),
          color: AppColors.primary,
          onTap: () => context.push('/admin/disbursements'),
          info: 'Earned processing fees from donations and payouts.',
        ),
        _StatCard(
          icon: LucideIcons.trendingUp,
          label: 'Per day',
          value: formatKwacha(stats.dailyRateCents),
          color: AppColors.primaryLight,
          onTap: () => context.push('/admin/transactions'),
          info: 'Average amount raised per day.',
        ),
        if (_can('campaigns'))
          _StatCard(
            icon: LucideIcons.hourglass,
            label: 'Pending hosts',
            value: '${stats.pendingApplications}',
            color: AppColors.gold,
            onTap: () => _openTile(
              context,
              AdminTileKind.applications,
              'Host applications',
              LucideIcons.hourglass,
              [
                ('Waiting for approval', '${stats.pendingApplications}'),
              ],
            ),
            info: 'Host applications waiting for your approval.',
          ),
        _StatCard(
          icon: LucideIcons.fileText,
          label: 'Receipts',
          value: '${stats.receiptsDownloaded}',
          color: AppColors.primary,
          onTap: () => context.push('/admin/transactions'),
          info: 'How many times donors downloaded a PDF receipt.',
        ),
        _StatCard(
          icon: LucideIcons.calendarClock,
          label: 'Pledges',
          value: '${stats.activePledges}',
          color: AppColors.gold,
          onTap: () => _openTile(
            context,
            AdminTileKind.pledges,
            'Recurring pledges',
            LucideIcons.calendarClock,
            [
              ('Donors on monthly reminders', '${stats.activePledges}'),
            ],
          ),
          info: 'Donors opted for monthly giving reminders.',
        ),
        if (_can('tickets'))
          _StatCard(
            icon: LucideIcons.messageCircle,
            label: 'Open tickets',
            value: '${stats.openTickets}',
            color: stats.openTickets > 0 ? AppColors.danger : AppColors.primary,
            onTap: () => _openTile(
              context,
              AdminTileKind.tickets,
              'Support tickets',
              LucideIcons.messageCircle,
              [
                ('Waiting for a reply', '${stats.openTickets}'),
              ],
            ),
            info: 'Support messages waiting for a reply.',
          ),
        if (_can('campaigns'))
          _StatCard(
            icon: LucideIcons.trash2,
            label: 'Delete reqs',
            value: '${stats.pendingDeleteRequests}',
            color: stats.pendingDeleteRequests > 0
                ? AppColors.danger
                : AppColors.primaryLight,
            onTap: () => _openTile(
              context,
              AdminTileKind.deleteRequests,
              'Campaign deletion',
              LucideIcons.trash2,
              [
                ('Pending approval', '${stats.pendingDeleteRequests}'),
              ],
            ),
            info: 'Campaign deletion requests awaiting approval.',
          ),
        if (_can('users'))
          _StatCard(
            icon: LucideIcons.gift,
            label: 'Referral rewards',
            value: '${stats.qualifiedReferrers}',
            color: stats.qualifiedReferrers > 0
                ? AppColors.primary
                : AppColors.primaryLight,
            onTap: () => _openTile(
              context,
              AdminTileKind.referrals,
              'Referral rewards',
              LucideIcons.gift,
              [
                ('Referrers waiting for reward', '${stats.qualifiedReferrers}'),
              ],
            ),
            info: 'Users who reached the referral target and are waiting to be '
                'rewarded by you. Tap to reward them.',
          ),
        if (_isAdmin)
          _StatCard(
            icon: LucideIcons.userCog,
            label: 'Staff & restore',
            value: '${stats.assistants}',
            color: AppColors.primary,
            onTap: () => context.push('/admin/staff'),
            info: 'Manage assistant admins, restore deleted campaigns, review the audit log.',
          ),
        if (_can('campaigns'))
          _StatCard(
            icon: LucideIcons.pencil,
            label: 'Edit requests',
            value: '${stats.pendingEditRequests}',
            color: stats.pendingEditRequests > 0 ? AppColors.primary : AppColors.primaryLight,
            onTap: () => context.push('/admin/edit-requests'),
            info: 'Host-submitted campaign changes awaiting your approval.',
          ),
        if (_can('campaigns'))
          _StatCard(
            icon: LucideIcons.megaphone,
            label: 'Updates to review',
            value: '${stats.pendingAnnouncements}',
            color: stats.pendingAnnouncements > 0 ? AppColors.primary : AppColors.primaryLight,
            onTap: () => context.push('/admin/announcements'),
            info: 'Host-posted updates waiting for your approval. Approving publishes '
                'them on the campaign/event page and pushes a notification to every donor.',
          ),
        if (_can('campaigns'))
          _StatCard(
            icon: LucideIcons.calendarDays,
            label: 'Events analytics',
          value: '${stats.activeEvents}',
          color: stats.ticketsSold > 0 ? AppColors.primary : AppColors.primaryLight,
          onTap: () => context.push('/admin/events'),
          info: 'Ticket sales, revenue, sell-through and RSVPs for events — kept '
              'separate from campaigns. Tap for the full breakdown.',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final String? info;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.info,
  });

  void _showExplanation(BuildContext context) {
    final text = info;
    if (text == null) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(text, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: color),
                if (info != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showExplanation(context),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.info, size: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Compact badge text for a user's host status on list rows.
String _hostBadgeLabel(String status) {
  switch (status) {
    case 'approved':
      return 'Host';
    case 'pending':
      return 'Host pending';
    case 'rejected':
      return 'Host rejected';
    default:
      return 'Giver';
  }
}

/// A small count pill shown in section headers ("{n}").
Widget _countBadge(int count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
    ),
  );
}

String _networkLabel(String id) {
  switch (id) {
    case 'airtel':
      return 'Airtel';
    case 'mtn':
      return 'MTN';
    case 'zamtel':
      return 'Zamtel';
    case 'zedmobile':
      return 'ZedMobile';
    default:
      return id;
  }
}

class _ApplicationsSection extends ConsumerWidget {
  final List<HostApplication> applications;

  const _ApplicationsSection({required this.applications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: LucideIcons.userCheck,
          title: 'Host applications',
          trailing: _countBadge(applications.length),
        ),
        const SizedBox(height: 8),
        if (applications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No applications yet.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          for (final app in applications)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.org ?? 'Unknown organisation',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: app.hostStatus == 'pending'
                                ? AppColors.gold.withValues(alpha: 0.15)
                                : app.hostStatus == 'approved'
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            app.hostStatus,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${app.username} • ${app.phone}', style: theme.textTheme.bodySmall),
                    if (app.role != null)
                      Text('Role: ${app.role}', style: theme.textTheme.bodySmall),
                    if (app.reason != null)
                      Text('For: ${app.reason}', style: theme.textTheme.bodySmall),
                    if (app.rejection != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Rejected: ${app.rejection}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                        ),
                      ),
                    if (app.hostStatus == 'pending')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Approve host?'),
                                    content: Text(
                                        '${app.username} will get full host access and a '
                                        'confirmation SMS. You can always ban them later.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Approve'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !context.mounted) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final res = await ref
                                    .read(adminDataProvider.notifier)
                                    .decideApplication(app.id, approve: true);
                                messenger.showSnackBar(SnackBar(
                                    content: Text(res['message'] as String? ?? 'Approved')));
                              },
                              icon: const Icon(LucideIcons.check, size: 16),
                              label: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _reject(context, ref, app),
                              icon: const Icon(LucideIcons.x, size: 16),
                              label: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, HostApplication app) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject application'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (shown to the applicant)',
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, controller.text);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final res = await ref
        .read(adminDataProvider.notifier)
        .decideApplication(app.id, approve: false, reason: reason);
    messenger.showSnackBar(SnackBar(content: Text(res['message'] as String? ?? 'Rejected')));
  }
}

/// Displays recent failed login attempts for intruder detection.
class _FailedLoginsSection extends ConsumerStatefulWidget {
  const _FailedLoginsSection();

  @override
  ConsumerState<_FailedLoginsSection> createState() => _FailedLoginsSectionState();
}

class _FailedLoginsSectionState extends ConsumerState<_FailedLoginsSection> {
  List<dynamic> _logs = [];
  bool _loading = true;
  String? _error;
  bool _scanEnabled = false;
  bool _scanLoading = true;
  bool _testing = false;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadScanConfig();
    _loadEmailConfig();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).get('/api/admin/failed-logins');
      if (mounted) setState(() => _logs = res['failedLogins'] as List<dynamic>);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadScanConfig() async {
    try {
      final res = await ref.read(apiClientProvider).getIntruderAlert();
      if (mounted) setState(() { _scanEnabled = res['enabled'] == true; _scanLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _scanLoading = false);
    }
  }

  Future<void> _loadEmailConfig() async {
    try {
      final res = await ref.read(apiClientProvider).getEmailConfig();
      if (mounted) {
        final email = res['email'] as String? ?? '';
        setState(() { _emailController.text = email; });
      }
    } catch (_) {}
  }

  Future<void> _toggleScan(bool v) async {
    setState(() => _scanEnabled = v);
    try {
      await ref.read(apiClientProvider).setIntruderAlert(v);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(v ? 'Intruder-alert scan enabled' : 'Intruder-alert scan disabled')),
        );
      }
    } catch (e) {
      setState(() => _scanEnabled = !v);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _saveEmail() async {
    try {
      await ref.read(apiClientProvider).setEmailConfig(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert email saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _testAlert() async {
    setState(() => _testing = true);
    try {
      final res = await ref.read(apiClientProvider).testIntruderAlert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test alert sent (Telegram: ${res['telegramSent']}, SMS: ${res['smsSent']}, Email: ${res['emailSent']})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.shieldAlert, size: 18, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(
                  'Failed login attempts',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (!_scanLoading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_scanEnabled ? 'Scan ON' : 'Scan OFF',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _scanEnabled ? AppColors.primary : AppColors.textMuted)),
                      Switch(value: _scanEnabled, onChanged: _toggleScan),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Failed sign-ins are pushed to Telegram bots + SMS/email every 15 minutes.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Alert email (optional)',
                hintText: 'admin@example.com',
                prefixIcon: Icon(LucideIcons.mail, size: 16),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveEmail,
                    icon: const Icon(LucideIcons.save, size: 14),
                    label: const Text('Save email'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _testAlert,
                    icon: _testing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.zap, size: 14),
                    label: const Text('Send test alert'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _loading
                ? const LinearProgressIndicator()
                : _error != null
                    ? Text(_error!, style: TextStyle(color: AppColors.danger))
                    : _logs.isEmpty
                        ? Text('No recent failed attempts.', style: theme.textTheme.bodySmall)
                        : SizedBox(
                            height: 200,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _logs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final log = _logs[i] as Map<String, dynamic>;
                                return ListTile(
                                  dense: true,
                                  leading: Icon(LucideIcons.alertTriangle,
                                      size: 14, color: AppColors.danger),
                                  title: Text('${log['phone'] ?? 'unknown'}',
                                      style: theme.textTheme.bodySmall),
                                  subtitle: Text(
                                    '${log['reason'] ?? 'unknown'} • ${log['ip'] ?? ''}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textMuted, fontSize: 11),
                                  ),
                                  trailing: Text(
                                    (log['created_at'] as String?) ?? '',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textMuted, fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
          ],
        ),
      ),
    );
  }
}

/// Superadmin-editable Telegram team bots (multiple, all get intruder alerts).
class _TelegramConfigSection extends ConsumerStatefulWidget {
  const _TelegramConfigSection();

  @override
  ConsumerState<_TelegramConfigSection> createState() => _TelegramConfigSectionState();
}

class _TelegramConfigSectionState extends ConsumerState<_TelegramConfigSection> {
  List<Map<String, dynamic>> _bots = [];
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).getTelegramConfig();
      if (mounted) {
        setState(() {
          _bots = (res['bots'] as List<dynamic>? ?? [])
              .map((b) => Map<String, dynamic>.from(b as Map))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBots() async {
    setState(() => _saving = true);
    try {
      final cleaned = _bots
          .map((b) => {
                'token': (b['token'] as String? ?? '').trim(),
                'chatId': (b['chatId'] as String? ?? '').trim(),
                if ((b['label'] as String? ?? '').trim().isNotEmpty)
                  'label': (b['label'] as String? ?? '').trim(),
              })
          .where((b) => (b['token'] as String).isNotEmpty && (b['chatId'] as String).isNotEmpty)
          .toList();
      final res = await ref.read(apiClientProvider).put('/api/admin/telegram-config', {
        'bots': cleaned,
      }, auth: true);
      if (mounted) {
        setState(() {
          _bots = (res['bots'] as List<dynamic>? ?? [])
              .map((b) => Map<String, dynamic>.from(b as Map))
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${_bots.length} Telegram bot${_bots.length == 1 ? '' : 's'}')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testBots() async {
    setState(() => _testing = true);
    try {
      final res = await ref.read(apiClientProvider).testTelegramBots();
      final results = res['results'] as List<dynamic>? ?? [];
      final msgs = results
          .map((r) => '${r['label'] ?? r['chatId']}: ${r['ok'] == true ? 'OK' : r['error'] ?? 'failed'}')
          .join('\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(results.isEmpty ? 'No bots configured.' : msgs)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.send, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Telegram alerts',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (!_loading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _bots.isNotEmpty ? AppColors.primary.withValues(alpha: 0.12) : AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _bots.isNotEmpty ? '${_bots.length} bot${_bots.length == 1 ? '' : 's'}' : 'Not set',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: _bots.isNotEmpty ? AppColors.primary : AppColors.gold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Intruder alerts and critical events are sent to EVERY team bot (on top of SMS + push). Add one bot per teammate.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else ...[
              for (int i = 0; i < _bots.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Bot ${i + 1} — token',
                          hintText: '123456:ABC-DEF...',
                          isDense: true,
                        ),
                        obscureText: true,
                        initialValue: _bots[i]['token'] as String? ?? '',
                        onChanged: (v) => setState(() => _bots[i]['token'] = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Remove bot',
                      icon: const Icon(LucideIcons.x, size: 18, color: AppColors.danger),
                      onPressed: () => setState(() => _bots.removeAt(i)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Chat ID',
                          hintText: '-1001234567890',
                          isDense: true,
                        ),
                        initialValue: _bots[i]['chatId'] as String? ?? '',
                        onChanged: (v) => setState(() => _bots[i]['chatId'] = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Label (e.g. "Godfrey")',
                          isDense: true,
                        ),
                        initialValue: _bots[i]['label'] as String? ?? '',
                        onChanged: (v) => setState(() => _bots[i]['label'] = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: () => setState(() => _bots.add({'token': '', 'chatId': '', 'label': ''})),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add another bot'),
              ),
              const SizedBox(height: 4),
              Text(
                'How to: create a bot via @BotFather, then message it and open '
                'https://api.telegram.org/bot<TOKEN>/getUpdates to find your chat id.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveBots,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.save, size: 16),
                      label: Text(_saving ? 'Saving…' : 'Save bots'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _testBots,
                      icon: _testing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.zap, size: 16),
                      label: Text(_testing ? 'Testing…' : 'Test bots'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Superadmin-editable SMS network status banner text.
class _MtnStatusSection extends ConsumerStatefulWidget {
  const _MtnStatusSection();
  @override
  ConsumerState<_MtnStatusSection> createState() => _MtnStatusSectionState();
}

class _MtnStatusSectionState extends ConsumerState<_MtnStatusSection> {
  String? _text;
  bool _loading = true;
  Map<String, String> _netStatus = {};
  bool _savingNets = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/api/admin/sms-status');
      final nets = await ref.read(apiClientProvider).getNetworkStatus();
      setState(() {
        _text = res['text'] as String? ?? '';
        _netStatus = (nets['networks'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String? ?? 'ok'));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNetworks() async {
    setState(() => _savingNets = true);
    try {
      await ref.read(apiClientProvider).setNetworkStatus(_netStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network statuses saved')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save network statuses.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNets = false);
    }
  }

  Future<void> _save(String text) async {
    try {
      await ref.read(apiClientProvider).put('/api/admin/sms-status', {'text': text}, auth: true);
      setState(() => _text = text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS status text saved')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.phone, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'SMS network status',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _loading
                ? const LinearProgressIndicator()
                : Text(
                    _text ?? 'No status message set.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
            const SizedBox(height: 12),
            Text(
              'SMS delivery per network (blocks login codes when down):',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _netStatus.entries)
                    _NetworkChip(
                      network: entry.key,
                      down: entry.value == 'down',
                      onChanged: (down) => setState(() {
                        _netStatus[entry.key] = down ? 'down' : 'ok';
                      }),
                    ),
                ],
              ),
            if (!_loading && _savingNets)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _edit(theme),
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loading || _savingNets ? null : _saveNetworks,
                  icon: const Icon(LucideIcons.wifiOff, size: 16),
                  label: const Text('Save network status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(ThemeData theme) async {
    final controller = TextEditingController(text: _text ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit SMS network status'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This message is shown to users on the campaign tab.', style: TextStyle(fontSize: 12, color: Color(0xFF7A6A5C))),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 200,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Message is required' : null,
                    decoration: const InputDecoration(
                      labelText: 'Status message',
                      hintText: 'e.g. MTN OTP is currently unavailable. Use Airtel or Zamtel.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => saving = true);
                try {
                  await _save(controller.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('SMS status updated.')),
                    );
                  }
                } catch (e) {
                  setDialogState(() => saving = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                  }
                }
              },
              child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

/// Toggle for one network's SMS health (mtn/airtel/zamtel/zedmobile).
class _NetworkChip extends StatelessWidget {
  const _NetworkChip({
    required this.network,
    required this.down,
    required this.onChanged,
  });

  final String network;
  final bool down;
  final ValueChanged<bool> onChanged;

  static const _labels = {
    'mtn': 'MTN',
    'airtel': 'Airtel',
    'zamtel': 'Zamtel',
    'zedmobile': 'ZedMobile',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[network] ?? network;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(down ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
              size: 14, color: down ? const Color(0xFFB3261E) : const Color(0xFF1B873F)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: down,
      selectedColor: const Color(0xFFFFEBE9),
      onSelected: (_) => onChanged(!down),
      tooltip: down ? '$label SMS is DOWN - login codes blocked' : '$label SMS is working',
    );
  }
}

/// Ban/unban users, hosts, or phone numbers.
class _BanSection extends ConsumerStatefulWidget {
  const _BanSection();

  @override
  ConsumerState<_BanSection> createState() => _BanSectionState();
}

class _BanSectionState extends ConsumerState<_BanSection> {
  List<dynamic> _banned = [];
  bool _loading = true;
  String? _error;
  final _targetController = TextEditingController();
  final _reasonController = TextEditingController();
  String _banKind = 'phone';

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _banReady {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return false;
    if (_banKind == 'host') return true;
    return _targetController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _targetController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).get('/api/admin/banned');
      if (mounted) setState(() => _banned = res['banned'] as List<dynamic>);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ban() async {
    final target = _targetController.text.trim();
    final reason = _reasonController.text.trim();
    final banAllHosts = _banKind == 'host' && target.isEmpty;

    if (reason.isEmpty || (target.isEmpty && !banAllHosts)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target and reason are required.')),
        );
      }
      return;
    }
    if (banAllHosts) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ban all approved hosts?'),
          content: const Text('Every approved host will lose host access. This cannot be undone quickly.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ban all hosts'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await ref.read(apiClientProvider).post('/api/admin/ban',
          {'target': target, 'reason': reason, 'kind': _banKind}, auth: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(banAllHosts ? 'All approved hosts banned.' : '"$target" banned.')),
        );
        _targetController.clear();
        _reasonController.clear();
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _unban(String target) async {
    try {
      await ref.read(apiClientProvider).post('/api/admin/unban',
          {'target': target, 'kind': 'phone'}, auth: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$target" unbanned.')),
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.ban, size: 18, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(
                  'Ban users / hosts / numbers',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _banKind,
              items: const [
                DropdownMenuItem(value: 'phone', child: Text('Phone number')),
                DropdownMenuItem(value: 'user_id', child: Text('User ID')),
                DropdownMenuItem(value: 'host', child: Text('All approved hosts')),
              ],
              onChanged: (v) => setState(() => _banKind = v ?? 'phone'),
              decoration: const InputDecoration(
                labelText: 'Ban type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _banKind == 'host'
                    ? 'Leave empty to ban all hosts'
                    : _banKind == 'user_id'
                        ? 'User ID'
                        : 'Phone number (e.g. 26097…)',
                hintText: _banKind == 'host' ? 'All approved hosts' : null,
                prefixIcon: Icon(LucideIcons.target, size: 18),
              ),
              keyboardType: _banKind == 'user_id'
                  ? TextInputType.number
                  : TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this ban being applied?',
                prefixIcon: Icon(LucideIcons.messageSquare, size: 18),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _banReady
                    ? _ban
                    : null,
                icon: const Icon(LucideIcons.ban, size: 16),
                label: const Text('Ban'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              ),
            ),
            if (!_banReady) ...[
              const SizedBox(height: 4),
              Text(
                _banKind == 'host'
                    ? 'A reason is required.'
                    : 'Target and reason are required.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Text(_error!, style: TextStyle(color: AppColors.danger))
            else if (_banned.isEmpty)
              Text('No banned users.', style: theme.textTheme.bodySmall)
            else
              SizedBox(
                height: 220,
                child: ListView.separated(
                  itemCount: _banned.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = _banned[i] as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      leading: Icon(LucideIcons.ban, size: 14, color: AppColors.danger),
                      title: Text(
                        b['phone'] ?? 'User #${b['id']}',
                        style: theme.textTheme.bodySmall,
                      ),
                      subtitle: Text(
                        b['ban_reason'] ?? 'Banned',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unban(b['phone'] ?? ''),
                        child: const Text('Unban', style: TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
