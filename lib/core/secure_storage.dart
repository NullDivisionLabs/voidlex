import 'package:flutter/services.dart';

/// Async key/value store backed by Android EncryptedSharedPreferences.
/// Used for credentials (proxy auth password) that must not sit in plain-text
/// SharedPreferences. On platforms without a native bridge yet, all calls
/// degrade to no-op so the app keeps working.
class SecureStorage {
  const SecureStorage();

  static const MethodChannel _channel = MethodChannel(
    'org.voidlex.vpn/service',
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
      throw const SecureStorageException(
        SecureStorageError.unavailable,
        'Secure storage is not available on this platform',
      );
    } on PlatformException catch (e) {
      throw SecureStorageException(
        SecureStorageError.writeFailed,
        e.message ?? 'Secure storage write failed',
      );
    }
  }

  Future<void> remove(String key) async {
    if (key.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('secureRemove', key);
    } on MissingPluginException {
      return;
    } on PlatformException catch (e) {
      throw SecureStorageException(
        SecureStorageError.writeFailed,
        e.message ?? 'Secure storage remove failed',
      );
    }
  }
}

enum SecureStorageError { unavailable, writeFailed }

class SecureStorageException implements Exception {
  const SecureStorageException(this.code, this.message);

  final SecureStorageError code;
  final String message;

  @override
  String toString() => 'SecureStorageException($code): $message';
}
