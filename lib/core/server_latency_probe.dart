import 'dart:async';
import 'dart:io';

import 'models/server_config.dart';

class LatencyProbeTarget {
  const LatencyProbeTarget._({this.host, this.port});

  factory LatencyProbeTarget.custom({required String host, required int port}) {
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      throw ArgumentError.value(host, 'host', 'Host must not be empty.');
    }
    if (!_isValidPort(port)) {
      throw ArgumentError.value(port, 'port', 'Port is out of range.');
    }
    return LatencyProbeTarget._(host: normalizedHost, port: port);
  }

  static const serverEndpoint = LatencyProbeTarget._();
  static const defaultCustomPort = 443;

  final String? host;
  final int? port;

  bool get usesServerEndpoint => host == null;

  String encode() {
    if (usesServerEndpoint) return '';
    return '${_formatHost(host!)}:$port';
  }

  _LatencyProbeEndpoint _resolve(ServerConfig server) {
    if (usesServerEndpoint) {
      return _LatencyProbeEndpoint(server.address, server.port);
    }
    return _LatencyProbeEndpoint(host!, port!);
  }

  bool hasSameConfiguration(LatencyProbeTarget other) {
    return host == other.host && port == other.port;
  }

  static LatencyProbeTarget decode(String? raw) {
    return tryParse(raw ?? '') ?? serverEndpoint;
  }

  static LatencyProbeTarget? tryParse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return serverEndpoint;

    // Reject trailing ":" (e.g. "example.com:") so a typo doesn't silently
    // collapse to the default port via Uri's lenient parsing.
    if (value.endsWith(':')) return null;

    final hasExplicitScheme = RegExp(
      r'^[a-zA-Z][a-zA-Z0-9+.-]*://',
    ).hasMatch(value);
    if (hasExplicitScheme) {
      final uri = Uri.tryParse(value);
      if (uri == null) return null;
      return _fromUri(uri);
    }

    final uri = Uri.tryParse('tcp://$value');
    if (uri == null) return null;
    return _fromUri(uri);
  }

  static LatencyProbeTarget? _fromUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isNotEmpty &&
        scheme != 'http' &&
        scheme != 'https' &&
        scheme != 'tcp') {
      return null;
    }
    // Reject anything beyond a bare host[:port] target — userinfo, paths,
    // query and fragment have no meaning for a TCP latency probe and would
    // otherwise be silently dropped (e.g. "user@evil.com" parsed as
    // "evil.com").
    if (uri.userInfo.isNotEmpty) return null;
    if (uri.hasQuery || uri.hasFragment) return null;
    if (uri.path.isNotEmpty && uri.path != '/') return null;
    final host = uri.host.trim();
    if (host.isEmpty || host.contains(RegExp(r'\s'))) return null;
    final port = uri.hasPort
        ? uri.port
        : (scheme == 'http' ? 80 : defaultCustomPort);
    if (!_isValidPort(port)) return null;
    return LatencyProbeTarget.custom(host: host, port: port);
  }

  static bool _isValidPort(int port) => port >= 1 && port <= 65535;

  static String _formatHost(String host) {
    if (host.contains(':') && !host.startsWith('[')) return '[$host]';
    return host;
  }

  @override
  bool operator ==(Object other) {
    return other is LatencyProbeTarget && hasSameConfiguration(other);
  }

  @override
  int get hashCode => Object.hash(host, port);
}

class _LatencyProbeEndpoint {
  const _LatencyProbeEndpoint(this.host, this.port);

  final String host;
  final int port;
}

class ServerLatencyProbe {
  const ServerLatencyProbe({
    this.attemptsPerAddress = 2,
    // Hard 1500 ms ceiling on Socket.connect. Servers that don't answer the
    // TCP handshake inside that window are unusable for an interactive
    // tunnel anyway, and waiting longer just keeps the radio hot while we
    // chase dead proxies.
    this.perAddressTimeout = const Duration(milliseconds: 1500),
    this.totalTimeout = const Duration(seconds: 5),
  });

  final int attemptsPerAddress;
  final Duration perAddressTimeout;
  final Duration totalTimeout;

  static final Uri _runtimeProbeUrl = Uri.parse(
    'https://www.gstatic.com/generate_204',
  );

  Future<String> measure(
    ServerConfig server, {
    LatencyProbeTarget target = LatencyProbeTarget.serverEndpoint,
  }) async {
    final endpoint = target._resolve(server);
    final stopwatch = Stopwatch()..start();
    try {
      final addresses = await InternetAddress.lookup(
        endpoint.host,
        type: InternetAddressType.any,
      ).timeout(totalTimeout);
      if (addresses.isEmpty) return 'ERR';

      Socket? socket;
      addressLoop:
      for (final address in addresses) {
        for (var attempt = 0; attempt < attemptsPerAddress; attempt++) {
          // Keep the whole probe within totalTimeout. Without a budget the
          // worst-case cost is addresses x attemptsPerAddress x
          // perAddressTimeout, which can run several times past the advertised
          // ceiling during a latency scan. Clamp each connect to whatever time
          // is left so measure() never overshoots by more than one in-flight
          // handshake.
          final remaining = totalTimeout - stopwatch.elapsed;
          if (remaining <= Duration.zero) break addressLoop;
          final connectTimeout = remaining < perAddressTimeout
              ? remaining
              : perAddressTimeout;
          var retryable = false;
          try {
            socket = await Socket.connect(
              address,
              endpoint.port,
              timeout: connectTimeout,
            );
            final elapsed = stopwatch.elapsedMilliseconds;
            return '$elapsed ms';
          } on SocketException catch (_) {
            // Hard refusals ("connection refused", network unreachable) won't
            // resolve themselves on a retry against the same address, so we
            // move on to the next IP immediately. Retrying only wastes the
            // user's time during a latency scan.
          } on TimeoutException catch (_) {
            // Transient: packet loss or slow handshake. Worth one more shot
            // before declaring the address bad.
            retryable = true;
          } finally {
            // Single close path — if Socket.connect succeeded we own the
            // socket and must release it; if it threw, socket stays null.
            await socket?.close();
            socket = null;
          }
          if (!retryable) break;
        }
      }

      if (stopwatch.elapsed >= totalTimeout) {
        return '>5s';
      }
      return 'ERR';
    } on SocketException catch (_) {
      return 'ERR';
    } on TimeoutException catch (_) {
      return '>5s';
    } catch (_) {
      return 'ERR';
    }
  }

  Future<String?> measureViaHttpProxy({
    required String proxyHost,
    required int proxyPort,
    String? proxyUser,
    String? proxyPassword,
    Uri? url,
  }) async {
    final stopwatch = Stopwatch()..start();
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = perAddressTimeout
        ..findProxy = (_) => 'PROXY $proxyHost:$proxyPort';

      final user = proxyUser ?? '';
      final password = proxyPassword ?? '';
      if (user.isNotEmpty && password.isNotEmpty) {
        client.addProxyCredentials(
          proxyHost,
          proxyPort,
          '',
          HttpClientBasicCredentials(user, password),
        );
      }

      final request = await client
          .getUrl(url ?? _runtimeProbeUrl)
          .timeout(totalTimeout);
      request.followRedirects = false;
      request.maxRedirects = 0;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(totalTimeout);
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 400) {
        return '${stopwatch.elapsedMilliseconds} ms';
      }
      return 'ERR';
    } on TimeoutException catch (_) {
      return '>5s';
    } on SocketException catch (_) {
      return null;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
