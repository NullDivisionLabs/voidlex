import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/core/tunnel_fragment_settings.dart';

void main() {
  test('uses screenshot defaults for new fragment settings', () {
    const settings = TunnelFragmentSettings.defaults;

    expect(settings.enabled, isFalse);
    expect(settings.packets, 'tlshello');
    expect(settings.length, '50-100');
    expect(settings.interval, '10-20');
    expect(settings.maxSplit, '100-200');
    expect(settings.noiseEnabled, isTrue);
    expect(settings.noiseType, 'rand');
    expect(settings.noisePacket, '10-20');
    expect(settings.noiseDelay, '10-16');
    expect(settings.noiseApplyTo, 'ip');
  });

  test('normalizes blanks before native export', () {
    final settings = TunnelFragmentSettings.decode(
      jsonEncode({
        'enabled': true,
        'packets': '',
        'length': '',
        'interval': '',
        'maxSplit': '',
        'noiseEnabled': true,
        'noiseType': '',
        'noisePacket': '',
        'noiseDelay': '',
        'noiseApplyTo': '',
      }),
    );

    final args = settings.toNativeArgs();
    expect(args['fragmentEnabled'], isTrue);
    expect(args['fragmentPackets'], 'tlshello');
    expect(args['fragmentLength'], '50-100');
    expect(args['fragmentInterval'], '10-20');
    expect(args['fragmentMaxSplit'], '100-200');
    expect(args['fragmentNoiseType'], 'rand');
    expect(args['fragmentNoisePacket'], '10-20');
    expect(args['fragmentNoiseDelay'], '10-16');
    expect(args['fragmentNoiseApplyTo'], 'ip');
  });
}
