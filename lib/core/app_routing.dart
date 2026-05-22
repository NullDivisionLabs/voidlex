import 'dart:convert';

enum AppRoutingMode {
  off,
  proxy,
  bypass;

  String get wireName => switch (this) {
    AppRoutingMode.off => 'off',
    AppRoutingMode.proxy => 'proxy',
    AppRoutingMode.bypass => 'bypass',
  };

  static AppRoutingMode parse(String? raw) {
    for (final mode in AppRoutingMode.values) {
      if (mode.wireName == raw) return mode;
    }
    return AppRoutingMode.off;
  }
}

class AppRoutingPolicy {
  const AppRoutingPolicy({
    required this.mode,
    this.proxyPackages = const <String>{},
    this.bypassPackages = const <String>{},
  });

  final AppRoutingMode mode;
  final Set<String> proxyPackages;
  final Set<String> bypassPackages;

  static const empty = AppRoutingPolicy(mode: AppRoutingMode.off);

  factory AppRoutingPolicy.legacy({
    required AppRoutingMode mode,
    required Set<String> packages,
  }) {
    return AppRoutingPolicy(
      mode: mode,
      proxyPackages: mode == AppRoutingMode.proxy ? packages : const <String>{},
      bypassPackages: mode == AppRoutingMode.bypass
          ? packages
          : const <String>{},
    );
  }

  Set<String> get packages => packagesForMode(mode);

  Set<String> packagesForMode(AppRoutingMode mode) {
    return switch (mode) {
      AppRoutingMode.proxy => proxyPackages,
      AppRoutingMode.bypass => bypassPackages,
      AppRoutingMode.off => const <String>{},
    };
  }

  AppRoutingPolicy copyWith({
    AppRoutingMode? mode,
    Set<String>? proxyPackages,
    Set<String>? bypassPackages,
  }) {
    return AppRoutingPolicy(
      mode: mode ?? this.mode,
      proxyPackages: proxyPackages ?? this.proxyPackages,
      bypassPackages: bypassPackages ?? this.bypassPackages,
    );
  }

  bool hasSameConfiguration(AppRoutingPolicy other) {
    return mode == other.mode &&
        _setEquals(proxyPackages, other.proxyPackages) &&
        _setEquals(bypassPackages, other.bypassPackages);
  }

  /// True when the policy actually constrains routing for the running tunnel.
  /// Used to decide whether the active connection has to be restarted after
  /// a settings change.
  bool get isActive =>
      mode != AppRoutingMode.off &&
      (mode == AppRoutingMode.bypass || packages.isNotEmpty);

  static String encodePackages(Set<String> packages) =>
      jsonEncode(packages.toList());

  static Set<String> decodePackages(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <String>{};
    }
    if (decoded is! List) return <String>{};
    return decoded.whereType<String>().toSet();
  }

  static bool _setEquals(Set<String> first, Set<String> second) {
    return first.length == second.length && first.containsAll(second);
  }
}
