String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _formatKwachaValue(int cents) {
  final negative = cents < 0;
  final abs = negative ? -cents : cents;
  final whole = _groupDigits((abs ~/ 100).toString());
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$whole.$frac';
}

String formatKwacha(int cents) => 'K${_formatKwachaValue(cents)}';

/// Formats an amount as USD dollars (whole dollars + cents), e.g. "$10.00".
String formatUsd(int cents) {
  final negative = cents < 0;
  final abs = negative ? -cents : cents;
  final whole = _groupDigits((abs ~/ 100).toString());
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}\$$whole.$frac';
}

String formatKwachaPlain(int cents) => _formatKwachaValue(cents);

String formatPct(double pct) {
  final rounded = pct.round();
  final t = (pct - rounded).abs() < 0.05 ? rounded.toString() : pct.toStringAsFixed(1);
  return '$t%';
}
