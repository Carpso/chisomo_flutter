import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin moderation queue for host-posted updates. Superadmins and assistants
/// with the `campaigns` scope review what hosts write before it goes live and
/// is pushed to their donors.
class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends ConsumerState<AdminAnnouncementsScreen> {
  List<dynamic> _pending = [];
  List<dynamic> _recent = [];
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
      final api = ref.read(apiClientProvider);
      final pending = await api.getAdminAnnouncements(status: 'pending');
      final recent = await api.getAdminAnnouncements(status: 'all');
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _recent = recent;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load updates. Try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _approve(Map<dynamic, dynamic> a) async {
    final id = (a['id'] as num?)?.toInt() ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish update?'),
        content: Text('This update will go live on "${a['campaignTitle']}" and be pushed to every confirmed donor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ref.read(apiClientProvider).approveAnnouncement(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Update published')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _reject(Map<dynamic, dynamic> a) async {
    final id = (a['id'] as num?)?.toInt() ?? 0;
    final reason = TextEditingController();
    var sending = false;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Decline update'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The host will see this reason and be notified that the update was not published.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'e.g. Please avoid asking donors for cash directly.',
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
              onPressed: sending ? null : () async {
                setDialogState(() => sending = true);
                try {
                  await ref.read(apiClientProvider).rejectAnnouncement(id, reason: reason.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Update declined — the host was notified.')),
                    );
                  }
                  await _load();
                } on ApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                    setDialogState(() => sending = false);
                  }
                }
              },
              child: sending
                  ? const SizedBox(width: 18, height: 18, child: AppIconSpinner(size: 18))
                  : const Text('Decline update'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Updates to review')),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Pending review (${_pending.length})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hosts post updates for their donors. Approving publishes them on the '
                        'campaign/event page and pushes a notification to everyone who supports it.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      if (_pending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No updates waiting for review.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                        ),
                      for (final a in _pending)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(LucideIcons.megaphone, size: 18, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a['campaignTitle'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                          Text(
                                            '${a['campaignType'] == 'event' ? 'Event' : 'Campaign'} • by ${a['author'] ?? 'Host'} • ${(a['createdAt'] as String? ?? '').replaceAll('T', ' ')}',
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  a['body'] ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _approve(a),
                                        icon: const Icon(LucideIcons.checkCircle, size: 16, color: AppColors.primary),
                                        label: const Text('Approve'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _reject(a),
                                        icon: const Icon(LucideIcons.xCircle, size: 16, color: AppColors.danger),
                                        label: const Text('Decline'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Recently decided',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      for (final a in _recent)
                        if ((a['status'] as String? ?? '') != 'pending')
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              (a['status'] as String? ?? '') == 'approved'
                                  ? LucideIcons.checkCircle
                                  : LucideIcons.xCircle,
                              size: 18,
                              color: (a['status'] as String? ?? '') == 'approved'
                                  ? AppColors.primary
                                  : AppColors.danger,
                            ),
                            title: Text(
                              a['body'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${a['campaignTitle'] ?? ''} • ${(a['createdAt'] as String? ?? '').replaceAll('T', ' ')}'
                              '${a['rejectionReason'] != null ? ' • ${a['rejectionReason']}' : ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      if (_recent.every((a) => (a['status'] as String? ?? '') == 'pending'))
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Nothing decided yet.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                        ),
                    ],
                  ),
                ),
    );
  }
}
