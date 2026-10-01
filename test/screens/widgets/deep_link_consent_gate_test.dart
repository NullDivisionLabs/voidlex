import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/deep_link_channel.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/widgets/deep_link_consent_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidlex.vpn/service');
  const stateChannel = MethodChannel('org.voidlex.vpn/state');
  const initialLink =
      'vless://f1cba4a1-1f16-4176-9c71-d7508ccd4db1@'
      'example.net:443?type=tcp&security=tls#ColdStart';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, (_) async => null);
    for (final name in ['speed', 'geodata_progress']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('org.voidlex.vpn/$name'),
            (_) async => null,
          );
    }
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, null);
    for (final name in ['speed', 'geodata_progress']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('org.voidlex.vpn/$name'),
            null,
          );
    }
  });

  testWidgets('shows consent that was pending before the UI mounted', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = VpnController(
      ServerRepository(prefs),
      deepLinkChannel: _InitialDeepLinkChannel(initialLink),
    );
    addTearDown(controller.dispose);
    await tester.runAsync(controller.bootstrap);
    expect(controller.pendingDeepLink, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DeepLinkConsentGate(
          controller: controller,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open external link?'), findsOneWidget);
    expect(find.text(initialLink), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.pendingDeepLink, isNull);
  });
}

class _InitialDeepLinkChannel extends DeepLinkChannel {
  _InitialDeepLinkChannel(this.initialLink);

  final String initialLink;

  @override
  Future<String?> consumeInitial() async => initialLink;

  @override
  Stream<String> get incomingLinks => const Stream<String>.empty();
}
