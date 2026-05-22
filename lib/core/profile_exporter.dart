import 'dart:convert';

import 'models/server_config.dart';
import 'models/server_subscription.dart';
import 'routing_preset.dart';

class ProfileExporter {
  const ProfileExporter._();

  static const format = 'voidtunnel.profile';
  // v1 (subscriptions cleared when protected) → v2 (encrypted
  // protectedSubscriptions field carries the originals). Bump invalidates no
  // imports: a v2 reader can still consume v1 files.
  static const version = 2;

  static String exportJson({
    required List<ServerConfig> manualNodes,
    required List<ServerSubscription> subscriptions,
    required List<RoutingPreset> routingPresets,
    required String selectedRoutingPresetId,
    required bool protectSubscriptions,
    List<String> protectedSubscriptionLinks = const <String>[],
    DateTime? exportedAt,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      toJson(
        manualNodes: manualNodes,
        subscriptions: subscriptions,
        routingPresets: routingPresets,
        selectedRoutingPresetId: selectedRoutingPresetId,
        protectSubscriptions: protectSubscriptions,
        protectedSubscriptionLinks: protectedSubscriptionLinks,
        exportedAt: exportedAt,
      ),
    );
  }

  static Map<String, dynamic> toJson({
    required List<ServerConfig> manualNodes,
    required List<ServerSubscription> subscriptions,
    required List<RoutingPreset> routingPresets,
    required String selectedRoutingPresetId,
    required bool protectSubscriptions,
    List<String> protectedSubscriptionLinks = const <String>[],
    DateTime? exportedAt,
  }) {
    final exportedManualNodes = manualNodes
        .map(_serverToProfileJson)
        .toList(growable: false);
    final exportedSubscriptions = protectSubscriptions
        ? const <Map<String, dynamic>>[]
        : subscriptions.map(_subscriptionToProfileJson).toList(growable: false);
    final manualNames = manualNodes
        .map((server) => RoutingPreset.normalizeServerName(server.name))
        .whereType<String>()
        .toSet();
    final exportedPresets = routingPresets
        .map(
          (preset) => _presetToProfileJson(
            preset,
            protectSubscriptions: protectSubscriptions,
            allowedServerNames: manualNames,
          ),
        )
        .toList(growable: false);

    return {
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'profile': {
        'manualNodes': exportedManualNodes,
        'subscriptions': exportedSubscriptions,
        if (protectSubscriptions)
          'protectedSubscriptions': List<String>.unmodifiable(
            protectedSubscriptionLinks,
          ),
        'routingPresets': exportedPresets,
        'selectedRoutingPresetId': selectedRoutingPresetId,
      },
    };
  }

  static Map<String, dynamic> _serverToProfileJson(ServerConfig server) {
    final json = Map<String, dynamic>.of(server.toJson());
    json.remove('isPinned');
    json.remove('ping');
    return json;
  }

  static Map<String, dynamic> _subscriptionToProfileJson(
    ServerSubscription subscription,
  ) {
    final json = Map<String, dynamic>.of(subscription.toJson());
    json['servers'] = subscription.servers
        .map(_serverToProfileJson)
        .toList(growable: false);
    return json;
  }

  static Map<String, dynamic> _presetToProfileJson(
    RoutingPreset preset, {
    required bool protectSubscriptions,
    required Set<String> allowedServerNames,
  }) {
    final exportPreset = protectSubscriptions
        ? preset.copyWith(
            serverNames: preset.serverNames
                .where(allowedServerNames.contains)
                .toSet(),
          )
        : preset;
    return exportPreset.normalized().toJson();
  }
}
