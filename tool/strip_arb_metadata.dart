// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main() {
  final en = File('lib/l10n/app_en.arb');
  final raw = json.decode(en.readAsStringSync()) as Map<String, dynamic>;
  final ru = <String, dynamic>{'@@locale': 'ru'};
  for (final e in raw.entries) {
    if (e.key.startsWith('@')) continue;
    ru[e.key] = e.value;
  }
  File('lib/l10n/app_ru.arb').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(ru),
  );
  print('Wrote ${ru.length} keys');
}
