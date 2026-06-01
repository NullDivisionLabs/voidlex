import 'dart:convert';

import 'bounded_json.dart';

class ConnectionPolicySettings {
  const ConnectionPolicySettings({
    this.handshakeSeconds = 4,
    this.connIdleSeconds = 60,
    this.uplinkOnlySeconds = 2,
    this.downlinkOnlySeconds = 5,
    this.maxTcpConnections = 256,
    this.maxUdpConnections = 128,
  });

  final int handshakeSeconds;
  final int connIdleSeconds;
  final int uplinkOnlySeconds;
  final int downlinkOnlySeconds;
  final int maxTcpConnections;
  final int maxUdpConnections;

  static const defaults = ConnectionPolicySettings();

  static const minIdleSeconds = 5;
  static const maxIdleSeconds = 3600;
  static const minConnections = 1;
  static const maxTcpLimit = 4096;
  static const maxUdpLimit = 4096;

  ConnectionPolicySettings copyWith({
    int? handshakeSeconds,
    int? connIdleSeconds,
    int? uplinkOnlySeconds,
    int? downlinkOnlySeconds,
    int? maxTcpConnections,
    int? maxUdpConnections,
  }) {
    return ConnectionPolicySettings(
      handshakeSeconds: handshakeSeconds ?? this.handshakeSeconds,
      connIdleSeconds: connIdleSeconds ?? this.connIdleSeconds,
      uplinkOnlySeconds: uplinkOnlySeconds ?? this.uplinkOnlySeconds,
      downlinkOnlySeconds: downlinkOnlySeconds ?? this.downlinkOnlySeconds,
      maxTcpConnections: maxTcpConnections ?? this.maxTcpConnections,
      maxUdpConnections: maxUdpConnections ?? this.maxUdpConnections,
    );
  }

  ConnectionPolicySettings normalized() {
    return ConnectionPolicySettings(
      handshakeSeconds: _clamp(handshakeSeconds, 1, 60),
      connIdleSeconds: _clamp(connIdleSeconds, minIdleSeconds, maxIdleSeconds),
      uplinkOnlySeconds: _clamp(uplinkOnlySeconds, 1, 60),
      downlinkOnlySeconds: _clamp(downlinkOnlySeconds, 1, 60),
      maxTcpConnections: _clamp(maxTcpConnections, minConnections, maxTcpLimit),
      maxUdpConnections: _clamp(maxUdpConnections, minConnections, maxUdpLimit),
    );
  }

  bool hasSameConfiguration(ConnectionPolicySettings other) {
    return handshakeSeconds == other.handshakeSeconds &&
        connIdleSeconds == other.connIdleSeconds &&
        uplinkOnlySeconds == other.uplinkOnlySeconds &&
        downlinkOnlySeconds == other.downlinkOnlySeconds &&
        maxTcpConnections == other.maxTcpConnections &&
        maxUdpConnections == other.maxUdpConnections;
  }

  Map<String, dynamic> toNativeArgs() {
    final n = normalized();
    return {
      'policyHandshakeSec': n.handshakeSeconds,
      'policyConnIdleSec': n.connIdleSeconds,
      'policyUplinkOnlySec': n.uplinkOnlySeconds,
      'policyDownlinkOnlySec': n.downlinkOnlySeconds,
      'policyMaxTcpConns': n.maxTcpConnections,
      'policyMaxUdpConns': n.maxUdpConnections,
    };
  }

  Map<String, dynamic> toJson() => {
    'handshakeSeconds': handshakeSeconds,
    'connIdleSeconds': connIdleSeconds,
    'uplinkOnlySeconds': uplinkOnlySeconds,
    'downlinkOnlySeconds': downlinkOnlySeconds,
    'maxTcpConnections': maxTcpConnections,
    'maxUdpConnections': maxUdpConnections,
  };

  String encode() => jsonEncode(toJson());

  static ConnectionPolicySettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = tryDecodeJson(raw, maxBytes: JsonPayloadLimits.settingsBlob);
      if (decoded is! Map<String, dynamic>) return defaults;
      return ConnectionPolicySettings(
        handshakeSeconds:
            _parseInt(decoded['handshakeSeconds']) ?? defaults.handshakeSeconds,
        connIdleSeconds:
            _parseInt(decoded['connIdleSeconds']) ?? defaults.connIdleSeconds,
        uplinkOnlySeconds: _parseInt(decoded['uplinkOnlySeconds']) ??
            defaults.uplinkOnlySeconds,
        downlinkOnlySeconds: _parseInt(decoded['downlinkOnlySeconds']) ??
            defaults.downlinkOnlySeconds,
        maxTcpConnections: _parseInt(decoded['maxTcpConnections']) ??
            defaults.maxTcpConnections,
        maxUdpConnections: _parseInt(decoded['maxUdpConnections']) ??
            defaults.maxUdpConnections,
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
