# Third-party notices

Void//Lex application code is licensed under the GNU General Public License
version 3.0 or later. See `LICENSE`.

This file records bundled or directly integrated third-party components. These
notices do not relicense third-party code; every component remains under its
own upstream license.

## Native networking components

### sing-box / libbox

- Local artifact: `android/app/libs/libbox.aar`
- Size: `86,833,563` bytes
- SHA-256: `513D487735C5CF80196C761E7C80BF63FAB4CA3AC7BFB2E9305E7FDA7EF24B42`
- Upstream project: https://github.com/SagerNet/sing-box
- Upstream tag: `v1.14.0`
- Upstream commit: `0b8995879f29a9b98ee027bc17b75e101445b238`
- Upstream license: GNU GPL v3.0 or later
- Android ABIs in this artifact: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- Go: `go1.26.2 windows/amd64`
- Java for build: Eclipse Temurin `17.0.20+8`
- Android NDK: `28.2.13676358` (`r28c`)
- gomobile/gobind: `github.com/sagernet/gomobile@v0.1.13`
- Android API: `24`
- Upstream build tags include `with_quic` and `with_naive_outbound` (plus the
  remaining tags selected by `cmd/internal/build_libbox` at the recorded tag).

Build commands from the checked-out upstream tag:

```powershell
go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.13
go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.13
$env:JAVA_HOME='<OpenJDK 17 home>'
$env:ANDROID_HOME='<Android SDK root>'
$env:ANDROID_NDK_HOME="$env:ANDROID_HOME\ndk\28.2.13676358"
go run ./cmd/internal/build_libbox -target android -platform android/arm,android/arm64,android/amd64
```

APK/AAB releases that include this artifact must provide the corresponding
source code for the exact libbox build and for the GPL-covered combined work,
including local modifications and build scripts needed to reproduce the shipped
object code.

### Xray-core / libxray

- Local artifacts:
  - `android/app/src/main/jniLibs/arm64-v8a/libxray.so`
    - SHA-256: `5AAB1C7153A763DCD6710FAD10EB2D17EC295206CA6F24B9C9F0A462D93EC3B9`
  - `android/app/src/main/jniLibs/armeabi-v7a/libxray.so`
    - SHA-256: `B4101D642D7E93F7D992CD081DBACA9510B3FFEDFD38BE88E77B2F3DF2BEBC5F`
  - `android/app/src/main/jniLibs/x86_64/libxray.so`
    - SHA-256: `194BA0992F4F48A9394F270F51F130FE1CE16E05FDFB67B24B3730A129EBAA8D`
- Upstream project: https://github.com/XTLS/Xray-core
- Upstream tag: `v26.7.28`
- Upstream commit: `5ca6f4b7d4dc20a881d4330e498892697627ec0c`
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
go build -trimpath -buildvcs=false -buildmode=pie -gcflags='all=-l=4' -ldflags='-X github.com/xtls/xray-core/core.build=5ca6f4b -s -w -buildid= -checklinkname=0' -o libxray.so ./main

$env:GOOS='android'
$env:GOARCH='arm'
$env:GOARM='7'
$env:CGO_ENABLED='1'
$env:ANDROID_HOME='<Android SDK root>'
$env:ANDROID_NDK_HOME="$env:ANDROID_HOME\ndk\28.2.13676358"
$env:CC="$env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\bin\armv7a-linux-androideabi23-clang.cmd"
go build -trimpath -buildvcs=false -buildmode=pie -gcflags='all=-l=4' -ldflags='-X github.com/xtls/xray-core/core.build=5ca6f4b -s -w -buildid= -checklinkname=0' -o libxray.so ./main

$env:GOOS='android'
$env:GOARCH='amd64'
$env:CGO_ENABLED='1'
$env:ANDROID_HOME='<Android SDK root>'
$env:ANDROID_NDK_HOME="$env:ANDROID_HOME\ndk\28.2.13676358"
$env:CC="$env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\bin\x86_64-linux-android23-clang.cmd"
go build -trimpath -buildvcs=false -buildmode=pie -gcflags='all=-l=4' -ldflags='-X github.com/xtls/xray-core/core.build=5ca6f4b -s -w -buildid= -checklinkname=0' -o libxray.so ./main
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
