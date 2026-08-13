import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Gamified donor achievements: badges, level, points and tier progress.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
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
      final res = await ref.read(apiClientProvider).getMyAchievements();
      if (mounted) setState(() => _data = res);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load achievements.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'first_gift': return LucideIcons.heart;
      case 'five_gifts': return LucideIcons.star;
      case 'ten_gifts': return LucideIcons.trophy;
      case 'three_campaigns': return LucideIcons.users;
      case 'big_giver': return LucideIcons.crown;
      case 'event_goer': return LucideIcons.ticket;
      case 'referrer': return LucideIcons.userPlus;
      case 'sponsor_tier': return LucideIcons.gem;
      default: return LucideIcons.badge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = (_data?['stats'] as Map<String, dynamic>?) ?? {};
    final badges = (_data?['badges'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
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
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [AppColors.gold, AppColors.primary]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(LucideIcons.crown, color: Colors.white, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${stats['tier'] ?? 'Giver'}',
                                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                    Text('${stats['gifts'] ?? 0} gifts • ${formatKwacha(stats['cents'] ?? 0)} given',
                                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                                    const SizedBox(height: 6),
                                    Text('Level ${stats['level'] ?? 0} • ${(stats['points'] ?? 0).toStringAsFixed(0)} pts',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                        child: Text('Badges', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.15,
                        children: [
                          for (final b in badges)
                            _BadgeCard(
                              label: b['label'] as String? ?? '',
                              desc: b['desc'] as String? ?? '',
                              icon: _iconFor(b['key'] as String? ?? ''),
                              earned: b['earned'] == true,
                              progress: (b['progress'] as num?)?.toDouble() ?? 0,
                            ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String label;
  final String desc;
  final IconData icon;
  final bool earned;
  final double progress;

  const _BadgeCard({
    required this.label,
    required this.desc,
    required this.icon,
    required this.earned,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: earned ? AppColors.gold.withValues(alpha: 0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: earned ? AppColors.gold : AppColors.textMuted),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: earned ? AppColors.gold : AppColors.textDark)),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 10.5, height: 1.3)),
            const Spacer(),
            if (!earned)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE8EDE8),
                  color: AppColors.primary,
                ),
              )
            else
              const Text('Earned!', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.gold)),
          ],
        ),
      ),
    );
  }
}
