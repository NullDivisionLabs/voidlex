import 'dart:io';

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

  static VpnDeepLinkCommand? vpnCommandFromHost(String host) {
    switch (host.toLowerCase()) {
      case 'connect':
      case 'open':
        return VpnDeepLinkCommand.connect;
      case 'disconnect':
      case 'close':
        return VpnDeepLinkCommand.disconnect;
      case 'toggle':
        return VpnDeepLinkCommand.toggle;
      case 'restart':
        return VpnDeepLinkCommand.restart;
      default:
        return null;
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
    final withoutLeadingSlash = path.startsWith('/') ? path.substring(1) : path;
    if (withoutLeadingSlash.isEmpty) return null;
    return Uri.tryParse(withoutLeadingSlash);
  }

  /// Only remote HTTPS endpoints on public hosts — blocks file://, private
  /// IPs, loopback, and other SSRF targets.
  static bool isAllowedRulesetUrl(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return isPublicRulesetHost(uri.host);
  }

  /// True when [host] resolves to a routable public ruleset endpoint.
  static bool isPublicRulesetHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized == 'localhost' ||
        normalized.endsWith('.localhost') ||
        normalized.endsWith('.local')) {
      return false;
    }
    if (normalized == 'metadata.google.internal') return false;

    final bracketed = normalized.startsWith('[') && normalized.endsWith(']')
        ? normalized.substring(1, normalized.length - 1)
        : normalized;
    final address = InternetAddress.tryParse(bracketed);
    if (address == null) return true;
    return isPublicRulesetAddress(address);
  }

  static bool isPublicRulesetAddress(InternetAddress address) {
    if (address.isLoopback) return false;
    if (address.type == InternetAddressType.IPv4) {
      final octets = address.rawAddress;
      if (octets[0] == 10) return false;
      if (octets[0] == 100 && octets[1] >= 64 && octets[1] <= 127) {
        return false;
      }
      if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) {
        return false;
      }
      if (octets[0] == 192 && octets[1] == 168) return false;
      if (octets[0] == 127) return false;
      if (octets[0] == 169 && octets[1] == 254) return false;
      if (octets[0] == 0) return false;
      if (octets[0] == 192 && octets[1] == 0 && octets[2] == 0) {
        return false;
      }
      if (octets[0] == 192 && octets[1] == 0 && octets[2] == 2) {
        return false;
      }
      if (octets[0] == 198 && (octets[1] == 18 || octets[1] == 19)) {
        return false;
      }
      if (octets[0] == 198 && octets[1] == 51 && octets[2] == 100) {
        return false;
      }
      if (octets[0] == 203 && octets[1] == 0 && octets[2] == 113) {
        return false;
      }
      if (octets[0] >= 224) return false;
      return true;
    }

    if (address.type == InternetAddressType.IPv6) {
      final bytes = address.rawAddress;
      if (bytes.every((byte) => byte == 0)) return false;
      // IPv4-mapped IPv6 (::ffff:0:0/96).
      if (bytes.take(10).every((byte) => byte == 0) &&
          bytes[10] == 0xff &&
          bytes[11] == 0xff) {
        return isPublicRulesetAddress(
          InternetAddress.fromRawAddress(bytes.sublist(12)),
        );
      }
      // Unique local (fc00::/7)
      if ((bytes[0] & 0xfe) == 0xfc) return false;
      // Link-local (fe80::/10)
      if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) return false;
      // Deprecated site-local (fec0::/10).
      if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0xc0) return false;
      // Multicast (ff00::/8).
      if (bytes[0] == 0xff) return false;
      // Documentation prefix (2001:db8::/32).
      if (bytes[0] == 0x20 &&
          bytes[1] == 0x01 &&
          bytes[2] == 0x0d &&
          bytes[3] == 0xb8) {
        return false;
      }
      return true;
    }

    return false;
  }
}

/// VPN control verbs carried by `voidlex://connect` and friends.
enum VpnDeepLinkCommand { connect, disconnect, toggle, restart }
