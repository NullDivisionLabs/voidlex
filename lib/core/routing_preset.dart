import 'dart:convert';

import 'bounded_json.dart';
import 'dart:math';

import 'app_routing.dart';
import 'routing_rule.dart';

class RoutingPreset {
  RoutingPreset({
    required this.id,
    required this.name,
    required this.appRoutingPolicy,
    required this.routingRules,
    this.serverNames = const <String>{},
  });

  static const mainId = 'main';
  static const mainName = 'Main';

  final String id;
  final String name;
  final AppRoutingPolicy appRoutingPolicy;
  final List<RoutingRule> routingRules;

  /// Main is the default for every saved server. Other presets apply only
  /// when their server list explicitly contains the node.
  final Set<String> serverNames;

  bool get isMain => id == mainId;
  bool get appliesToAllServers => isMain;

  bool appliesToServer(String? serverName) {
    final normalizedServerName = normalizeServerName(serverName);
    return isMain ||
        (normalizedServerName != null &&
            serverNames.contains(normalizedServerName));
  }

  RoutingPreset copyWith({
    String? name,
    AppRoutingPolicy? appRoutingPolicy,
    List<RoutingRule>? routingRules,
    Set<String>? serverNames,
  }) {
    return RoutingPreset(
      id: id,
      name: name ?? this.name,
      appRoutingPolicy: appRoutingPolicy ?? this.appRoutingPolicy,
      routingRules: routingRules ?? this.routingRules,
      serverNames: serverNames ?? this.serverNames,
    );
  }

  RoutingPreset normalized() {
    final normalizedName = isMain ? mainName : name.trim();
    return copyWith(
      name: normalizedName.isEmpty ? 'Preset' : normalizedName,
      routingRules: List<RoutingRule>.of(routingRules),
      serverNames: _cleanStringSet(serverNames),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': isMain ? mainName : name,
    'appRoutingMode': appRoutingPolicy.mode.wireName,
    'appRoutingPackages': appRoutingPolicy.packages.toList(),
    'appRoutingProxyPackages': appRoutingPolicy.proxyPackages.toList(),
    'appRoutingBypassPackages': appRoutingPolicy.bypassPackages.toList(),
    'routingRules': routingRules.map((rule) => rule.toJson()).toList(),
    'serverNames': serverNames.toList(),
  };

  static RoutingPreset main({
    AppRoutingPolicy appRoutingPolicy = AppRoutingPolicy.empty,
    List<RoutingRule> routingRules = const [],
  }) {
    return RoutingPreset(
      id: mainId,
      name: mainName,
      appRoutingPolicy: appRoutingPolicy,
      routingRules: List<RoutingRule>.of(routingRules),
    );
  }

  static RoutingPreset fresh(String name) {
    return RoutingPreset(
      id: _newId(),
      name: name.trim(),
      appRoutingPolicy: AppRoutingPolicy.empty,
      routingRules: const [],
    );
  }

  static RoutingPreset? fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] as String?;
    final id = rawId?.trim();
    if (id == null || id.isEmpty) return null;

    final mode = AppRoutingMode.parse(json['appRoutingMode'] as String?);
    final legacyPackages = _cleanStringSet(
      _listLike(json['appRoutingPackages']),
    );
    final hasSplitPackages =
        json.containsKey('appRoutingProxyPackages') ||
        json.containsKey('appRoutingBypassPackages');
    final appRoutingPolicy = hasSplitPackages
        ? AppRoutingPolicy(
            mode: mode,
            proxyPackages: _cleanStringSet(
              _listLike(json['appRoutingProxyPackages']),
            ),
            bypassPackages: _cleanStringSet(
              _listLike(json['appRoutingBypassPackages']),
            ),
          )
        : AppRoutingPolicy.legacy(mode: mode, packages: legacyPackages);
    final rules = _decodeRules(json['routingRules']);
    final name = id == mainId
        ? mainName
        : ((json['name'] as String?) ?? 'Preset');

    return RoutingPreset(
      id: id,
      name: name,
      appRoutingPolicy: appRoutingPolicy,
      routingRules: rules,
      serverNames: _cleanStringSet(_listLike(json['serverNames'])),
    ).normalized();
  }

  static String encodeList(List<RoutingPreset> presets) {
    return jsonEncode(
      presets.map((preset) => preset.normalized().toJson()).toList(),
    );
  }

  static List<RoutingPreset> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = decodeJson(raw, maxBytes: JsonPayloadLimits.routingDocument);
    } on FormatException {
      return const [];
    } on JsonPayloadTooLargeException {
      return const [];
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map(RoutingPreset.fromJson)
        .whereType<RoutingPreset>()
        .toList();
  }

  static List<RoutingRule> _decodeRules(Object? value) {
    if (value is String) {
      return RoutingRule.decodeListFromStorage(value);
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map(RoutingRule.fromJson)
        .whereType<RoutingRule>()
        .toList();
  }

  static Iterable<String> _listLike(Object? value) {
    if (value is List) {
      return value.whereType<Object>().map((e) => e.toString());
    }
    if (value is Set) return value.whereType<Object>().map((e) => e.toString());
    return const <String>[];
  }

  static Set<String> _cleanStringSet(Iterable<String> values) {
    return values
        .map(normalizeServerName)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static String? normalizeServerName(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static Set<String> cleanServerNames(Iterable<String> values) {
    return values
        .map(normalizeServerName)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static String _newId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(0x100));
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final tail = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'preset-$stamp-$tail';
  }
}
