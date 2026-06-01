/// Whether a raw ping value should display as N/A in the UI (ERR / timeout).
bool isPingDisplayNa(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty || trimmed == '--') return false;
  final upper = trimmed.toUpperCase();
  return upper == 'ERR' || trimmed.startsWith('>');
}
