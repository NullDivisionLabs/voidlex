import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/ping_label.dart';

void main() {
  group('isPingDisplayNa', () {
    test('timeouts and ERR are N/A', () {
      expect(isPingDisplayNa('ERR'), isTrue);
      expect(isPingDisplayNa('>5s'), isTrue);
      expect(isPingDisplayNa('>10'), isTrue);
    });

    test('numeric and empty pings are not N/A', () {
      expect(isPingDisplayNa('42'), isFalse);
      expect(isPingDisplayNa(''), isFalse);
      expect(isPingDisplayNa('--'), isFalse);
      expect(isPingDisplayNa(null), isFalse);
    });
  });
}
