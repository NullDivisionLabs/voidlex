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

  test('isVpnControlHost recognizes connection commands', () {
    expect(DeepLinkHandler.isVpnControlHost('connect'), isTrue);
    expect(DeepLinkHandler.isVpnControlHost('toggle'), isTrue);
    expect(DeepLinkHandler.isVpnControlHost('import'), isFalse);
  });
}
