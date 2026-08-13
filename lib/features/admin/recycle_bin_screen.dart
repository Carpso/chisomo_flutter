import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Recycle Bin: soft-deleted campaigns kept out of the main admin list.
/// Restoring requires typing RESTORE (explicit guardrail gate).
class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  List<dynamic> _deleted = [];
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
      final res = await ref.read(apiClientProvider).getDeletedCampaigns();
      if (mounted) setState(() => _deleted = res['campaigns'] as List<dynamic>? ?? []);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the recycle bin.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(Map<String, dynamic> c) async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Restore this campaign?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${c['title']}" will go live again and the host will be notified. '
                'Type RESTORE to confirm.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                decoration: const InputDecoration(labelText: 'Type RESTORE', isDense: true),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: confirm.text.trim().toUpperCase() == 'RESTORE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );
    confirm.dispose();
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).restoreCampaign((c['id'] as num?)?.toInt() ?? 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${c['title']}" restored.')));
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not restore.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: [IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _load)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: AppIconSpinner())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                    ],
                  )
                : _deleted.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(LucideIcons.archive, size: 44, color: AppColors.textMuted),
                                SizedBox(height: 12),
                                Text('Recycle bin is empty.',
                                    style: TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.archive, size: 15, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text('Deleted campaigns (${_deleted.length})',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          for (final c in _deleted)
                            Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(LucideIcons.archiveRestore, size: 20, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c['title'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(
                                            c['hostName'] != null ? 'Hosted by ${c['hostName']}' : 'Deleted campaign',
                                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _restore(c),
                                      icon: const Icon(LucideIcons.rotateCcw, size: 14),
                                      label: const Text('Restore'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}
