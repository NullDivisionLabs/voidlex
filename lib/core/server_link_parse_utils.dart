/// Helpers shared by the VLESS / Hysteria2 link parsers and the JSON server
/// importer. Kept in one place so their behaviour can't quietly drift between
/// the parsers (the three copies of [ensureUniqueServerName] previously did).
library;

/// Returns [baseName] trimmed and made unique against [existingNames] by
/// appending " (2)", " (3)", … When [baseName] is blank, [fallback] is used as
/// the base instead.
String ensureUniqueServerName(
  String baseName,
  Set<String> existingNames, {
  required String fallback,
}) {
  final normalized = baseName.trim().isEmpty ? fallback : baseName.trim();
  if (!existingNames.contains(normalized)) return normalized;
  var index = 2;
  while (existingNames.contains('$normalized ($index)')) {
    index++;
  }
  return '$normalized ($index)';
}

/// Parses a query-string boolean flag as used by the link parsers'
/// insecure/allowInsecure handling: "1"/"true"/"yes" → true, "0"/"false"/"no"
/// → false (case-insensitive). Returns null for null or unrecognised input.
bool? parseQueryBoolFlag(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null) return null;
  return switch (value) {
    '1' || 'true' || 'yes' => true,
    '0' || 'false' || 'no' => false,
    _ => null,
  };
}
