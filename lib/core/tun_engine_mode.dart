enum TunEngineMode {
  libbox,
  xray;

  String get wireName => name;

  String get label => switch (this) {
    TunEngineMode.libbox => 'libbox',
    TunEngineMode.xray => 'Xray',
  };

  String get description => switch (this) {
    TunEngineMode.libbox => 'Stable Android VpnService bridge',
    TunEngineMode.xray => 'Experimental Xray TUN path',
  };

  static TunEngineMode parse(String? raw) {
    for (final mode in TunEngineMode.values) {
      if (mode.wireName == raw) return mode;
    }
    return TunEngineMode.libbox;
  }
}
