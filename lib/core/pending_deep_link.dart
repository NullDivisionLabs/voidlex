/// A configuration-changing `voidlex://` deep link that is awaiting explicit
/// user consent before it runs. Surfaced via [VpnController.pendingDeepLink]
/// so the UI can show the source/URL and let the user accept or reject it,
/// instead of silently mutating servers, subscriptions or routing rules.
enum DeepLinkActionKind {
  /// `voidlex://import/<base64>` — adds one or more servers.
  importServers,

  /// `voidlex://import-ruleset/<url>` — downloads and appends routing rules,
  /// which may restart the active tunnel.
  importRuleset,

  /// Encrypted subscription code or a plain http(s) subscription URL.
  importSubscription,
}

class PendingDeepLink {
  const PendingDeepLink({
    required this.kind,
    required this.displayUrl,
    this.isInsecureHttp = false,
  });

  final DeepLinkActionKind kind;

  /// Human-readable URL/source shown in the consent dialog.
  final String displayUrl;

  /// True when the payload would be fetched over plain `http://` (no TLS),
  /// so the UI can warn that the link can be observed/tampered in transit.
  final bool isInsecureHttp;
}
