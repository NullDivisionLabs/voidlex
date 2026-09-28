import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_config_exporter.dart';

const _uuid = '00000000-0000-4000-8000-000000000000';

ServerConfig _server({
  String path = '/',
  bool? xPaddingObfsMode,
  String xPaddingPlacement = '',
  String xPaddingKey = '',
  String xPaddingHeader = '',
  String xPaddingMethod = '',
  String xPaddingBytes = '',
  String sessionIDPlacement = '',
  String sessionIDKey = '',
  String seqPlacement = '',
  String seqKey = '',
  Map<String, dynamic> rawSettings = const {},
  Map<String, dynamic> rawExtra = const {},
}) => ServerConfig(
  name: 'XHTTP validation',
  address: 'example.com',
  port: 443,
  uuid: _uuid,
  transport: VlessTransport.xhttp,
  security: VlessSecurity.tls,
  transportPath: path,
  sni: 'example.com',
  xPaddingObfsMode: xPaddingObfsMode,
  xPaddingPlacement: xPaddingPlacement,
  xPaddingKey: xPaddingKey,
  xPaddingHeader: xPaddingHeader,
  xPaddingMethod: xPaddingMethod,
  xPaddingBytes: xPaddingBytes,
  sessionIDPlacement: sessionIDPlacement,
  sessionIDKey: sessionIDKey,
  seqPlacement: seqPlacement,
  seqKey: seqKey,
  xhttpRawSettings: rawSettings,
  xhttpRawExtra: rawExtra,
);

void main() {
  final xrayBinary = Platform.environment['XRAY_TEST_BINARY'];

  test(
    'seven generated XHTTP configurations pass real Xray run -test',
    () async {
      final cases = <String, ServerConfig>{
        '01-stock': _server(),
        '02-referer': _server(
          xPaddingObfsMode: true,
          xPaddingPlacement: 'query-in-header',
          xPaddingKey: 'v',
          xPaddingHeader: 'Referer',
          xPaddingMethod: 'tokenish',
          xPaddingBytes: '100-1000',
        ),
        '03-header': _server(
          xPaddingObfsMode: true,
          xPaddingPlacement: 'header',
          xPaddingHeader: 'X-Padding',
          xPaddingMethod: 'repeat-x',
          xPaddingBytes: '64-256',
        ),
        '04-query': _server(
          xPaddingObfsMode: true,
          xPaddingPlacement: 'query',
          xPaddingKey: 'pad',
          xPaddingMethod: 'tokenish',
          xPaddingBytes: '32-128',
        ),
        '05-session-seq-query': _server(
          sessionIDPlacement: 'query',
          sessionIDKey: 'sid',
          seqPlacement: 'query',
          seqKey: 'n',
        ),
        '06-file-like-path': _server(
          path: '/cdnapi.txt',
          sessionIDPlacement: 'query',
          sessionIDKey: 'sid',
          seqPlacement: 'query',
          seqKey: 'n',
        ),
        '07-preserved-raw': _server(
          rawSettings: const {
            'futureTopLevel': {'enabled': true},
          },
          rawExtra: const {
            'futureExtra': {
              'values': [1, 2],
            },
          },
        ),
      };

      final directory = await Directory.systemTemp.createTemp(
        'voidlex-xray-validation-',
      );
      addTearDown(() => directory.delete(recursive: true));

      for (final entry in cases.entries) {
        final config = ServerConfigExporter.toXrayConfig(entry.value);
        if (entry.key == '06-file-like-path') {
          final outbound = (config['outbounds']! as List).first as Map;
          final stream = outbound['streamSettings'] as Map;
          final xhttp = stream['xhttpSettings'] as Map;
          expect(xhttp['path'], '/cdnapi.txt');
        }
        final file = File('${directory.path}/${entry.key}.json');
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(config),
        );
        final result = await Process.run(xrayBinary!, [
          'run',
          '-test',
          '-config',
          file.path,
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${entry.key} failed:\n${result.stdout}\n${result.stderr}',
        );
      }
    },
    skip: xrayBinary == null
        ? 'Set XRAY_TEST_BINARY to Xray-core v26.7.28.'
        : false,
  );
}
