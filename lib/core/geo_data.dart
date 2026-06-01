import 'package:flutter/services.dart';

enum GeoDataKind {
  geoip,
  geosite;

  String get wireName => switch (this) {
    GeoDataKind.geoip => 'geoip',
    GeoDataKind.geosite => 'geosite',
  };

  String get fileName => '$wireName.dat';

  String get displayName => fileName;

  static GeoDataKind? parse(String? raw) {
    for (final kind in GeoDataKind.values) {
      if (kind.wireName == raw) return kind;
    }
    return null;
  }
}

enum GeoDataSource {
  unknown,
  bundled,
  url,
  device;

  String get wireName => switch (this) {
    GeoDataSource.unknown => 'unknown',
    GeoDataSource.bundled => 'bundled',
    GeoDataSource.url => 'url',
    GeoDataSource.device => 'device',
  };

  String get displayName => switch (this) {
    GeoDataSource.unknown => 'Unknown',
    GeoDataSource.bundled => 'Bundled',
    GeoDataSource.url => 'URL',
    GeoDataSource.device => 'Device',
  };

  static GeoDataSource parse(String? raw) {
    return GeoDataSource.values.firstWhere(
      (source) => source.wireName == raw,
      orElse: () => GeoDataSource.unknown,
    );
  }
}

class GeoDataMetadata {
  const GeoDataMetadata({
    required this.source,
    this.url,
    this.updatedAt,
    this.fileSize = 0,
  });

  final GeoDataSource source;
  final String? url;
  final DateTime? updatedAt;
  final int fileSize;

  bool get isEmpty =>
      source == GeoDataSource.unknown &&
      (url == null || url!.isEmpty) &&
      updatedAt == null &&
      fileSize <= 0;

  GeoDataMetadata copyWith({
    GeoDataSource? source,
    String? url,
    bool clearUrl = false,
    DateTime? updatedAt,
    int? fileSize,
  }) {
    return GeoDataMetadata(
      source: source ?? this.source,
      url: clearUrl ? null : url ?? this.url,
      updatedAt: updatedAt ?? this.updatedAt,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}

class GeoDataNativeStatus {
  const GeoDataNativeStatus({
    required this.kind,
    required this.installed,
    required this.fileSize,
    required this.modifiedAt,
  });

  final GeoDataKind kind;
  final bool installed;
  final int fileSize;
  final DateTime? modifiedAt;

  static GeoDataNativeStatus? fromNative(Map<dynamic, dynamic> raw) {
    final kind = GeoDataKind.parse(raw['kind'] as String?);
    if (kind == null) return null;

    final modifiedAtMillis = _readInt(raw['modifiedAtMillis']);
    return GeoDataNativeStatus(
      kind: kind,
      installed: raw['installed'] == true,
      fileSize: _readInt(raw['fileSize']),
      modifiedAt: modifiedAtMillis <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modifiedAtMillis, isUtc: true),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class GeoDataFileStatus {
  const GeoDataFileStatus({
    required this.kind,
    required this.installed,
    required this.fileSize,
    required this.updatedAt,
    required this.source,
    required this.savedUrl,
  });

  final GeoDataKind kind;
  final bool installed;
  final int fileSize;
  final DateTime? updatedAt;
  final GeoDataSource source;
  final String? savedUrl;

  String get fileName => kind.fileName;
}

class GeoDataDownloadProgress {
  const GeoDataDownloadProgress({required this.kind, required this.percent});

  final GeoDataKind kind;

  /// Null means indeterminate (Content-Length unknown); otherwise 0–100.
  final int? percent;

  static GeoDataDownloadProgress? fromNative(dynamic raw) {
    if (raw is! Map) return null;
    final kind = GeoDataKind.parse(raw['kind'] as String?);
    if (kind == null) return null;
    final raw_ = _readInt(raw['percent']);
    final int? percent = raw_ < 0 ? null : raw_.clamp(0, 100);
    return GeoDataDownloadProgress(kind: kind, percent: percent);
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class GeoDataBridge {
  const GeoDataBridge();

  static const MethodChannel _channel = MethodChannel(
    'org.voidlex.vpn/service',
  );
  static const EventChannel _progressChannel = EventChannel(
    'org.voidlex.vpn/geodata_progress',
  );

  Future<List<GeoDataNativeStatus>> getStatus() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getGeoDataStatus');
    return (raw ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(GeoDataNativeStatus.fromNative)
        .whereType<GeoDataNativeStatus>()
        .toList(growable: false);
  }

  Future<GeoDataNativeStatus> download({
    required GeoDataKind kind,
    required String url,
  }) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'downloadGeoDataFile',
      {'kind': kind.wireName, 'url': url},
    );
    final status = raw == null ? null : GeoDataNativeStatus.fromNative(raw);
    if (status == null) {
      throw const FormatException('Native geodata status is invalid.');
    }
    return status;
  }

  Future<GeoDataNativeStatus?> pick(GeoDataKind kind) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'pickGeoDataFile',
      {'kind': kind.wireName},
    );
    return raw == null ? null : GeoDataNativeStatus.fromNative(raw);
  }

  Stream<GeoDataDownloadProgress> downloadProgressStream() {
    return _progressChannel
        .receiveBroadcastStream()
        .map(GeoDataDownloadProgress.fromNative)
        .where((event) => event != null)
        .cast<GeoDataDownloadProgress>();
  }
}
