import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/badges.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

class HostDashboardScreen extends ConsumerWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(hostProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My fundraisers'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: host.when(
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
                  onPressed: () => ref.invalidate(hostProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(hostProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          data.user.username.substring(0, 1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.user.username,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              data.user.phone,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              data.user.tier,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8A6A00),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gave ${formatKwacha(data.user.totalGivenCents)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BadgesCard(totalGivenCents: data.user.totalGivenCents),
              const SizedBox(height: 16),
              _HostStatusSection(
                user: data.user,
                refreshHost: () => ref.invalidate(hostProvider),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: data.user.hostStatus == 'approved'
                          ? () => context.push('/host/create')
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(data.user.hostStatus == 'none'
                                      ? 'Apply to become a host first — approval unlocks campaign creation'
                                      : data.user.hostStatus == 'pending'
                                          ? 'Your application is under review'
                                          : 'Your application was not approved yet'),
                                ),
                              ),
                      icon: const Icon(LucideIcons.plus),
                      label: const Text('New campaign'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref.invalidate(hostProvider),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'My campaigns',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (data.campaigns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No campaigns yet. Tap "New campaign" to start fundraising.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                )
              else
                for (final c in data.campaigns) _HostCampaignCard(campaign: c),
              const SizedBox(height: 24),
              Text(
                'Recent transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (data.transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Donations will appear here once people give.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final t in data.transactions)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            t.status == 'confirmed'
                                ? LucideIcons.checkCircle
                                : t.status == 'failed'
                                    ? LucideIcons.xCircle
                                    : LucideIcons.clock,
                            color: t.status == 'confirmed'
                                ? AppColors.primary
                                : t.status == 'failed'
                                    ? AppColors.danger
                                    : AppColors.gold,
                          ),
                          title: Text('${t.name} - ${formatKwacha(t.amountCents)}'),
                          subtitle: Text('${t.campaignTitle}\n${t.phone} • ${t.date}'),
                          isThreeLine: true,
                          trailing: t.status == 'confirmed'
                              ? IconButton(
                                  tooltip: 'Download receipt',
                                  icon: const Icon(LucideIcons.download, size: 18),
                                  onPressed: () async {
                                    final url = ref.read(apiClientProvider).receiptUrl(t.id);
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not open receipt')),
                                      );
                                    }
                                  },
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostStatusSection extends ConsumerStatefulWidget {
  final HostUser user;
  final VoidCallback refreshHost;

  const _HostStatusSection({required this.user, required this.refreshHost});

  @override
  ConsumerState<_HostStatusSection> createState() => _HostStatusSectionState();
}

class _HostStatusSectionState extends ConsumerState<_HostStatusSection> {
  final _orgController = TextEditingController();
  final _roleController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _orgController.dispose();
    _roleController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final org = _orgController.text.trim();
    final role = _roleController.text.trim();
    final reason = _reasonController.text.trim();
    if (org.isEmpty || role.isEmpty || reason.isEmpty) {
      setState(() => _error = 'Fill in all fields so the review is quick.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(hostProvider.notifier).applyAsHost(org: org, role: role, reason: reason);
      widget.refreshHost();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = widget.user;
    final s = u.hostStatus;

    if (s == 'approved') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.badgeCheck, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                u.hostOrg != null ? 'Host approved • ${u.hostOrg}' : 'Host approved',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    if (s == 'pending') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.hourglass, color: Color(0xFF8A6A00), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Application under review — you can start once a superadmin approves you.',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (s == 'rejected') {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: AppColors.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    u.hostRejection != null
                        ? 'Application not approved: ${u.hostRejection}'
                        : 'Application not approved',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _applyCard(theme),
        ],
      );
    }

    return _applyCard(theme);
  }

  Widget _applyCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Become a host',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Anyone can host a fundraiser. A superadmin will review and approve your application — approval unlocks campaign creation.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _orgController,
              decoration: const InputDecoration(
                labelText: 'Church / organisation',
                hintText: 'e.g. UPC Lusaka Youths Dept',
                prefixIcon: Icon(LucideIcons.building2, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Your role',
                hintText: 'e.g. Treasurer, Youth Pastor',
                prefixIcon: Icon(LucideIcons.userCheck, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What will you fundraise for?',
                hintText: 'e.g. Youth trip to Livingstone',
                prefixIcon: Icon(LucideIcons.flag, size: 20),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(LucideIcons.send, size: 18),
                label: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit application'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCampaignCard extends ConsumerWidget {
  final Campaign campaign;

  const _HostCampaignCard({required this.campaign});

  Future<void> _uploadLogo(WidgetRef ref, BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).uploadLogo(campaign.id, bytes, file.name);
      ref.invalidate(hostProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Logo updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final available = campaign.availableCents ?? 0;
    final canWithdraw = available >= (campaign.minWithdrawCents ?? 20000);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: campaign.logoUrl != null
                      ? Image.network(
                          campaign.logoUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(LucideIcons.tent, color: AppColors.primary, size: 20),
                        )
                      : const Icon(LucideIcons.tent, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    campaign.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: campaign.logoUrl == null ? 'Add logo' : 'Change logo',
                  icon: Icon(
                    campaign.logoUrl == null ? LucideIcons.imagePlus : LucideIcons.image,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => _uploadLogo(ref, context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: campaign.status == 'active' ? AppColors.primary : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    campaign.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (campaign.hasGoal)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: campaign.progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EDE8),
                  color: AppColors.gold,
                ),
              )
            else
              const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              campaign.hasGoal
                  ? '${campaign.raisedLabel} of ${campaign.goalLabel}'
                  : '${campaign.raisedLabel} raised',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'Available: ${formatKwacha(available)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MiniStat(label: 'Avg donation', value: formatKwacha(campaign.avgDonationCents)),
                _MiniStat(label: 'Per day', value: formatKwacha(campaign.dailyRateCents)),
                if (campaign.donorsNeededAtAvg != null && campaign.hasGoal)
                  _MiniStat(label: 'To goal', value: '${campaign.donorsNeededAtAvg} more'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canWithdraw
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final res = await ref
                                .read(hostProvider.notifier)
                                .withdraw(campaign.id);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] as String? ?? 'Done'),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(LucideIcons.send, size: 16),
                    label: Text(
                      canWithdraw
                          ? 'Withdraw ${formatKwacha(available)}'
                          : 'Min ${formatKwacha(campaign.minWithdrawCents ?? 0)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (campaign.status == 'active')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final res = await ref
                          .read(hostProvider.notifier)
                          .endCampaign(campaign.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(res['message'] as String? ?? 'Campaign ended'),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.flag, size: 16),
                    label: const Text('End', style: TextStyle(fontSize: 13)),
                  ),
                if (campaign.status == 'active' && !campaign.promoted)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final res = await ref
                            .read(apiClientProvider)
                            .promoteCampaign(campaign.id);
                        messenger.showSnackBar(SnackBar(
                            content: Text(
                                'Check your phone and enter PIN to promote. Ref: ${res['referenceId']}')));
                      } on ApiException catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    icon: const Icon(LucideIcons.star, size: 16),
                    label: const Text('Promote', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
