// Network-dependent regression test for ServerLatencyProbe's total-time
// ceiling. It connects to a TEST-NET-1 blackhole address (192.0.2.1, reserved
// by RFC 5737) whose SYN packets are dropped on the public internet, so
// Socket.connect runs until its timeout instead of failing fast.
//
// Run explicitly on a device/host with real networking:
//   flutter test test/server_latency_probe_timeout_test.dart
//
// The assertion that matters is the elapsed-time bound: before the budget
// clamp a single blackhole address tied measure() up for ~perAddressTimeout
// (10s here); the fix caps the whole probe near totalTimeout (0.8s). On a
// network that intercepts outbound connections (some CI sandboxes answer
// instantly), the probe simply returns fast and the bound still holds — the
// test then degrades to a smoke check rather than failing falsely.
import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/server_latency_probe.dart';

void main() {
  test('measure stays within totalTimeout despite a long perAddressTimeout',
      () async {
    const probe = ServerLatencyProbe(
      attemptsPerAddress: 3,
      perAddressTimeout: Duration(seconds: 10),
      totalTimeout: Duration(milliseconds: 800),
    );
    const server = ServerConfig(
      name: 'probe',
      address: 'unused-when-target-is-custom',
      port: 1,
      uuid: '00000000-0000-0000-0000-000000000000',
      transport: VlessTransport.tcp,
      security: VlessSecurity.none,
    );
    final target = LatencyProbeTarget.custom(host: '192.0.2.1', port: 81);

    final stopwatch = Stopwatch()..start();
    final result = await probe.measure(server, target: target);
    stopwatch.stop();

    // Core guarantee: the probe never runs anywhere near perAddressTimeout.
    // Generous slack covers slow CI and DNS resolution.
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 4)),
      reason: 'measure() must honour totalTimeout, not perAddressTimeout',
    );
    // Whatever the network does, measure() always resolves to a label.
    expect(result, isNotEmpty);
  });
}
