import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/core/routing_rule.dart';

void main() {
  test('imports wrapped Xray field rules in priority order', () {
    const raw = '''
{
  "rules": [
    {
      "__name__": "0. Block QUIC",
      "type": "field",
      "port": "443",
      "network": ["udp"],
      "outboundTag": "block"
    },
    {
      "__name__": "1. VK direct",
      "type": "field",
      "domain": ["geosite:vk"],
      "outboundTag": "direct",
      "enabled": false
    }
  ]
}
''';

    final rules = RoutingRule.importRulesFromJsonString(raw);

    expect(rules, hasLength(2));
    expect(rules[0].name, '0. Block QUIC');
    expect(rules[0].port, '443');
    expect(rules[0].networks, ['udp']);
    expect(rules[0].outbound, RoutingOutbound.block);
    expect(rules[1].domains, ['geosite:vk']);
    expect(rules[1].outbound, RoutingOutbound.direct);
    expect(rules[1].enabled, isFalse);
  });

  test('exports disabled flag and Xray-compatible field names', () {
    final json = RoutingRule.exportRulesToJsonString([
      RoutingRule(
        id: 'id',
        name: 'Ads',
        enabled: false,
        outbound: RoutingOutbound.block,
        domains: const ['geosite:category-ads-all'],
      ),
    ]);

    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final rule =
        (decoded['rules'] as List<dynamic>).single as Map<String, dynamic>;

    expect(rule['__name__'], 'Ads');
    expect(rule['type'], 'field');
    expect(rule['outboundTag'], 'block');
    expect(rule['enabled'], isFalse);
    expect(rule['domain'], ['geosite:category-ads-all']);
  });
}
