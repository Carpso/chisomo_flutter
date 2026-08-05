import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kingdom_sponsor_app/features/campaigns/campaigns_controller.dart';
import 'package:kingdom_sponsor_app/features/campaigns/models.dart';
import 'package:kingdom_sponsor_app/features/host/promote_screen.dart';

// Fake notifiers so PromoteScreen renders without any network access.
class _PromoInfoFake extends PromotionInfoController {
  _PromoInfoFake(this.value);
  final PromotionInfo value;
  @override
  Future<PromotionInfo> build() async => value;
}

class _HostFake extends HostController {
  _HostFake(this.value);
  final HostData value;
  @override
  Future<HostData> build() async => value;
}

class _MineFake extends MyPromotionsController {
  _MineFake(this.value);
  final List<MyPromotion> value;
  @override
  Future<List<MyPromotion>> build() async => value;
}

void main() {
  group('PromoteScreen empty states', () {
    Widget harness({required List<MyPromotion> mine}) {
      return ProviderScope(
        overrides: [
          promotionInfoProvider.overrideWith(() => _PromoInfoFake(
                const PromotionInfo(
                  slots: 5,
                  active: 0,
                  available: 5,
                  priceCents: 15000,
                  days: 7,
                  promotedIds: [],
                ),
              )),
          hostProvider.overrideWith(() => _HostFake(const HostData(
                user: HostUser(
                  id: 1,
                  phone: '+260970000000',
                  username: 'host',
                  isHost: true,
                  isAdmin: false,
                  hostStatus: 'approved',
                  hostOrg: null,
                  hostRole: null,
                  hostRejection: null,
                  totalGivenCents: 0,
                  tier: 'Giver',
                ),
                campaigns: [],
                transactions: [],
                payouts: [],
              ))),
          myPromotionsProvider.overrideWith(() => _MineFake(mine)),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, _) => const PromoteScreen()),
          ]),
        ),
      );
    }

    testWidgets('shows the no-promotions hint', (tester) async {
      await tester.pumpWidget(harness(mine: const []));
      await tester.pumpAndSettle();
      expect(find.text('No promotions yet. Pick a campaign above to get started.'),
          findsOneWidget);
      expect(find.text('Your promotion history'), findsOneWidget);
    });

    testWidgets('renders an expired promotion entry', (tester) async {
      await tester.pumpWidget(harness(mine: const [
        MyPromotion(
          id: 1,
          campaignId: 1,
          campaignTitle: 'Back to school',
          amountCents: 15000,
          days: 7,
          status: 'expired',
          expiresAt: null,
          createdAt: '2026-08-01 10:00:00',
        ),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Back to school'), findsOneWidget);
      expect(find.text('K150.00 • 7 days\nExpired'), findsOneWidget);
      expect(find.textContaining('Expired'), findsOneWidget);
    });
  });
}
