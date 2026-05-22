import 'dart:convert';

class SubscriptionProviderSettings {
  const SubscriptionProviderSettings({
    this.updateInterval = SubscriptionUpdateInterval.sixHours,
    this.pingOnUpdate = true,
    this.updateOnLaunch = false,
    this.sendHwid = true,
    this.allowInsecureTls = false,
    this.protectSubscriptions = true,
  });

  final SubscriptionUpdateInterval updateInterval;
  final bool pingOnUpdate;
  final bool updateOnLaunch;
  final bool sendHwid;
  final bool allowInsecureTls;
  final bool protectSubscriptions;

  static const defaults = SubscriptionProviderSettings();

  SubscriptionProviderSettings copyWith({
    SubscriptionUpdateInterval? updateInterval,
    bool? pingOnUpdate,
    bool? updateOnLaunch,
    bool? sendHwid,
    bool? allowInsecureTls,
    bool? protectSubscriptions,
  }) {
    return SubscriptionProviderSettings(
      updateInterval: updateInterval ?? this.updateInterval,
      pingOnUpdate: pingOnUpdate ?? this.pingOnUpdate,
      updateOnLaunch: updateOnLaunch ?? this.updateOnLaunch,
      sendHwid: sendHwid ?? this.sendHwid,
      allowInsecureTls: allowInsecureTls ?? this.allowInsecureTls,
      protectSubscriptions: protectSubscriptions ?? this.protectSubscriptions,
    );
  }

  SubscriptionProviderSettings normalized() {
    return SubscriptionProviderSettings(
      updateInterval: updateInterval,
      pingOnUpdate: pingOnUpdate,
      updateOnLaunch: updateOnLaunch,
      sendHwid: sendHwid,
      allowInsecureTls: allowInsecureTls,
      protectSubscriptions: protectSubscriptions,
    );
  }

  bool hasSameConfiguration(SubscriptionProviderSettings other) {
    return updateInterval == other.updateInterval &&
        pingOnUpdate == other.pingOnUpdate &&
        updateOnLaunch == other.updateOnLaunch &&
        sendHwid == other.sendHwid &&
        allowInsecureTls == other.allowInsecureTls &&
        protectSubscriptions == other.protectSubscriptions;
  }

  Map<String, dynamic> toJson() => {
    'updateIntervalHours': updateInterval.hours,
    'pingOnUpdate': pingOnUpdate,
    'updateOnLaunch': updateOnLaunch,
    'sendHwid': sendHwid,
    'allowInsecureTls': allowInsecureTls,
    'protectSubscriptions': protectSubscriptions,
  };

  String encode() => jsonEncode(normalized().toJson());

  static SubscriptionProviderSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return defaults;
      return SubscriptionProviderSettings(
        updateInterval: SubscriptionUpdateInterval.parse(
          decoded['updateIntervalHours'] ?? decoded['updateInterval'],
        ),
        pingOnUpdate: decoded['pingOnUpdate'] as bool? ?? defaults.pingOnUpdate,
        updateOnLaunch:
            decoded['updateOnLaunch'] as bool? ?? defaults.updateOnLaunch,
        sendHwid: decoded['sendHwid'] as bool? ?? defaults.sendHwid,
        allowInsecureTls:
            decoded['allowInsecureTls'] as bool? ?? defaults.allowInsecureTls,
        protectSubscriptions:
            decoded['protectSubscriptions'] as bool? ??
            defaults.protectSubscriptions,
      ).normalized();
    } on FormatException {
      return defaults;
    } on TypeError {
      return defaults;
    }
  }
}

enum SubscriptionUpdateInterval {
  oneHour(1, '1 hour'),
  threeHours(3, '3 hours'),
  sixHours(6, '6 hours'),
  twelveHours(12, '12 hours');

  const SubscriptionUpdateInterval(this.hours, this.label);

  final int hours;
  final String label;

  Duration get duration => Duration(hours: hours);

  static SubscriptionUpdateInterval parse(Object? raw) {
    return tryParse(raw) ??
        SubscriptionProviderSettings.defaults.updateInterval;
  }

  static SubscriptionUpdateInterval? tryParse(Object? raw) {
    if (raw is int) return _fromHoursOrNull(raw);
    if (raw is num) return _fromHoursOrNull(raw.toInt());
    final normalized = raw?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final parsedHours = int.tryParse(
      normalized.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (parsedHours != null) return _fromHoursOrNull(parsedHours);
    for (final interval in values) {
      if (interval.name.toLowerCase() == normalized ||
          interval.label.toLowerCase() == normalized) {
        return interval;
      }
    }
    return null;
  }

  static SubscriptionUpdateInterval? _fromHoursOrNull(int hours) {
    for (final interval in values) {
      if (interval.hours == hours) return interval;
    }
    return null;
  }
}
