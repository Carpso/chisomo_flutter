import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminDataProvider);

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
        loading: () => const Center(child: CircularProgressIndicator()),
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
              _StatGrid(stats: data.stats),
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
              const SizedBox(height: 20),
              _ApplicationsSection(applications: data.applications),
              const SizedBox(height: 20),
              if (data.topCampaigns.isNotEmpty) ...[
                _SectionTitle(
                  icon: LucideIcons.trophy,
                  title: 'Top campaigns',
                  trailing: '${data.topCampaigns.length} shown',
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
            ],
          ),
        ),
      ),
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
          loading: () => const Center(child: CircularProgressIndicator()),
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
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _statusColor(p.status).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              p.status == 'active' ? LucideIcons.star : LucideIcons.clock,
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
                              Text('K${(p.amountCents / 100).toStringAsFixed(0)} • ${p.days} days • ${p.status}'),
                              if (p.expiresAt != null)
                                Text('Expires: ${p.expiresAt!.substring(0, 10)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            p.createdAt.substring(0, 10),
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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
      case 'expired':
        return AppColors.textMuted;
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
        ),
        _StatCard(
          icon: LucideIcons.tent,
          label: 'Active campaigns',
          value: '${stats.activeCampaigns}',
          color: AppColors.primaryLight,
        ),
        _StatCard(
          icon: LucideIcons.users,
          label: 'Donors',
          value: '${stats.donors}',
          color: AppColors.gold,
        ),
        _StatCard(
          icon: LucideIcons.coins,
          label: 'Platform fees',
          value: formatKwacha(stats.platformFeesCents),
          color: AppColors.primary,
        ),
        _StatCard(
          icon: LucideIcons.trendingUp,
          label: 'Per day',
          value: formatKwacha(stats.dailyRateCents),
          color: AppColors.primaryLight,
        ),
        _StatCard(
          icon: LucideIcons.hourglass,
          label: 'Pending hosts',
          value: '${stats.pendingApplications}',
          color: AppColors.gold,
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

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

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
        if (trailing != null)
          Text(trailing!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
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
