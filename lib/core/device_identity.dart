import 'package:flutter/services.dart';

class DeviceIdentityBridge {
  const DeviceIdentityBridge();

  static const MethodChannel _channel = MethodChannel(
    'org.voidtunnel.vpn/service',
  );

  Future<String> getHwid() async {
    return await _channel.invokeMethod<String>('getDeviceHwid') ?? '';
  }
}
