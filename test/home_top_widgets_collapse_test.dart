import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/app_locale.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/models/server_subscription.dart';
import 'package:voidlex/core/pending_deep_link.dart';
import 'package:voidlex/core/server_repository.dart';
import 'package:voidlex/core/subscription_provider_settings.dart';
import 'package:voidlex/core/vpn_controller.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/home_screen.dart';
import 'package:voidlex/screens/widgets/exit_info_bar.dart';
import 'package:voidlex/screens/widgets/global_proxy_pill.dart';
import 'package:voidlex/screens/widgets/status_strip.dart';
import 'package:voidlex/screens/widgets/triangle_hub.dart';
import 'package:voidlex/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('org.voidlex.vpn/service');
  const stateChannel = MethodChannel('org.voidlex.vpn/state');
  const speedChannel = MethodChannel('org.voidlex.vpn/speed');
  const geoDataProgressChannel = MethodChannel(
    'org.voidlex.vpn/geodata_progress',
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (call) async {
          switch (call.method) {
            case 'prepareVpn':
              return true;
            case 'startVpn':
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speedChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geoDataProgressChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(stateChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speedChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geoDataProgressChannel, null);
  });

  testWidgets('home top widgets collapse and expand', (tester) async {
    final controller = await _buildController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-top-expanded')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-top-collapsed')), findsNothing);
    expect(find.byKey(const ValueKey('home-triangle-hub')), findsOneWidget);
    expect(find.byType(GlobalProxyPill), findsOneWidget);
    expect(find.byType(ExitInfoBar), findsOneWidget);
    final statusButtonRect = tester.getRect(
      find.byKey(const ValueKey('home-top-collapse-button')),
    );
    final triangleRect = tester.getRect(
      find.byKey(const ValueKey('home-triangle-hub')),
    );
    final routingPillRect = tester.getRect(find.byType(GlobalProxyPill));
    final exitBarRect = tester.getRect(
      find.byKey(const ValueKey('exit-info-bar-toggle')),
    );
    expect(triangleRect.top - statusButtonRect.bottom, closeTo(8, 0.01));
    expect(routingPillRect.top - triangleRect.bottom, closeTo(8, 0.01));
    expect(exitBarRect.top - routingPillRect.bottom, closeTo(8, 0.01));
    final expandedButtonTop = tester
        .getTopLeft(find.byKey(const ValueKey('home-top-collapse-button')))
        .dy;

    await tester.tap(find.byKey(const ValueKey('home-top-collapse-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('home-top-expanded')), findsNothing);
    expect(find.byKey(const ValueKey('home-top-collapsed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-compact-triangle-hub')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-triangle-hub')), findsNothing);
    expect(find.byType(GlobalProxyPill), findsNothing);
    expect(find.byType(ExitInfoBar), findsNothing);
    expect(find.text('IDLE'), findsOneWidget);
    final collapsedButtonTop = tester
        .getTopLeft(find.byKey(const ValueKey('home-top-expand-button')))
        .dy;
    expect(collapsedButtonTop, closeTo(expandedButtonTop, 1));

    await tester.tap(find.byKey(const ValueKey('home-top-expand-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('home-top-expanded')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-top-collapsed')), findsNothing);
    expect(find.byKey(const ValueKey('home-triangle-hub')), findsOneWidget);
    expect(find.byType(GlobalProxyPill), findsOneWidget);
    expect(find.byType(ExitInfoBar), findsOneWidget);
  });

  testWidgets('home top widgets can start collapsed from app setting', (
    tester,
  ) async {
    final controller = await _buildController(startHomeWidgetsCollapsed: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-top-expanded')), findsNothing);
    expect(find.byKey(const ValueKey('home-top-collapsed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-compact-triangle-hub')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-triangle-hub')), findsNothing);
    expect(find.byType(GlobalProxyPill), findsNothing);
    expect(find.byType(ExitInfoBar), findsNothing);
  });

  testWidgets('collapsed home top row does not overflow on narrow widths', (
    tester,
  ) async {
    final previousOnError = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in <double>[320, 390, 600]) {
      await tester.binding.setSurfaceSize(Size(width, 640));
      final controller = await _buildController();

      await tester.pumpWidget(_testApp(controller));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-top-collapse-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('home-top-collapsed')), findsOneWidget);
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }

    final overflowErrors = errors.where(
      (error) => error.exceptionAsString().contains('overflowed by'),
    );
    expect(overflowErrors, isEmpty);
  });

  testWidgets('compact triangle calls tap only when enabled', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _widgetApp(
        CompactTriangleHub(state: HubVisualState.off, onTap: () => taps += 1),
      ),
    );

    await tester.tap(find.byType(CompactTriangleHub));
    expect(taps, 1);
    expect(find.text('//'), findsOneWidget);

    await tester.pumpWidget(
      _widgetApp(
        CompactTriangleHub(
          state: HubVisualState.connecting,
          enabled: false,
          onTap: () => taps += 1,
        ),
      ),
    );

    await tester.tap(find.byType(CompactTriangleHub));
    expect(taps, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('status strip trailing stays pinned when timer width changes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 120));

    await tester.pumpWidget(_statusStripApp('0'));
    final initialCenter = tester.getCenter(
      find.byKey(const ValueKey('status-strip-trailing-probe')),
    );

    await tester.pumpWidget(_statusStripApp('123:45:67'));
    final changedCenter = tester.getCenter(
      find.byKey(const ValueKey('status-strip-trailing-probe')),
    );

    expect(changedCenter.dx, initialCenter.dx);
  });

  testWidgets('status strip timer stays pinned when status changes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 120));

    await tester.pumpWidget(_statusStripApp('00:00:01', label: 'OFF'));
    final initialRight = tester.getRect(find.text('00:00:01')).right;

    for (final label in ['CONNECTING', 'SECURE', 'RECONNECTING NETWORK']) {
      await tester.pumpWidget(_statusStripApp('00:00:01', label: label));
      expect(tester.getRect(find.text('00:00:01')).right, initialRight);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(_statusStripApp('— : —', label: 'OFF'));
    expect(tester.getRect(find.text('— : —')).right, initialRight);
  });
}

Future<VpnController> _buildController({
  bool startHomeWidgetsCollapsed = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final repository = ServerRepository(prefs);
  return _TestHomeController(
    repository,
    startHomeWidgetsCollapsed: startHomeWidgetsCollapsed,
  );
}

Widget _testApp(VpnController controller) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomeScreen(
      controller: controller,
      isDarkTheme: false,
      onThemeModeChanged: (_) {},
      localePreference: AppLocalePreference.english,
      onLocalePreferenceChanged: (_) {},
    ),
  );
}

Widget _widgetApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

Widget _statusStripApp(String right, {String label = 'SECURE'}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 390,
          child: StatusStrip(
            label: label,
            tone: StatusTone.ok,
            right: right,
            trailing: const SizedBox(
              key: ValueKey('status-strip-trailing-probe'),
              width: 24,
              height: 24,
            ),
          ),
        ),
      ),
    ),
  );
}

class _TestHomeController extends VpnController {
  _TestHomeController(
    super.repository, {
    bool startHomeWidgetsCollapsed = false,
  }) : _startHomeWidgetsCollapsed = startHomeWidgetsCollapsed;

  final ValueNotifier<int> _homeRevision = ValueNotifier(0);
  final ValueNotifier<VpnConnectionState> _state = ValueNotifier(
    VpnConnectionState.disconnected,
  );
  final ValueNotifier<String> _duration = ValueNotifier('00:00:00');
  final bool _startHomeWidgetsCollapsed;

  @override
  ValueListenable<int> get homeListRevisionListenable => _homeRevision;

  @override
  ValueListenable<VpnConnectionState> get connectionStateListenable => _state;

  @override
  ValueListenable<String> get connectionDurationLabelListenable => _duration;

  @override
  VpnConnectionState get connectionState => _state.value;

  @override
  bool get isConnected => false;

  @override
  bool get isBusy => false;

  @override
  bool get showGlobalProxyButton => true;

  @override
  bool get showExitNodeInfoBar => true;

  @override
  bool get startHomeWidgetsCollapsed => _startHomeWidgetsCollapsed;

  @override
  bool get isGlobalProxy => false;

  @override
  ServerConfig? get selectedServer => null;

  @override
  ServerConfig? get exitServer => null;

  @override
  List<ServerConfig> get favoriteServers => const [];

  @override
  List<ServerConfig> get manualServers => const [];

  @override
  List<ServerSubscription> get subscriptions => const [];

  @override
  bool get hasAnyServers => false;

  @override
  bool get favoritesSectionCollapsed => false;

  @override
  SubscriptionProviderSettings get subscriptionProviderSettings =>
      SubscriptionProviderSettings.defaults;

  @override
  String? get externalIpIfResolved => null;

  @override
  bool get isResolvingExternalIp => false;

  @override
  double get downloadBps => 0;

  @override
  double get uploadBps => 0;

  @override
  String? get lastError => null;

  @override
  PendingDeepLink? get pendingDeepLink => null;

  @override
  String? consumeRoutingPresetWarning() => null;

  @override
  String? consumeDeepLinkNotice() => null;

  @override
  Future<void> toggleConnection() async {}

  @override
  Future<void> clearExitNode() async {}

  @override
  Future<void> setGlobalProxy(bool value, {bool fromTvHome = false}) async {}

  @override
  void dispose() {
    _homeRevision.dispose();
    _state.dispose();
    _duration.dispose();
    super.dispose();
  }
}
