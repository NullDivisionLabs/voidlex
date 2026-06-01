import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:voidlex/core/app_locale.dart';

void main() {
  group('resolveEffectiveLocale', () {
    test('english forces en', () {
      expect(
        resolveEffectiveLocale(
          preference: AppLocalePreference.english,
          systemLocale: const Locale('ru'),
        ),
        const Locale('en'),
      );
    });

    test('russian forces ru', () {
      expect(
        resolveEffectiveLocale(
          preference: AppLocalePreference.russian,
          systemLocale: const Locale('en', 'US'),
        ),
        const Locale('ru'),
      );
    });

    test('system uses ru when primary language is Russian', () {
      expect(
        resolveEffectiveLocale(
          preference: AppLocalePreference.system,
          systemLocale: const Locale('ru', 'RU'),
        ),
        const Locale('ru'),
      );
    });

    test('system uses en for non-Russian primary language', () {
      expect(
        resolveEffectiveLocale(
          preference: AppLocalePreference.system,
          systemLocale: const Locale('de', 'DE'),
        ),
        const Locale('en'),
      );
    });

    test('system treats ru script variants as Russian', () {
      expect(
        resolveEffectiveLocale(
          preference: AppLocalePreference.system,
          systemLocale: Locale.fromSubtags(languageCode: 'ru'),
        ),
        const Locale('ru'),
      );
    });
  });

  group('AppLocalePreference.parse', () {
    test('defaults and trims', () {
      expect(AppLocalePreference.parse(null), AppLocalePreference.system);
      expect(AppLocalePreference.parse(''), AppLocalePreference.system);
      expect(AppLocalePreference.parse(' en '), AppLocalePreference.english);
      expect(AppLocalePreference.parse('ru'), AppLocalePreference.russian);
      expect(AppLocalePreference.parse('system'), AppLocalePreference.system);
    });
  });
}
