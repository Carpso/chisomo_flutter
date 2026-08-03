import 'package:intl/intl.dart';

final NumberFormat _kFmt = NumberFormat('#,##0.00', 'en_US');

String formatKwacha(int cents) => 'K${_kFmt.format(cents / 100)}';

String formatKwachaPlain(int cents) => _kFmt.format(cents / 100);

String formatPct(double pct) {
  final t = pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1);
  return '$t%';
}
