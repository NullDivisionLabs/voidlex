import Flutter
import Foundation

/// iOS counterpart of the Android `DeepLinkBridge`. Buffers `voidtunnel://`
/// URLs emitted by the scene delegate and pushes them onto the
/// `void.deeplink/events` EventChannel. The cold-launch URL is also
/// exposed once via the `void.deeplink` MethodChannel's `consumeInitial`
/// method.
final class DeepLinkBridge: NSObject, FlutterStreamHandler {
  static let shared = DeepLinkBridge()

  private let lock = NSLock()
  private var buffer: [String] = []
  private var pendingInitial: String?
  private var sink: FlutterEventSink?

  private override init() {}

  /// Registers the method and event channels on the given binary messenger.
  /// Call once after the FlutterEngine is attached.
  func register(with messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "void.deeplink",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "consumeInitial":
        result(self.consumeInitial())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: "void.deeplink/events",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func emit(url: String, isInitial: Bool) {
    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    lock.lock()
    if isInitial {
      pendingInitial = trimmed
    }
    buffer.append(trimmed)
    if buffer.count > 8 {
      buffer.removeFirst(buffer.count - 8)
    }
    let currentSink = sink
    lock.unlock()
    if let currentSink = currentSink {
      DispatchQueue.main.async {
        currentSink(trimmed)
      }
    }
  }

  func consumeInitial() -> String? {
    lock.lock()
    defer { lock.unlock() }
    let value = pendingInitial
    pendingInitial = nil
    return value
  }

  // MARK: - FlutterStreamHandler

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    lock.lock()
    sink = events
    let pending = buffer
    lock.unlock()
    for link in pending {
      events(link)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    lock.lock()
    sink = nil
    lock.unlock()
    return nil
  }
}
