# ──────────────────────────────────────────────────────────
# ProGuard / R8 rules for sing-box (libbox.aar) integration
# ──────────────────────────────────────────────────────────

# Aggressive optimisation: let R8 widen package-private accessors to
# public when that enables inlining, and collapse all obfuscated classes
# into a single anonymous package ("") to shrink the DEX class name
# table. Together these typically trim 2–4% off the release DEX size.
# Safe here because we have no plugin host that introspects package
# names at runtime.
-allowaccessmodification
-repackageclasses ''

# Keep all Go mobile (gomobile) JNI bridge classes.
-keep class go.** { *; }
-dontwarn go.**

# Keep all sing-box libbox bindings — these are called by name from the Go
# runtime through reflection; renaming will crash at openTun().
-keep class io.nekohasekai.libbox.** { *; }
-dontwarn io.nekohasekai.libbox.**

# Our PlatformInterface / CommandServerHandler implementations and the
# foreground service are entry points for libbox callbacks and Intent
# routing — both classes of caller bypass the regular Kotlin call graph
# and would be considered unreachable by R8 without explicit keeps.
-keep class com.voidtunnel.voidtunnel.VoidVpnService { *; }
-keep class com.voidtunnel.voidtunnel.LibboxTunRuntime { *; }
-keep class com.voidtunnel.voidtunnel.LibboxLocalDnsTransport { *; }
-keep class com.voidtunnel.voidtunnel.XrayNativeProcess { *; }

# The Quick Settings tile is referenced by AndroidManifest only — keep it
# whole so the OS's TileService binding doesn't NoSuchMethod at runtime.
-keep class com.voidtunnel.voidtunnel.VoidTunnelTileService { *; }

# androidx.security.crypto pulls in Tink (Google's crypto library) which
# uses reflection-driven keyset parsing. The library publishes its own
# consumer rules, but they only cover the public API; we additionally keep
# the Tink protobuf classes to silence R8 warnings on missing references
# from the optional cleartext-protocol paths we don't use.
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
