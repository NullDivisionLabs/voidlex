import 'dart:convert';

class TunnelFragmentSettings {
  const TunnelFragmentSettings({
    required this.enabled,
    required this.packets,
    required this.length,
    required this.interval,
    required this.maxSplit,
    required this.noiseEnabled,
    required this.noiseType,
    required this.noisePacket,
    required this.noiseDelay,
    required this.noiseApplyTo,
  });

  static const defaultPackets = 'tlshello';
  static const defaultLength = '50-100';
  static const defaultInterval = '10-20';
  static const defaultMaxSplit = '100-200';
  static const defaultNoiseType = 'rand';
  static const defaultNoisePacket = '10-20';
  static const defaultNoiseDelay = '10-16';
  static const defaultNoiseApplyTo = 'ip';

  static const defaults = TunnelFragmentSettings(
    enabled: false,
    packets: defaultPackets,
    length: defaultLength,
    interval: defaultInterval,
    maxSplit: defaultMaxSplit,
    noiseEnabled: true,
    noiseType: defaultNoiseType,
    noisePacket: defaultNoisePacket,
    noiseDelay: defaultNoiseDelay,
    noiseApplyTo: defaultNoiseApplyTo,
  );

  final bool enabled;
  final String packets;
  final String length;
  final String interval;
  final String maxSplit;
  final bool noiseEnabled;
  final String noiseType;
  final String noisePacket;
  final String noiseDelay;
  final String noiseApplyTo;

  TunnelFragmentSettings copyWith({
    bool? enabled,
    String? packets,
    String? length,
    String? interval,
    String? maxSplit,
    bool? noiseEnabled,
    String? noiseType,
    String? noisePacket,
    String? noiseDelay,
    String? noiseApplyTo,
  }) {
    return TunnelFragmentSettings(
      enabled: enabled ?? this.enabled,
      packets: packets ?? this.packets,
      length: length ?? this.length,
      interval: interval ?? this.interval,
      maxSplit: maxSplit ?? this.maxSplit,
      noiseEnabled: noiseEnabled ?? this.noiseEnabled,
      noiseType: noiseType ?? this.noiseType,
      noisePacket: noisePacket ?? this.noisePacket,
      noiseDelay: noiseDelay ?? this.noiseDelay,
      noiseApplyTo: noiseApplyTo ?? this.noiseApplyTo,
    );
  }

  TunnelFragmentSettings normalized() {
    return TunnelFragmentSettings(
      enabled: enabled,
      packets: _fallback(packets, defaultPackets),
      length: _fallback(length, defaultLength),
      interval: _fallback(interval, defaultInterval),
      maxSplit: _fallback(maxSplit, defaultMaxSplit),
      noiseEnabled: noiseEnabled,
      noiseType: _fallback(noiseType, defaultNoiseType),
      noisePacket: _fallback(noisePacket, defaultNoisePacket),
      noiseDelay: _fallback(noiseDelay, defaultNoiseDelay),
      noiseApplyTo: _fallback(noiseApplyTo, defaultNoiseApplyTo),
    );
  }

  bool hasSameConfiguration(TunnelFragmentSettings other) {
    return enabled == other.enabled &&
        packets == other.packets &&
        length == other.length &&
        interval == other.interval &&
        maxSplit == other.maxSplit &&
        noiseEnabled == other.noiseEnabled &&
        noiseType == other.noiseType &&
        noisePacket == other.noisePacket &&
        noiseDelay == other.noiseDelay &&
        noiseApplyTo == other.noiseApplyTo;
  }

  Map<String, dynamic> toNativeArgs() {
    final normalized = this.normalized();
    return {
      'fragmentEnabled': normalized.enabled,
      'fragmentPackets': normalized.packets,
      'fragmentLength': normalized.length,
      'fragmentInterval': normalized.interval,
      'fragmentMaxSplit': normalized.maxSplit,
      'fragmentNoiseEnabled': normalized.noiseEnabled,
      'fragmentNoiseType': normalized.noiseType,
      'fragmentNoisePacket': normalized.noisePacket,
      'fragmentNoiseDelay': normalized.noiseDelay,
      'fragmentNoiseApplyTo': normalized.noiseApplyTo,
    };
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'packets': packets,
    'length': length,
    'interval': interval,
    'maxSplit': maxSplit,
    'noiseEnabled': noiseEnabled,
    'noiseType': noiseType,
    'noisePacket': noisePacket,
    'noiseDelay': noiseDelay,
    'noiseApplyTo': noiseApplyTo,
  };

  String encode() => jsonEncode(toJson());

  static TunnelFragmentSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return defaults;
      return TunnelFragmentSettings(
        enabled: decoded['enabled'] as bool? ?? defaults.enabled,
        packets: decoded['packets'] as String? ?? defaults.packets,
        length: decoded['length'] as String? ?? defaults.length,
        interval: decoded['interval'] as String? ?? defaults.interval,
        maxSplit: decoded['maxSplit'] as String? ?? defaults.maxSplit,
        noiseEnabled: decoded['noiseEnabled'] as bool? ?? defaults.noiseEnabled,
        noiseType: decoded['noiseType'] as String? ?? defaults.noiseType,
        noisePacket: decoded['noisePacket'] as String? ?? defaults.noisePacket,
        noiseDelay: decoded['noiseDelay'] as String? ?? defaults.noiseDelay,
        noiseApplyTo:
            decoded['noiseApplyTo'] as String? ?? defaults.noiseApplyTo,
      ).normalized();
    } on FormatException {
      return defaults;
    } on TypeError {
      return defaults;
    }
  }

  static String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
