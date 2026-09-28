import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/deep_link_handler.dart';

void main() {
  test('rulesetTargetFromUri parses path-style https URL', () {
    final uri = Uri.parse(
      'voidlex://import-ruleset/https://example.com/rules.json',
    );
    final target = DeepLinkHandler.rulesetTargetFromUri(uri);
    expect(target, Uri.parse('https://example.com/rules.json'));
  });

  test('rulesetTargetFromUri parses query parameter url', () {
    final uri = Uri.parse(
      'voidlex://import-ruleset?url=https%3A%2F%2Fexample.com%2Frules.json',
    );
    final target = DeepLinkHandler.rulesetTargetFromUri(uri);
    expect(target, Uri.parse('https://example.com/rules.json'));
  });

  test('isAllowedRulesetUrl rejects non-http schemes', () {
    expect(
      DeepLinkHandler.isAllowedRulesetUrl(Uri.parse('file:///etc/passwd')),
      isFalse,
    );
    expect(
      DeepLinkHandler.isAllowedRulesetUrl(
        Uri.parse('https://example.com/a.json'),
      ),
      isTrue,
    );
  });

  test('isAllowedRulesetUrl rejects plain http', () {
    expect(
      DeepLinkHandler.isAllowedRulesetUrl(
        Uri.parse('http://example.com/a.json'),
      ),
      isFalse,
    );
  });

  test('isAllowedRulesetUrl rejects private and loopback hosts', () {
    for (final host in [
      '127.0.0.1',
      'localhost',
      '10.0.0.1',
      '192.168.1.1',
      '172.16.0.1',
      '169.254.169.254',
    ]) {
      expect(
        DeepLinkHandler.isAllowedRulesetUrl(
          Uri.parse('https://$host/rules.json'),
        ),
        isFalse,
        reason: host,
      );
    }
  });

  test('isPublicRulesetAddress rejects non-public address ranges', () {
    for (final host in [
      '0.0.0.0',
      '100.64.0.1',
      '198.18.0.1',
      '224.0.0.1',
      '255.255.255.255',
      '::',
      '::1',
      '::ffff:127.0.0.1',
      'fc00::1',
      'fe80::1',
      'ff02::1',
    ]) {
      expect(
        DeepLinkHandler.isPublicRulesetAddress(InternetAddress.tryParse(host)!),
        isFalse,
        reason: host,
      );
    }
    expect(
      DeepLinkHandler.isPublicRulesetAddress(
        InternetAddress.tryParse('8.8.8.8')!,
      ),
      isTrue,
    );
    expect(
      DeepLinkHandler.isPublicRulesetAddress(
        InternetAddress.tryParse('2606:4700:4700::1111')!,
      ),
      isTrue,
    );
  });

  test('isVpnControlHost recognizes connection commands', () {
    expect(DeepLinkHandler.isVpnControlHost('connect'), isTrue);
    expect(DeepLinkHandler.isVpnControlHost('toggle'), isTrue);
    expect(DeepLinkHandler.isVpnControlHost('import'), isFalse);
  });

  test('vpnCommandFromHost maps hosts to commands', () {
    expect(
      DeepLinkHandler.vpnCommandFromHost('connect'),
      VpnDeepLinkCommand.connect,
    );
    expect(
      DeepLinkHandler.vpnCommandFromHost('disconnect'),
      VpnDeepLinkCommand.disconnect,
    );
  });
}
