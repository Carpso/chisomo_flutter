import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_sponsor_app/core/money.dart';

void main() {
  group('formatKwacha', () {
    test('formats cents as kwacha', () {
      expect(formatKwacha(100), 'K1.00');
      expect(formatKwacha(0), 'K0.00');
      expect(formatKwacha(123456), 'K1,234.56');
      expect(formatKwacha(5), 'K0.05');
    });

    test('handles negatives and thousands grouping', () {
      expect(formatKwacha(-100), 'K-1.00');
      expect(formatKwacha(100000000), 'K1,000,000.00');
    });
  });

  group('formatUsd', () {
    test('formats cents as dollars', () {
      expect(formatUsd(1000), r'$10.00');
      expect(formatUsd(123456), r'$1,234.56');
      expect(formatUsd(5), r'$0.05');
    });
  });

  group('formatKwachaPlain', () {
    test('no currency symbol', () {
      expect(formatKwachaPlain(1234), '12.34');
      expect(formatKwachaPlain(100000), '1,000.00');
    });
  });

  group('formatPct', () {
    test('rounds whole percentages and keeps one decimal otherwise', () {
      expect(formatPct(1), '1%');
      expect(formatPct(2.5), '2.5%'); // 0.5 away from whole -> keep one decimal
      expect(formatPct(3.25), '3.3%');
      expect(formatPct(2.96), '3%'); // 0.04 from whole -> rounds
    });
  });
}
