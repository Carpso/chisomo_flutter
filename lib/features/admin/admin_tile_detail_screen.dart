import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/campaigns_controller.dart';

/// What data the tile-detail screen loads under its breakdown rows.
enum AdminTileKind {
  users,
  applications,
  pledges,
  tickets,
  deleteRequests,
  campaigns,
  referrals,
}

/// Full-screen detail behind a dashboard stat tile. Replaces the old
/// slide-up breakdown modal: the same rows are shown, and where a live
/// list exists (applications, pledges, tickets, delete requests) it is
/// fetched and rendered with its actions.
class AdminTileDetailScreen extends ConsumerStatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final AdminTileKind kind;
  final List<(String, String)> breakdown;

  const AdminTileDetailScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.kind,
    required this.breakdown,
  });

  @override
  ConsumerState<AdminTileDetailScreen> createState() => _AdminTileDetailScreenState();
}

class _AdminTileDetailScreenState extends ConsumerState<AdminTileDetailScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  int _threshold = 10;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    if (widget.kind != AdminTileKind.users) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      if (widget.kind == AdminTileKind.referrals) {
        final res = await api.getAdminReferrals();
        if (mounted) {
          setState(() {
            _threshold = res['threshold'] as int? ?? 10;
            _items = res['referrers'] as List<dynamic>? ?? [];
          });
        }
      } else {
        final List<dynamic> items = switch (widget.kind) {
          AdminTileKind.applications => await api.getAdminApplications(),
          AdminTileKind.pledges => await api.getAdminPledges(),
          AdminTileKind.tickets => (await api.getAdminTickets()).$1,
          AdminTileKind.deleteRequests => await api.getDeleteRequests(),
          AdminTileKind.campaigns => await api.getAdminCampaigns(),
          AdminTileKind.referrals => [],
          AdminTileKind.users => [],
        };
        if (mounted) setState(() => _items = items);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load ${widget.title.toLowerCase()}.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() call, int id,
      {String okMessage = 'Done'}) async {
    setState(() => _busy.add(id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await call();
      messenger.showSnackBar(SnackBar(content: Text(okMessage)));
      await _load();
      ref.invalidate(adminDataProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  /// Lets the admin set how many sign-ups qualify a referrer for a reward.
  Future<void> _editThreshold() async {
    final controller = TextEditingController(text: '$_threshold');
    var saving = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Referral reward target'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A user qualifies for the admin reward once this many invited sign-ups register.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Invites needed',
                    prefixIcon: Icon(LucideIcons.userPlus, size: 18),
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
                      final n = int.tryParse(controller.text.trim());
                      if (n == null || n < 1 || n > 1000) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter a number between 1 and 1000')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final res = await ref
                            .read(apiClientProvider)
                            .put('/api/admin/referral-threshold', {'threshold': n}, auth: true);
                        if (ctx.mounted) {
                          Navigator.pop(ctx, true);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Reward target set to $n invites')),
                          );
                        }
                        if (mounted) setState(() => _threshold = res['threshold'] as int? ?? n);
                      } on ApiException catch (e) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
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
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (ok == true) await _load();
  }

  /// Mark an approved host as independently verified (with private notes).
  Future<void> _verifyHost(ApiClient api, int id, Map<String, dynamic> item) async {
    final currentlyVerified = item['hostVerified'] == true;
    final notesController = TextEditingController(
        text: (item['hostVerificationNotes'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentlyVerified ? 'Revoke verification?' : 'Verify this host?'),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentlyVerified
                    ? 'This removes the verified-host mark for ${item['username'] ?? 'this user'}.'
                    : 'Confirm this host beyond the app (e.g. checked registration, called them). '
                      'These notes are private to admins.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              if (!currentlyVerified) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Verification notes (private)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: currentlyVerified
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(currentlyVerified ? 'Revoke' : 'Verify host'),
          ),
        ],
      ),
    );
    notesController.dispose();
    if (ok != true) return;
    await _run(
      () => api.verifyHost(id,
          verified: !currentlyVerified, notes: notesController.text.trim()),
      id,
      okMessage: currentlyVerified ? 'Verification revoked' : 'Host verified',
    );
  }

  /// Approve or reject a host's KYC submission (flips the public verified badge).
  Future<void> _kycDecide(ApiClient api, int id, Map<dynamic, dynamic> item, bool approve) async {
    final notesController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve KYC?' : 'Reject KYC?'),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approve
                    ? 'This confirms the identity document and turns on the public verified badge for this host.'
                    : 'Rejecting keeps the verified badge off. Add a note for the host.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (private)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: approve ? null : FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve KYC' : 'Reject KYC'),
          ),
        ],
      ),
    );
    notesController.dispose();
    if (ok != true) return;
    await _run(
      () => api.decideKyc(id, approve: approve, notes: notesController.text.trim()),
      id,
      okMessage: approve ? 'KYC approved — host verified' : 'KYC rejected',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(widget.icon, size: 18, color: widget.color),
                        const SizedBox(width: 8),
                        Text(
                          'Overview',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final (label, value) in widget.breakdown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                            Text(
                              value,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.kind == AdminTileKind.referrals)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.target, size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reward target: $_threshold invited sign-ups',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(onPressed: _editThreshold, child: const Text('Change')),
                    ],
                  ),
                ),
              ),
            if (widget.kind == AdminTileKind.users)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'User-level detail lives in the transactions ledger. '
                          'Tap "Donors" or "Per day" tiles to explore giving.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: AppIconSpinner()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.danger)),
                ),
              )
            else if (_items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nothing here yet.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              for (final item in _items) _buildItem(item),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final busy = _busy.contains(id);
    final api = ref.read(apiClientProvider);

    return Card(
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
                    switch (widget.kind) {
                      AdminTileKind.applications =>
                        item['org'] as String? ?? 'Unknown organisation',
                      AdminTileKind.pledges =>
                        item['campaignTitle'] as String? ?? 'Campaign',
                      AdminTileKind.tickets =>
                        '#$id ${item['subject'] ?? ''}',
                      AdminTileKind.deleteRequests =>
                        item['campaignTitle'] as String? ?? 'Campaign',
                      AdminTileKind.campaigns =>
                        item['title'] as String? ?? 'Campaign',
                      AdminTileKind.referrals =>
                        item['username'] as String? ?? 'Referrer',
                      AdminTileKind.users => '',
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(item).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusLabel(item),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _statusColor(item),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            switch (widget.kind) {
              AdminTileKind.applications => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['username'] ?? 'Giver'} • ${item['phone'] ?? ''}',
                        style: theme.textTheme.bodySmall),
                    if (item['role'] != null)
                      Text('Role: ${item['role']}', style: theme.textTheme.bodySmall),
                    if (item['reason'] != null)
                      Text('For: ${item['reason']}', style: theme.textTheme.bodySmall),
                    if (item['rejection'] != null)
                      Text('Rejected: ${item['rejection']}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.danger)),
                    if (item['kycStatus'] != null && item['kycStatus'] != 'none') ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(LucideIcons.fileBadge, size: 13, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(
                            'KYC: ${_kycStatusLabel(item['kycStatus'])}${item['kycType'] != null ? ' • ${_kycTypeLabel(item['kycType'])}' : ''}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ],
                      ),
                      if (item['kycNotes'] != null)
                        Text('KYC note: ${item['kycNotes']}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted, fontSize: 11)),
                      if (item['kycDocUrl'] != null) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => launchUrl(Uri.parse(item['kycDocUrl'] as String)),
                          child: Row(
                            children: [
                              Icon(LucideIcons.eye, size: 13, color: AppColors.primary),
                              const SizedBox(width: 5),
                              Text('View document',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              AdminTileKind.pledges => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['username'] ?? 'Giver'} • ${item['phone'] ?? ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${formatKwacha(item['amountCents'] ?? 0)} on day ${item['dayOfMonth'] ?? '-'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text('Since ${safePrefix(item['createdAt'], 16)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              AdminTileKind.tickets => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['username'] ?? 'Giver'} • ${item['phone'] ?? ''}',
                        style: theme.textTheme.bodySmall),
                    Text(item['message'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              AdminTileKind.deleteRequests => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Host: ${item['hostUsername'] ?? item['hostPhone'] ?? ''}',
                        style: theme.textTheme.bodySmall),
                    if (item['reason'] != null)
                      Text('Reason: ${item['reason']}', style: theme.textTheme.bodySmall),
                  ],
                ),
              AdminTileKind.campaigns => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Host: ${item['hostPhone'] ?? '—'}',
                        style: theme.textTheme.bodySmall),
                    Text('Raised: ${formatKwacha(item['raisedCents'] ?? 0)}',
                        style: theme.textTheme.bodySmall),
                    if (item['goalCents'] != null && item['goalCents'] > 0)
                      Text('Goal: ${formatKwacha(item['goalCents'])}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              AdminTileKind.referrals => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['phone'] ?? ''} • ${item['invites'] ?? 0} '
                        'of $_threshold referrals',
                        style: theme.textTheme.bodySmall),
                    if (item['rewardedAt'] != null)
                      Text('Rewarded on ${item['rewardedAt']}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.primary)),
                  ],
                ),
              AdminTileKind.users => const SizedBox.shrink(),
            },
            if (_canAct(item)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: busy ? null : () => _run(_approve(api, item, id), id,
                          okMessage: _okMessage()),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(widget.kind == AdminTileKind.referrals
                          ? 'Reward'
                          : 'Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: busy ? null : () => _run(_reject(api, item, id), id,
                          okMessage: 'Rejected'),
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.kind == AdminTileKind.applications &&
                (item['hostStatus'] ?? '') == 'approved') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    item['hostVerified'] == true
                        ? LucideIcons.badgeCheck
                        : LucideIcons.badge,
                    size: 16,
                    color: item['hostVerified'] == true
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['hostVerified'] == true
                          ? 'Verified host'
                          : 'Not yet independently verified',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (item['hostVerificationNotes'] != null) ...[
                const SizedBox(height: 4),
                Text('Notes: ${item['hostVerificationNotes']}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted)),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _verifyHost(api, id, item),
                icon: Icon(item['hostVerified'] == true
                    ? LucideIcons.badgeX
                    : LucideIcons.badgeCheck),
                label: Text(item['hostVerified'] == true
                    ? 'Revoke verification'
                    : 'Mark as verified'),
              ),
              if ((item['kycStatus'] ?? 'none') == 'submitted') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: busy ? null : () => _kycDecide(api, id, item, false),
                        icon: const Icon(LucideIcons.x, size: 16),
                        label: const Text('Reject KYC'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: busy ? null : () => _kycDecide(api, id, item, true),
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text('Approve KYC'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _canAct(Map<String, dynamic> item) {
    if (widget.kind == AdminTileKind.referrals) {
      return item['qualified'] == true;
    }
    final status = (item['status'] ?? item['hostStatus'] ?? '') as String;
    return status == 'pending';
  }

  String _kycStatusLabel(dynamic s) => switch (s) {
        'submitted' => 'Submitted',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'None',
      };

  String _kycTypeLabel(dynamic t) => switch (t) {
        'nrc' => 'NRC',
        'ngo_cert' => 'NGO cert',
        'endorsement' => 'Endorsement',
        _ => 'Doc',
      };

  String _okMessage() {
    return switch (widget.kind) {
      AdminTileKind.applications => 'Application approved',
      AdminTileKind.pledges => 'Pledge cancelled',
      AdminTileKind.deleteRequests => 'Delete request approved',
      AdminTileKind.referrals => 'Referrer rewarded — they were notified',
      _ => 'Done',
    };
  }

  Future<Map<String, dynamic>> Function() _approve(
      ApiClient api, Map<String, dynamic> item, int id) {
    return switch (widget.kind) {
      AdminTileKind.applications => () => api.approveApplication(id),
      AdminTileKind.pledges => () => api.cancelAdminPledge(id),
      AdminTileKind.deleteRequests => () => api.approveDeleteRequest(id),
      AdminTileKind.referrals => () => api.rewardReferral(id),
      _ => () async => {'ok': false},
    };
  }

  Future<Map<String, dynamic>> Function() _reject(
      ApiClient api, Map<String, dynamic> item, int id) {
    return switch (widget.kind) {
      AdminTileKind.applications => () => api.rejectApplication(id),
      AdminTileKind.pledges => () => api.cancelAdminPledge(id),
      AdminTileKind.deleteRequests => () => api.rejectDeleteRequest(id),
      _ => () async => {'ok': false},
    };
  }

  String _statusLabel(Map<String, dynamic> item) {
    if (widget.kind == AdminTileKind.referrals) {
      return item['rewardedAt'] != null ? 'Rewarded' : 'Qualified';
    }
    final status = (item['status'] ?? item['hostStatus'] ?? '') as String;
    return switch (status) {
      'pending' => 'Pending',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'open' => 'Open',
      'answered' => 'Answered',
      'resolved' => 'Resolved',
      _ => status.isEmpty ? '—' : status,
    };
  }

  Color _statusColor(Map<String, dynamic> item) {
    if (widget.kind == AdminTileKind.referrals) {
      return item['rewardedAt'] != null ? AppColors.primary : AppColors.gold;
    }
    final status = (item['status'] ?? item['hostStatus'] ?? '') as String;
    return switch (status) {
      'pending' || 'open' => AppColors.gold,
      'approved' || 'resolved' => AppColors.primary,
      'rejected' => AppColors.danger,
      _ => AppColors.textMuted,
    };
  }
}
