import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/libbox_version_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.voidlex.vpn/service');
  const bridge = LibboxVersionBridge();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the version reported by the packaged libbox core', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getLibboxVersion');
          return ' 1.14.0 ';
        });

    expect(await bridge.getVersion(), '1.14.0');
  });

  test('returns an empty value when native returns no version', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    expect(await bridge.getVersion(), isEmpty);
  });
}
