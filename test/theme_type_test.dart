import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    VoidType.useRussianPrimary = false;
  });

  test('uses Manrope as the primary family for Russian UI', () {
    VoidType.useLocale(const Locale('ru'));

    expect(VoidType.sans().fontFamily, VoidType.russianSansFamily);
    expect(VoidType.mono().fontFamily, VoidType.russianSansFamily);
  });

  test('keeps Geist primary family outside Russian UI', () {
    VoidType.useLocale(const Locale('en'));

    expect(VoidType.sans().fontFamily, isNot(VoidType.russianSansFamily));
    expect(VoidType.mono().fontFamily, isNot(VoidType.russianSansFamily));
    expect(
      VoidType.sans().fontFamilyFallback,
      contains(VoidType.russianSansFamily),
    );
    expect(
      VoidType.mono().fontFamilyFallback,
      contains(VoidType.russianSansFamily),
    );
  });
}
