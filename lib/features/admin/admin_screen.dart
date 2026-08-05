import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/api_client.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Text('$e', textAlign: TextAlign.center),
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatGrid(stats: data.stats),              const SizedBox(height: 16),
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
                icon: const Icon(LucideIcons.tent, size: 18),
                label: const Text('Campaigns'),
              ),
              const SizedBox(height: 20),
              _ApplicationsSection(applications: data.applications),
              const SizedBox(height: 20),
              if (data.topCampaigns.isNotEmpty) ...[
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
              if (data.topDonors.isNotEmpty) ...[
                _SectionTitle(icon: LucideIcons.users, title: 'Top supporters'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final d in data.topDonors)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                            child: Text(
                              d.username.substring(0, 1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, color: Color(0xFF8A6A00), fontSize: 14),
                            ),
                          ),
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
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              r.username.substring(0, 1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  fontSize: 14),
                            ),
                          ),
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
              _PromotionsSection(),
              const SizedBox(height: 12),
              const _PromoConfigSection(),
              const SizedBox(height: 12),
              const _TicketsSection(),
              const SizedBox(height: 12),
              const _DeleteRequestsSection(),
            ],
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
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: AlertDialog(
            title: const Text('Promotion paywall'),
            content: SingleChildScrollView(
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
        child: Row(
          children: [
            const Icon(LucideIcons.settings, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Promotion paywall',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _loading
                        ? 'Loading…'
                        : 'K${((_priceCents ?? 15000) / 100).toStringAsFixed(0)} for ${_days ?? 7} days • set by the admin',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _edit,
              icon: const Icon(LucideIcons.pencil, size: 15),
              label: const Text('Edit'),
            ),
          ],
        ),
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
      final tickets = await ref.read(apiClientProvider).getAdminTickets(status: 'open');
      if (mounted) setState(() => _tickets = tickets);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load tickets.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply(Map<String, dynamic> ticket) async {
    final text = TextEditingController();
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: AlertDialog(
            title: Text('Reply to #${ticket['id']}'),
            content: TextField(
              controller: text,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Reply (user is notified by push; SMS if no app)',
                alignLabelWithHint: true,
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
          title: 'Support tickets (open)',
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
        else if (_tickets.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No open tickets.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
          )
        else
          for (final t in _tickets)
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
                            '#${t['id']} ${t['subject'] ?? ''}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          (t['createdAt'] ?? '').toString().substring(0, 10),
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
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => _reply(t),
                          icon: const Icon(LucideIcons.reply, size: 15),
                          label: const Text('Reply'),
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
    final confirmed = approve ||
        (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reject delete request?'),
            content: const Text('The host will be notified that the campaign stays up.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reject'),
              ),
            ],
          ),
        ) ??
            false);
    if (!confirmed || !mounted) return;

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
              child: Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
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
                                        'K${(p.amountCents / 100).toStringAsFixed(0)} • ${p.days} days • ${p.status}'),
                                    if (p.expiresAt != null)
                                      Text(
                                          'Expires: ${p.expiresAt!.substring(0, 10)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Text(
                                  p.createdAt.substring(0, 10),
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
                                              'K${(p.amountCents / 100).toStringAsFixed(0)} will be sent back to the host\'s mobile money (${p.hostPhone}).'),
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

  void _showBreakdown(BuildContext context, String title, List<(String, String)> rows) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted)),
                    ),
                    Text(value,
                        style: Theme.of(ctx)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
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
          icon: LucideIcons.wallet,
          label: 'Total raised',
          value: formatKwacha(stats.totalRaisedCents),
          color: AppColors.primary,
          onTap: () => context.push('/admin/transactions'),
          info:
              'Sum of all confirmed donations, before fees. Platform fee (1%, min K3) and mobile money fee (2.5%) are removed before the host\u2019s available balance is calculated.',
        ),
        _StatCard(
          icon: LucideIcons.tent,
          label: 'Active campaigns',
          value: '${stats.activeCampaigns}',
          color: AppColors.primaryLight,
          onTap: () => _showBreakdown(context, 'Campaigns', [
            ('Active now', '${stats.activeCampaigns}'),
            ('All time (not deleted)', '${stats.campaignsTotal}'),
            ('New (7 days)', '${stats.newCampaigns7d}'),
            ('New (30 days)', '${stats.newCampaigns30d}'),
          ]),
          info: 'Fundraisers currently open for donations. Tap for all-time and new counts.',
        ),
        _StatCard(
          icon: LucideIcons.users,
          label: 'Donors',
          value: '${stats.donors}',
          color: AppColors.gold,
          onTap: () => _showBreakdown(context, 'Donors', [
            ('Distinct donors', '${stats.donors}'),
          ]),
          info:
              'Distinct people who completed at least one donation. One person giving many times counts once.',
        ),
        _StatCard(
          icon: LucideIcons.userPlus,
          label: 'Users',
          value: '${stats.usersTotal}',
          color: AppColors.gold,
          onTap: () => _showBreakdown(context, 'Users', [
            ('Total users', '${stats.usersTotal}'),
            ('Approved hosts', '${stats.hostsTotal}'),
            ('Distinct donors', '${stats.donors}'),
            ('New (7 days)', '${stats.newUsers7d}'),
            ('New (30 days)', '${stats.newUsers30d}'),
          ]),
          info:
              'Every phone number that verified with an SMS code. A host is a user approved to run fundraisers.',
        ),
        _StatCard(
          icon: LucideIcons.coins,
          label: 'Platform fees',
          value: formatKwacha(stats.platformFeesCents),
          color: AppColors.primary,
          onTap: () => context.push('/admin/disbursements'),
          info:
              'Earned fees: 1% (minimum K3) of every confirmed donation, plus 1% (minimum K3) of every host payout. The full breakdown lives under Disbursements.',
        ),
        _StatCard(
          icon: LucideIcons.trendingUp,
          label: 'Per day',
          value: formatKwacha(stats.dailyRateCents),
          color: AppColors.primaryLight,
          onTap: () => _showBreakdown(context, 'Growth', [
            ('Daily average raised', formatKwacha(stats.dailyRateCents)),
            ('Donations (7 days)', '${stats.newDonations7d}'),
            ('Donations (30 days)', '${stats.newDonations30d}'),
            ('Donations (all time)', '${stats.donationsTotal}'),
          ]),
          info: 'Average amount raised per day since the first campaign was created.',
        ),
        _StatCard(
          icon: LucideIcons.hourglass,
          label: 'Pending hosts',
          value: '${stats.pendingApplications}',
          color: AppColors.gold,
          onTap: () => _showBreakdown(context, 'Host applications', [
            ('Waiting for approval', '${stats.pendingApplications}'),
          ]),
          info: 'Host applications waiting for your approval. Tap to review them.',
        ),
        _StatCard(
          icon: LucideIcons.fileText,
          label: 'Receipts downloaded',
          value: '${stats.receiptsDownloaded}',
          color: AppColors.primary,
          onTap: () => _showBreakdown(context, 'Receipt downloads', [
            ('All time', '${stats.receiptsDownloaded}'),
            ('Last 7 days', '${stats.receiptsDownloaded7d}'),
          ]),
          info: 'How many times donors downloaded a donation receipt (PDF).',
        ),
        _StatCard(
          icon: LucideIcons.calendarClock,
          label: 'Active pledges',
          value: '${stats.activePledges}',
          color: AppColors.gold,
          onTap: () => _showBreakdown(context, 'Recurring pledges', [
            ('Donors on monthly reminders', '${stats.activePledges}'),
          ]),
          info:
              'Donors who opted for a monthly reminder: they get an SMS on the same day each month to give again.',
        ),
        _StatCard(
          icon: LucideIcons.messageCircle,
          label: 'Open tickets',
          value: '${stats.openTickets}',
          color: stats.openTickets > 0 ? AppColors.danger : AppColors.primary,
          onTap: () => _showBreakdown(context, 'Support', [
            ('Waiting for a reply', '${stats.openTickets}'),
          ]),
          info: 'Support messages from users that still need a reply.',
        ),
        _StatCard(
          icon: LucideIcons.trash2,
          label: 'Delete requests',
          value: '${stats.pendingDeleteRequests}',
          color: stats.pendingDeleteRequests > 0
              ? AppColors.danger
              : AppColors.primaryLight,
          onTap: () => _showBreakdown(context, 'Campaign deletion', [
            ('Pending approval', '${stats.pendingDeleteRequests}'),
          ]),
          info: 'Hosts who asked to remove their campaign, waiting for your approval.',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const Spacer(),
                if (info != null)
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
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
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
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason (shown to the applicant)',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
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
