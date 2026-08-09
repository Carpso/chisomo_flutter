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
import '../host/host_badge_screen.dart';
import '../campaigns/campaigns_controller.dart';
import 'admin_tile_detail_screen.dart';
import '../campaigns/models.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

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

  /// Downloads an admin export (CSV/PDF/JSON) with the session token and
  /// offers to open it once saved.
  Future<void> _downloadExport(BuildContext context, String path, String fileName) async {
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

  static const _sectionLabels = <(String, String, IconData)>[
    ('stats', 'Stats', LucideIcons.barChart3),
    ('apps', 'Applications', LucideIcons.userCheck),
    ('top', 'Top campaigns', LucideIcons.trophy),
    ('promos', 'Promotions', LucideIcons.star),
    ('tickets', 'Tickets', LucideIcons.headphones),
    ('deletes', 'Delete requests', LucideIcons.trash2),
  ];

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
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
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDataProvider),
          child: SingleChildScrollView(
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
                      child: _StatGrid(stats: data.stats),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
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
                        const SizedBox(width: 10),
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => context.push('/admin/campaigns'),
                      icon: const AppBrandIcon(size: 18),
                      label: const Text('Campaigns'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => context.push('/admin/lipila-logs'),
                      icon: const Icon(LucideIcons.list, size: 18),
                      label: const Text('Lipila logs'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () =>
                                _downloadExport(context, '/api/admin/stats/export.csv', 'kingdom_sponsor_stats.csv'),
                            icon: const Icon(LucideIcons.fileSpreadsheet, size: 18),
                            label: const Text('Stats CSV'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () =>
                                _downloadExport(context, '/api/admin/stats/export.pdf', 'kingdom_sponsor_report.pdf'),
                            icon: const Icon(LucideIcons.fileText, size: 18),
                            label: const Text('PDF report'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () =>
                          _downloadExport(context, '/api/admin/backup/export', 'kingdom_sponsor_backup.json'),
                      icon: const Icon(LucideIcons.databaseBackup, size: 18),
                      label: const Text('Download full backup (JSON)'),
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
                              trailing: Text(
                                '${data.topCampaigns.length} shown',
                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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
                      _SectionTitle(icon: LucideIcons.users, title: 'Top supporters'),
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
                      _SectionTitle(icon: LucideIcons.userPlus, title: 'Top referrers'),
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
                      _SectionTitle(icon: LucideIcons.receipt, title: 'Recent contributions'),
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
                    KeyedSubtree(
                      key: _newKey('tickets'),
                      child: const _TicketsSection(),
                    ),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _newKey('deletes'),
                      child: const _DeleteRequestsSection(),
                    ),
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
            ),
          ),
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
                      helperText: 'What hosts pay to reach the top-5',
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
                      if (price == null || days == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter valid numbers')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(apiClientProvider)
                            .setPromotionConfig(price * 100, days);
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
                  : '${formatKwacha(_priceCents ?? 15000)} for ${_days ?? 7} days — Set by admin',
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
              : TextButton(onPressed: _load, child: const Text('Refresh')),
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

  const _StatGrid({required this.stats});

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
        _StatCard(
          icon: LucideIcons.userPlus,
          label: 'Users',
          value: '${stats.usersTotal}',
          color: AppColors.gold,
          onTap: () => _openTile(
            context,
            AdminTileKind.users,
            'Users',
            LucideIcons.userPlus,
            [
              ('Total users', '${stats.usersTotal}'),
              ('Approved hosts', '${stats.hostsTotal}'),
              ('Distinct donors', '${stats.donors}'),
              ('New (7 days)', '${stats.newUsers7d}'),
              ('New (30 days)', '${stats.newUsers30d}'),
            ],
          ),
          info: 'Every phone number that verified with an SMS code.',
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
        _StatCard(
          icon: LucideIcons.userCog,
          label: 'Staff & restore',
          value: '${stats.assistants}',
          color: AppColors.primary,
          onTap: () => context.push('/admin/staff'),
          info: 'Manage assistant admins, restore deleted campaigns, review the audit log.',
        ),
        _StatCard(
          icon: LucideIcons.pencil,
          label: 'Edit requests',
          value: '${stats.pendingEditRequests}',
          color: stats.pendingEditRequests > 0 ? AppColors.primary : AppColors.primaryLight,
          onTap: () => context.push('/admin/edit-requests'),
          info: 'Host-submitted campaign changes awaiting your approval.',
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
    return InkWell(
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

class _ApplicationsSection extends ConsumerWidget {
  final List<HostApplication> applications;

  const _ApplicationsSection({required this.applications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: LucideIcons.userCheck, title: 'Host applications'),
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

  @override
  void initState() {
    super.initState();
    _load();
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
              ],
            ),
            const SizedBox(height: 8),
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

/// Superadmin-editable Telegram intruder-alert channel (bot token + chat id).
class _TelegramConfigSection extends ConsumerStatefulWidget {
  const _TelegramConfigSection();

  @override
  ConsumerState<_TelegramConfigSection> createState() => _TelegramConfigSectionState();
}

class _TelegramConfigSectionState extends ConsumerState<_TelegramConfigSection> {
  final _tokenController = TextEditingController();
  final _chatController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).getTelegramConfig();
      if (mounted) {
        setState(() {
          _configured = res['configured'] == true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).setTelegramConfig(
            token: _tokenController.text.trim(),
            chatId: _chatController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telegram alert channel saved')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
                      color: _configured ? AppColors.primary.withValues(alpha: 0.12) : AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _configured ? 'Active' : 'Not set',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: _configured ? AppColors.primary : AppColors.gold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Intruder alerts and critical events are also sent to this Telegram chat (on top of SMS + push).',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Bot token',
                hintText: '123456:ABC-DEF...',
                prefixIcon: Icon(LucideIcons.key, size: 16),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _chatController,
              decoration: const InputDecoration(
                labelText: 'Chat ID',
                hintText: '-1001234567890',
                prefixIcon: Icon(LucideIcons.hash, size: 16),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How to: create a bot via @BotFather, then message it and open '
              'https://api.telegram.org/bot<TOKEN>/getUpdates to find your chat id.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(_saving ? 'Saving…' : 'Save Telegram channel'),
              ),
            ),
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
