import 'package:flutter/services.dart';

class LibboxVersionBridge {
  const LibboxVersionBridge();

  static const MethodChannel _channel = MethodChannel(
    'org.voidlex.vpn/service',
  );

  Future<String> getVersion() async {
    return (await _channel.invokeMethod<String>('getLibboxVersion'))?.trim() ??
        '';
  }
}
