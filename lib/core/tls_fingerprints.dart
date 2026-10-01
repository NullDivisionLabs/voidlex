/// Names accepted by the packaged Xray 26.7.28 uTLS implementation.
abstract final class TlsFingerprints {
  static const standard = <String>[
    '',
    'chrome',
    'firefox',
    'safari',
    'ios',
    'android',
    'edge',
    '360',
    'qq',
    'random',
    'randomized',
  ];
  static const additional = <String>[
    'hellosafari_16_0',
    'hellochrome_120',
    'helloios_14',
  ];

  static List<String> options({
    required bool additionalEnabled,
    String current = '',
  }) {
    final result = <String>[...standard, if (additionalEnabled) ...additional];
    final value = current.trim();
    if (!result.contains(value)) result.add(value);
    return result;
  }

  static String label(String value) => switch (value) {
    'hellosafari_16_0' => 'Safari 16.0',
    'hellochrome_120' => 'Chrome 120',
    'helloios_14' => 'iOS 14',
    _ => value,
  };
}
