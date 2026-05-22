import 'package:flutter/services.dart';

class ProfileFileExporter {
  const ProfileFileExporter();

  static const MethodChannel _channel = MethodChannel(
    'org.voidtunnel.vpn/service',
  );

  Future<bool> export({
    required String content,
    required String fileName,
  }) async {
    return await _channel.invokeMethod<bool>('exportProfileFile', {
          'content': content,
          'fileName': fileName,
        }) ??
        false;
  }
}
