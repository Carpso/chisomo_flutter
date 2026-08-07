import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import '../campaigns/campaign_image.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

/// Host screen for promoting a campaign to the paid top-5 list:
/// slot availability, price, which of your campaigns can be promoted,
/// and the history/status of your past promotions.
class PromoteScreen extends ConsumerWidget {
  const PromoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(promotionInfoProvider);
    final host = ref.watch(hostProvider);
    final mine = ref.watch(myPromotionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promote your campaign'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              ref.invalidate(promotionInfoProvider);
              ref.invalidate(hostProvider);
              ref.invalidate(myPromotionsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(promotionInfoProvider);
          ref.invalidate(myPromotionsProvider);
        },
        child: ListView(
          padding: EdgeInsets.all(16).copyWith(
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            info.when(
              loading: () => const Center(child: AppIconSpinner()),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(friendlyError(e), style: const TextStyle(color: AppColors.danger)),
                ),
              ),
              data: (i) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.star, color: Color(0xFF8A6A00), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Top ${i.slots} list',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${i.available} of ${i.slots} slots open • '
                                  '${formatKwacha(i.priceCents)} for ${i.days} days',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        i.available == 0
                            ? 'All slots are currently taken. Check back later — a slot frees up '
                                'when a promoted campaign expires.'
                            : 'Pay ${formatKwacha(i.priceCents)} once from your mobile money and your '
                                'campaign sits on top of the app list for ${i.days} days, above every '
                                'unpromoted campaign.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your campaigns',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            host.when(
              loading: () => const Center(child: AppIconSpinner()),
              error: (e, _) => Text(friendlyError(e), style: const TextStyle(color: AppColors.danger)),
              data: (data) {
                final promotable = data.campaigns
                    .where((c) => c.status == 'active' && !c.promoted)
                    .toList();
                if (promotable.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        data.campaigns.any((c) => c.promoted)
                            ? 'This campaign is already on the top-5 list. '
                                'Promotions renew when the current window ends.'
                            : 'You have no active campaigns that can be promoted right now.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final c in promotable) _PromotableCard(campaign: c),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Your promotion history',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            mine.when(
              loading: () => const Center(child: AppIconSpinner()),
              error: (e, _) => Text(friendlyError(e), style: const TextStyle(color: AppColors.danger)),
              data: (items) => items.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No promotions yet. Pick a campaign above to get started.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : Card(
                      child: Column(
                        children: [
                          for (final p in items)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                _statusIcon(p.status),
                                size: 18,
                                color: _statusColor(p.status),
                              ),
                              title: Text(
                                p.campaignTitle,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${formatKwacha(p.amountCents)} • ${p.days} days\n${p.statusLabel}',
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                safeDate(p.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) => switch (status) {
        'active' => LucideIcons.star,
        'pending_approval' => LucideIcons.hourglass,
        'rejected' || 'refunded' => LucideIcons.xCircle,
        _ => LucideIcons.clock,
      };

  Color _statusColor(String status) => switch (status) {
        'active' => AppColors.primary,
        'pending_approval' || 'pending' => AppColors.gold,
        'rejected' || 'refunded' => AppColors.danger,
        _ => AppColors.textMuted,
      };
}

class _PromotableCard extends ConsumerStatefulWidget {
  final Campaign campaign;

  const _PromotableCard({required this.campaign});

  @override
  ConsumerState<_PromotableCard> createState() => _PromotableCardState();
}

class _PromotableCardState extends ConsumerState<_PromotableCard> {
  bool _promoting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final campaign = widget.campaign;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CampaignImage(campaign: campaign, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${campaign.raisedLabel} raised',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _promoting
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          icon: const Icon(LucideIcons.star,
                              color: AppColors.gold, size: 28),
                          title: const Text('Promote this campaign?'),
                          content: Text(
                            'Promoting costs ${formatKwacha(ref.read(promotionInfoProvider).value?.priceCents ?? 0)}. '
                            'A payment request will be sent to your phone — '
                            'enter your PIN to pay. The promotion goes live '
                            'after a superadmin approves it.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      setState(() => _promoting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final res = await ref
                            .read(apiClientProvider)
                            .promoteCampaign(campaign.id);
                        ref.invalidate(myPromotionsProvider);
                        if (context.mounted) {
                          await showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              icon: const Icon(LucideIcons.smartphone,
                                  color: AppColors.primary, size: 28),
                              title: const Text('Confirm payment on your phone'),
                              content: Text(
                                'A ${formatKwacha(res['priceCents'] as int? ?? 0)} request was sent '
                                'to your phone. Enter your PIN to pay — the promotion goes live '
                                'after a superadmin approves it.\n\n'
                                'Ref: ${res['referenceId']}',
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(e.message)));
                      } finally {
                        if (mounted) setState(() => _promoting = false);
                      }
                    },
              icon: const Icon(LucideIcons.star, size: 16),
              label: Text(_promoting ? 'Processing…' : 'Promote'),
            ),
          ],
        ),
      ),
    );
  }
}
