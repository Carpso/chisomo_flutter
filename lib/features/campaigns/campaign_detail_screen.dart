import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/countdown_banner.dart';
import 'campaigns_controller.dart';
import 'campaign_image.dart';
import 'models.dart';
import 'share_sheet.dart';

class CampaignDetailScreen extends ConsumerWidget {
  final int campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(campaignDetailProvider(campaignId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2),
            tooltip: 'Share',
            onPressed: () async {
              final detailValue = detail.value;
              if (detailValue == null) return;
              await showShareSheet(context, ref, detailValue.campaign);
            },
          ),
        ],
      ),
       body: detail.when(
         loading: () => const Center(child: AppIconSpinner()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(campaignDetailProvider(campaignId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (d) => _DetailBody(detail: d),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final CampaignDetail detail;

  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = detail.campaign;
    final shown = c.withdrawnCents > 0;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(campaignDetailProvider(c.id)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // Cover photos fill the banner edge-to-edge; logos stay centered.
              Container(
                height: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: c.imageUrl != null
                    ? SizedBox.expand(
                        child: CampaignImage(campaign: c, fit: BoxFit.cover),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: CampaignImage(campaign: c, fit: BoxFit.contain),
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (c.promoted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.star, size: 14, color: AppColors.gold),
                          SizedBox(width: 4),
                          Text('Promoted',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(c.description, style: theme.textTheme.bodyMedium),
              if (c.endsAt != null) ...[
                const SizedBox(height: 12),
                CountdownBanner(endsAt: DateTime.parse(c.endsAt!)),
              ],
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.hasGoal) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: c.progress,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE8EDE8),
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              c.raisedLabel,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                            Text(
                              'Goal ${c.goalLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              c.raisedLabel,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'No target',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (shown) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${formatKwacha(c.withdrawnCents)} already withdrawn by the host',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${c.donationCount} ${c.donationCount == 1 ? 'donation' : 'donations'}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      _InsightRow(
                        icon: LucideIcons.barChart3,
                        label: 'Average donation',
                        value: formatKwacha(c.avgDonationCents),
                      ),
                      _InsightRow(
                        icon: LucideIcons.trendingUp,
                        label: 'Raising per day',
                        value: formatKwacha(c.dailyRateCents),
                      ),
                      if (c.donorsNeededAtAvg != null && c.hasGoal)
                        _InsightRow(
                          icon: LucideIcons.users,
                          label: 'To reach the goal at this average',
                          value: '${c.donorsNeededAtAvg} more',
                          valueColor: AppColors.primary,
                        ),
                      if (c.estimatedEndDate != null)
                        _InsightRow(
                          icon: LucideIcons.calendarCheck,
                          label: 'On track to complete by',
                          value: c.estimatedEndDate!,
                          valueColor: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
              if (detail.leaderboard.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Top supporters',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < detail.leaderboard.length; i++)
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? AppColors.gold.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: i == 0 ? const Color(0xFF8A6A00) : AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            detail.leaderboard[i].username,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: Text(
                            formatKwacha(detail.leaderboard[i].totalCents),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _AnnouncementsSection(campaignId: c.id),
              const SizedBox(height: 20),
              Text(
                'Recent donors',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (detail.donors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No donations yet. Be the first to give!',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final donor in detail.donors)
                        ListTile(
                          dense: true,
                          leading: Avatar(
                            url: donor.avatarUrl,
                            name: donor.username,
                            radius: 16,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  donor.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (donor.tier != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    donor.tier!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A6A00),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(donor.summary),
                          trailing: donor.amountHidden
                              ? const Icon(LucideIcons.eyeOff,
                                  size: 18, color: AppColors.textMuted)
                              : Text(
                                  formatKwacha(donor.amountCents ?? 0),
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                        ),
                    ],
                  ),
                ),
            ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => showShareSheet(context, ref, c),
                    icon: const Icon(LucideIcons.share2, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => context.push('/donate/${c.id}'),
                    icon: const Icon(LucideIcons.heartHandshake),
                    label: const Text('Donate now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementsSection extends ConsumerStatefulWidget {
  final int campaignId;

  const _AnnouncementsSection({required this.campaignId});

  @override
  ConsumerState<_AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends ConsumerState<_AnnouncementsSection> {
  late final Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).getAnnouncements(widget.campaignId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (snapshot.hasData && items.isEmpty) return const SizedBox.shrink();
        if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Updates from the host',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final a in items)
                    ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.megaphone, size: 20, color: AppColors.primary),
                      title: Text(
                        a['body'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${a['author'] ?? 'Host'} · ${(a['createdAt'] as String? ?? '').replaceFirst(' ', ' · ')}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
