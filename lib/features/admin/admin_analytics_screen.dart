import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin analytics — donations-over-time, per-campaign conversion
/// (views → gifts), and top events. Charts are dependency-free bars.
class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
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
      final res = await ref.read(apiClientProvider).getAdminAnalytics();
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
        title: const Text('Analytics'),
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
                      _SectionCard(
                        title: 'Donations — last 30 days',
                        icon: LucideIcons.trendingUp,
                        child: _DailyBarChart(days: _data?['daily'] as List<dynamic>? ?? []),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Campaign conversion (views → gifts)',
                        icon: LucideIcons.target,
                        child: _ConversionList(rows: _data?['conversion'] as List<dynamic>? ?? []),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Top events',
                        icon: LucideIcons.ticket,
                        child: _TopEventsList(rows: _data?['topEvents'] as List<dynamic>? ?? []),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Horizontal-ish bar chart of daily donation amounts (last 30 days).
class _DailyBarChart extends StatelessWidget {
  final List<dynamic> days;

  const _DailyBarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No donations in the last 30 days.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    final maxCents = days.fold<int>(0, (m, d) => ((d['cents'] as int?) ?? 0) > m ? (d['cents'] as int?)! : m);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (((d['cents'] as int?) ?? 0) > 0)
                      Text(
                        formatKwachaShort((d['cents'] as int?) ?? 0),
                        style: const TextStyle(fontSize: 7.5, color: AppColors.textMuted),
                      ),
                    const SizedBox(height: 2),
                    Container(
                      height: maxCents > 0 ? 100 * ((d['cents'] as int?) ?? 0) / maxCents : 0,
                      decoration: BoxDecoration(
                        color: ((d['cents'] as int?) ?? 0) > 0 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversionList extends StatelessWidget {
  final List<dynamic> rows;

  const _ConversionList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No active campaigns yet.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => context.push('/campaign/${r['campaignId']}'),
                        child: Text(
                          r['title'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${r['views'] ?? 0} views · ${r['gifts'] ?? 0} gifts',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ((r['rate'] as num?) ?? 0) / 100,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE8EDE8),
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${r['rate'] ?? 0}%',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopEventsList extends StatelessWidget {
  final List<dynamic> rows;

  const _TopEventsList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No event campaigns yet.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/campaign/${r['campaignId']}'),
                    child: Text(
                      r['title'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${r['sold'] ?? 0}/${r['capacity'] ?? 0} tickets',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Compact kwacha label for bar charts (e.g. K1.2k).
String formatKwachaShort(int cents) {
  final k = cents / 100;
  if (k >= 1000000) return 'K${(k / 1000000).toStringAsFixed(1)}M';
  if (k >= 1000) return 'K${(k / 1000).toStringAsFixed(1)}k';
  return 'K${k.round()}';
}
