import 'dart:async';

import 'package:flutter/services.dart';

/// Bridges OS-level `voidtunnel://...` deep links from the platform into
/// Dart. Mirrors the [VpnEventBridge] singleton pattern on Android: the
/// native side buffers links until Flutter listens, and replays them on
/// connect so cold-launch links are never dropped.
///
/// Cold-launch case (app started by tapping a link): the URL is also
/// retrievable once via [consumeInitial]; safe to call together with the
/// event stream — the bridge dedupes by emitting only through the stream
/// (the cold link is exposed strictly via the explicit one-shot method so
/// callers can choose which path to consume).
class DeepLinkChannel {
  DeepLinkChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _method = methodChannel ?? const MethodChannel('void.deeplink'),
       _events = eventChannel ?? const EventChannel('void.deeplink/events');

  final MethodChannel _method;
  final EventChannel _events;
  Stream<String>? _cachedStream;

  /// Stream of incoming `voidtunnel://...` URLs received while Flutter is
  /// running. Cached so multiple subscribers share one platform listener.
  Stream<String> get incomingLinks {
    return _cachedStream ??= _events
        .receiveBroadcastStream()
        .map((event) => event is String ? event : event?.toString() ?? '')
        .where((link) => link.isNotEmpty);
  }

  /// Returns the URL the app was launched with, if any, and clears the
  /// native-side buffer so subsequent calls return null. No-op (returns
  /// null) on platforms without a native bridge.
  Future<String?> consumeInitial() async {
    try {
      return await _method.invokeMethod<String?>('consumeInitial');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
