import 'bounded_json.dart';
import 'models/server_config.dart';
import 'models/server_subscription.dart';
import 'profile_exporter.dart';
import 'routing_preset.dart';

enum ProfileImportError {
  empty,
  invalidJson,
  payloadTooLarge,
  unsupportedFormat,
  unsupportedVersion,
  emptyProfile,
}

class ProfileImportException implements Exception {
  const ProfileImportException(this.code, this.message);

  final ProfileImportError code;
  final String message;

  @override
  String toString() => 'ProfileImportException($code): $message';
}

class ProfileImportPayload {
  const ProfileImportPayload({
    required this.manualNodes,
    required this.subscriptions,
    required this.protectedSubscriptionLinks,
    required this.routingPresets,
    required this.selectedRoutingPresetId,
  });

  final List<ServerConfig> manualNodes;
  final List<ServerSubscription> subscriptions;
  final List<String> protectedSubscriptionLinks;
  final List<RoutingPreset> routingPresets;
  final String? selectedRoutingPresetId;

  bool get hasData =>
      manualNodes.isNotEmpty ||
      subscriptions.isNotEmpty ||
      protectedSubscriptionLinks.isNotEmpty ||
      routingPresets.isNotEmpty;

  static ProfileImportPayload parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const ProfileImportException(
        ProfileImportError.empty,
        'Profile file is empty',
      );
    }

    final Object? decoded;
    try {
      decoded = decodeJson(trimmed, maxBytes: JsonPayloadLimits.profile);
    } on JsonPayloadTooLargeException {
      throw const ProfileImportException(
        ProfileImportError.payloadTooLarge,
        'Profile file is too large',
      );
    } on FormatException catch (e) {
      throw ProfileImportException(ProfileImportError.invalidJson, e.message);
    }

    final root = _stringMap(decoded);
    if (root == null || root['format'] != ProfileExporter.format) {
      throw const ProfileImportException(
        ProfileImportError.unsupportedFormat,
        'File is not a Void//Lex profile',
      );
    }

    final version = root['version'];
    if (version is! int || version < 1 || version > ProfileExporter.version) {
      throw ProfileImportException(
        ProfileImportError.unsupportedVersion,
        'Unsupported profile version: $version',
      );
    }

    final profile = _stringMap(root['profile']);
    if (profile == null) {
      throw const ProfileImportException(
        ProfileImportError.unsupportedFormat,
        'Profile payload is missing',
      );
    }

    final payload = ProfileImportPayload(
      manualNodes: _decodeServers(profile['manualNodes']),
      subscriptions: _decodeSubscriptions(profile['subscriptions']),
      protectedSubscriptionLinks: _decodeStringList(
        profile['protectedSubscriptions'],
      ),
      routingPresets: _decodePresets(profile['routingPresets']),
      selectedRoutingPresetId: profile['selectedRoutingPresetId'] is String
          ? profile['selectedRoutingPresetId'] as String
          : null,
    );
    if (!payload.hasData) {
      throw const ProfileImportException(
        ProfileImportError.emptyProfile,
        'Profile does not contain importable data',
      );
    }
    return payload;
  }

  static List<ServerConfig> _decodeServers(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(_serverFromJson)
        .whereType<ServerConfig>()
        .toList(growable: false);
  }

  static ServerConfig? _serverFromJson(Object? raw) {
    final map = _stringMap(raw);
    if (map == null) return null;
    final server = ServerConfig.fromJson(map);
    return server?.copyWith(isPinned: false, ping: '--');
  }

  static List<ServerSubscription> _decodeSubscriptions(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(_subscriptionFromJson)
        .whereType<ServerSubscription>()
        .toList(growable: false);
  }

  static ServerSubscription? _subscriptionFromJson(Object? raw) {
    final map = _stringMap(raw);
    if (map == null) return null;
    final subscription = ServerSubscription.fromJson(map);
    if (subscription == null) return null;
    return subscription.copyWith(
      servers: List.unmodifiable(
        subscription.servers
            .map((server) => server.copyWith(isPinned: false, ping: '--'))
            .toList(growable: false),
      ),
    );
  }

  static List<RoutingPreset> _decodePresets(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(_stringMap)
        .whereType<Map<String, dynamic>>()
        .map(RoutingPreset.fromJson)
        .whereType<RoutingPreset>()
        .toList(growable: false);
  }

  static List<String> _decodeStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic>? _stringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}

class ProfileImportResult {
  const ProfileImportResult({
    required this.manualNodeCount,
    required this.subscriptionCount,
    required this.routingPresetCount,
    required this.protectedSubscriptionFailureCount,
    required this.droppedAppRoutingPackageCount,
  });

  final int manualNodeCount;
  final int subscriptionCount;
  final int routingPresetCount;
  final int protectedSubscriptionFailureCount;

  /// Number of per-app routing packages that were dropped during import
  /// because the corresponding apps are not installed on this device.
  final int droppedAppRoutingPackageCount;
}
