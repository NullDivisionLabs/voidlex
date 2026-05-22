import 'dart:convert';

class MultiplexSettings {
  const MultiplexSettings({
    this.enabled = false,
    this.tcpConnections = 8,
    this.xudpConnections = 8,
    this.quicBehavior = MultiplexQuicBehavior.reject,
  });

  final bool enabled;
  final int tcpConnections;
  final int xudpConnections;
  final MultiplexQuicBehavior quicBehavior;

  static const defaults = MultiplexSettings();
  static const minConnections = -1;
  static const maxTcpConnections = 128;
  static const maxXudpConnections = 1024;

  MultiplexSettings copyWith({
    bool? enabled,
    int? tcpConnections,
    int? xudpConnections,
    MultiplexQuicBehavior? quicBehavior,
  }) {
    return MultiplexSettings(
      enabled: enabled ?? this.enabled,
      tcpConnections: tcpConnections ?? this.tcpConnections,
      xudpConnections: xudpConnections ?? this.xudpConnections,
      quicBehavior: quicBehavior ?? this.quicBehavior,
    );
  }

  MultiplexSettings normalized() {
    return MultiplexSettings(
      enabled: enabled,
      tcpConnections: _clamp(
        tcpConnections,
        minConnections,
        maxTcpConnections,
      ),
      xudpConnections: _clamp(
        xudpConnections,
        minConnections,
        maxXudpConnections,
      ),
      quicBehavior: quicBehavior,
    );
  }

  bool hasSameConfiguration(MultiplexSettings other) {
    return enabled == other.enabled &&
        tcpConnections == other.tcpConnections &&
        xudpConnections == other.xudpConnections &&
        quicBehavior == other.quicBehavior;
  }

  Map<String, dynamic> toNativeArgs() {
    final normalized = this.normalized();
    return {
      'muxEnabled': normalized.enabled,
      'muxTcpConcurrency': normalized.tcpConnections,
      'muxXudpConcurrency': normalized.xudpConnections,
      'muxQuicBehavior': normalized.quicBehavior.wireName,
    };
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'tcpConnections': tcpConnections,
    'xudpConnections': xudpConnections,
    'quicBehavior': quicBehavior.wireName,
  };

  String encode() => jsonEncode(toJson());

  static MultiplexSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return defaults;
      return MultiplexSettings(
        enabled: decoded['enabled'] as bool? ?? defaults.enabled,
        tcpConnections:
            _parseInt(decoded['tcpConnections']) ?? defaults.tcpConnections,
        xudpConnections:
            _parseInt(decoded['xudpConnections']) ?? defaults.xudpConnections,
        quicBehavior: MultiplexQuicBehavior.parse(
          decoded['quicBehavior'] as String?,
        ),
      ).normalized();
    } on FormatException {
      return defaults;
    } on TypeError {
      return defaults;
    }
  }

  static int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

enum MultiplexQuicBehavior {
  reject('reject', 'Reject'),
  allow('allow', 'Allow'),
  passthrough('skip', 'Passthrough');

  const MultiplexQuicBehavior(this.wireName, this.label);
  final String wireName;
  final String label;

  static MultiplexQuicBehavior parse(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    for (final behavior in values) {
      if (behavior.wireName == normalized || behavior.name == normalized) {
        return behavior;
      }
    }
    return MultiplexSettings.defaults.quicBehavior;
  }
}
