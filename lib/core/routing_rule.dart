import 'dart:convert';
import 'dart:math';

enum RoutingOutbound {
  proxy,
  direct,
  block;

  String get wireName => switch (this) {
    RoutingOutbound.proxy => 'proxy',
    RoutingOutbound.direct => 'direct',
    RoutingOutbound.block => 'block',
  };

  String get displayName => switch (this) {
    RoutingOutbound.proxy => 'Proxy',
    RoutingOutbound.direct => 'Direct',
    RoutingOutbound.block => 'Block',
  };

  static RoutingOutbound parse(String? raw) {
    final lowered = raw?.trim().toLowerCase() ?? '';
    return switch (lowered) {
      'proxy' || 'проксируемое' || 'proxied' => RoutingOutbound.proxy,
      'direct' || 'прямое' || 'freedom' => RoutingOutbound.direct,
      'block' || 'блок' || 'reject' || 'blackhole' => RoutingOutbound.block,
      _ => RoutingOutbound.proxy,
    };
  }
}

/// User-authored routing rule. Mirrors the Xray "field" rule schema closely so
/// imported configs round-trip without lossy translation.
class RoutingRule {
  RoutingRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.outbound,
    this.domains = const [],
    this.ips = const [],
    this.port = '',
    this.networks = const [],
    this.protocols = const [],
  });

  final String id;
  final String name;
  final bool enabled;
  final RoutingOutbound outbound;
  final List<String> domains;
  final List<String> ips;
  final String port;
  final List<String> networks;
  final List<String> protocols;

  /// True when no actual matcher field is populated. Such rules would match
  /// every flow, so we surface them as a warning in the UI and skip them
  /// when serialising for the native side.
  bool get hasMatcher =>
      domains.isNotEmpty ||
      ips.isNotEmpty ||
      port.trim().isNotEmpty ||
      networks.isNotEmpty ||
      protocols.isNotEmpty;

  RoutingRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    RoutingOutbound? outbound,
    List<String>? domains,
    List<String>? ips,
    String? port,
    List<String>? networks,
    List<String>? protocols,
  }) {
    return RoutingRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      outbound: outbound ?? this.outbound,
      domains: domains ?? this.domains,
      ips: ips ?? this.ips,
      port: port ?? this.port,
      networks: networks ?? this.networks,
      protocols: protocols ?? this.protocols,
    );
  }

  /// Compact storage representation. Internal IDs are preserved so the UI
  /// can remember selection and reorder semantics across sessions.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'outbound': outbound.wireName,
    'domains': domains,
    'ips': ips,
    'port': port,
    'networks': networks,
    'protocols': protocols,
  };

  /// Public, user-facing form. Matches the Xray field-rule schema with a
  /// `__name__` extension that carries the human label round-trip.
  Map<String, dynamic> toExportJson() {
    final out = <String, dynamic>{
      '__name__': name,
      'type': 'field',
      'outboundTag': outbound.wireName,
    };
    if (!enabled) out['enabled'] = false;
    if (domains.isNotEmpty) out['domain'] = domains;
    if (ips.isNotEmpty) out['ip'] = ips;
    if (port.trim().isNotEmpty) out['port'] = port.trim();
    if (networks.isNotEmpty) out['network'] = networks;
    if (protocols.isNotEmpty) out['protocol'] = protocols;
    return out;
  }

  static RoutingRule? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final port = json['port'];
    return RoutingRule(
      id: id,
      name: (json['name'] as String?) ?? 'Rule',
      enabled: (json['enabled'] as bool?) ?? true,
      outbound: RoutingOutbound.parse(json['outbound'] as String?),
      domains: _stringList(json['domains']),
      ips: _stringList(json['ips']),
      port: port == null ? '' : port.toString(),
      networks: _stringList(json['networks']),
      protocols: _stringList(json['protocols']),
    );
  }

  /// Imports a rule from the user-facing format. Accepts both single string
  /// and string list values for `domain`/`ip`/`network`/`protocol` so that
  /// hand-written files don't need to be normalised before import.
  static RoutingRule? fromImportedJson(Map<String, dynamic> json) {
    final outboundRaw =
        (json['outboundTag'] as String?) ?? (json['outbound'] as String?);
    if (outboundRaw == null) return null;
    final type = (json['type'] as String?)?.trim().toLowerCase();
    if (type != null && type.isNotEmpty && type != 'field') return null;
    final port = json['port'];
    final portString = port == null
        ? ''
        : port is num
        ? port.toString()
        : port.toString().trim();
    return RoutingRule(
      id: _newId(),
      name:
          (json['__name__'] as String?) ??
          (json['name'] as String?) ??
          'Imported rule',
      enabled: (json['enabled'] as bool?) ?? true,
      outbound: RoutingOutbound.parse(outboundRaw),
      domains: _stringList(json['domain']),
      ips: _stringList(json['ip']),
      port: portString,
      networks: _stringList(json['network']),
      protocols: _stringList(json['protocol']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      return [trimmed];
    }
    if (value is List) {
      return value
          .whereType<Object>()
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static String encodeListForStorage(List<RoutingRule> rules) =>
      jsonEncode(rules.map((r) => r.toJson()).toList());

  static List<RoutingRule> decodeListFromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = _tryDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map(RoutingRule.fromJson)
        .whereType<RoutingRule>()
        .toList();
  }

  /// Renders the entire rule set as the user-facing export string.
  static String exportRulesToJsonString(List<RoutingRule> rules) {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'rules': rules.map((r) => r.toExportJson()).toList(),
    });
  }

  /// Reads a user-facing JSON document. Accepts either the wrapping
  /// `{ "rules": [...] }` form (the file format the user supplied) or a
  /// bare array of field rules.
  static List<RoutingRule> importRulesFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map ? decoded['rules'] : decoded;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map(RoutingRule.fromImportedJson)
        .whereType<RoutingRule>()
        .toList();
  }

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static String _newId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(0x100));
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final tail = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$stamp-$tail';
  }

  /// Mints an empty rule with sensible defaults. Centralising id generation
  /// here keeps the ad-hoc "new rule" path off the UI layer.
  static RoutingRule fresh() {
    return RoutingRule(
      id: _newId(),
      name: '',
      enabled: true,
      outbound: RoutingOutbound.proxy,
    );
  }
}
