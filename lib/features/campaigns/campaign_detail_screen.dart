import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/info_badge.dart';
import '../auth/auth_controller.dart';
import '../events/event_detail_screen.dart';
import 'announcements_section.dart';
import 'campaigns_controller.dart';
import 'campaign_image.dart';
import 'live_overlay.dart';
import 'models.dart';
import 'share_sheet.dart';

class CampaignDetailScreen extends ConsumerWidget {
  final int campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(campaignDetailProvider(campaignId));

    // Events are their own first-class flow: if this id happens to resolve to
    // an event campaign, hand off to the event detail screen so users never
    // see campaign/donate UI for an event.
    final campaign = detail.value?.campaign;
    if (campaign != null && campaign.isEvent) {
      return EventDetailScreen(eventId: campaignId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final isAdmin = ref.watch(authControllerProvider).value?.isAdmin ?? false;
              if (!isAdmin) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(LucideIcons.pencil),
                tooltip: 'Edit campaign',
                onPressed: () {
                  final detailValue = detail.value;
                  if (detailValue == null) return;
                  context.push('/host/edit/${detailValue.campaign.id}');
                },
              );
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
                Text(friendlyError(e), textAlign: TextAlign.center),
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

/// Best-effort: admins always see the live toggle; hosts see it when the
/// campaign's host name matches their account username.
bool _isHostOrAdmin(WidgetRef ref, Campaign c) {
  final auth = ref.read(authControllerProvider).value;
  if (auth?.isAdmin == true) return true;
  final u = auth?.username;
  return u != null && u.isNotEmpty && u == c.hostName;
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (c.status == 'deleted') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shieldAlert, size: 18, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This campaign was removed by the administrator.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Cover photos fill the banner edge-to-edge; logos stay centered.
              Stack(
                children: [
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
                    child: Hero(
                      tag: 'campaign-image-${c.id}',
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
                  ),
                  if (c.isLive)
                    const Positioned(
                      left: 10,
                      top: 10,
                      child: LiveBadge(),
                    ),
                ],
              ),
              if (c.isLive) LiveDonorFeed(campaignId: c.id) else const SizedBox.shrink(),
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
              if (_isHostOrAdmin(ref, c))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: LiveToggleButton(campaignId: c.id, currentlyLive: c.isLive),
                      ),
                      const SizedBox(width: 8),
                      InfoBadge(
                        title: 'Go Live',
                        text: 'Go Live starts a live donor feed on this page and shows a '
                            '"LIVE" badge. Only the host or an admin can turn it on. While live, '
                            'new donations appear on the screen in real time. Tap "End Live" '
                            'anytime to stop it.',
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (c.hostName != null && c.hostName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.user, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Hosted by ${c.hostName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                            if (c.hostVerified) ...[
                              const SizedBox(width: 4),
                              Icon(LucideIcons.badgeCheck,
                                  size: 13, color: AppColors.primary),
                            ],
                          ],
                        ),
                      ),
                      if (c.isPrivate) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.textMuted.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.lock,
                                  size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Private',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (c.category.isNotEmpty && c.category != 'Other') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            c.category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Text(c.description, style: theme.textTheme.bodyMedium),
              if (c.endsAt != null) ...[
                const SizedBox(height: 12),
                CountdownBadge(endsAt: DateTime.tryParse(c.endsAt!)),
              ],
              if (c.shareUrl != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          c.shareUrl!,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CopyButton(text: c.shareUrl!, label: 'Copy'),
                  ],
                ),
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
                Row(
                  children: [
                    Text(
                      'Top supporters',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    InfoBadge(
                      title: 'Top supporters',
                      text:
                          'Everyone who has given to this campaign, ordered by total amount donated. '
                          'Donations with a hidden amount stay private and do not appear here.',
                    ),
                    const Spacer(),
                    Text(
                      '${detail.leaderboard.length}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
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
                                  : AppColors.accentFor(i).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: i == 0
                                    ? const Color(0xFF8A6A00)
                                    : AppColors.accentFor(i),
                              ),
                            ),
                          ),
                          title: Text(
                            detail.leaderboard[i].username,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: detail.leaderboard[i].tier.isEmpty
                              ? null
                              : Text(detail.leaderboard[i].tier),
                          trailing: Text(
                            formatKwacha(detail.leaderboard[i].totalCents),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              AnnouncementsSection(campaignId: c.id),
              const SizedBox(height: 20),
              if (c.hostOrg != null && c.hostOrg!.isNotEmpty)
                _MoreFromOrgSection(campaign: c),
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
                  child: c.status == 'deleted'
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: const Text(
                            'Campaign closed',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : c.isEvent
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: AppColors.primary,
                              ),
                              onPressed: c.isSoldOut
                                  ? null
                                  : () => context.push('/event/${c.id}/buy-ticket'),
                              icon: const Icon(LucideIcons.ticket),
                              label: Text(c.isSoldOut ? 'Sold out' : 'Buy ticket'),
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => context.push('/donate/${c.id}'),
                              icon: const Icon(LucideIcons.heartHandshake),
                              label: const Text('Donate Now'),
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

/// Shows other active campaigns from the same church/organisation so users can
/// see everything their community is raising for in one place.
class _MoreFromOrgSection extends ConsumerWidget {
  final Campaign campaign;

  const _MoreFromOrgSection({required this.campaign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final org = campaign.hostOrg ?? '';
    final all = ref.watch(campaignsProvider).value ?? const <Campaign>[];
    final others = all
        .where((c) =>
            c.id != campaign.id &&
            c.hostOrg != null &&
            c.hostOrg == org &&
            c.status == 'active')
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More from $org',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'All the ways this church / organisation is raising funds.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        for (final o in others.take(4))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: SizedBox(
                width: 44,
                height: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CampaignImage(campaign: o, fit: BoxFit.cover),
                ),
              ),
              title: Text(o.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text('${o.raisedLabel} raised',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => context.push('/campaign/${o.id}'),
            ),
          ),
        if (others.length > 4)
          TextButton.icon(
            onPressed: () => context.push('/'),
            icon: const Icon(LucideIcons.search, size: 16),
            label: Text('See all ${others.length} campaigns'),
          ),
      ],
    );
  }
}

