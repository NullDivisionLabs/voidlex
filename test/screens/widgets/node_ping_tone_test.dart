import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/screens/widgets/node_row.dart';

void main() {
  group('NodePingTone.fromRaw', () {
    test('classifies fast / slow / very slow buckets', () {
      expect(NodePingTone.fromRaw('42'), NodePingTone.ok);
      expect(NodePingTone.fromRaw('179'), NodePingTone.ok);
      expect(NodePingTone.fromRaw('180'), NodePingTone.warn);
      expect(NodePingTone.fromRaw('299'), NodePingTone.warn);
      expect(NodePingTone.fromRaw('300'), NodePingTone.err);
      expect(NodePingTone.fromRaw('900'), NodePingTone.err);
    });

    test('timeouts and ERR collapse to err', () {
      expect(NodePingTone.fromRaw('ERR'), NodePingTone.err);
      expect(NodePingTone.fromRaw('>5s'), NodePingTone.err);
      expect(NodePingTone.fromRaw('>10'), NodePingTone.err);
    });

    test('empty / sentinel / non-numeric collapses to none', () {
      expect(NodePingTone.fromRaw(''), NodePingTone.none);
      expect(NodePingTone.fromRaw('--'), NodePingTone.none);
      expect(NodePingTone.fromRaw(null), NodePingTone.none);
      expect(NodePingTone.fromRaw('???'), NodePingTone.none);
    });
  });

  group('NodePingTone.shortLabel', () {
    test('strips units, keeps leading digit run', () {
      expect(NodePingTone.shortLabel('42 ms'), '42');
      expect(NodePingTone.shortLabel('  138  '), '138');
    });

    test('collapses timeouts and errors to N/A', () {
      expect(NodePingTone.shortLabel('ERR'), 'N/A');
      expect(NodePingTone.shortLabel('>5s'), 'N/A');
    });

    test('renders empty / sentinel as em dash', () {
      expect(NodePingTone.shortLabel(''), '—');
      expect(NodePingTone.shortLabel('--'), '—');
      expect(NodePingTone.shortLabel(null), '—');
    });
  });
}
