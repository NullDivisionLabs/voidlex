# Void//Lex 1.1.8-beta

Changes since 1.1.2-beta.

Important Updates:
• Version bumped to 1.1.8-beta+1.
• Updated bundled cores to Xray-core 26.7.28 and stable sing-box/libbox 1.14.0.
• Added a full node JSON editor with line numbers, syntax validation, error-line highlighting, formatting, line wrapping, and error navigation; switching between JSON and forms preserves supported advanced fields.
• Added outbound URL latency tests with configurable HTTP/HTTPS targets, proxy authentication, warm-up requests, cancellation, and isolated probe runtimes that do not interrupt the active VPN.
• Added a persistent TCP/URL diagnostic selector, separate per-node diagnostic tools, and an optional alternate test in node menus; active-connection latency reflects the current tunnel or two-hop chain.
• Expanded XHTTP tuning with padding obfuscation, placement/key/header/method controls, session ID and sequence placement, CDN/WAF compatibility presets, and preservation of raw XHTTP settings during import/export.
• Added optional Safari 16.0, Chrome 120, and iOS 14 TLS fingerprints; saved and imported fingerprint choices remain available when the extra profiles are hidden.
• Improved VPN recovery after underlying-network changes and offline periods, added a reconnecting status, and tightened libbox startup readiness and partial-runtime cleanup.
• Improved Hysteria2/NaiveProxy direct libbox configuration and guards for unsupported TUN engines, proxy-only mode, and two-hop chains.
• Hardened imports with payload limits, explicit warnings for HTTP subscriptions, and HTTPS-only public-host ruleset downloads with DNS and redirect validation.
• Added consent-gated VPN control deep links for connect, disconnect, toggle, and restart, with an opt-in setting for automation.
• Improved server/subscription persistence and secure-storage fallback recovery, subscription redirects, and client identification using the installed app version.
• Refined the home screen with collapsible connection widgets and a compact-start preference; improved compact Android widgets, node/subscription reordering, and Android TV interactions.
• Reorganized diagnostic settings, expanded the FAQ, added tunnel-setting explanations and unsaved-change prompts, and validated routing-rule port expressions.
• Improved GeoData download/import size limits and Xray process startup/config-test handling; expanded Flutter and Android regression coverage for the updated flows.

Built from the standard development `main` at
`e82ed3b981a8f65f9b5c340adf2095866d561cf7`, with the release version and
documentation updated separately in `VoidLex-Release`.

Build verification (2026-10-01): Flutter analysis passed; 306 Flutter tests and
122 Android/Kotlin tests passed. One real-Xray integration test was skipped
because `XRAY_TEST_BINARY` was not supplied. Both release APK signatures,
application ID (`com.voidlex.voidlex`), version (`1.1.8-beta`), ABI contents,
and packaged core provenance were verified. Live-device connections were not
tested.
