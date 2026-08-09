import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/offline_cache.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/home_carousel.dart';
import '../auth/auth_controller.dart';
import 'campaigns_controller.dart';
import 'campaign_image.dart';
import 'models.dart';

class CampaignListScreen extends ConsumerStatefulWidget {
  const CampaignListScreen({super.key});

  @override
  ConsumerState<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends ConsumerState<CampaignListScreen> {
  String _category = 'All';
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(campaignsProvider);
    final offline = ref.watch(offlineModeProvider);
    final auth = ref.watch(authControllerProvider).value;
    final isAdmin = auth?.isAdmin ?? false;
    final isApprovedHost = auth?.hostStatus == 'approved';

    // Smart local filter over the already-loaded campaigns.
    final loaded = campaigns.value ?? const <Campaign>[];
    final q = _searchController.text.trim().toLowerCase();
    final List<Campaign> searched = q.isEmpty
        ? loaded
        : loaded.where((c) {
            final hay = [
              c.title, c.description, c.category, c.hostName ?? '', c.hostOrg ?? '',
            ].join(' ').toLowerCase();
            return hay.contains(q);
          }).toList();
    final trendId = searched.isNotEmpty
        ? searched.reduce((a, b) => (a.dailyRateCents >= b.dailyRateCents) ? a : b).id
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
            icon: Icon(_searching ? LucideIcons.x : LucideIcons.search),
            tooltip: _searching ? 'Close search' : 'Search campaigns',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
          ),
        ],
      ),
      floatingActionButton: isApprovedHost
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/host/create'),
              icon: const Icon(LucideIcons.plus),
              label: const Text('New campaign'),
            )
          : null,
body: campaigns.when(
              loading: () => const _ListSkeleton(),
              error: (e, _) =>
                  _ErrorRetry(message: friendlyError(e), onRetry: () => ref.invalidate(campaignsProvider)),
              data: (items) {
                final qq = _searchController.text.trim().toLowerCase();
                final List<Campaign> searched = qq.isEmpty
                    ? items
                    : items.where((c) {
                        final hay = [
                          c.title, c.description, c.category, c.hostName ?? '', c.hostOrg ?? '',
                        ].join(' ').toLowerCase();
                        return hay.contains(qq);
                      }).toList();
                final filtered = _category == 'All'
                    ? searched
                    : searched.where((c) => c.category == _category).toList();
                return RefreshIndicator(
                onRefresh: () async => ref.invalidate(campaignsProvider),
                child: CustomScrollView(
                  slivers: [
                    if (_searching) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search campaigns, hosts, churches…',
                              prefixIcon: const Icon(LucideIcons.search, size: 20),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(LucideIcons.x, size: 18),
                                      onPressed: () => setState(() => _searchController.clear()),
                                    ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ],
                    if (offline)
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          color: AppColors.gold.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.wifiOff,
                                  size: 16, color: Color(0xFF8A6A00)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Offline — showing last saved campaigns',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                     const SliverToBoxAdapter(child: HomeCarousel()),
                     const SliverToBoxAdapter(child: SizedBox(height: 8)),
                     SliverToBoxAdapter(
                       child: SizedBox(
                         height: 40,
                         child: ListView(
                           scrollDirection: Axis.horizontal,
                           padding: const EdgeInsets.symmetric(horizontal: 12),
                           children: [
                             _CategoryChip(
                               label: 'All',
                               selected: _category == 'All',
                               onTap: () => setState(() => _category = 'All'),
                             ),
                             for (final c in kCampaignCategories)
                               _CategoryChip(
                                 label: c,
                                 selected: _category == c,
                                 onTap: () => setState(() => _category = c),
                               ),
                           ],
                         ),
                       ),
                     ),
                     const SliverToBoxAdapter(child: SizedBox(height: 8)),
                     if (filtered.isEmpty)
                       SliverToBoxAdapter(
                         child: Padding(
                           padding: const EdgeInsets.all(40),
                           child: Column(
                             children: [
                               Container(
                                 padding: const EdgeInsets.all(20),
                                 decoration: BoxDecoration(
                                   color: AppColors.primary.withValues(alpha: 0.08),
                                   shape: BoxShape.circle,
                                 ),
                                  child: Icon(
                                    _searchController.text.trim().isNotEmpty
                                        ? LucideIcons.search
                                        : _category == 'All'
                                            ? LucideIcons.megaphone
                                            : LucideIcons.filter,
                                    size: 34,
                                    color: AppColors.primary,
                                  ),
                               ),
                               const SizedBox(height: 16),
                                Text(
                                  _searchController.text.trim().isNotEmpty
                                      ? 'No campaigns match "${_searchController.text.trim()}"'
                                      : _category == 'All'
                                          ? 'No campaigns yet'
                                          : 'No campaigns in "$_category"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark)),
                                const SizedBox(height: 8),
                                Text(
                                  _searchController.text.trim().isNotEmpty
                                      ? 'Try a different word, or clear the search.'
                                      : _category == 'All'
                                          ? 'Be the first to share a fundraiser. Hosts can start one in the Host tab.'
                                          : 'Try another category or share the first campaign here.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textMuted, height: 1.4),
                                ),
                                if (_category != 'All' ||
                                    _searchController.text.trim().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _category = 'All';
                                      _searchController.clear();
                                    }),
                                    icon: const Icon(LucideIcons.undo2, size: 16),
                                    label: const Text('Clear search & filters'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                         delegate: SliverChildBuilderDelegate(
                           (context, i) => _CampaignCard(
                               campaign: filtered[i],
                               isTrending: filtered[i].id == trendId,
                               onOrgTap: () => setState(() {
                                 _searching = true;
                                 _searchController.text = filtered[i].hostOrg ?? '';
                               })),
                           childCount: filtered.length,
                         ),
                       ),
                     // Bottom spacing so last card isn't flush with screen edge or hidden by FAB
                     SliverToBoxAdapter(
                       child: SizedBox(height: isApprovedHost ? 100 : 24),
                     ),
                  ],
                ),
              );
              },
            ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textMuted,
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: const Color(0xFF151521),
        side: BorderSide(
          color: selected ? AppColors.primary : const Color(0xFF2A2A3A),
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final bool isTrending;
  final VoidCallback? onOrgTap;

  const _CampaignCard({required this.campaign, this.isTrending = false, this.onOrgTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accentFor(campaign.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isTrending
              ? AppColors.gold.withValues(alpha: 0.4)
              : accent.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
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
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: CampaignImage(campaign: campaign, fit: BoxFit.cover),
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
                                       textAlign: TextAlign.center,
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
                    if (campaign.hostName != null && campaign.hostName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Hosted by ${campaign.hostName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ),
                          if (campaign.hostVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.badgeCheck,
                                size: 12, color: AppColors.primary),
                          ],
                        ],
                      ),
                    ],
                    if (campaign.hostOrg != null && campaign.hostOrg!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      InkWell(
                        onTap: onOrgTap,
                        child: Row(
                          children: [
                            Icon(LucideIcons.building2, size: 11, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${campaign.hostOrg}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.gold)),
                                ],
                              ),
                            ),
                          ),
                        if (campaign.isPrivate)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.lock, size: 10, color: AppColors.textMuted),
                                  SizedBox(width: 2),
                                  Text('Private',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textMuted)),
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
                        color: accent,
                      ),
                    )
                  else
                    Text(
                      campaign.raisedLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
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
                    color: accent,
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 88,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(height: 14, width: 160, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 120, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 10),
                    Container(height: 10, width: 90, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
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
