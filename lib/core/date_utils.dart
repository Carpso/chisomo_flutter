/// Returns the date portion (`YYYY-MM-DD`) of an ISO timestamp string.
/// Never throws on empty/short/malformed values: null and '' fall back to '',
/// anything shorter than a full date is returned as-is.
String safeDate(Object? value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.length < 10) return s;
  return s.substring(0, 10);
}

/// Returns a human date + time ("14 Aug 2026 · 14:30") for a UTC `YYYY-MM-DD
/// HH:MM:SS` string (what the backend's `datetime('now')` produces for
/// notifications), converted to the device's local timezone. Falls back to
/// [safeDate] when the value can't be parsed so nothing ever throws.
String safeDateTime(Object? value) {
  if (value == null) return '';
  final s = value.toString().trim();
  final parsed = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (parsed == null) return safeDate(s);
  final local = parsed.toLocal();
  final months = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year} · $hh:$mm';
}

/// Returns up to [length] chars of a string, or '' for null.
/// Never throws on short/malformed values.
String safePrefix(Object? value, int length) {
  if (value == null) return '';
  final s = value.toString();
  return s.length <= length ? s : s.substring(0, length);
}
