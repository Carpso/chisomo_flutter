/// Returns the date portion (`YYYY-MM-DD`) of an ISO timestamp string.
/// Never throws on empty/short/malformed values: null and '' fall back to '',
/// anything shorter than a full date is returned as-is.
String safeDate(Object? value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.length < 10) return s;
  return s.substring(0, 10);
}

/// Returns up to [length] chars of a string, or '' for null.
/// Never throws on short/malformed values.
String safePrefix(Object? value, int length) {
  if (value == null) return '';
  final s = value.toString();
  return s.length <= length ? s : s.substring(0, length);
}
