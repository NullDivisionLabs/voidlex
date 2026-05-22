import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/core/models/server_config.dart';

void main() {
  group('ServerConfig.pingOrderKey', () {
    test('orders successful measurements by milliseconds', () {
      expect(
        ServerConfig.pingOrderKey('12 ms'),
        lessThan(ServerConfig.pingOrderKey('50 ms')),
      );
    });

    test('places ERR and unknown after good pings', () {
      expect(
        ServerConfig.pingOrderKey('100 ms'),
        lessThan(ServerConfig.pingOrderKey('>5S')),
      );
      expect(
        ServerConfig.pingOrderKey('>5S'),
        lessThan(ServerConfig.pingOrderKey('ERR')),
      );
      expect(
        ServerConfig.pingOrderKey('ERR'),
        lessThan(ServerConfig.pingOrderKey('--')),
      );
    });
  });
}
