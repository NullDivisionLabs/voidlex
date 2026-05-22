# VoidTunnel Checkpoint

Date: 2026-05-21

## Current Status

This checkpoint captures the main-branch stabilization after adding the
libbox/Xray TUN engine selector and the refreshed UI.

## Fixed In This Checkpoint

- Cross-engine cleanup now closes the inactive runtime resources when switching
  between libbox and Xray TUN.
- External IP lookup uses the active Android VPN route directly instead of a
  missing SOCKS inbound in Xray TUN mode.
- Xray TUN config now includes DNS and routes DNS traffic through the proxy.
- Xray runtime stop/start is synchronized, and Xray TUN readiness waits for the
  Xray startup marker instead of accepting a live PID after a fixed delay.
- Stale libbox `serviceStop` callbacks are generation-checked during restarts.
- Ping error states are shown as errors in the UI, and the status line reflects
  the selected engine.
- Connection duration updates use a dedicated `ValueNotifier`, so the whole
  `HomeScreen` is no longer rebuilt every second.
- Removing the active selected server now reconnects to the next selected server
  or disconnects if no servers remain.
- Both Android TUN paths use the shared `198.18.0.1/30` address.
- Xray runtime now ships upstream Xray-core `v26.5.9`, which includes Android
  `protocol: tun` and `xray.tun.fd` support without a local patch.
- libbox AAR rebuilt from upstream sing-box `v1.14.0-alpha.24` (no local
  patches). Build provenance — commit, Go/NDK versions, exact commands and
  SHA-256 — is recorded in `THIRD_PARTY_NOTICES.md`.
- Settings → About now surfaces the libbox version alongside the xray-core
  version; xray-core string updated from the previous `26.3.27` placeholder
  to the actually-shipped `26.5.9`.

## Verified

- `.\gradlew.bat :app:testDebugUnitTest`
- `dart analyze lib/core/vpn_controller.dart lib/screens/home_screen.dart lib/screens/settings_screen.dart`
- `dart format`
- `git diff --check`

## Remaining Risks

- Xray TUN readiness is based on the Xray startup log marker, not a packet-level
  health check through the TUN device.
- Emulator/device QA is still needed for live cross-engine switching, DNS, and
  connected/disconnected event behavior.
- The local folder `.claude/worktrees/frosty-brown-8dc865` may remain on disk if
  another process keeps it open, but it is ignored and no longer tracked.
