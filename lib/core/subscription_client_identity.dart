import 'dart:io';

/// HTTP identity sent to subscription providers (VPN admin panels).
///
/// Dart's [HttpClient] defaults to `User-Agent: Dart/3.x`, which panels often
/// show as an unknown client.
abstract final class SubscriptionClientIdentity {
  static const String appName = 'VoidLex';
  static const String appVersion = '1.0.1-beta';

  /// Sent as the standard `User-Agent` header on subscription fetches.
  static const String userAgent = '$appName/$appVersion';

  static void applyTo(HttpClientRequest request) {
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
  }
}
