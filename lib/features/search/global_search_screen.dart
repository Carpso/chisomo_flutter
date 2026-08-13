import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../auth/auth_controller.dart';
import '../campaigns/models.dart';

/// Global search across campaigns and (for admins) users, support tickets and
/// transactions — all from one box.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  Map<String, dynamic>? _results;
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? _]) async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() { _results = null; _searched = false; });
      return;
    }
    setState(() { _loading = true; });
    try {
      final res = await ref.read(apiClientProvider).globalSearch(q);
      if (mounted) setState(() { _results = res; _searched = true; });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not search. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authControllerProvider).value?.isAdmin ?? false;
    final campaigns = (_results?['campaigns'] as List<dynamic>? ?? [])
        .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
        .toList();
    final users = _results?['users'] as List<dynamic>? ?? [];
    final tickets = _results?['tickets'] as List<dynamic>? ?? [];
    final transactions = _results?['transactions'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Campaigns, hosts, donors, tickets, transactions…',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() { _results = null; _searched = false; });
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : !_searched
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.search, size: 44, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('Search campaigns, people, tickets and transactions.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Header('Campaigns', campaigns.length),
                    if (campaigns.isEmpty)
                      const _Empty('No campaigns match.')
                    else
                      for (final c in campaigns)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(LucideIcons.megaphone, color: AppColors.primary),
                            title: Text(c.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            subtitle: Text('${c.hostName ?? 'Host'} • ${c.raisedLabel}'),
                            trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                            onTap: () => context.push('/campaign/${c.id}'),
                          ),
                        ),
                    if (isAdmin) ...[
                      const SizedBox(height: 8),
                      _Header('Users', users.length),
                      if (users.isEmpty)
                        const _Empty('No users match.')
                      else
                        for (final u in users)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(LucideIcons.user, color: AppColors.primary),
                              title: Text('${u['name'] ?? u['username']}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              subtitle: Text('${u['phone'] ?? ''} • ${u['username'] ?? ''}'),
                              onTap: () => context.push('/admin/users'),
                            ),
                          ),
                      const SizedBox(height: 8),
                      _Header('Support tickets', tickets.length),
                      if (tickets.isEmpty)
                        const _Empty('No tickets match.')
                      else
                        for (final t in tickets)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(LucideIcons.headphones, color: AppColors.primary),
                              title: Text(t['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              subtitle: Text('${t['username'] ?? ''} • ${t['phone'] ?? ''}'),
                              onTap: () => context.push('/admin'),
                            ),
                          ),
                      const SizedBox(height: 8),
                      _Header('Transactions', transactions.length),
                      if (transactions.isEmpty)
                        const _Empty('No transactions match.')
                      else
                        for (final t in transactions)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(LucideIcons.receipt, color: AppColors.primary),
                              title: Text('${formatKwacha(t['amountCents'] ?? 0)} • ${t['status']}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              subtitle: Text('${t['campaignTitle'] ?? ''} • ${t['phone'] ?? ''}'),
                              onTap: () => context.push('/admin/transactions'),
                            ),
                          ),
                    ],
                  ],
                ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  final int count;

  const _Header(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;

  const _Empty(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}
