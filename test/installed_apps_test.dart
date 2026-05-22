import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidtunnel/core/installed_apps.dart';

void main() {
  test('prioritizes selected apps while preserving order within groups', () {
    final apps = [
      _app('Alpha', 'app.alpha'),
      _app('Beta', 'app.beta'),
      _app('Gamma', 'app.gamma'),
      _app('Delta', 'app.delta'),
    ];

    final sorted = prioritizeSelectedInstalledApps(apps, {
      'app.gamma',
      'app.beta',
    });

    expect(sorted.map((app) => app.packageName), [
      'app.beta',
      'app.gamma',
      'app.alpha',
      'app.delta',
    ]);
  });
}

InstalledApp _app(String name, String packageName) {
  return InstalledApp(
    name: name,
    packageName: packageName,
    isSystem: false,
    iconPng: Uint8List(0),
  );
}
