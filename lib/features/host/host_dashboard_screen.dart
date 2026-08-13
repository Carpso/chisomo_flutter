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
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/avatar.dart';
import '../auth/auth_controller.dart';
import '../campaigns/campaign_image.dart';
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
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('You will need to verify your phone number again to sign back in.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                  ],
                ),
              );
              if (confirmed != true) return;
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
       body: host.when(
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
            padding: EdgeInsets.all(16).copyWith(
              bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Avatar(
                        url: data.user.avatarUrl,
                        name: data.user.name?.isNotEmpty == true ? data.user.name! : data.user.username,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.user.name?.isNotEmpty == true
                                  ? data.user.name!
                                  : data.user.username,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              data.user.name?.isNotEmpty == true
                                  ? '${data.user.username} • ${data.user.phone}'
                                  : data.user.phone,
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
                                      ? 'Your application is under review.'
                                      : 'Your application was not approved yet.'),
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
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => context.push('/pledges'),
                icon: const Icon(LucideIcons.calendarClock, size: 18, color: AppColors.primary),
                label: const Text('Monthly giving pledges'),
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
                _HostTransactionsCard(transactions: data.transactions),
              const SizedBox(height: 24),
              Text(
                'Payout history',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (data.payouts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Your payouts to mobile money will appear here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final p in data.payouts)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            p.status == 'success'
                                ? LucideIcons.send
                                : p.status == 'failed'
                                    ? LucideIcons.xCircle
                                    : LucideIcons.clock,
                            color: p.status == 'success'
                                ? AppColors.primary
                                : p.status == 'failed'
                                    ? AppColors.danger
                                    : AppColors.gold,
                          ),
                          title: Text(
                            '${p.campaignTitle} • ${formatKwacha(p.amountCents)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${p.status} • ${p.date}${p.reference == null ? '' : '\n${p.reference}'}',
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            'processing fees ${formatKwacha(p.platformFeeCents + p.disbursementFeeCents)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
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
  String _kycType = 'nrc';
  String? _kycDocUrl;
  bool _kycUploading = false;
  String _orgType = 'individual';

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
      await ref.read(hostProvider.notifier).applyAsHost(
            org: org,
            role: role,
            reason: reason,
            orgType: _orgType,
            kycType: _kycType,
            kycDocUrl: _kycDocUrl,
          );
      widget.refreshHost();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickKycDoc() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _kycUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final res = await ref.read(apiClientProvider).uploadKycDoc(bytes, file.name);
      if (mounted) setState(() => _kycDocUrl = res['docUrl'] as String?);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _kycUploading = false);
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
            DropdownButtonFormField<String>(
              initialValue: _orgType,
              items: const [
                DropdownMenuItem(value: 'individual', child: Text('Individual / church member')),
                DropdownMenuItem(value: 'ngo', child: Text('NGO / non-profit organisation')),
                DropdownMenuItem(value: 'agency', child: Text('Fundraising agency')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _orgType = v);
              },
              decoration: const InputDecoration(
                labelText: 'What best describes you?',
                prefixIcon: Icon(LucideIcons.building, size: 18),
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 12),
            const Text(
              'Verification (KYC) — helps donors trust that you are real.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _kycType,
              items: const [
                DropdownMenuItem(value: 'nrc', child: Text('National Registration Card (NRC)')),
                DropdownMenuItem(value: 'ngo_cert', child: Text('NGO / registration certificate')),
                DropdownMenuItem(value: 'endorsement', child: Text('Community leader endorsement')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _kycType = v);
              },
              decoration: const InputDecoration(
                labelText: 'Document type',
                prefixIcon: Icon(LucideIcons.fileBadge, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _kycUploading ? null : _pickKycDoc,
              icon: _kycUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_kycDocUrl == null ? LucideIcons.upload : LucideIcons.fileCheck,
                      size: 16, color: AppColors.primary),
              label: Text(_kycUploading
                  ? 'Uploading…'
                  : _kycDocUrl == null
                      ? 'Upload a document photo (optional)'
                      : 'Document uploaded'),
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
                     ? SizedBox(
                         width: 20,
                         height: 20,
                         child: AppIconSpinner(size: 20, color: Colors.white),
                       )
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

/// Host dashboard "Recent transactions" card — groups the host's donations
/// into Awaiting payment / Confirmed / Failed sections.
class _HostTransactionsCard extends ConsumerWidget {
  final List<Transaction> transactions;

  const _HostTransactionsCard({required this.transactions});

  static const _labels = <String, String>{
    'pending': 'Awaiting payment',
    'confirmed': 'Confirmed',
    'failed': 'Failed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<Transaction>>{};
    for (final t in transactions) {
      final key = _labels.containsKey(t.status) ? t.status : 'pending';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final keys = _labels.keys.where((k) => grouped[k]?.isNotEmpty ?? false).toList();
    return Card(
      child: Column(
        children: [
          for (final key in keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Text(
                    _labels[key]!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${grouped[key]!.length}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final t in grouped[key]!)
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
                title: Text('${t.displayName} - ${formatKwacha(t.amountCents)}'),
                subtitle: Text('${t.campaignTitle}\n${t.phone} • ${t.createdAt}'),
                isThreeLine: true,
                trailing: t.status == 'confirmed'
                    ? IconButton(
                        tooltip: 'Download receipt',
                        icon: const Icon(LucideIcons.download, size: 18),
                        onPressed: () async {
                          final url = ref.read(apiClientProvider).receiptUrl(t.id);
                          final uri = Uri.parse(url);
                          final messenger = ScaffoldMessenger.of(context);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Could not open receipt.')),
                            );
                          }
                        },
                      )
                    : t.status == 'pending' && t.lipilaReference != null
                        ? IconButton(
                            tooltip: 'Check status',
                            icon: const Icon(LucideIcons.refreshCw, size: 18),
                            onPressed: () async {
                              try {
                                final res = await ref.read(apiClientProvider)
                                    .checkContributionStatus(t.lipilaReference!);
                                final newStatus = res['status'] as String? ?? 'pending';
                                if (newStatus == 'confirmed' || newStatus == 'failed') {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Transaction is now $newStatus.'),
                                      ),
                                    );
                                    ref.invalidate(hostProvider);
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Still pending on Lipila.'),
                                      ),
                                    );
                                  }
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not check status.'),
                                    ),
                                  );
                                }
                              }
                            },
                          )
                        : null,
              ),
          ],
        ],
      ),
    );
  }
}

class _HostCampaignCard extends ConsumerWidget {
  final Campaign campaign;

  const _HostCampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final available = campaign.availableCents ?? 0;
    final canWithdraw = available >= (campaign.minWithdrawCents ?? 20000);
    // Calculate effective payout after Lipila + platform processing fees.
    // Platform processing fee = K0.48 + 1% (K3 minimum), same as collections.
    final lipilaFee = (available * 1.5 / 100).round();
    final platformFee = [348, (available * 1 / 100).round() + 48].reduce((a, b) => a > b ? a : b);
    final netPayout = available - lipilaFee - platformFee;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: campaign.status == 'active'
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.textMuted.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
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
                    color: campaign.status == 'active'
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CampaignImage(campaign: campaign, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    campaign.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (campaign.isPrivate)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: 'Private campaign — only people with the link can see it',
                      child: const Icon(LucideIcons.lock,
                          size: 15, color: AppColors.textMuted),
                    ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Available: ${formatKwacha(available)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'How Available is calculated',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How Available is calculated',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Available = confirmed donations minus anything already paid out. '
                                'Processing fees (K0.48 + 1% (K3 minimum) + Lipila charges) are paid by the '
                                'donor on top of their gift, so the campaign receives the full gift amount.\n\n'
                                'Example: a K50 donation gives K50.00 to the campaign. The donor pays '
                                'K54.73 (K50.00 + K4.73 processing fees: K3.48 platform — K3.00 minimum + K0.48 — '
                                'plus K1.25 Lipila). Withdraw when the balance reaches the minimum shown below.',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        LucideIcons.info,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
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
            StatefulBuilder(
              builder: (context, setLocalState) {
                bool withdrawing = false;
                return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  onPressed: canWithdraw && !withdrawing
                      ? () async {
                          setLocalState(() => withdrawing = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm withdrawal'),
                              content: Text(
                                'Send ${formatKwacha(netPayout)} to the mobile money number '
                                'linked to your account? (${formatKwacha(available)} '
                                'minus ${formatKwacha(lipilaFee + platformFee)} processing fees.)',
                                style: const TextStyle(height: 1.5),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Withdraw'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          try {
                          final res = await ref
                              .read(hostProvider.notifier)
                              .withdraw(campaign.id);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res['message'] as String? ?? 'Withdrawal initiated'),
                            ),
                          );
                          } on ApiException catch (e) {
                            if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(e.message)));
                          } catch (_) {
                            if (context.mounted) messenger.showSnackBar(const SnackBar(content: Text('Could not start the withdrawal. Check your connection and try again.')));
                          }
                          } finally {
                            if (context.mounted) setLocalState(() => withdrawing = false);
                          }
                        }
                      : null,
                  icon: const Icon(LucideIcons.send, size: 16),
                  label: Text(
                    canWithdraw
                        ? withdrawing ? 'Processing…' : 'Withdraw ${formatKwacha(netPayout)}'
                        : 'Min ${formatKwacha(campaign.minWithdrawCents ?? 0)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (campaign.status == 'active')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('End this campaign?'),
                          content: const Text(
                            'New donations will be blocked. Existing donors and the '
                            'remaining balance stay available for withdrawal.',
                            style: TextStyle(height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('End campaign'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      try {
                      final res = await ref
                          .read(hostProvider.notifier)
                          .endCampaign(campaign.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(res['message'] as String? ?? 'Campaign ended'),
                        ),
                      );
                      } on ApiException catch (e) {
                        if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(e.message)));
                      } catch (_) {
                        if (context.mounted) messenger.showSnackBar(const SnackBar(content: Text('Could not end the campaign. Try again.')));
                      }
                    },
                    icon: const Icon(LucideIcons.flag, size: 16),
                    label: const Text('End', style: TextStyle(fontSize: 13)),
                  ),
                if (campaign.status == 'active' && !campaign.promoted)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/host/promote'),
                    icon: const Icon(LucideIcons.star, size: 16),
                    label: const Text('Promote', style: TextStyle(fontSize: 13)),
                  ),
                if (campaign.status != 'deleted')
                  OutlinedButton.icon(
                    onPressed: () => context.push('/host/edit/${campaign.id}'),
                    icon: const Icon(LucideIcons.pencil, size: 15),
                    label: const Text('Edit', style: TextStyle(fontSize: 13)),
                  ),
                if (campaign.status != 'deleted')
                  OutlinedButton.icon(
                    onPressed: () => _postUpdate(ref, context, campaign),
                    icon: const Icon(LucideIcons.megaphone, size: 15),
                    label: const Text('Update', style: TextStyle(fontSize: 13)),
                  ),
                if (campaign.status != 'deleted')
                  OutlinedButton.icon(
                    onPressed: () => context.push('/host/analytics/${campaign.id}'),
                    icon: const Icon(LucideIcons.barChart3, size: 15),
                    label: const Text('Stats', style: TextStyle(fontSize: 13)),
                  ),
                if (campaign.status != 'deleted')
                  IconButton(
                    tooltip: 'Request deletion',
                    icon: const Icon(LucideIcons.trash2,
                        size: 18, color: AppColors.danger),
                    onPressed: () => _requestDelete(ref, context),
                  ),
              ],
            );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postUpdate(WidgetRef ref, BuildContext context, Campaign campaign) async {
    final controller = TextEditingController();
    var sending = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(campaign.isEvent ? 'Post an event update' : 'Post an update'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share news with your ${campaign.isEvent ? 'attendees and ticket holders' : 'donors'}. '
                  'Your update is reviewed by a Kingdom Sponsor admin before it goes live '
                  'and is pushed to everyone who supports this ${campaign.isEvent ? 'event' : 'campaign'}.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLength: 500,
                  maxLines: 5,
                  minLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Update message',
                    hintText: 'e.g. We\'ve reached 50% of our goal — thank you!',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(LucideIcons.megaphone),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sending ? null : () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Write your update first.')),
                  );
                  return;
                }
                setDialogState(() => sending = true);
                try {
                  final res = await ref.read(apiClientProvider).postAnnouncement(campaign.id, text);
                  final status = res['status'] as String?;
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(
                        status == 'approved'
                            ? 'Update published — your supporters have been notified.'
                            : 'Update submitted for review. You\'ll be notified once an admin approves it.',
                      )),
                    );
                  }
                } on ApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                    setDialogState(() => sending = false);
                  }
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Could not post the update. Try again.')),
                    );
                    setDialogState(() => sending = false);
                  }
                }
              },
              child: sending
                  ? const SizedBox(width: 18, height: 18, child: AppIconSpinner(size: 18))
                  : const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (ok == true) ref.invalidate(hostProvider);
  }

  Future<void> _requestDelete(WidgetRef ref, BuildContext context) async {
    final reason = TextEditingController();
    var sending = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Request to delete campaign?'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The admin will review your request. If approved, the campaign will be removed '
                  'from Kingdom Sponsor. Financial records are kept for compliance.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() => sending = true);
                      final messenger = ScaffoldMessenger.of(ctx);
                      try {
                        await ref
                            .read(apiClientProvider)
                            .requestCampaignDelete(campaign.id,
                                reason: reason.text.trim());
                        if (ctx.mounted) {
                          Navigator.pop(ctx, true);
                          messenger.showSnackBar(const SnackBar(
                              content:
                                  Text('Delete request sent to the admin')));
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => sending = false);
                        messenger.showSnackBar(SnackBar(content: Text(e.message)));
                      } catch (_) {
                        setDialogState(() => sending = false);
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Could not send the request. Try again.')));
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (ok == true) ref.invalidate(hostProvider);
  }
}
