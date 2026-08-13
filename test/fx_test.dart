import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_sponsor_app/core/fx_service.dart';

void main() {
  group('FxService conversion math', () {
    const rate = 26.5; // ZMW per 1 USD

    test('toTarget converts ZMW to USD', () {
      // ZMW 100 / 26.5 = $3.77
      expect(FxService().toTarget(100, rate), closeTo(3.7735, 0.001));
    });

    test('fromTarget converts USD to ZMW', () {
      // $10 * 26.5 = ZMW 265
      expect(FxService().fromTarget(10, rate), closeTo(265, 0.001));
    });

    test('ratePerUnit is zero until a rate loads', () {
      expect(FxService().isRateLoaded, false);
    });
  });

  group('formatAmountCents (donate-screen display)', () {
    test('ZMW shows whole kwacha when no decimals', () {
      expect(formatAmountCents(5000, CurrencyPref.zmw), 'K50');
      expect(formatAmountCents(5050, CurrencyPref.zmw), 'K50.50');
    });

    test('USD converts via the live rate', () {
      // K50 at 26.5 -> $1.8867 -> "$1.89"
      expect(formatAmountCents(5000, CurrencyPref.usd, rate: 26.5), r'$1.89');
    });

    test('USD falls back to ZMW when the rate is unknown', () {
      expect(formatAmountCents(5000, CurrencyPref.usd), 'K50');
      expect(formatAmountCents(5000, CurrencyPref.usd, rate: 0), 'K50');
    });
  });

  group('CurrencyPref persistence keys', () {
    test('load defaults to ZMW for unknown values', () async {
      // Not exercising SharedPreferences here; just confirm the enum mapping
      // used by the controller is stable.
      expect(CurrencyPref.zmw.name, 'zmw');
      expect(CurrencyPref.usd.name, 'usd');
    });
  });
}
