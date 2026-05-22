import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class InstalledApp {
  const InstalledApp({
    required this.name,
    required this.packageName,
    required this.isSystem,
    required this.iconPng,
  });

  final String name;
  final String packageName;
  final bool isSystem;
  final Uint8List iconPng;

  static InstalledApp? fromMap(Map<dynamic, dynamic> raw) {
    final packageName = raw['packageName'] as String?;
    if (packageName == null || packageName.isEmpty) return null;
    final name = raw['name'] as String? ?? packageName;
    final isSystem = raw['isSystem'] as bool? ?? false;
    final iconPng = raw['iconPng'];
    final bytes = iconPng is Uint8List
        ? iconPng
        : (iconPng is List<int> ? Uint8List.fromList(iconPng) : Uint8List(0));
    return InstalledApp(
      name: name,
      packageName: packageName,
      isSystem: isSystem,
      iconPng: bytes,
    );
  }
}

class InstalledAppsBridge {
  const InstalledAppsBridge();

  static const MethodChannel _channel = MethodChannel(
    'org.voidtunnel.vpn/service',
  );
  static final Map<String, Uint8List> _iconCache = <String, Uint8List>{};
  static final Map<String, Future<Uint8List>> _iconFutureCache =
      <String, Future<Uint8List>>{};

  Future<List<InstalledApp>> list() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listInstalledApps');
    if (raw == null) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(InstalledApp.fromMap)
        .whereType<InstalledApp>()
        .toList();
  }

  /// Names-only view over the installed apps list. Returns `null` when the
  /// platform doesn't expose installed apps (non-Android) so callers can skip
  /// filtering instead of treating "no apps" as "drop everything".
  Future<Set<String>?> listPackageNames() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'listInstalledApps',
      );
      if (raw == null) return null;
      final names = <String>{};
      for (final entry in raw) {
        if (entry is Map) {
          final packageName = entry['packageName'];
          if (packageName is String && packageName.isNotEmpty) {
            names.add(packageName);
          }
        }
      }
      // Empty result on a real device only happens on PackageManager failure;
      // treat that as "unknown" rather than "all apps missing".
      if (names.isEmpty) return null;
      return names;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Uint8List> iconPng(String packageName) {
    final cached = _iconCache[packageName];
    if (cached != null) return SynchronousFuture(cached);
    return _iconFutureCache.putIfAbsent(packageName, () async {
      try {
        final raw = await _channel.invokeMethod<Uint8List>(
          'getInstalledAppIcon',
          packageName,
        );
        final icon = raw ?? Uint8List(0);
        _iconCache[packageName] = icon;
        return icon;
      } finally {
        _iconFutureCache.remove(packageName);
      }
    });
  }
}

List<InstalledApp> prioritizeSelectedInstalledApps(
  Iterable<InstalledApp> apps,
  Set<String> selectedPackages,
) {
  if (selectedPackages.isEmpty) return apps.toList();

  final selected = <InstalledApp>[];
  final rest = <InstalledApp>[];
  for (final app in apps) {
    final target = selectedPackages.contains(app.packageName) ? selected : rest;
    target.add(app);
  }
  return [...selected, ...rest];
}
