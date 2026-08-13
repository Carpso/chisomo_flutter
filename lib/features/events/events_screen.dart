import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../campaigns/campaign_image.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';
import '../campaigns/share_sheet.dart';

/// Events tab — Instagram-style feed of event campaigns (tiered tickets).
/// Includes trending, recently-opened and private events, plus a create FAB.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(campaignsProvider);
    final auth = ref.watch(authControllerProvider).value;
    final isApprovedHost = auth?.hostStatus == 'approved';
    final views = ref.watch(campaignViewsProvider).value ?? const <Campaign>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back to Campaigns',
          onPressed: () => context.go('/'),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Events', maxLines: 1),
        ),
        actions: [
          if (isApprovedHost)
            IconButton(
              icon: const Icon(LucideIcons.qrCode),
              tooltip: 'Scan & check in',
              onPressed: () => context.push('/admin/scan-qr'),
            ),
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadNotificationsProvider);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell),
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                  ),
                  if ((unread.value ?? 0) > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${unread.value}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            tooltip: 'Global search',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      floatingActionButton: isApprovedHost
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black87,
              onPressed: () => context.push('/host/create-event'),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Create event'),
            )
          : null,
      body: campaigns.when(
        loading: () => const Center(child: AppIconSpinner()),
        error: (e, _) => _ErrorRetry(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(campaignsProvider),
        ),
        data: (items) {
          final events = items.where((c) => c.isEvent || c.campaignType == 'event').toList();
          if (events.isEmpty && views.where((c) => c.isEvent || c.campaignType == 'event').isEmpty) {
            return const _EmptyEvents();
          }
          final trending = [...events]
            ..sort((a, b) {
              final pa = a.promoted ? 1 : 0;
              final pb = b.promoted ? 1 : 0;
              if (pa != pb) return pb - pa;
              return b.dailyRateCents.compareTo(a.dailyRateCents);
            });
          final opened = views.where((c) => c.isEvent || c.campaignType == 'event').toList();
          final private = opened.where((c) => c.isPrivate).toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(campaignsProvider);
              ref.invalidate(campaignViewsProvider);
            },
            child: CustomScrollView(
              slivers: [
                if (trending.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _SectionLabel('Trending events', LucideIcons.flame)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 250,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: trending.length.clamp(0, 8),
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => _TrendingEventCard(campaign: trending[i]),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                if (opened.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _SectionLabel('Recently opened', LucideIcons.clock)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: opened.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => _RecentlyOpenedEventCard(campaign: opened[i]),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                if (private.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _SectionLabel('Private events you opened', LucideIcons.lock)),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                ],
                if (events.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No public events yet — share an invite link to open a private one.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                // Instagram-style event feed.
                for (final c in events)
                  SliverToBoxAdapter(
                    child: _EventPost(campaign: c, isPrivateFeed: false),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;

  const _SectionLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TrendingEventCard extends StatelessWidget {
  final Campaign campaign;

  const _TrendingEventCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return SizedBox(
      width: 230,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push('/event/${c.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CampaignImage(campaign: c, fit: BoxFit.cover),
                    if (c.promoted)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.star, size: 11, color: Colors.black87),
                              SizedBox(width: 3),
                              Text('Promoted', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 2),
                    Text('${c.ticketsSold} ${c.ticketsSold == 1 ? 'ticket' : 'tickets'} • ${c.raisedLabel}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentlyOpenedEventCard extends StatelessWidget {
  final Campaign campaign;

  const _RecentlyOpenedEventCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return SizedBox(
      width: 210,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push('/event/${c.id}'),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CampaignImage(campaign: c, fit: BoxFit.cover),
                    if (c.isPrivate)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.lock, size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.2)),
                      const SizedBox(height: 4),
                      Text('${c.ticketsSold} tickets • ${c.raisedLabel}',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A large Instagram-style event post: big poster carousel (slides through
/// the event's images), then title, host, date/venue, tiers and actions.
class _EventPost extends ConsumerWidget {
  final Campaign campaign;
  final bool isPrivateFeed;

  const _EventPost({required this.campaign, this.isPrivateFeed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = campaign;
    final theme = Theme.of(context);
    // Poster list: the campaign image(s) plus a nice fallback so the carousel
    // always has something big to show.
    final posters = <Campaign>[];
    if (c.logoUrl != null || c.imageUrl != null) posters.add(c);
    if (posters.isEmpty) posters.add(c);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster carousel. The whole poster (image, scrim and caption) is
          // tappable and opens the event detail; the PageView still handles
          // horizontal swipes between posters.
          GestureDetector(
            onTap: () => context.push('/event/${c.id}'),
            child: SizedBox(
              height: 320,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: posters.length,
                    itemBuilder: (context, i) => Hero(
                      tag: 'event-image-${c.id}-$i',
                      child: CampaignImage(campaign: posters[i], fit: BoxFit.cover),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (c.promoted) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.star, size: 11, color: Colors.black87),
                                  SizedBox(width: 4),
                                  Text('Promoted', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (c.isPrivate) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.lock, size: 11, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Private', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(LucideIcons.user, size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(c.hostName ?? 'Host', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          if (c.eventDate != null) ...[
                            const SizedBox(width: 10),
                            const Icon(LucideIcons.calendarDays, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(c.eventDate!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ],
                      ),
                      if (c.eventVenue != null) ...[
                        const SizedBox(height: 2),
                        Text(c.eventVenue!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
          // Post body.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted, height: 1.4)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in c.eventTiers)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text('${t.name} • ${formatKwacha(t.amountCents)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: c.isTicketedEvent
                          ? Text(
                              '${c.ticketsSold} ${c.ticketsSold == 1 ? 'ticket' : 'tickets'} sold'
                              '${c.eventCapacity > 0 ? ' of ${c.eventCapacity}' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                            )
                          : Text(
                              '${c.rsvpCount} ${c.rsvpCount == 1 ? 'RSVP' : 'RSVPs'}',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                            ),
                    ),
                    c.isTicketedEvent
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                            onPressed: c.isSoldOut
                                ? null
                                : () => context.push('/event/${c.id}/buy-ticket'),
                            icon: const Icon(LucideIcons.ticket, size: 15),
                            label: Text(c.isSoldOut ? 'Sold out' : 'Buy ticket'),
                          )
                        : FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                            onPressed: () => context.push('/event/${c.id}'),
                            icon: const Icon(LucideIcons.calendarCheck, size: 15),
                            label: const Text('RSVP'),
                          ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Share event',
                      icon: const Icon(LucideIcons.share2, size: 18),
                      onPressed: () => showShareSheet(context, ref, c),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(LucideIcons.ticket, size: 34, color: AppColors.gold),
            ),
            const SizedBox(height: 16),
            const Text('No events yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text(
              'Hosts can create event campaigns that sell tiered tickets '
              '(Standard, VIP, Table of 10…) with big posters. Tap "Create event".',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
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
