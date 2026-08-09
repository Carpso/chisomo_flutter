import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme.dart';
import '../../features/airtime/airtime_screen.dart';
import '../../features/campaigns/campaigns_controller.dart';
import '../../features/campaigns/models.dart';

/// Auto-slide toggle for the home carousel (persisted; lives in Settings).
class CarouselAutoSlide extends Notifier<bool> {
  static const _key = 'carousel_auto_slide';

  @override
  bool build() {
    SharedPreferences.getInstance().then((p) {
      final v = p.getBool(_key) ?? true;
      if (v != state) state = v;
    });
    return true;
  }

  Future<void> set(bool value) async {
    state = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, value);
  }
}

final carouselAutoSlideProvider =
    NotifierProvider<CarouselAutoSlide, bool>(CarouselAutoSlide.new);

/// Sample promoted campaigns shown in the home carousel when there are no real
/// promoted campaigns live yet. Each maps to a bundled sample asset so the
/// carousel always has something attractive to present.
final _sampleCampaigns = <Campaign>[
  Campaign(
    id: 1001, slug: 'water-well', title: 'Water Well for Chilombola',
    description: 'Clean water project in Chilombola community.',
    imageUrl: 'assets/campaign_samples/sample_1.png', logoUrl: null,
    goalCents: 500000, hasGoal: true, raisedCents: 325000, withdrawnCents: 0,
    donorCount: 87, donationCount: 87, avgDonationCents: 3700,
    donorsNeededAtAvg: 47, dailyRateCents: 22000, status: 'active', promoted: true,
    promotedUntil: '2026-09-08', createdAt: '2026-08-01', hostName: 'Kingdom Sponsor',
  ),
  Campaign(
    id: 1002, slug: 'school-fees', title: 'School Fees for Vulnerable Pupils',
    description: 'Helping orphaned and vulnerable learners stay in school.',
    imageUrl: 'assets/campaign_samples/sample_2.png',
    goalCents: 300000, hasGoal: true, raisedCents: 180000, withdrawnCents: 0,
    donorCount: 64, donationCount: 64, avgDonationCents: 2800,
    donorsNeededAtAvg: 43, dailyRateCents: 15000, status: 'active', promoted: true,
    promotedUntil: '2026-09-08', createdAt: '2026-08-02', hostName: 'Kingdom Sponsor',
  ),
  Campaign(
    id: 1003, slug: 'cyclone-relief', title: 'Cyclone Relief — Clean Up Kits',
    description: 'Emergency relief supplies for families affected by recent floods.',
    imageUrl: 'assets/campaign_samples/sample_3.png',
    goalCents: 400000, hasGoal: true, raisedCents: 280000, withdrawnCents: 0,
    donorCount: 92, donationCount: 92, avgDonationCents: 3000,
    donorsNeededAtAvg: 40, dailyRateCents: 25000, status: 'active', promoted: true,
    promotedUntil: '2026-09-08', createdAt: '2026-08-03', hostName: 'Kingdom Sponsor',
  ),
  Campaign(
    id: 1004, slug: 'memorial-fund', title: 'Memorial Fund — Mama Nalili',
    description: 'Supporting the family of the late Mama Nalili with medical and burial costs.',
    imageUrl: 'assets/campaign_samples/sample_4.png',
    goalCents: 250000, hasGoal: true, raisedCents: 150000, withdrawnCents: 0,
    donorCount: 54, donationCount: 54, avgDonationCents: 2800,
    donorsNeededAtAvg: 36, dailyRateCents: 12000, status: 'active', promoted: true,
    promotedUntil: '2026-09-08', createdAt: '2026-08-04', hostName: 'Kingdom Sponsor',
  ),
  Campaign(
    id: 1005, slug: 'church-roof', title: 'Rebuild Our Church Roof',
    description: 'Raising funds to replace the roof damaged by last season\'s storms.',
    imageUrl: 'assets/campaign_samples/sample_5.png',
    goalCents: 600000, hasGoal: true, raisedCents: 390000, withdrawnCents: 0,
    donorCount: 110, donationCount: 110, avgDonationCents: 3600,
    donorsNeededAtAvg: 59, dailyRateCents: 28000, status: 'active', promoted: true,
    promotedUntil: '2026-09-08', createdAt: '2026-08-05', hostName: 'Kingdom Sponsor',
  ),
];

/// Home carousel that blends promoted campaigns with the airtime deck.
/// Auto-slides every 4 seconds; the pause/play toggle lives in Settings.
/// Promoted campaigns carry their own image (network URL or bundled asset).
class HomeCarousel extends ConsumerStatefulWidget {
  const HomeCarousel({super.key});

  @override
  ConsumerState<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends ConsumerState<HomeCarousel> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    // Keep the auto-slide timer in sync with the Settings toggle without
    // recreating it on every rebuild (which caused slide-timer drift).
    ref.listenManual(carouselAutoSlideProvider, (prev, next) {
      if (!mounted) return;
      if (next) {
        _startAutoSlide();
      } else {
        _autoSlideTimer?.cancel();
        _autoSlideTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    final auto = ref.read(carouselAutoSlideProvider);
    if (!auto) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !ref.read(carouselAutoSlideProvider)) return;
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
    final camps = promoted.isNotEmpty ? promoted : _sampleCampaigns;
    final items = [for (final c in camps) _CarouselItem.campaign(c)];
    // Buy Airtime slide strictly follows the admin toggle (shared provider).
    if (ref.read(airtimeEnabledProvider).value == true) {
      items.add(_CarouselItem.buyAirtime());
      items.add(_CarouselItem.airtimeRewards());
    }
    // Host-only slide(s): list the signed-in host's own campaigns so they can
    // jump straight to managing them. Chunked 3 per slide; extra slides extend
    // the carousel automatically.
    final host = ref.read(hostProvider).value;
    if (host != null && host.campaigns.isNotEmpty) {
      final mine = host.campaigns.where((c) => c.status != 'deleted').toList();
      for (var i = 0; i < mine.length; i += 3) {
        final chunk = mine.sublist(i, i + 3 > mine.length ? mine.length : i + 3);
        items.add(_CarouselItem.hostCampaigns(chunk));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    // Watch the admin airtime toggle so the Buy Airtime slide appears/disappears
    // immediately when the admin flips it (no stale cache).
    ref.watch(airtimeEnabledProvider);
    final items = _getItems();
    if (items.isEmpty) return const SizedBox.shrink();
    final isSingle = items.length == 1;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: SizedBox(
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
              // Page indicator
              if (!isSingle)
                Positioned(
                  bottom: 10,
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
    );
  }

  Widget _buildPage(BuildContext context, _CarouselItem item) {
    final theme = Theme.of(context);

    switch (item.type) {
      case _CarouselType.campaign:
        final c = item.campaign!;
        final accent = AppColors.accentFor(c.id);
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            onTap: () => context.push('/campaign/${c.id}'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _campaignBackground(accent, c.imageUrl),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.star, size: 11, color: AppColors.textDark),
                        SizedBox(width: 3),
                        Text('Promoted',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('FEATURED CAMPAIGN',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                )),
                          ),
                          const Spacer(),
                          Text(c.raisedLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(c.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      if (c.hostName != null && c.hostName!.isNotEmpty)
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Hosted by ${c.hostName}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.white.withValues(alpha: 0.9), height: 1.2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (c.hostVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.badgeCheck,
                                  size: 12, color: AppColors.gold),
                            ],
                          ],
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: () => context.push('/campaign/${c.id}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.textDark,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          child: const Text('Give Now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                _airtimeGradient(AppColors.primary),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Buy Airtime',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buy Mobile Airtime',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Top up any Zambian number instantly. Every purchase earns you credits.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      const _NetworkEmblemRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case _CarouselType.airtimeRewards:
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            onTap: () => context.push('/airtime'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _airtimeGradient(AppColors.gold),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.gift, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Rewards',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Airtime Rewards',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.gold, height: 1.15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Earn airtime credit for every donation you make and share.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      const _NetworkEmblemRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case _CarouselType.hostCampaigns:
        final mine = item.hostCampaigns;
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            onTap: () => context.push('/host'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.gold.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.folderHeart, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Your campaigns',
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          mine.length == 1 ? '1 campaign' : '${mine.length} campaigns',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final c in mine) ...[
                    InkWell(
                      onTap: () => context.push('/campaign/${c.id}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: c.status == 'active' ? AppColors.primary : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(LucideIcons.chevronRight, size: 14, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    if (c != mine.last) const Divider(height: 1, color: Colors.white24),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/host'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: const Text('Manage / add'),
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

/// Campaign slide background: the campaign's own image when available
/// (network URL or bundled asset), otherwise a branded gradient.
Widget _campaignBackground(Color accent, String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return _gradientFallback(accent);
  }
  final gradient = _gradientFallback(accent);
  if (imageUrl.startsWith('assets/')) {
    return Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => gradient);
  }
  return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => gradient);
}

Widget _gradientFallback(Color accent) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: 0.15), AppColors.gold.withValues(alpha: 0.12)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

Widget _airtimeGradient(Color accent) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: 0.25), accent.withValues(alpha: 0.10)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

/// Row of Zambian mobile network emblems (Airtel, MTN, Zamtel, Zed Mobile)
/// using the real provider icons bundled in assets.
class _NetworkEmblemRow extends StatelessWidget {
  const _NetworkEmblemRow();

  static const _networks = [
    ('assets/airtel_icon.jpg', 'Airtel'),
    ('assets/mtn_icon.webp', 'MTN'),
    ('assets/zamtel_icon.jpg', 'Zamtel'),
    ('assets/zedmobile_icon.jpg', 'Zed Mobile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (path, name) in _networks) ...[
          Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(path, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                      color: const Color(0xFFBDBDBD),
                      child: Center(
                          child: Text(name[0],
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))))),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ],
    );
  }
}

enum _CarouselType { campaign, buyAirtime, airtimeRewards, hostCampaigns }

class _CarouselItem {
  final _CarouselType type;
  final Campaign? campaign;
  final List<Campaign> hostCampaigns;
  _CarouselItem.campaign(this.campaign) : type = _CarouselType.campaign, hostCampaigns = const [];
  _CarouselItem.hostCampaigns(this.hostCampaigns) : type = _CarouselType.hostCampaigns, campaign = null;
  const _CarouselItem.buyAirtime() : type = _CarouselType.buyAirtime, campaign = null, hostCampaigns = const [];
  const _CarouselItem.airtimeRewards() : type = _CarouselType.airtimeRewards, campaign = null, hostCampaigns = const [];
}
