import 'package:flutter/services.dart';

/// One-shot detector for "am I running on an actual Android TV / Leanback
/// device?". Captured once at app start, then read synchronously.
///
/// The actual TV-vs-mobile layout decision lives in `main.dart`, where
/// it can combine the native flag with the user's persisted
/// `TvLayoutPreference` and — crucially for the auto-rotate case — the
/// current device orientation.
///
/// Non-Android platforms (tests, desktop, web) silently report `false`.
class TvModeDetector {
  const TvModeDetector._(this.isNativeTv);

  /// `true` when `UiModeManager.currentModeType` is
  /// `UI_MODE_TYPE_TELEVISION` or the device exposes
  /// `PackageManager.FEATURE_LEANBACK[_ONLY]`.
  final bool isNativeTv;

  static const MethodChannel _channel = MethodChannel('org.voidlex.tv/info');

  static Future<TvModeDetector> detect() async {
    return TvModeDetector._(await _queryNative());
  }

  static Future<bool> _queryNative() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTelevision');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
