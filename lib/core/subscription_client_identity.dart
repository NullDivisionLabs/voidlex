import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// HTTP identity sent to subscription providers (VPN admin panels).
///
/// Dart's [HttpClient] defaults to `User-Agent: Dart/3.x`, which panels often
/// show as an unknown client. Call [init] during app bootstrap to load the
/// real version from package metadata.
abstract final class SubscriptionClientIdentity {
  static const String appName = 'VoidLex';
  static String _appVersion = 'unknown';

  static String get appVersion => _appVersion;

  /// Sent as the standard `User-Agent` header on subscription fetches.
  static String get userAgent => '$appName/$_appVersion';

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (version.isNotEmpty) {
        _appVersion = version;
      }
    } catch (_) {
      // Keep the fallback for unit tests and unsupported platforms.
    }
  }

  static void applyTo(HttpClientRequest request) {
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
  }
}
