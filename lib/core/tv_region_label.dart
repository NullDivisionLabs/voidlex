/// Best-effort mapping from a server-name prefix (e.g. `ams-3.void.net`) to
/// a country/city label such as `NL · AMSTERDAM`. ServerConfig does not
/// store geography, so this lookup is the cheapest way to surface "where
/// the exit is" on the TV layout without a network call or a UI change.
///
/// The mapping is intentionally rendered in lighter type by callers — if
/// a user named their node `home-1.example.net`, the prefix lookup will
/// return the uppercased segment, which reads as a hint, not a claim.
library;

class TvRegionLabel {
  TvRegionLabel._();

  static const Map<String, String> _byPrefix = <String, String>{
    'ams': 'NL · AMSTERDAM',
    'rtm': 'NL · ROTTERDAM',
    'fra': 'DE · FRANKFURT',
    'ber': 'DE · BERLIN',
    'mun': 'DE · MUNICH',
    'lon': 'UK · LONDON',
    'man': 'UK · MANCHESTER',
    'par': 'FR · PARIS',
    'mar': 'FR · MARSEILLE',
    'mad': 'ES · MADRID',
    'bcn': 'ES · BARCELONA',
    'mil': 'IT · MILAN',
    'rom': 'IT · ROME',
    'zur': 'CH · ZURICH',
    'gva': 'CH · GENEVA',
    'sto': 'SE · STOCKHOLM',
    'osl': 'NO · OSLO',
    'hel': 'FI · HELSINKI',
    'cph': 'DK · COPENHAGEN',
    'war': 'PL · WARSAW',
    'pra': 'CZ · PRAGUE',
    'vie': 'AT · VIENNA',
    'bru': 'BE · BRUSSELS',
    'dub': 'IE · DUBLIN',
    'ist': 'TR · ISTANBUL',
    'mow': 'RU · MOSCOW',
    'led': 'RU · ST PETERSBURG',
    'kbp': 'UA · KYIV',
    'sgp': 'SG · SINGAPORE',
    'hkg': 'HK · HONG KONG',
    'tok': 'JP · TOKYO',
    'osa': 'JP · OSAKA',
    'sel': 'KR · SEOUL',
    'tpe': 'TW · TAIPEI',
    'bom': 'IN · MUMBAI',
    'del': 'IN · DELHI',
    'syd': 'AU · SYDNEY',
    'mel': 'AU · MELBOURNE',
    'akl': 'NZ · AUCKLAND',
    'nyc': 'US · NEW YORK',
    'lax': 'US · LOS ANGELES',
    'sjc': 'US · SAN JOSE',
    'sfo': 'US · SAN FRANCISCO',
    'sea': 'US · SEATTLE',
    'chi': 'US · CHICAGO',
    'dal': 'US · DALLAS',
    'mia': 'US · MIAMI',
    'iad': 'US · WASHINGTON',
    'tor': 'CA · TORONTO',
    'yyz': 'CA · TORONTO',
    'yvr': 'CA · VANCOUVER',
    'mex': 'MX · MEXICO CITY',
    'sao': 'BR · SAO PAULO',
    'gru': 'BR · SAO PAULO',
    'eze': 'AR · BUENOS AIRES',
    'jhb': 'ZA · JOHANNESBURG',
    'dxb': 'AE · DUBAI',
    'tlv': 'IL · TEL AVIV',
  };

  /// Returns a human label for [serverName], using the leading dotted /
  /// dash / underscore segment as the prefix key. Falls back to the
  /// uppercased prefix when nothing matches, and to an em dash when the
  /// name is empty.
  static String regionFor(String? serverName) {
    final raw = (serverName ?? '').trim();
    if (raw.isEmpty) return '—';
    final segments = raw.split(RegExp(r'[.\-_]'));
    final leading = segments.first.trim().toLowerCase();
    if (leading.isEmpty) return raw.toUpperCase();
    final byExact = _byPrefix[leading];
    if (byExact != null) return byExact;
    // Try the first three letters as a fallback — many naming schemes
    // append a digit (e.g. `ams3.void.net` rather than `ams-3.void.net`).
    if (leading.length > 3) {
      final byHead = _byPrefix[leading.substring(0, 3)];
      if (byHead != null) return byHead;
    }
    return leading.toUpperCase();
  }
}
