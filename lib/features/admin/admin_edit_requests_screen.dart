import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin review screen for host-submitted campaign-edit requests. Hosts can't
/// edit campaigns directly (fraud protection) — they propose changes and a
/// superadmin approves or rejects them here.
class AdminEditRequestsScreen extends ConsumerStatefulWidget {
  const AdminEditRequestsScreen({super.key});

  @override
  ConsumerState<AdminEditRequestsScreen> createState() => _AdminEditRequestsScreenState();
}

class _AdminEditRequestsScreenState extends ConsumerState<AdminEditRequestsScreen> {
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
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).getEditRequests();
      if (mounted) setState(() => _requests = res['requests'] as List<dynamic>? ?? []);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load edit requests.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(int id, bool approve, Map<dynamic, dynamic> req) async {
    setState(() => _busy.add(id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (approve) {
        await ref.read(apiClientProvider).approveEditRequest(id);
        messenger.showSnackBar(const SnackBar(content: Text('Changes applied to the campaign')));
      } else {
        await ref.read(apiClientProvider).rejectEditRequest(id);
        messenger.showSnackBar(const SnackBar(content: Text('Edit request rejected')));
      }
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Edit Requests')),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger)),
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
                      const Text(
                        'Hosts submit proposed campaign changes for review. Approve to apply them, '
                        'or reject with a note — the host is notified either way.',
                        style: TextStyle(color: AppColors.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (_requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(LucideIcons.pencil, size: 40, color: AppColors.primaryLight),
                              SizedBox(height: 12),
                              Text('No edit requests. Hosts can request changes to their '
                                  'campaigns here for your approval.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      else
                        for (final r in _requests)
                          _requestCard(theme, r),
                    ],
                  ),
                ),
    );
  }

  Widget _requestCard(ThemeData theme, Map<dynamic, dynamic> r) {
    final id = (r['id'] as num?)?.toInt() ?? 0;
    final status = (r['status'] as String?) ?? 'pending';
    final proposed = (r['proposed'] as Map<dynamic, dynamic>?) ?? {};
    final busy = _busy.contains(id);

    final Color statusColor = switch (status) {
      'pending' => AppColors.gold,
      'approved' => AppColors.primary,
      'rejected' => AppColors.danger,
      _ => AppColors.textMuted,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r['campaignTitle'] ?? 'Campaign',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ],
            ),
            Text('Host: ${r['hostName'] ?? 'Giver'}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 10),
            for (final entry in proposed.entries) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(_labelFor(entry.key),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(child: Text(_valueFor(entry.key, entry.value),
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 3),
            ],
            if (r['adminNotes'] != null) ...[
              const SizedBox(height: 6),
              Text('Admin note: ${r['adminNotes']}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : () => _decide(id, true, r),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('Approve & apply'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: busy ? null : () => _decide(id, false, r),
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text('Reject'),
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

  String _labelFor(String key) => switch (key) {
        'title' => 'Title',
        'description' => 'Description',
        'goalCents' => 'Goal',
        'minWithdrawCents' => 'Min withdraw',
        'category' => 'Category',
        'visibility' => 'Visibility',
        'endsAt' => 'End date',
        _ => key,
      };

  String _valueFor(String key, dynamic v) {
    if (v == null) return '(none)';
    if (key == 'goalCents' || key == 'minWithdrawCents') return formatKwacha((v as num).toInt());
    return v.toString();
  }
}
