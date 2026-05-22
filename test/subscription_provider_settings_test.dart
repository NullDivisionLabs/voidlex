import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidtunnel/core/models/server_config.dart';
import 'package:voidtunnel/core/models/server_subscription.dart';
import 'package:voidtunnel/core/server_repository.dart';
import 'package:voidtunnel/core/subscription_provider_settings.dart';
import 'package:voidtunnel/core/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses protected provider defaults', () {
    const defaults = SubscriptionProviderSettings.defaults;

    expect(defaults.pingOnUpdate, isTrue);
    expect(defaults.sendHwid, isTrue);
    expect(defaults.protectSubscriptions, isTrue);
    expect(defaults.updateOnLaunch, isFalse);
    expect(defaults.allowInsecureTls, isFalse);
  });

  test('encodes and decodes subscription provider settings', () {
    const settings = SubscriptionProviderSettings(
      updateInterval: SubscriptionUpdateInterval.threeHours,
      pingOnUpdate: true,
      updateOnLaunch: true,
      sendHwid: true,
      allowInsecureTls: true,
      protectSubscriptions: true,
    );

    final decoded = SubscriptionProviderSettings.decode(settings.encode());

    expect(decoded.updateInterval, SubscriptionUpdateInterval.threeHours);
    expect(decoded.updateInterval.duration, const Duration(hours: 3));
    expect(decoded.pingOnUpdate, isTrue);
    expect(decoded.updateOnLaunch, isTrue);
    expect(decoded.sendHwid, isTrue);
    expect(decoded.allowInsecureTls, isTrue);
    expect(decoded.protectSubscriptions, isTrue);
  });

  test('falls back to defaults for unsupported interval values', () {
    final decoded = SubscriptionProviderSettings.decode(
      '{"updateIntervalHours":2,"pingOnUpdate":true}',
    );

    expect(
      decoded.updateInterval,
      SubscriptionProviderSettings.defaults.updateInterval,
    );
    expect(decoded.pingOnUpdate, isTrue);
  });

  test('encodes nullable per-subscription update interval override', () {
    final encoded = ServerSubscription.encodeList([
      _subscription(
        updateIntervalOverride: SubscriptionUpdateInterval.threeHours,
      ),
    ]);

    final decoded = ServerSubscription.decodeList(encoded).single;

    expect(
      decoded.updateIntervalOverride,
      SubscriptionUpdateInterval.threeHours,
    );
    expect(
      ServerSubscription.fromJson({
        'id': 'sub-1',
        'name': 'Provider',
        'url': 'https://provider.example.com/sub',
        'updateIntervalOverrideHours': 2,
        'servers': [_server().toJson()],
      })!.updateIntervalOverride,
      isNull,
    );
  });

  test(
    'uses subscription update interval override before global interval',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs);
      await repository.saveSubscriptionProviderSettings(
        const SubscriptionProviderSettings(
          updateInterval: SubscriptionUpdateInterval.twelveHours,
        ),
      );
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final inherited = _subscription(
        id: 'inherited',
        updatedAt: now.subtract(const Duration(hours: 7)),
      );
      final overridden = _subscription(
        id: 'overridden',
        updatedAt: now.subtract(const Duration(minutes: 30)),
        updateIntervalOverride: SubscriptionUpdateInterval.oneHour,
      );
      await repository.saveSubscriptions([inherited, overridden]);

      final controller = VpnController(repository);
      addTearDown(controller.dispose);
      await controller.bootstrap();

      expect(
        controller.effectiveSubscriptionUpdateIntervalForTesting(inherited),
        SubscriptionUpdateInterval.twelveHours,
      );
      expect(
        controller.effectiveSubscriptionUpdateIntervalForTesting(overridden),
        SubscriptionUpdateInterval.oneHour,
      );
      expect(
        controller.isSubscriptionAutoRefreshDueForTesting(inherited, now),
        isFalse,
      );
      expect(
        controller.isSubscriptionAutoRefreshDueForTesting(
          overridden.copyWith(
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
          now,
        ),
        isTrue,
      );
      expect(
        controller.nextSubscriptionAutoRefreshDelayForTesting(now),
        const Duration(minutes: 30),
      );

      await controller.setSubscriptionProviderSettings(
        const SubscriptionProviderSettings(
          updateInterval: SubscriptionUpdateInterval.oneHour,
        ),
      );

      final persistedOverride = repository.load().subscriptions.firstWhere(
        (subscription) => subscription.id == 'overridden',
      );
      expect(
        persistedOverride.updateIntervalOverride,
        SubscriptionUpdateInterval.oneHour,
      );
    },
  );
}

ServerSubscription _subscription({
  String id = 'sub-1',
  DateTime? updatedAt,
  SubscriptionUpdateInterval? updateIntervalOverride,
}) {
  return ServerSubscription(
    id: id,
    name: 'Provider',
    url: 'https://provider.example.com/sub',
    servers: [_server()],
    updatedAt: updatedAt,
    updateIntervalOverride: updateIntervalOverride,
  );
}

ServerConfig _server() {
  return ServerConfig(
    name: 'Sub A',
    address: 'sub-a.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
  );
}
