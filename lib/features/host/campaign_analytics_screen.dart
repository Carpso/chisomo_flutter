import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Per-campaign analytics for the host: views, gifts, conversion rate,
/// share clicks and a 14-day giving chart.
class CampaignAnalyticsScreen extends ConsumerStatefulWidget {
  final int campaignId;
  final String title;

  const CampaignAnalyticsScreen({super.key, required this.campaignId, required this.title});

  @override
  ConsumerState<CampaignAnalyticsScreen> createState() => _CampaignAnalyticsScreenState();
}

class _CampaignAnalyticsScreenState extends ConsumerState<CampaignAnalyticsScreen> {
  Map<String, dynamic>? _data;
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
      final res = await ref.read(apiClientProvider).getCampaignAnalytics(widget.campaignId);
      if (mounted) setState(() => _data = res);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load analytics.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _metric(context, 'Views', '${_data?['views'] ?? 0}', LucideIcons.eye),
                              const SizedBox(width: 12),
                              _metric(context, 'Gifts', '${_data?['gifts'] ?? 0}', LucideIcons.hand),
                              const SizedBox(width: 12),
                              _metric(context, 'Conversion', '${_data?['conversionRate'] ?? 0}%', LucideIcons.target),
                            ],
                          ),
                        ),
                      ),
                      if (_data?['isEvent'] == true) ...[
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(LucideIcons.ticket, size: 16, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text('Event performance', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _metric(context, 'Tickets sold', '${_data?['ticketsSold'] ?? 0}', LucideIcons.ticket),
                                    const SizedBox(width: 12),
                                    _metric(context, 'Revenue', formatKwacha(_data?['revenueCents'] as int? ?? 0), LucideIcons.banknote),
                                    const SizedBox(width: 12),
                                    _metric(context, 'Attendees', '${_data?['attendees'] ?? 0}', LucideIcons.users),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_data?['ticketCapacity'] is int && (_data?['ticketCapacity'] as int) > 0) ...[
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text('Sell-through', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                      ),
                                      Text('${_data?['sellThrough'] ?? 0}%',
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ((_data?['sellThrough'] as num?) ?? 0) / 100,
                                      minHeight: 7,
                                      backgroundColor: const Color(0xFFE8EDE8),
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(LucideIcons.link, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text('Share link clicks',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text('${_data?['shareClicks'] ?? 0}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(LucideIcons.trendingUp, size: 16, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Giving — last 14 days',
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _Last14BarChart(days: _data?['last14d'] as List<dynamic>? ?? []),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Last14BarChart extends StatelessWidget {
  final List<dynamic> days;

  const _Last14BarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No confirmed gifts in the last 14 days.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    final maxCents = days.fold<int>(0, (m, d) => ((d['cents'] as int?) ?? 0) > m ? (d['cents'] as int?)! : m);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: maxCents > 0 ? 110 * ((d['cents'] as int?) ?? 0) / maxCents : 0,
                  decoration: BoxDecoration(
                    color: ((d['cents'] as int?) ?? 0) > 0 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
