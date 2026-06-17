import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/deep_link_channel.dart';
import 'package:voidlex/core/pending_deep_link.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidlex.vpn/service');
  const stateChannel = MethodChannel('org.voidlex.vpn/state');
  const validUuid = 'f1cba4a1-1f16-4176-9c71-d7508ccd4db1';
  const serverLink =
      'vless://$validUuid@example.net:443?type=tcp&security=tls&sni=example.net#Imported';

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
    'incoming import deep link waits for consent before adding a server',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      final channel = _StreamDeepLinkChannel();
      final controller = VpnController(repository, deepLinkChannel: channel);
      await controller.bootstrap();

      channel.emit(serverLink);
      await _settle();

      // The link must not mutate state on its own.
      expect(controller.servers, isEmpty);
      final pending = controller.pendingDeepLink;
      expect(pending, isNotNull);
      expect(pending!.kind, DeepLinkActionKind.importSubscription);
      expect(pending.displayUrl, serverLink);

      await controller.confirmPendingDeepLink();
      await _settle();

      expect(controller.pendingDeepLink, isNull);
      expect(controller.servers.length, 1);

      await channel.close();
      controller.dispose();
    },
  );

  test('rejecting a deep link discards it without importing', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final channel = _StreamDeepLinkChannel();
    final controller = VpnController(repository, deepLinkChannel: channel);
    await controller.bootstrap();

    channel.emit(serverLink);
    await _settle();
    expect(controller.pendingDeepLink, isNotNull);

    controller.cancelPendingDeepLink();
    await _settle();

    expect(controller.pendingDeepLink, isNull);
    expect(controller.servers, isEmpty);

    await channel.close();
    controller.dispose();
  });

  test('http ruleset deep link is flagged as insecure', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);
    final channel = _StreamDeepLinkChannel();
    final controller = VpnController(repository, deepLinkChannel: channel);
    await controller.bootstrap();

    channel.emit('voidlex://import-ruleset/http://rules.example.com/r.json');
    await _settle();

    final pending = controller.pendingDeepLink;
    expect(pending, isNotNull);
    expect(pending!.kind, DeepLinkActionKind.importRuleset);
    expect(pending.isInsecureHttp, isTrue);

    controller.cancelPendingDeepLink();
    await channel.close();
    controller.dispose();
  });
}

/// Lets a test push links onto [VpnController]'s incoming-link stream.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _StreamDeepLinkChannel extends DeepLinkChannel {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  void emit(String url) => _controller.add(url);

  Future<void> close() => _controller.close();

  @override
  Future<String?> consumeInitial() async => null;

  @override
  Stream<String> get incomingLinks => _controller.stream;
}
