import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/core/tv_region_label.dart';

void main() {
  group('TvRegionLabel.regionFor', () {
    test('maps known prefixes', () {
      expect(TvRegionLabel.regionFor('ams-3.void.net'), 'NL · AMSTERDAM');
      expect(TvRegionLabel.regionFor('fra-1.void.net'), 'DE · FRANKFURT');
      expect(TvRegionLabel.regionFor('tok-1.void.net'), 'JP · TOKYO');
    });

    test('strips digits before lookup (ams3 → ams)', () {
      expect(TvRegionLabel.regionFor('ams3.void.net'), 'NL · AMSTERDAM');
    });

    test('falls back to uppercase prefix on unknown name', () {
      expect(TvRegionLabel.regionFor('home-1.example.net'), 'HOME');
    });

    test('returns em dash for empty input', () {
      expect(TvRegionLabel.regionFor(null), '—');
      expect(TvRegionLabel.regionFor(''), '—');
      expect(TvRegionLabel.regionFor('   '), '—');
    });
  });
}
