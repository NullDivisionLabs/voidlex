import 'models/server_config.dart';

/// Returns a list of development/testing servers seeded on first launch.
///
/// By default this is empty — the production build ships without bundled
/// credentials. Developers who want to pre-seed their own server can create
/// `lib/core/dev_servers_local.dart` (gitignored) that exposes a
/// `List<ServerConfig> devServers()` function and import it from here.
List<ServerConfig> defaultDevServers() => const <ServerConfig>[];
