import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme.dart';
import '../../features/campaigns/campaigns_controller.dart';
import '../../features/campaigns/models.dart';

/// Home carousel that blends promoted campaigns, "Buy Airtime", and
/// "Airtime rewards coming soon" into a single attractive slide deck.
/// Auto-slides every 4 seconds; user can tap to pause/resume.
class HomeCarousel extends ConsumerStatefulWidget {
  const HomeCarousel({super.key});

  @override
  ConsumerState<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends ConsumerState<HomeCarousel> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  bool _autoSlide = true;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (!_autoSlide) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_autoSlide) return;
      final items = _getItems();
      if (items.length <= 1) return;
      final nextPage = (_currentPage + 1) % items.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  List<_CarouselItem> _getItems() {
    final campaignsAsync = ref.read(campaignsProvider);
    final promoted = campaignsAsync.when(
      loading: () => <Campaign>[],
      error: (_, __) => <Campaign>[],
      data: (items) => items.where((c) => c.promoted).toList(),
    );
    return [
      for (final c in promoted) _CarouselItem.campaign(c),
      const _CarouselItem.buyAirtime(),
      const _CarouselItem.airtimeRewards(),
    ];
  }

  void _toggleAutoSlide() {
    setState(() {
      _autoSlide = !_autoSlide;
    });
    if (_autoSlide) {
      _startAutoSlide();
    } else {
      _autoSlideTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _getItems();
    if (items.isEmpty) return const SizedBox.shrink();

    final isSingle = items.length == 1;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) => _buildPage(context, items[i]),
                  ),
                  // Auto-slide toggle button
                  if (!isSingle)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggleAutoSlide,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _autoSlide ? LucideIcons.pause : LucideIcons.play,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // Page indicator
                  if (!isSingle)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedSmoothIndicator(
                          activeIndex: _currentPage,
                          count: items.length,
                          effect: ExpandingDotsEffect(
                            dotHeight: 6,
                            dotWidth: 8,
                            dotColor: Colors.white.withValues(alpha: 0.4),
                            activeDotColor: AppColors.gold,
                            expansionFactor: 2.5,
                            spacing: 6,
                          ),
                        ),
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

  Widget _buildPage(BuildContext context, _CarouselItem item) {
    final theme = Theme.of(context);

    switch (item.type) {
      case _CarouselType.campaign:
        final c = item.campaign!;
        final accent = AppColors.accentFor(c.id);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              onTap: () => context.push('/campaign/${c.id}'),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.15),
                      AppColors.gold.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.star, size: 11, color: AppColors.gold),
                            SizedBox(width: 3),
                            Text('Promoted',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.gold)),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Featured Campaign',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(c.title,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textDark),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c.raisedLabel, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: accent)),
                              FilledButton(
                                onPressed: () => context.push('/campaign/${c.id}'),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.textDark),
                                child: const Text('Give Now'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case _CarouselType.buyAirtime:
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            onTap: () => context.push('/airtime'),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(top: -20, right: -20, child: Icon(LucideIcons.smartphone, size: 120, color: AppColors.primary.withValues(alpha: 0.08))),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Buy Mobile Airtime',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        Text('Top up any Airtel or Zamtel number in Zambia instantly. Every purchase earns you Kingdom Sponsor credits.',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Text('Coming soon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.gold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case _CarouselType.airtimeRewards:
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gold.withValues(alpha: 0.15), AppColors.gold.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(top: -15, right: -15, child: Icon(LucideIcons.gift, size: 110, color: AppColors.gold.withValues(alpha: 0.1))),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Airtime Rewards',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        Text("Soon you'll earn airtime credit for every donation you make and share. The more you give, the more you get back.",
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
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
}

enum _CarouselType { campaign, buyAirtime, airtimeRewards }

class _CarouselItem {
  final _CarouselType type;
  final Campaign? campaign;
  _CarouselItem.campaign(this.campaign) : type = _CarouselType.campaign;
  const _CarouselItem.buyAirtime() : type = _CarouselType.buyAirtime, campaign = null;
  const _CarouselItem.airtimeRewards() : type = _CarouselType.airtimeRewards, campaign = null;
}
