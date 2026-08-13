import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_sponsor_app/core/fx_service.dart';
import 'package:kingdom_sponsor_app/features/auth/auth_controller.dart';
import 'package:kingdom_sponsor_app/features/campaigns/campaigns_controller.dart';
import 'package:kingdom_sponsor_app/features/campaigns/models.dart';
import 'package:kingdom_sponsor_app/features/donate/donate_screen.dart';
import 'package:kingdom_sponsor_app/features/events/buy_ticket_screen.dart';

/// Fake auth: a signed-in non-staff donor.
class _AuthFake extends AuthController {
  _AuthFake(this.value);
  final AuthState value;
  @override
  Future<AuthState> build() async => value;
}

/// Fake campaign detail so no network is hit.
class _CampaignDetailFake extends CampaignDetailController {
  _CampaignDetailFake(super.campaignId, this.value);
  final CampaignDetail value;
  @override
  Future<CampaignDetail> build() async => value;
}

AuthState _donorAuth() => const AuthState(
      token: 't',
      phone: '+260970000000',
      username: 'donor',
      isAdmin: false,
      hostStatus: 'none',
    );

Campaign _campaign({List<EventTier> tiers = const []}) => Campaign(
      id: 1,
      slug: 'test',
      title: 'Test campaign',
      description: 'A test campaign.',
      imageUrl: null,
      goalCents: 100000,
      hasGoal: true,
      raisedCents: 10000,
      withdrawnCents: 0,
      donorCount: 3,
      donationCount: 3,
      avgDonationCents: 3300,
      donorsNeededAtAvg: null,
      dailyRateCents: 500,
      status: 'active',
      promoted: false,
      createdAt: '2026-01-01 00:00:00',
      category: 'Community',
      visibility: 'public',
      campaignType: 'community',
      waivePayoutFees: false,
      eventTiers: tiers,
      eventCapacity: 0,
      ticketsSold: 0,
      rsvpCount: 0,
      isMine: false,
      isLive: false,
    );

CampaignDetail _detail(Campaign c) => CampaignDetail(
      campaign: c,
      donors: const [],
      leaderboard: const [],
      fees: const FeesInfo(
        platformPct: 1,
        platformMinFeeCents: 300,
        platformFixedFeeCents: 48,
        momoPct: 2.5,
        totalPct: 3.5,
        disbursementPct: 1.5,
        cardPct: 2,
        cardMinFeeCents: 500,
        cardLipilaPct: 2.5,
      ),
    );

void main() {
  group('DonateScreen form', () {
    Widget harness({List<EventTier> tiers = const []}) {
      return ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _AuthFake(_donorAuth())),
          campaignDetailProvider(1).overrideWith(() => _CampaignDetailFake(1, _detail(_campaign(tiers: tiers)))),
          currencyPrefProvider.overrideWith(() => CurrencyController(CurrencyPref.zmw)),
          fxServiceProvider.overrideWith((ref) => FxService()..setFallbackRate(26.5)),
        ],
        child: const MaterialApp(home: DonateScreen(campaignId: 1)),
      );
    }

    testWidgets('renders the amount presets and currency toggle', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Choose an amount'), findsOneWidget);
      expect(find.text('ZMW'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
    });

    testWidgets('switching to USD shows dollar presets', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();

      expect(find.text(r'$5'), findsOneWidget);
      expect(find.text(r'$100'), findsOneWidget);
    });
  });

  group('BuyTicketScreen form', () {
    Widget harness() {
      final event = _campaign(tiers: const [
        EventTier(name: 'Standard', amountCents: 20000),
        EventTier(name: 'VIP', amountCents: 50000),
      ]);
      return ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _AuthFake(_donorAuth())),
          campaignDetailProvider(9).overrideWith(() => _CampaignDetailFake(9, _detail(event))),
          currencyPrefProvider.overrideWith(() => CurrencyController(CurrencyPref.zmw)),
          fxServiceProvider.overrideWith((ref) => FxService()..setFallbackRate(26.5)),
        ],
        child: const MaterialApp(home: BuyTicketScreen(eventId: 9)),
      );
    }

    testWidgets('shows ticket tiers', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Choose a ticket tier'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('How would you like to pay?'), findsOneWidget);
    });
  });
}
