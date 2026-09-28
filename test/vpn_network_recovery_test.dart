import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/vpn_controller.dart';

void main() {
  const service = MethodChannel('org.voidlex.vpn/service');
  const events = MethodChannel('org.voidlex.vpn/state');

  testWidgets('offline recovery waits beyond startup timeout and can be stopped', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(service, (call) async {
      calls.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    final prefs = await SharedPreferences.getInstance();
    final controller = VpnController(ServerRepository(prefs));
    await tester.pump();

    Future<void> emit(Map<String, Object> event) async {
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );
      await tester.pump();
    }

    await emit({'state': 'connecting', 'recovering': true});
    expect(controller.isRecoveringNetwork, isTrue);
    await tester.pump(const Duration(minutes: 2));
    expect(controller.connectionState, VpnConnectionState.connecting);
    expect(calls, isNot(contains('stopVpn')));

    await controller.toggleConnection();
    expect(calls, contains('stopVpn'));
    expect(controller.isRecoveringNetwork, isFalse);
    // A queued recovery event must not undo the user's stop request.
    await emit({'state': 'connecting', 'recovering': true});
    await emit({'state': 'connected'});
    expect(controller.connectionState, VpnConnectionState.disconnecting);
    await emit({'state': 'disconnected'});
    expect(controller.connectionState, VpnConnectionState.disconnected);

    controller.dispose();
    await tester.pump();
    messenger.setMockMethodCallHandler(service, null);
    messenger.setMockMethodCallHandler(events, null);
  });
}
