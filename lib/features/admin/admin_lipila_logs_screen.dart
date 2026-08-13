import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';

const _kGreen = Color(0xFF1B873F);

class LipilaLogsScreen extends ConsumerStatefulWidget {
  const LipilaLogsScreen({super.key});

  @override
  ConsumerState<LipilaLogsScreen> createState() => _LipilaLogsScreenState();
}

class _LipilaLogsScreenState extends ConsumerState<LipilaLogsScreen> {
  String? _kindFilter;     // null = all, else "collection" | "disbursement"
  String? _statusFilter;   // null = all, else pending/success/failed/error
  List<dynamic> _logs = [];
  bool _loading = false;
  String? _error;
  static const _statuses = ['All', 'pending', 'success', 'failed', 'error'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _logs = []; });
    try {
      final res = await ref.read(apiClientProvider).getLipilaLogs(
        kind: _kindFilter, status: _statusFilter, limit: 200,
      );
      if (!mounted) return;
      final logs = (res['logs'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      setState(() { _logs = logs; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lipila Logs'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: Text(_kindFilter == null ? 'All types' : _kindFilter! == 'collection' ? 'Collections' : 'Disbursements'),
                  selected: _kindFilter == null,
                  onSelected: (_) => _setKind(null),
                ),
                ChoiceChip(
                  label: const Text('Collections'),
                  selected: _kindFilter == 'collection',
                  onSelected: (_) => _setKind('collection'),
                ),
                ChoiceChip(
                  label: const Text('Disbursements'),
                  selected: _kindFilter == 'disbursement',
                  onSelected: (_) => _setKind('disbursement'),
                ),
                for (final s in _statuses.skip(1))
                  ChoiceChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    selected: _statusFilter == s,
                    onSelected: (_) => _setStatus(s),
                  ),
                if (_statusFilter != null)
                  ChoiceChip(
                    label: const Text('Clear'),
                    selected: false,
                    onSelected: (_) => _setStatus(null),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppIconSpinner())
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      )
                    : _logs.isEmpty
                        ? const _Empty()
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: _logs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final log = _logs[i];
                              final amount = (log['amountCents'] as int? ?? 0);
                              final status = log['status'] as String? ?? 'unknown';
                              final kind = log['kind'] as String? ?? '?';
                              final down = status == 'failed' || status == 'error';
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  leading: Icon(
                                    kind == 'collection' ? LucideIcons.wallet : LucideIcons.send,
                                    size: 18, color: down ? AppColors.danger : _kGreen,
                                  ),
                                  title: Text(log['referenceId'] ?? '', style: theme.textTheme.bodySmall),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (log['phone'] != null)
                                        Text('Phone: ${log['phone']}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                                      if ((log['message'] as String?)?.isNotEmpty == true)
                                        Text(log['message'] as String, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(formatKwacha(amount), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: down ? AppColors.danger.withValues(alpha: 0.12) : _kGreen.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(status, style: TextStyle(
                                          color: down ? AppColors.danger : _kGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        )),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _setKind(String? k) {
    setState(() { _kindFilter = k; });
    _load();
  }

  void _setStatus(String? s) {
    setState(() { _statusFilter = s; });
    _load();
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No Lipila logs yet.', textAlign: TextAlign.center),
      ),
    );
  }
}
