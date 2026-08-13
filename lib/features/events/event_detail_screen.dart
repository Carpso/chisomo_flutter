import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/info_badge.dart';
import '../auth/auth_controller.dart';
import '../campaigns/announcements_section.dart';
import '../campaigns/campaign_image.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/live_overlay.dart';
import '../campaigns/models.dart';
import '../campaigns/share_sheet.dart';

/// Dedicated event detail screen — events never open the campaign screen.
/// Shows the poster, date/venue/capacity, tiers, RSVP (free events), buy
/// tickets (ticketed events), share, and Go live for the host/admin.
class EventDetailScreen extends ConsumerStatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _rsvpBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider).value;
      if (auth?.loggedIn == true) {
        ref.read(apiClientProvider).recordCampaignView(widget.eventId).ignore();
      }
    });
  }

  Future<void> _rsvp() async {
    setState(() => _rsvpBusy = true);
    final auth = ref.read(authControllerProvider).value;
    try {
      final res = await ref.read(apiClientProvider).rsvpEvent(
        widget.eventId,
        name: auth?.name ?? auth?.username,
        phone: auth?.phone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You\'re going! ${res['rsvpCount']} people have RSVP\'d.',
            ),
          ),
        );
        ref.invalidate(campaignDetailProvider(widget.eventId));
        ref.invalidate(campaignsProvider);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _rsvpBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(campaignDetailProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2),
            tooltip: 'Share event',
            onPressed: () async {
              final d = detail.value;
              if (d == null) return;
              await showShareSheet(context, ref, d.campaign);
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
                Text(
                  friendlyError(e),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(campaignDetailProvider(widget.eventId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (d) => _EventBody(
          detail: d,
          onRsvp: d.campaign.isEvent || d.campaign.isSoldOut ? null : _rsvp,
          rsvpBusy: _rsvpBusy,
        ),
      ),
    );
  }
}

class _EventBody extends ConsumerWidget {
  final CampaignDetail detail;
  final VoidCallback? onRsvp;
  final bool rsvpBusy;

  const _EventBody({required this.detail, this.onRsvp, this.rsvpBusy = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = detail.campaign;
    final auth = ref.watch(authControllerProvider).value;
    final canGoLive = c.isMine || (auth?.isAdmin ?? false);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(campaignDetailProvider(c.id)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Stack(
                  children: [
                    Container(
                      height: 220,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, const Color(0xFF7C2D12)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Hero(
                        tag: 'event-image-${c.id}',
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
                      const Positioned(left: 10, top: 10, child: LiveBadge()),
                  ],
                ),
                if (c.isLive) LiveDonorFeed(campaignId: c.id) else const SizedBox.shrink(),
                const SizedBox(height: 16),
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
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gold)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(LucideIcons.user, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Hosted by ${c.hostName ?? 'Host'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                    if (c.hostVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.badgeCheck, size: 13, color: AppColors.primary),
                    ],
                    if (c.isPrivate) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.lock, size: 11, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text('Private',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        if (c.eventDate != null)
                          _EventRow(LucideIcons.calendarDays, 'When', c.eventDate!),
                        if (c.eventVenue != null)
                          _EventRow(LucideIcons.mapPin, 'Where', c.eventVenue!),
                        if (c.eventCapacity > 0)
                          _EventRow(
                            LucideIcons.ticket,
                            'Tickets',
                            '${c.ticketsSold}/${c.eventCapacity} sold',
                            valueColor: c.isSoldOut ? AppColors.danger : null,
                          )
                        else if (c.isEvent)
                          _EventRow(LucideIcons.ticket, 'Tickets', '${c.ticketsSold} sold'),
                        if (!c.isEvent)
                          _EventRow(
                            LucideIcons.users,
                            'Going',
                            '${c.rsvpCount} RSVP${c.rsvpCount == 1 ? '' : 's'}',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (c.isSoldOut)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.ticket, color: AppColors.danger, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This event is sold out. Thank you for your interest!',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (canGoLive)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: LiveToggleButton(campaignId: c.id, currentlyLive: c.isLive),
                        ),
                        const SizedBox(width: 8),
                        InfoBadge(
                          title: 'Go live',
                          text: 'Go live starts a live donor feed on this event page and shows a '
                              '"LIVE" badge. Only the host or an admin can turn it on. While live, '
                              'new donations and ticket sales appear on the screen in real time. '
                              'Tap "End live" anytime to stop it.',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Text(c.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                const SizedBox(height: 14),
                AnnouncementsSection(campaignId: c.id, isEvent: true),
                if (c.isEvent && c.eventTiers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Ticket tiers',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      InfoBadge(
                        title: 'Ticket tiers',
                        text: 'Pick a ticket tier (Standard, VIP, Table of 10…) and how many '
                            'tickets you need. You pay with mobile money (enter your PIN on the '
                            'prompt) or by card. Your tickets count towards the tickets sold.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final tier in c.eventTiers)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(LucideIcons.ticket, color: AppColors.primary),
                        title: Text(tier.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${formatKwacha(tier.amountCents)} per ticket'),
                        trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      ),
                    ),
                ],
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
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => showShareSheet(context, ref, c),
                    icon: const Icon(LucideIcons.share2, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: c.isEvent
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
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: onRsvp,
                          icon: rsvpBusy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(LucideIcons.calendarCheck),
                          label: Text(rsvpBusy ? 'Saving…' : 'RSVP — I\'m going'),
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

class _EventRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _EventRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.textDark,
                ),
          ),
        ],
      ),
    );
  }
}
