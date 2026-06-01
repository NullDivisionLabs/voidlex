enum RunMode {
  tun('tun'),
  proxyOnly('proxyOnly');

  const RunMode(this.wireName);
  final String wireName;

  static RunMode parse(String? raw) {
    final normalized = raw?.trim();
    for (final mode in values) {
      if (mode.wireName == normalized || mode.name == normalized) {
        return mode;
      }
    }
    return RunMode.tun;
  }
}
