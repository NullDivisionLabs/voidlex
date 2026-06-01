# libxray.so

The native Xray binary, packaged as a `.so` so the Android package manager
extracts it into `nativeLibraryDir` (where executables are runnable even on
no-exec data partitions). `XrayRuntime.resolveBinary()` finds it there.

The checked-in binaries are built from Xray-core `v26.5.9` (unmodified
upstream sources, `-ldflags="-s -w"` applied so #40 below is already in
effect). Exact build commands, NDK version, and SHA-256 hashes are recorded
in `THIRD_PARTY_NOTICES.md`.

## Build optimisations (deferred Group-3 items #39 / #40)

The pre-built binaries shipped in this directory are stock builds of
upstream xray-core. There are two easy wins available when you control the
build pipeline:

### #39 — Slim build with only the protocols this app uses

Void//Lex only dials `vless` and `hysteria2` outbounds (the latter via
sing-box's libbox, not xray). A custom xray-core build with `-tags` set
to the actual feature flags we touch drops the binary size from ~36 MB
to ~14–18 MB:

```bash
# from a checkout of github.com/XTLS/Xray-core
go build -tags "with_quic with_grpc with_utls with_reality" \
    -trimpath -buildmode=pie -o libxray.so .
```

Remove tags as needed; the default build pulls in shadowsocks, trojan,
vmess, wireguard, ssh probe, sniffing for every supported app — all
unused by this client.

### #40 — Strip debug symbols on release

The Gradle config currently sets
`packaging.jniLibs.keepDebugSymbols += "**/libxray.so"`, which preserves
the (~10 MB) debug symbol table inside the APK so crash backtraces stay
useful. For a public release where stack-trace fidelity isn't required:

```bash
# Strip in-place — chops ~30% off the size
llvm-strip --strip-unneeded libxray.so

# Or build with -ldflags
go build -ldflags "-s -w" ...
```

Combine both and the binary lands around 10–12 MB. Together with the
already-merged `-PslimGeoData=true` flag (drops the ~28 MB geo bundle)
that's a ~50 MB reduction in APK size — but each step is a CI policy
decision (build provenance vs. binary size), so we don't apply them
automatically.
