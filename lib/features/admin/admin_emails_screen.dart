import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin: list of donor emails captured on card donations and card ticket
/// purchases, with their giving totals. Only emails that have given are shown.
class AdminEmailsScreen extends ConsumerStatefulWidget {
  const AdminEmailsScreen({super.key});

  @override
  ConsumerState<AdminEmailsScreen> createState() => _AdminEmailsScreenState();
}

class _AdminEmailsScreenState extends ConsumerState<AdminEmailsScreen> {
  final _search = TextEditingController();
  List<dynamic> _emails = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).getAdminEmails(q: _search.text.trim());
      if (!mounted) return;
      setState(() {
        _emails = res['emails'] as List<dynamic>? ?? [];
        _total = (res['total'] as num?)?.toInt() ?? _emails.length;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load emails. Try again.'; _loading = false; });
    }
  }

  Future<void> _copyEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$email copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Donor emails ($_total)'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(LucideIcons.refreshCw, size: 18)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search email or donor name',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Clear', icon: const Icon(LucideIcons.x, size: 18), onPressed: () { _search.clear(); _load(); }),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
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
                        child: _emails.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(48),
                                    child: Column(
                                      children: [
                                        Icon(LucideIcons.mail, size: 44, color: AppColors.textMuted),
                                        SizedBox(height: 12),
                                        Text('No card-donor emails yet.', style: TextStyle(color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _emails.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 6),
                                itemBuilder: (context, i) {
                                  final e = _emails[i];
                                  final email = e['email'] as String? ?? '';
                                  return Card(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      leading: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(LucideIcons.mail, size: 19, color: AppColors.primary),
                                      ),
                                      title: Text(email, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                      subtitle: Text(
                                        '${e['donor'] ?? 'Giver'} • ${e['contributions'] ?? 0} contribution(s) • ${formatKwacha((e['totalCents'] as num?)?.toInt() ?? 0)}\n${(e['lastContribution'] as String? ?? '').replaceAll('T', ' ')}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11.5),
                                      ),
                                      trailing: IconButton(
                                        tooltip: 'Copy email',
                                        icon: const Icon(LucideIcons.copy, size: 18, color: AppColors.textMuted),
                                        onPressed: () => _copyEmail(email),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
