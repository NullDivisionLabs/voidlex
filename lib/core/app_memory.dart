import 'package:flutter/services.dart';

class AppMemoryBridge {
  const AppMemoryBridge();

  static const MethodChannel _channel = MethodChannel(
    'org.voidlex.vpn/service',
  );

  Future<int?> getPssKb() async {
    try {
      return await _channel.invokeMethod<int>('getAppMemoryPssKb');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
