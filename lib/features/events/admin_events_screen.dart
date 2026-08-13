import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/info_badge.dart';

/// Admin events analytics — events kept fully separate from campaigns:
/// ticket sales, revenue, sell-through, RSVPs and top events.
class AdminEventsScreen extends ConsumerStatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  ConsumerState<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends ConsumerState<AdminEventsScreen> {
  Map<String, dynamic>? _data;
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
      final res = await ref.read(apiClientProvider).getAdminEventsStats();
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
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
          _error = 'Could not load event stats.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
          ),
          IconButton(
            tooltip: 'What is this?',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Event analytics are tracked separately from campaigns. '
                    'Tickets sold counts every ticket bought (a table of 10 counts as 10). '
                    'Sell-through shows how full your capped events are, and RSVPs count '
                    'everyone going to free events.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted, height: 1.5),
                  ),
                ),
              ),
            ),
            icon: const Icon(LucideIcons.info, size: 18),
          ),
        ],
      ),
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
                      if (_data?['stats'] is Map<String, dynamic>) ...[
                        _StatCard(
                          icon: LucideIcons.calendarDays,
                          label: 'Active events',
                          value: '${_data!['stats']['activeEvents'] ?? 0}',
                          hint: 'Events currently accepting ticket sales',
                        ),
                        _StatCard(
                          icon: LucideIcons.ticket,
                          label: 'Tickets sold',
                          value: '${_data!['stats']['ticketsSold'] ?? 0}',
                          hint: 'Every ticket bought (quantity counted)',
                        ),
                        _StatCard(
                          icon: LucideIcons.wallet,
                          label: 'Ticket revenue',
                          value: formatKwacha((_data!['stats']['ticketsSoldValueCents'] as num?)?.toInt() ?? 0),
                          hint: 'Confirmed ticket payments',
                        ),
                        _StatCard(
                          icon: LucideIcons.gauge,
                          label: 'Sell-through',
                          value: '${_data!['stats']['sellThrough'] ?? 0}%',
                          hint: 'Tickets sold vs total capacity of capped events',
                        ),
                        _StatCard(
                          icon: LucideIcons.users,
                          label: 'RSVPs',
                          value: '${_data!['stats']['rsvps'] ?? 0}',
                          hint: 'People going to free events',
                        ),
                        _StatCard(
                          icon: LucideIcons.shoppingBag,
                          label: 'Average ticket price',
                          value: formatKwacha((_data!['stats']['avgTicketCents'] as num?)?.toInt() ?? 0),
                          hint: 'Revenue per ticket sold',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Top events',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          InfoBadge(
                            title: 'Top events',
                            text: 'The events selling the most tickets right now, with their capacity and revenue.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final e in (_data?['topEvents'] as List<dynamic>? ?? const []))
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.ticket, size: 20, color: AppColors.gold),
                            ),
                            title: Text(
                              e['title'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${e['sold'] ?? 0} sold${(e['capacity'] as num? ?? 0) > 0 ? ' / ${e['capacity']} capacity' : ''}'
                              '${e['eventDate'] != null ? ' • ${e['eventDate']}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              formatKwacha((e['revenueCents'] as num?)?.toInt() ?? 0),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      if ((_data?['topEvents'] as List<dynamic>? ?? const []).isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No ticket sales yet.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Recent ticket sales',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          InfoBadge(
                            title: 'Recent ticket sales',
                            text: 'The latest confirmed ticket purchases across all events.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final s in (_data?['recentSales'] as List<dynamic>? ?? const []))
                        ListTile(
                          dense: true,
                          leading: const Icon(LucideIcons.ticket, size: 18, color: AppColors.primary),
                          title: Text(
                            '${s['ticketQty'] ?? 1}× ${s['tierName'] ?? 'ticket'} — ${s['title'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            (s['createdAt'] as String? ?? '').replaceAll('T', ' '),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            formatKwacha((s['amountCents'] as num?)?.toInt() ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      if ((_data?['recentSales'] as List<dynamic>? ?? const []).isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No recent sales.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;

  const _StatCard({required this.icon, required this.label, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                  ),
                  if (hint.isNotEmpty)
                    Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            InfoBadge(text: hint),
          ],
        ),
      ),
    );
  }
}
