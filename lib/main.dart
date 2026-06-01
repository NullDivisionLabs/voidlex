import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_locale.dart';
import 'core/server_repository.dart';
import 'core/tv_layout_preference.dart';
import 'core/tv_mode_detector.dart';
import 'core/vpn_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/tv/tv_home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await ServerRepository.open();
  final controller = VpnController(repository);
  await controller.bootstrap();
  final tvMode = await TvModeDetector.detect();
  runApp(
    VoidLexApp(
      controller: controller,
      repository: repository,
      tvMode: tvMode,
    ),
  );
}

class VoidLexApp extends StatefulWidget {
  const VoidLexApp({
    super.key,
    required this.controller,
    required this.repository,
    required this.tvMode,
  });

  final VpnController controller;
  final ServerRepository repository;
  final TvModeDetector tvMode;

  @override
  State<VoidLexApp> createState() => _VoidLexAppState();
}

class _VoidLexAppState extends State<VoidLexApp>
    with WidgetsBindingObserver {
  static const Duration _autoPingScanCooldown = Duration(minutes: 1);

  late bool _isDarkTheme;
  late AppLocalePreference _localePreference;
  Locale _systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
  bool _wasInBackground = false;
  DateTime? _lastAutoPingScanAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDarkTheme = widget.repository.loadDarkTheme();
    _localePreference = widget.repository.loadAppLocalePreference();
    widget.repository.tvLayoutPreferenceListenable.addListener(
      _applyOrientationLock,
    );
    _applyOrientationLock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runLaunchTasks());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.repository.tvLayoutPreferenceListenable.removeListener(
      _applyOrientationLock,
    );
    super.dispose();
  }

  /// Maps the persisted [TvLayoutPreference] to a `SystemChrome`
  /// orientation lock and applies it. Skipped on real Android TV — that
  /// surface ignores orientation, so locking it would be misleading.
  void _applyOrientationLock() {
    if (widget.tvMode.isNativeTv) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      return;
    }
    final pref = widget.repository.loadTvLayoutPreference();
    SystemChrome.setPreferredOrientations(pref.allowedOrientations);
  }

  /// Decides which layout flavour to render given the user's
  /// preference and the current device orientation.
  ///
  /// On a real Android TV the answer is always "TV" — the user's
  /// preference is overridden by the host's native UI mode.
  ///
  /// On a phone or tablet:
  /// - `vertical`   → mobile UI (orientation is portrait-locked anyway).
  /// - `horizontal` → TV UI    (orientation is landscape-locked anyway).
  /// - `autoRotate` → TV UI only when the device is actually in
  ///   landscape; portrait falls back to the mobile UI so a tablet
  ///   user gets a sensible layout in either hand position.
  bool _shouldUseTvLayout(TvLayoutPreference pref, Orientation orientation) {
    if (widget.tvMode.isNativeTv) return true;
    switch (pref) {
      case TvLayoutPreference.vertical:
        return false;
      case TvLayoutPreference.horizontal:
        return true;
      case TvLayoutPreference.autoRotate:
        return orientation == Orientation.landscape;
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final next = WidgetsBinding.instance.platformDispatcher.locale;
    if (next == _systemLocale) return;
    setState(() => _systemLocale = next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_wasInBackground) {
          _wasInBackground = false;
          unawaited(_scanPingOnAppVisible());
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _wasInBackground = true;
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _runLaunchTasks() async {
    await _connectOnLaunchIfNeeded();
    await _scanPingOnAppVisible();
  }

  Future<void> _connectOnLaunchIfNeeded() async {
    if (!mounted || !widget.controller.autoConnectOnLaunch) return;
    if (widget.controller.isConnected || widget.controller.isBusy) return;
    await widget.controller.connect();
  }

  Future<void> _scanPingOnAppVisible() async {
    if (!mounted) return;
    final now = DateTime.now();
    final lastScanAt = _lastAutoPingScanAt;
    if (lastScanAt != null &&
        now.difference(lastScanAt) < _autoPingScanCooldown) {
      return;
    }
    _lastAutoPingScanAt = now;
    if (widget.controller.isScanningLatency) return;
    // If the controller's 15-min throttle blocks the full sweep, fall back
    // to a single-node ping on the active server so the user still sees a
    // fresh number for the node they actually care about.
    if (widget.controller.isFullScanOnCooldown) {
      await widget.controller.pingActiveServerOnly();
      return;
    }
    await widget.controller.scanLatencies();
  }

  Future<void> _setDarkTheme(bool value) async {
    if (_isDarkTheme == value) return;
    setState(() => _isDarkTheme = value);
    await widget.repository.saveDarkTheme(value);
  }

  Locale get _effectiveLocale => resolveEffectiveLocale(
    preference: _localePreference,
    systemLocale: _systemLocale,
  );

  Future<void> _setLocalePreference(AppLocalePreference value) async {
    if (_localePreference == value) return;
    setState(() => _localePreference = value);
    await widget.repository.saveAppLocalePreference(value);
  }

  @override
  Widget build(BuildContext context) {
    // Drives `VoidType.sans`/`mono` font-family selection. Must be set before
    // `AppTheme.lightTheme`/`darkTheme` getters run below — they call
    // `VoidType.sans` inline while constructing TextTheme entries.
    final effectiveLocale = _effectiveLocale;
    VoidType.useLocale(effectiveLocale);
    return AppLocaleScope(
      preference: _localePreference,
      onPreferenceChanged: _setLocalePreference,
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
        locale: effectiveLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ValueListenableBuilder<TvLayoutPreference>(
          valueListenable: widget.repository.tvLayoutPreferenceListenable,
          builder: (context, pref, _) {
            // `OrientationBuilder` rebuilds when the device flips
            // between portrait and landscape, which lets `autoRotate`
            // hand portrait back to the mobile [HomeScreen] and lift
            // landscape into [TvHomeScreen] without restarting either.
            return OrientationBuilder(
              builder: (context, orientation) {
                final useTv = _shouldUseTvLayout(pref, orientation);
                if (useTv) {
                  return TvHomeScreen(
                    controller: widget.controller,
                    repository: widget.repository,
                    tvMode: widget.tvMode,
                    isDarkTheme: _isDarkTheme,
                    onThemeModeChanged: _setDarkTheme,
                    localePreference: _localePreference,
                    onLocalePreferenceChanged: _setLocalePreference,
                  );
                }
                return HomeScreen(
                  controller: widget.controller,
                  isDarkTheme: _isDarkTheme,
                  onThemeModeChanged: _setDarkTheme,
                  localePreference: _localePreference,
                  onLocalePreferenceChanged: _setLocalePreference,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
