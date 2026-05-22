# Third-party notices

VoidTunnel application code is licensed under the GNU General Public License
version 3.0 or later. See `LICENSE`.

This file records bundled or directly integrated third-party components. These
notices do not relicense third-party code; every component remains under its
own upstream license.

## Native networking components

### sing-box / libbox

- Local artifact: `android/app/libs/libbox.aar`
- SHA-256: `FCFC6CDBA4E160160FAE3C878EF7E2ED9A8E419ED6B4C698869306F7E8CAC67C`
- Upstream project: https://github.com/SagerNet/sing-box
- Upstream tag: `v1.14.0-alpha.24`
- Upstream commit: `6b07a229185de1566a403582832df5aae8276bc0`
- Upstream license: GNU GPL v3.0 or later
- Android ABIs in this artifact: `arm64-v8a`, `x86_64`
- Go: `go1.26.2 windows/amd64`
- Java for build: Temurin `17.0.19+10`
- Android NDK: `28.2.13676358` (`r28c`)
- gomobile/gobind: `github.com/sagernet/gomobile@v0.1.12`

Build commands from the checked-out upstream tag:

```powershell
go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.12
$env:JAVA_HOME='<OpenJDK 17 home>'
$env:ANDROID_HOME='<Android SDK root>'
$env:ANDROID_NDK_HOME="$env:ANDROID_HOME\ndk\28.2.13676358"
go run ./cmd/internal/build_libbox -target android -platform android/arm64,android/amd64
```

APK/AAB releases that include this artifact must provide the corresponding
source code for the exact libbox build and for the GPL-covered combined work,
including local modifications and build scripts needed to reproduce the shipped
object code.

### Xray-core / libxray

- Local artifacts:
  - `android/app/src/main/jniLibs/arm64-v8a/libxray.so`
    - SHA-256: `15C4816996F2232A8E6EB98B1B90B7B68A553E1B61B181D9D986BB6BD5E42B10`
  - `android/app/src/main/jniLibs/x86_64/libxray.so`
    - SHA-256: `89C2B49892ACC9573607200493BE2FA188FFF561BA5398736A4F47D06861C9A0`
- Upstream project: https://github.com/XTLS/Xray-core
- Upstream tag: `v26.5.9`
- Upstream commit: `1bdb488c9ec09ea51e6899697d5b7437f3cf6eb2`
- Upstream license: Mozilla Public License 2.0
- Go: `go1.26.2 windows/amd64`
- Android NDK: `28.2.13676358` (`r28c`)

Build commands from the checked-out upstream tag:

```powershell
$env:GOOS='android'
$env:GOARCH='arm64'
$env:CGO_ENABLED='1'
$env:ANDROID_HOME='<Android SDK root>'
$env:ANDROID_NDK_HOME="$env:ANDROID_HOME\ndk\28.2.13676358"
$env:CC="$env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android23-clang.cmd"
go build -trimpath -buildvcs=false -buildmode=pie -ldflags='-s -w -buildid=' -o libxray.so ./main

$env:GOOS='android'
$env:GOARCH='amd64'
$env:CGO_ENABLED='1'
$env:ANDROID_HOME='<Android SDK root>'
$env:ANDROID_NDK_HOME="$env:ANDROID_HOME\ndk\28.2.13676358"
$env:CC="$env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\bin\x86_64-linux-android23-clang.cmd"
go build -trimpath -buildvcs=false -buildmode=pie -ldflags='-s -w -buildid=' -o libxray.so ./main
```

APK/AAB releases that include these binaries must preserve upstream notices and
make the source code for the shipped Xray-core build available. If the binaries
are built from modified Xray-core sources, the corresponding modified source
files and build instructions must be published as well.

## Bundled data

### Xray geodata

- Local artifacts:
  - `android/app/src/main/assets/xray/geoip.dat`
  - `android/app/src/main/assets/xray/geosite.dat`

When these files are bundled into a release, keep the upstream source,
generation process, and license notices for the exact geodata snapshots used by
that release.

## Fonts

### Manrope

- Local artifacts: `assets/fonts/manrope/*.ttf`
- License file: `assets/fonts/manrope/OFL.txt`
- License: SIL Open Font License 1.1

### Geist / Geist Mono

- Local artifacts: `google_fonts/*.ttf`
- Local note: `google_fonts/README.md`
- License: SIL Open Font License 1.1

## Dart, Flutter, Android, and Gradle dependencies

Dart and Flutter package dependencies are tracked in `pubspec.lock`; Android
and Gradle dependencies are tracked by the Gradle build files. Release
packaging should preserve their upstream license notices according to the
licenses of the exact dependency versions used for that release.
