import 'package:flutter/services.dart';

/// Thin wrapper around the native SAF document picker. The native side
/// returns null when the user cancels, and throws PlatformException when a
/// chosen URI cannot be read — callers translate both into user-facing
/// snackbars.
class TextFilePicker {
  const TextFilePicker();

  static const MethodChannel _channel = MethodChannel(
    'org.voidlex.vpn/service',
  );

  Future<String?> pick() async {
    return _channel.invokeMethod<String>('pickTextFile');
  }

  Future<String?> pickJson() async {
    return _channel.invokeMethod<String>('pickJsonFile');
  }
}
