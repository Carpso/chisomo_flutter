import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/offline_cache.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'campaigns_controller.dart';
import 'campaign_image.dart';
import 'models.dart';

class CampaignListScreen extends ConsumerWidget {
  const CampaignListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignsProvider);
    final offline = ref.watch(offlineModeProvider);
    final isAdmin = ref.watch(authControllerProvider).value?.isAdmin ?? false;
    final trendId = campaigns.value != null && (campaigns.value?.isNotEmpty ?? false)
        ? campaigns.value!
            .reduce((a, b) => (a.dailyRateCents >= b.dailyRateCents) ? a : b)
            .id
        : -1;

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Kingdom Sponsor', maxLines: 1),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(LucideIcons.shieldCheck),
              tooltip: 'Admin dashboard',
              onPressed: () => context.push('/admin'),
            ),
          IconButton(
            icon: const Icon(LucideIcons.repeat),
            tooltip: 'Monthly reminders',
            onPressed: () => context.push('/pledges'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.user),
            onPressed: () => context.push('/host'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (offline)
            Container(
              width: double.infinity,
              color: AppColors.gold.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Icon(LucideIcons.wifiOff, size: 16, color: Color(0xFF8A6A00)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline — showing last saved campaigns',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: campaigns.when(
              loading: () => const _ListSkeleton(),
              error: (e, _) =>
                  _ErrorRetry(message: '$e', onRetry: () => ref.invalidate(campaignsProvider)),
              data: (items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(campaignsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) =>
                      _CampaignCard(campaign: items[i], isTrending: items[i].id == trendId),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final bool isTrending;

  const _CampaignCard({required this.campaign, this.isTrending = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/campaign/${campaign.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: CampaignImage(campaign: campaign, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTrending)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.flame, size: 12, color: AppColors.gold),
                                  SizedBox(width: 3),
                                  Text('Trending',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.gold)),
                                ],
                              ),
                            ),
                          ),
Text(
                      campaign.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (campaign.promoted)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.star, size: 10, color: AppColors.gold),
                                  SizedBox(width: 2),
                                  Text('Promoted',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.gold)),
                                ],
                              ),
                            ),
                          ),
                        Text(
                          campaign.donorCount == 0
                              ? 'Be the first to give'
                              : '${campaign.donorCount} ${campaign.donorCount == 1 ? 'donor' : 'donors'}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),                      ],
                    ),
                      ],
                    ),
                  ),
                  if (campaign.hasGoal)
                    Text(
                      '${(campaign.progress * 100).round()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    Text(
                      campaign.raisedLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              if (campaign.hasGoal) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: campaign.progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE8EDE8),
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      campaign.raisedLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'of ${campaign.goalLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EDE8),
      highlightColor: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
