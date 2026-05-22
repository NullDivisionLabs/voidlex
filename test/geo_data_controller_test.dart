import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidtunnel/core/geo_data.dart';
import 'package:voidtunnel/core/server_repository.dart';
import 'package:voidtunnel/core/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidtunnel.vpn/service');
  const stateChannel = MethodChannel('org.voidtunnel.vpn/state');

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
}

class _FakeGeoDataBridge extends GeoDataBridge {
  final _progress = StreamController<GeoDataDownloadProgress>.broadcast();
  final _download = Completer<GeoDataNativeStatus>();

  @override
  Future<GeoDataNativeStatus> download({
    required GeoDataKind kind,
    required String url,
  }) {
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
