import 'package:flutter/services.dart';

/// Async key/value store backed by Android EncryptedSharedPreferences.
/// Used for credentials (proxy auth password) that must not sit in plain-text
/// SharedPreferences. On platforms without a native bridge yet, all calls
/// degrade to no-op so the app keeps working.
class SecureStorage {
  const SecureStorage();

  static const MethodChannel _channel = MethodChannel(
    'org.voidtunnel.vpn/service',
  );

  Future<String?> readString(String key) async {
    if (key.isEmpty) return null;
    try {
      return await _channel.invokeMethod<String>('secureGetString', key);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> writeString(String key, String value) async {
    if (key.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('secureSetString', {
        'key': key,
        'value': value,
      });
    } on MissingPluginException {
      // No native bridge available — silently drop. Better than crashing.
    } on PlatformException {
      // Same — the secret remains unwritten; UI surfaces this through whatever
      // call site triggered the write.
    }
  }

  Future<void> remove(String key) async {
    if (key.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('secureRemove', key);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
