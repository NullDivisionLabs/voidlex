# Void//Lex Checkpoint

Date: 2026-09-03

## Current Status

Void//Lex now ships the stable sing-box/libbox `1.14.0` Android API 24 AAR,
built from signed upstream commit
`0b8995879f29a9b98ee027bc17b75e101445b238`. App version
App version is now `1.1.7-beta+1`; Xray-core remains `26.7.28`.

## Added In This Checkpoint

- Rebuilt the main (non-legacy) `libbox.aar` for `android/arm`,
  `android/arm64`, and `android/amd64` with Temurin `17.0.20+8`, Go `1.26.2`,
  NDK `r28c`, and gomobile/gobind `v0.1.13`. Size, SHA-256, exact tag,
  commit, and reproduction command are recorded in `THIRD_PARTY_NOTICES.md`.
- Adapted the Android platform interface for the stable API: notification
  cancellation is a safe no-op and interface data now includes IPv4/IPv6
  gateways taken from Android default routes.
- Pinned libbox TUN routing to `auto_route=true`, `strict_route=false`, and
  `dns_mode=hijack`.
- Startup now waits up to three seconds for a successful libbox default-interface
  update. A timeout tears down partial TUN/runtime resources and publishes the
  localized `vpnLibboxNetworkUnavailable` error instead of `connected`.
- Settings → About reads the packaged version from `Libbox.version()` through
  the existing service method channel for both mobile and TV layouts. Loading
  and failure states display `—`.

## Verification

- `flutter gen-l10n` completed successfully.
- `dart analyze` → no issues.
- `flutter test` → 241 passed; the existing real-Xray integration test was
  skipped because no host-runnable `XRAY_TEST_BINARY` was supplied.
- `./gradlew.bat :app:testDebugUnitTest` on Temurin `17.0.20+8` →
  `BUILD SUCCESSFUL`.
- `./gradlew.bat :app:assembleDebug` on Temurin `17.0.20+8` →
  `BUILD SUCCESSFUL`.
- The debug APK contains `libbox.so` and `libxray.so` for `arm64-v8a`,
  `armeabi-v7a`, and `x86_64`.
- Packaged AAR SHA-256 matches `THIRD_PARTY_NOTICES.md`:
  `513D487735C5CF80196C761E7C80BF63FAB4CA3AC7BFB2E9305E7FDA7EF24B42`.
- `git diff --check` → clean (line-ending conversion warnings only).

Hardware/device acceptance remains a manual release gate and was intentionally
not run from the workstation test suite.

## Previous Checkpoint (2026-05-23)

## Current Status

`armeabi-v7a` is now a first-class shipped ABI alongside `arm64-v8a` and
`x86_64`, primarily so the app installs and runs the VPN core on 32-bit
Android TV devices.

## Added In This Checkpoint

- `armeabi-v7a` `libxray.so` rebuilt from upstream Xray-core `v26.5.9` with the
  same toolchain documented for arm64/amd64 (NDK `r28c`, Go `1.26.2`).
  SHA-256 and the armv7 build command are recorded in
  `THIRD_PARTY_NOTICES.md`.
- `libbox.aar` rebuilt from upstream sing-box `v1.14.0-alpha.24` for
  `android/arm,android/arm64,android/amd64`. New AAR SHA-256 is recorded in
  `THIRD_PARTY_NOTICES.md`; build is otherwise byte-for-byte the same provenance
  (Temurin `17.0.19+10`, gomobile/gobind `v0.1.12`, NDK `r28c`).
- `android/app/build.gradle.kts`: `shippedAbis` extended to include
  `armeabi-v7a`, the `excludes += "lib/armeabi-v7a/**"` packaging filter
  removed, and the policy comments updated to reflect the new three-ABI set.

## Verified

- `.\gradlew.bat :app:testDebugUnitTest` → `BUILD SUCCESSFUL`
- `flutter build apk --debug` → `app-debug.apk` contains
  `lib/arm64-v8a`, `lib/armeabi-v7a`, and `lib/x86_64`, each with both
  `libxray.so` and `libbox.so`.

## Remaining Risks

- Live install/run on a real 32-bit Android TV (or armv7 emulator image) has
  not yet been exercised. The APK now ships the binaries, but the Xray TUN
  readiness check, libbox restart behavior, and DNS routing should still be
  spot-checked on armv7 hardware before a public release.

## Previous Checkpoint (2026-05-21)

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
