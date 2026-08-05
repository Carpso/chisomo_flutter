import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_sponsor_app/core/money.dart';

void main() {
  group('formatKwacha', () {
    test('formats ngwee as kwacha with two decimals', () {
      expect(formatKwacha(100), 'K1.00');
      expect(formatKwacha(5000), 'K50.00');
      expect(formatKwacha(123456), 'K1,234.56');
      expect(formatKwacha(0), 'K0.00');
    });

    test('plain variant omits the K sign', () {
      expect(formatKwachaPlain(123456), '1,234.56');
    });
  });

  group('formatPct', () {
    test('drops decimals on whole percentages', () {
      expect(formatPct(25), '25%');
      expect(formatPct(1), '1%');
      expect(formatPct(100), '100%');
    });

    test('keeps one decimal for fractional percentages', () {
      expect(formatPct(2.5), '2.5%');
      expect(formatPct(33.33), '33.3%');
    });
  });
}
