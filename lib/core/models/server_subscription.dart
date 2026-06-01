import 'dart:convert';

import '../bounded_json.dart';

import '../subscription_provider_settings.dart';
import 'server_config.dart';

class ServerSubscription {
  const ServerSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.servers,
    this.updatedAt,
    this.expiresAt,
    this.trafficUsedBytes,
    this.trafficLimitBytes,
    this.updateIntervalOverride,
    this.hideNaServers = false,
  });

  final String id;
  final String name;
  final String url;
  final List<ServerConfig> servers;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final int? trafficUsedBytes;
  final int? trafficLimitBytes;
  final SubscriptionUpdateInterval? updateIntervalOverride;
  final bool hideNaServers;

  ServerSubscription copyWith({
    String? id,
    String? name,
    String? url,
    List<ServerConfig>? servers,
    DateTime? updatedAt,
    DateTime? expiresAt,
    int? trafficUsedBytes,
    int? trafficLimitBytes,
    SubscriptionUpdateInterval? updateIntervalOverride,
    bool? hideNaServers,
    bool clearUpdatedAt = false,
    bool clearExpiresAt = false,
    bool clearTrafficUsedBytes = false,
    bool clearTrafficLimitBytes = false,
    bool clearUpdateIntervalOverride = false,
  }) {
    return ServerSubscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      servers: servers ?? this.servers,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      trafficUsedBytes: clearTrafficUsedBytes
          ? null
          : (trafficUsedBytes ?? this.trafficUsedBytes),
      trafficLimitBytes: clearTrafficLimitBytes
          ? null
          : (trafficLimitBytes ?? this.trafficLimitBytes),
      updateIntervalOverride: clearUpdateIntervalOverride
          ? null
          : (updateIntervalOverride ?? this.updateIntervalOverride),
      hideNaServers: hideNaServers ?? this.hideNaServers,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'updatedAt': updatedAt?.toUtc().millisecondsSinceEpoch,
    'expiresAt': expiresAt?.toUtc().millisecondsSinceEpoch,
    'trafficUsedBytes': trafficUsedBytes,
    'trafficLimitBytes': trafficLimitBytes,
    'updateIntervalOverrideHours': updateIntervalOverride?.hours,
    'hideNaServers': hideNaServers,
    'servers': servers.map((server) => server.toJson()).toList(),
  };

  static ServerSubscription? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final url = json['url'] as String?;
    if (id == null || id.isEmpty || url == null || url.isEmpty) return null;

    final rawServers = json['servers'];
    final servers = rawServers is List
        ? rawServers
              .whereType<Map<String, dynamic>>()
              .map(ServerConfig.fromJson)
              .whereType<ServerConfig>()
              .toList()
        : <ServerConfig>[];
    if (servers.isEmpty) return null;

    final updatedAtMillis = json['updatedAt'];
    final updatedAt = updatedAtMillis is int
        ? DateTime.fromMillisecondsSinceEpoch(updatedAtMillis, isUtc: true)
        : null;
    final expiresAtMillis = json['expiresAt'];
    final expiresAt = expiresAtMillis is int
        ? DateTime.fromMillisecondsSinceEpoch(expiresAtMillis, isUtc: true)
        : null;
    final trafficUsedBytes = _nonNegativeInt(json['trafficUsedBytes']);
    final trafficLimitBytes = _positiveInt(json['trafficLimitBytes']);
    final updateIntervalOverride = SubscriptionUpdateInterval.tryParse(
      json['updateIntervalOverrideHours'] ?? json['updateIntervalOverride'],
    );
    final hideNaServers = json['hideNaServers'] == true;

    return ServerSubscription(
      id: id,
      name: (name == null || name.trim().isEmpty)
          ? _fallbackNameFromUrl(url)
          : name.trim(),
      url: url,
      servers: List.unmodifiable(servers),
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      trafficUsedBytes: trafficUsedBytes,
      trafficLimitBytes: trafficLimitBytes,
      updateIntervalOverride: updateIntervalOverride,
      hideNaServers: hideNaServers,
    );
  }

  static List<ServerSubscription> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = decodeJson(raw, maxBytes: JsonPayloadLimits.serverCatalog);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ServerSubscription.fromJson)
          .whereType<ServerSubscription>()
          .toList();
    } on FormatException {
      return const [];
    } on JsonPayloadTooLargeException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  static String encodeList(List<ServerSubscription> subscriptions) {
    return jsonEncode(
      subscriptions.map((subscription) => subscription.toJson()).toList(),
    );
  }

  static String _fallbackNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.trim();
    if (host != null && host.isNotEmpty) return host;
    return 'Subscription';
  }

  static int? _nonNegativeInt(Object? raw) {
    final value = raw is int ? raw : null;
    if (value == null || value < 0) return null;
    return value;
  }

  static int? _positiveInt(Object? raw) {
    final value = _nonNegativeInt(raw);
    if (value == null || value <= 0) return null;
    return value;
  }
}
