/// Pure helpers for parsing and classifying `voidlex://` deep links.
abstract final class DeepLinkHandler {
  static const String scheme = 'voidlex';

  static bool isVoidLexUri(Uri? uri) =>
      uri != null && uri.scheme.toLowerCase() == scheme;

  /// Home-screen widget PendingIntents use unique `voidlex://widget/...`
  /// URIs but are handled in native broadcast receivers, not in Dart.
  static bool isWidgetDeepLink(Uri uri) => uri.host.toLowerCase() == 'widget';

  static bool isVpnControlHost(String host) {
    switch (host.toLowerCase()) {
      case 'connect':
      case 'open':
      case 'disconnect':
      case 'close':
      case 'toggle':
      case 'restart':
        return true;
      default:
        return false;
    }
  }

  /// Extracts the remote ruleset URL from
  /// `voidlex://import-ruleset/https://host/path.json`.
  static Uri? rulesetTargetFromUri(Uri voidlexUri) {
    if (voidlexUri.host.toLowerCase() != 'import-ruleset') return null;

    final queryUrl = voidlexUri.queryParameters['url']?.trim();
    if (queryUrl != null && queryUrl.isNotEmpty) {
      return Uri.tryParse(queryUrl);
    }

    final path = voidlexUri.path;
    if (path.isEmpty || path == '/') return null;
    final withoutLeadingSlash = path.startsWith('/')
        ? path.substring(1)
        : path;
    if (withoutLeadingSlash.isEmpty) return null;
    return Uri.tryParse(withoutLeadingSlash);
  }

  /// Only plain remote HTTP(S) endpoints — blocks file://, javascript:, etc.
  static bool isAllowedRulesetUrl(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }
}
