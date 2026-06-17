import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/geo_data.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidlex.vpn/service');
  const stateChannel = MethodChannel('org.voidlex.vpn/state');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, null);
  });

  test(
    'geodata download state is owned by the controller until completion',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      final bridge = _FakeGeoDataBridge();
      final controller = VpnController(repository, geoDataBridge: bridge);
      addTearDown(controller.dispose);
      addTearDown(bridge.dispose);

      final update = controller.updateGeoDataFromUrl(
        kind: GeoDataKind.geoip,
        url: 'https://example.com/geoip.dat',
      );

      expect(controller.isGeoDataBusy(GeoDataKind.geoip), isTrue);
      expect(
        controller.geoDataProgressByKind.containsKey(GeoDataKind.geoip),
        isTrue,
      );

      bridge.emitProgress(
        const GeoDataDownloadProgress(kind: GeoDataKind.geoip, percent: 37),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.geoDataProgressByKind[GeoDataKind.geoip], 37);

      final modifiedAt = DateTime.utc(2026, 5, 20, 12);
      bridge.completeDownload(
        GeoDataNativeStatus(
          kind: GeoDataKind.geoip,
          installed: true,
          fileSize: 1234,
          modifiedAt: modifiedAt,
        ),
      );

      final status = await update;

      expect(status.fileSize, 1234);
      expect(controller.isGeoDataBusy(GeoDataKind.geoip), isFalse);
      expect(
        controller.geoDataProgressByKind.containsKey(GeoDataKind.geoip),
        isFalse,
      );

      final metadata = repository.loadGeoDataMetadata(GeoDataKind.geoip);
      expect(metadata.source, GeoDataSource.url);
      expect(metadata.url, 'https://example.com/geoip.dat');
      expect(metadata.fileSize, 1234);
      expect(metadata.updatedAt, modifiedAt);
    },
  );

  test(
    'geodata auto-update interval defaults to disabled and persists',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);

      expect(
        repository.loadGeoDataAutoUpdateInterval(),
        GeoDataAutoUpdateInterval.disabled,
      );

      await repository.saveGeoDataAutoUpdateInterval(
        GeoDataAutoUpdateInterval.threeDays,
      );

      expect(
        repository.loadGeoDataAutoUpdateInterval(),
        GeoDataAutoUpdateInterval.threeDays,
      );
    },
  );

  test(
    'geodata auto-update due calculation only includes URL sources',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      final now = DateTime.now();
      await repository.saveGeoDataMetadata(
        GeoDataKind.geoip,
        GeoDataMetadata(
          source: GeoDataSource.url,
          url: 'https://example.com/geoip.dat',
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      await repository.saveGeoDataMetadata(
        GeoDataKind.geosite,
        GeoDataMetadata(
          source: GeoDataSource.device,
          url: 'https://example.com/geosite.dat',
          updatedAt: now.subtract(const Duration(days: 10)),
        ),
      );
      final controller = VpnController(repository);
      addTearDown(controller.dispose);

      await controller.setGeoDataAutoUpdateInterval(
        GeoDataAutoUpdateInterval.threeDays,
      );

      expect(
        controller.isGeoDataAutoUpdateDueForTesting(GeoDataKind.geoip, now),
        isFalse,
      );
      expect(
        controller.isGeoDataAutoUpdateDueForTesting(
          GeoDataKind.geoip,
          now.add(const Duration(days: 1)),
        ),
        isTrue,
      );
      expect(
        controller.isGeoDataAutoUpdateDueForTesting(GeoDataKind.geosite, now),
        isFalse,
      );
      final delay = controller.nextGeoDataAutoUpdateDelayForTesting(now);
      expect(delay, isNotNull);
      expect(
        (delay! - const Duration(days: 1)).abs(),
        lessThan(const Duration(milliseconds: 1)),
      );

      await controller.setGeoDataAutoUpdateInterval(
        GeoDataAutoUpdateInterval.disabled,
      );
      expect(
        controller.isGeoDataAutoUpdateDueForTesting(
          GeoDataKind.geoip,
          now.add(const Duration(days: 20)),
        ),
        isFalse,
      );
      expect(controller.nextGeoDataAutoUpdateDelayForTesting(now), isNull);
    },
  );

  test('automatic geodata refresh continues after one file fails', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final bridge = _SequentialGeoDataBridge(failKind: GeoDataKind.geoip);
    final controller = VpnController(repository, geoDataBridge: bridge);
    addTearDown(controller.dispose);
    addTearDown(bridge.dispose);
    await controller.setGeoDataAutoUpdateInterval(
      GeoDataAutoUpdateInterval.oneDay,
    );

    final old = DateTime.now().subtract(const Duration(days: 10));
    for (final kind in GeoDataKind.values) {
      await repository.saveGeoDataMetadata(
        kind,
        GeoDataMetadata(
          source: GeoDataSource.url,
          url: 'https://example.com/${kind.fileName}',
          updatedAt: old,
        ),
      );
    }
    await controller.refreshDueGeoData();

    expect(bridge.downloadedKinds, GeoDataKind.values);
    expect(
      repository
          .loadGeoDataMetadata(GeoDataKind.geoip)
          .updatedAt
          ?.millisecondsSinceEpoch,
      old.millisecondsSinceEpoch,
    );
    expect(
      repository.loadGeoDataMetadata(GeoDataKind.geosite).updatedAt,
      isNot(old),
    );
  });

  test('automatic geodata refresh rejects a parallel second run', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final bridge = _FakeGeoDataBridge();
    final controller = VpnController(repository, geoDataBridge: bridge);
    addTearDown(controller.dispose);
    addTearDown(bridge.dispose);
    await controller.setGeoDataAutoUpdateInterval(
      GeoDataAutoUpdateInterval.oneDay,
    );

    await repository.saveGeoDataMetadata(
      GeoDataKind.geoip,
      GeoDataMetadata(
        source: GeoDataSource.url,
        url: 'https://example.com/geoip.dat',
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );
    final first = controller.refreshDueGeoData();
    await Future<void>.delayed(Duration.zero);
    await controller.refreshDueGeoData();

    bridge.completeDownload(
      GeoDataNativeStatus(
        kind: GeoDataKind.geoip,
        installed: true,
        fileSize: 42,
        modifiedAt: DateTime.now(),
      ),
    );
    await first;

    expect(bridge.downloadCount, 1);
  });

  test('automatic batch refresh restarts an active session once', () async {
    var starts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (call) async {
          switch (call.method) {
            case 'prepareVpn':
              return true;
            case 'startVpn':
              starts++;
              return true;
            default:
              return null;
          }
        });

    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    await repository.saveNotificationPermissionAsked(true);
    await repository.saveSelected('Geo test');
    await repository.saveServers([_server()]);
    final bridge = _SequentialGeoDataBridge();
    final controller = VpnController(repository, geoDataBridge: bridge);
    addTearDown(controller.dispose);
    addTearDown(bridge.dispose);
    await controller.bootstrap();
    await controller.connect();
    expect(starts, 1);

    await controller.setGeoDataAutoUpdateInterval(
      GeoDataAutoUpdateInterval.oneDay,
    );
    final old = DateTime.now().subtract(const Duration(days: 10));
    for (final kind in GeoDataKind.values) {
      await repository.saveGeoDataMetadata(
        kind,
        GeoDataMetadata(
          source: GeoDataSource.url,
          url: 'https://example.com/${kind.fileName}',
          updatedAt: old,
        ),
      );
    }

    await controller.refreshDueGeoData();

    expect(bridge.downloadedKinds, GeoDataKind.values);
    expect(starts, 2);
  });

  test('device import removes a file from automatic updates', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final bridge = _SequentialGeoDataBridge();
    final controller = VpnController(repository, geoDataBridge: bridge);
    addTearDown(controller.dispose);
    addTearDown(bridge.dispose);
    await controller.setGeoDataAutoUpdateInterval(
      GeoDataAutoUpdateInterval.oneDay,
    );
    await repository.saveGeoDataMetadata(
      GeoDataKind.geoip,
      GeoDataMetadata(
        source: GeoDataSource.url,
        url: 'https://example.com/geoip.dat',
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );

    await controller.importGeoDataFromDevice(GeoDataKind.geoip);

    expect(
      repository.loadGeoDataMetadata(GeoDataKind.geoip).source,
      GeoDataSource.device,
    );
    expect(
      controller.isGeoDataAutoUpdateDueForTesting(
        GeoDataKind.geoip,
        DateTime.now().add(const Duration(days: 10)),
      ),
      isFalse,
    );
  });
}

ServerConfig _server() {
  return const ServerConfig(
    name: 'Geo test',
    address: 'geo-test.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
  );
}

class _FakeGeoDataBridge extends GeoDataBridge {
  final _progress = StreamController<GeoDataDownloadProgress>.broadcast();
  final _download = Completer<GeoDataNativeStatus>();
  int downloadCount = 0;

  @override
  Future<GeoDataNativeStatus> download({
    required GeoDataKind kind,
    required String url,
  }) {
    downloadCount++;
    return _download.future;
  }

  @override
  Stream<GeoDataDownloadProgress> downloadProgressStream() {
    return _progress.stream;
  }

  void emitProgress(GeoDataDownloadProgress progress) {
    _progress.add(progress);
  }

  void completeDownload(GeoDataNativeStatus status) {
    _download.complete(status);
  }

  Future<void> dispose() {
    return _progress.close();
  }
}

class _SequentialGeoDataBridge extends GeoDataBridge {
  _SequentialGeoDataBridge({this.failKind});

  final GeoDataKind? failKind;
  final List<GeoDataKind> downloadedKinds = [];
  final _progress = StreamController<GeoDataDownloadProgress>.broadcast();

  @override
  Future<GeoDataNativeStatus> download({
    required GeoDataKind kind,
    required String url,
  }) async {
    downloadedKinds.add(kind);
    if (kind == failKind) {
      throw PlatformException(code: 'DOWNLOAD_FAILED');
    }
    return GeoDataNativeStatus(
      kind: kind,
      installed: true,
      fileSize: 123,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Future<GeoDataNativeStatus?> pick(GeoDataKind kind) async {
    return GeoDataNativeStatus(
      kind: kind,
      installed: true,
      fileSize: 321,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Stream<GeoDataDownloadProgress> downloadProgressStream() {
    return _progress.stream;
  }

  Future<void> dispose() {
    return _progress.close();
  }
}
