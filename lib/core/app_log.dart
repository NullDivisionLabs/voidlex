import 'package:flutter/services.dart';

enum AppLogLevel {
  debug,
  info,
  warning,
  error;

  static const defaultLevels = {
    AppLogLevel.info,
    AppLogLevel.warning,
    AppLogLevel.error,
  };

  String get wireName => switch (this) {
    AppLogLevel.debug => 'debug',
    AppLogLevel.info => 'info',
    AppLogLevel.warning => 'warning',
    AppLogLevel.error => 'error',
  };

  String get label => switch (this) {
    AppLogLevel.debug => 'Debug',
    AppLogLevel.info => 'Info',
    AppLogLevel.warning => 'Warnings',
    AppLogLevel.error => 'Errors',
  };

  static AppLogLevel? parse(String raw) {
    for (final level in AppLogLevel.values) {
      if (level.wireName == raw) return level;
    }
    return null;
  }

  static Set<AppLogLevel> decodeSet(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return Set<AppLogLevel>.of(defaultLevels);
    }
    if (normalized == 'none') return <AppLogLevel>{};
    final levels = normalized
        .split(',')
        .map((value) => parse(value.trim()))
        .whereType<AppLogLevel>()
        .toSet();
    return levels.isEmpty ? Set<AppLogLevel>.of(defaultLevels) : levels;
  }

  static String encodeSet(Set<AppLogLevel> levels) {
    if (levels.isEmpty) return 'none';
    return AppLogLevel.values
        .where(levels.contains)
        .map((level) => level.wireName)
        .join(',');
  }
}

enum AppLogRetention {
  oneHour,
  oneDay,
  oneWeek,
  forever;

  static const defaultRetention = AppLogRetention.oneDay;

  String get wireName => switch (this) {
    AppLogRetention.oneHour => 'hour',
    AppLogRetention.oneDay => 'day',
    AppLogRetention.oneWeek => 'week',
    AppLogRetention.forever => 'forever',
  };

  String get label => switch (this) {
    AppLogRetention.oneHour => '1 hour',
    AppLogRetention.oneDay => '1 day',
    AppLogRetention.oneWeek => '1 week',
    AppLogRetention.forever => 'Never delete',
  };

  static AppLogRetention decode(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) return defaultRetention;
    for (final retention in AppLogRetention.values) {
      if (retention.wireName == normalized) return retention;
    }
    return defaultRetention;
  }
}

class AppLogBridge {
  const AppLogBridge();

  static const MethodChannel _channel = MethodChannel(
    'org.voidtunnel.vpn/service',
  );

  Future<String> read({
    Set<AppLogLevel>? levels,
    AppLogRetention? retention,
  }) async {
    final selectedLevels = levels ?? AppLogLevel.defaultLevels;
    final selectedRetention = retention ?? AppLogRetention.defaultRetention;
    if (selectedLevels.isEmpty) return '';
    return await _channel.invokeMethod<String>('getAppLogs', {
          'levels': selectedLevels.map((level) => level.wireName).toList(),
          'retention': selectedRetention.wireName,
        }) ??
        '';
  }

  /// Returns only the log lines newer than [sinceEpochMs]. UI pollers
  /// should pass the wall-clock timestamp of the most recent line they've
  /// already displayed so the bridge can ship the delta instead of the
  /// full buffer on every refresh. A zero (or negative) [sinceEpochMs]
  /// falls back to a full snapshot via the regular `read()` path.
  Future<String> readSince({
    required int sinceEpochMs,
    Set<AppLogLevel>? levels,
    AppLogRetention? retention,
  }) async {
    final selectedLevels = levels ?? AppLogLevel.defaultLevels;
    final selectedRetention = retention ?? AppLogRetention.defaultRetention;
    if (selectedLevels.isEmpty) return '';
    return await _channel.invokeMethod<String>('getAppLogsSince', {
          'levels': selectedLevels.map((level) => level.wireName).toList(),
          'retention': selectedRetention.wireName,
          'sinceEpochMs': sinceEpochMs,
        }) ??
        '';
  }

  Future<void> setRetention(AppLogRetention retention) async {
    try {
      await _channel.invokeMethod<void>(
        'setAppLogRetention',
        retention.wireName,
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> clear() {
    return _channel.invokeMethod<void>('clearAppLogs');
  }

  Future<bool> export({
    required String content,
    required String fileName,
  }) async {
    return await _channel.invokeMethod<bool>('exportAppLogs', {
          'content': content,
          'fileName': fileName,
        }) ??
        false;
  }
}
