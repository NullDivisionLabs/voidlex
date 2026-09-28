import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_config_exporter.dart';
import 'package:voidlex/core/server_importer.dart';
import 'package:voidlex/core/tun_engine_mode.dart';
import 'package:voidlex/core/vless_parser.dart';
import 'package:voidlex/l10n/app_localizations.dart';
import 'package:voidlex/screens/widgets/xhttp_advanced_fields.dart';

const _uuid = '00000000-0000-4000-8000-000000000000';

ServerConfig _xhttpServer({
  bool? obfsMode,
  String path = '/cdnapi.txt',
  Map<String, dynamic> rawSettings = const {},
  Map<String, dynamic> rawExtra = const {},
}) => ServerConfig(
  name: 'XHTTP',
  address: 'edge.example.com',
  port: 443,
  uuid: _uuid,
  transport: VlessTransport.xhttp,
  security: VlessSecurity.tls,
  transportPath: path,
  xPaddingObfsMode: obfsMode,
  xPaddingPlacement: obfsMode == true ? 'query-in-header' : '',
  xPaddingHeader: obfsMode == true ? 'Referer' : '',
  xPaddingKey: obfsMode == true ? 'v' : '',
  xPaddingMethod: obfsMode == true ? 'tokenish' : '',
  xPaddingBytes: obfsMode == true ? '100-1000' : '',
  sessionIDPlacement: obfsMode == true ? 'query' : '',
  sessionIDKey: obfsMode == true ? 'sid' : '',
  seqPlacement: obfsMode == true ? 'query' : '',
  seqKey: obfsMode == true ? 'n' : '',
  xhttpRawSettings: rawSettings,
  xhttpRawExtra: rawExtra,
);

Map<String, dynamic> _xhttpSettings(ServerConfig server) {
  final config = ServerConfigExporter.toXrayConfig(server);
  final outbounds = config['outbounds']! as List<dynamic>;
  final proxy = outbounds.first as Map<String, dynamic>;
  final stream = proxy['streamSettings']! as Map<String, dynamic>;
  return stream['xhttpSettings']! as Map<String, dynamic>;
}

void main() {
  test('migrates legacy xhttpPadding and preserves nullable false', () {
    final legacy = ServerConfig.fromJson({
      'name': 'Legacy',
      'address': 'legacy.example.com',
      'port': 443,
      'uuid': _uuid,
      'transport': 'xhttp',
      'security': 'tls',
      'xhttpPadding': '50-100',
      'xPaddingObfsMode': false,
    })!;

    expect(legacy.xPaddingBytes, '50-100');
    expect(legacy.xPaddingObfsMode, isFalse);
    final encoded = legacy.toJson();
    expect(encoded['xPaddingBytes'], '50-100');
    expect(encoded, isNot(contains('xhttpPadding')));
    expect(ServerConfig.fromJson(encoded)!.xPaddingObfsMode, isFalse);
  });

  test('advanced fields and unknown maps survive app JSON round-trip', () {
    final original = _xhttpServer(
      obfsMode: true,
      rawSettings: const {
        'futureTopLevel': {'enabled': true},
      },
      rawExtra: const {
        'futureExtra': [1, 2, 3],
      },
    );

    final decoded = ServerConfig.decodeList(
      ServerConfig.encodeList([original]),
    );
    expect(decoded, hasLength(1));
    final round = decoded.single;
    expect(round.xPaddingPlacement, 'query-in-header');
    expect(round.sessionIDKey, 'sid');
    expect(round.xhttpRawSettings['futureTopLevel'], {'enabled': true});
    expect(round.xhttpRawExtra['futureExtra'], [1, 2, 3]);
  });

  test('stock XHTTP emits no mode or extra and keeps file-like path', () {
    final settings = _xhttpSettings(_xhttpServer());
    expect(settings['path'], '/cdnapi.txt');
    expect(settings, isNot(contains('mode')));
    expect(settings, isNot(contains('extra')));
  });

  test('CDN WAF fields use exact Xray wire names and casing', () {
    final settings = _xhttpSettings(_xhttpServer(obfsMode: true));
    final extra = settings['extra']! as Map<String, dynamic>;
    expect(extra, containsPair('xPaddingObfsMode', true));
    expect(extra, containsPair('xPaddingPlacement', 'queryInHeader'));
    expect(extra, containsPair('xPaddingHeader', 'Referer'));
    expect(extra, containsPair('xPaddingKey', 'v'));
    expect(extra, containsPair('xPaddingMethod', 'tokenish'));
    expect(extra, containsPair('xPaddingBytes', '100-1000'));
    expect(extra, containsPair('sessionIDPlacement', 'query'));
    expect(extra, containsPair('sessionIDKey', 'sid'));
    expect(extra, containsPair('seqPlacement', 'query'));
    expect(extra, containsPair('seqKey', 'n'));
    expect(settings['path'], '/cdnapi.txt');
  });

  test('Xray import preserves unknown settings through edit and export', () {
    final result = const ServerImporter().parse('''
{
  "outbounds": [{
    "tag": "proxy",
    "protocol": "vless",
    "settings": {"vnext": [{
      "address": "edge.example.com",
      "port": 443,
      "users": [{"id": "$_uuid"}]
    }]},
    "streamSettings": {
      "network": "xhttp",
      "security": "tls",
      "tlsSettings": {"serverName": "edge.example.com"},
      "xhttpSettings": {
        "path": "/cdnapi.txt",
        "futureTopLevel": {"keep": true},
        "extra": {
          "xPaddingObfsMode": true,
          "xPaddingPlacement": "queryInHeader",
          "xPaddingHeader": "Referer",
          "xPaddingKey": "v",
          "xPaddingMethod": "tokenish",
          "xPaddingBytes": "100-1000",
          "sessionIDPlacement": "query",
          "sessionIDKey": "sid",
          "seqPlacement": "query",
          "seqKey": "n",
          "futureExtra": {"keep": [1, 2]}
        }
      }
    }
  }]
}
''');

    expect(result.isOk, isTrue);
    final imported = result.configs.single;
    expect(imported.xPaddingPlacement, 'query-in-header');
    expect(imported.xhttpRawSettings['futureTopLevel'], {'keep': true});
    expect(imported.xhttpRawExtra['futureExtra'], {
      'keep': [1, 2],
    });

    final exported = _xhttpSettings(imported.copyWith(name: 'Edited'));
    expect(exported['futureTopLevel'], {'keep': true});
    expect((exported['extra'] as Map)['futureExtra'], {
      'keep': [1, 2],
    });
  });

  test('VLESS link round-trip keeps supported advanced fields', () {
    final original = _xhttpServer(obfsMode: true);
    final url = ServerConfigExporter.toVlessUrl(original);
    final parsed = const VlessParser().parse(url).config!;

    expect(parsed.xPaddingObfsMode, isTrue);
    expect(parsed.xPaddingPlacement, 'query-in-header');
    expect(parsed.xPaddingHeader, 'Referer');
    expect(parsed.sessionIDPlacement, 'query');
    expect(parsed.seqKey, 'n');
  });

  test('raw fields trigger URL omission warning', () {
    expect(
      ServerConfigExporter.hasUrlOmittedAdvancedFields(
        _xhttpServer(rawExtra: const {'future': true}),
      ),
      isTrue,
    );
  });

  test('native bridge entry carries all advanced fields with its prefix', () {
    final entry = _xhttpServer(
      obfsMode: true,
      rawSettings: const {'futureTop': 1},
      rawExtra: const {'futureExtra': true},
    ).copyWith(name: 'Entry');
    final outer = _xhttpServer().copyWith(name: 'Outer');
    final args = outer.toNativeArgs(
      isGlobalProxy: true,
      tunEngineMode: TunEngineMode.libbox,
      entryServer: entry,
    );

    expect(args['entryXPaddingObfsMode'], isTrue);
    expect(args['entryXPaddingPlacement'], 'query-in-header');
    expect(args['entryXPaddingBytes'], '100-1000');
    expect(args['entrySessionIDPlacement'], 'query');
    expect(args['entrySessionIDKey'], 'sid');
    expect(args['entrySeqPlacement'], 'query');
    expect(args['entrySeqKey'], 'n');
    expect(args['entryXhttpRawSettingsJson'], '{"futureTop":1}');
    expect(args['entryXhttpRawExtraJson'], '{"futureExtra":true}');
  });

  test('validation follows Xray token and Int32 range constraints', () {
    expect(XhttpAdvancedFields.isValidHttpToken('X-Session'), isTrue);
    expect(XhttpAdvancedFields.isValidHttpToken('bad key'), isFalse);
    expect(XhttpAdvancedFields.isValidPositiveRange('100-1000'), isTrue);
    expect(XhttpAdvancedFields.isValidPositiveRange('0-1000'), isFalse);
    expect(XhttpAdvancedFields.isValidPositiveRange('1000-100'), isFalse);
    expect(XhttpAdvancedFields.isValidPositiveRange('1-2147483648'), isFalse);
  });

  test('CDN WAF preset has the documented ten values only', () {
    final preset = XhttpAdvancedFields.cdnWafPreset;
    expect(preset.xPaddingObfsMode, isTrue);
    expect(preset.xPaddingPlacement, 'query-in-header');
    expect(preset.xPaddingHeader, 'Referer');
    expect(preset.xPaddingKey, 'v');
    expect(preset.xPaddingMethod, 'tokenish');
    expect(preset.xPaddingBytes, '100-1000');
    expect(preset.sessionIDPlacement, 'query');
    expect(preset.sessionIDKey, 'sid');
    expect(preset.seqPlacement, 'query');
    expect(preset.seqKey, 'n');
  });

  testWidgets('dependent placement validation requires the matching keys', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final paddingKey = TextEditingController();
    final paddingHeader = TextEditingController();
    final paddingBytes = TextEditingController(text: '0-1');
    final sessionKey = TextEditingController();
    final seqKey = TextEditingController();
    final maxPost = TextEditingController();
    final minInterval = TextEditingController();
    addTearDown(() {
      paddingKey.dispose();
      paddingHeader.dispose();
      paddingBytes.dispose();
      sessionKey.dispose();
      seqKey.dispose();
      maxPost.dispose();
      minInterval.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: XhttpAdvancedFields(
                enabled: true,
                mode: '',
                onModeChanged: (_) {},
                obfsEnabled: true,
                onObfsEnabledChanged: (_) {},
                paddingPlacement: 'query-in-header',
                onPaddingPlacementChanged: (_) {},
                paddingMethod: 'tokenish',
                onPaddingMethodChanged: (_) {},
                sessionIDPlacement: 'query',
                onSessionIDPlacementChanged: (_) {},
                seqPlacement: 'query',
                onSeqPlacementChanged: (_) {},
                paddingKeyController: paddingKey,
                paddingHeaderController: paddingHeader,
                paddingBytesController: paddingBytes,
                sessionIDKeyController: sessionKey,
                seqKeyController: seqKey,
                maxPostController: maxPost,
                minIntervalController: minInterval,
                onApplyCdnWafPreset: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required for the selected placement'), findsNWidgets(4));
    expect(
      find.text('Use a positive number or range up to 2147483647'),
      findsOneWidget,
    );

    paddingKey.text = 'v';
    paddingHeader.text = 'Referer';
    paddingBytes.text = '100-1000';
    sessionKey.text = 'sid';
    seqKey.text = 'n';
    expect(formKey.currentState!.validate(), isTrue);
  });
}
