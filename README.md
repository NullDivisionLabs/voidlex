# Void//Lex

[English](#english) · [Русский](#russian)

---

<a id="english"></a>

## English

A Flutter VPN client for Android. Device traffic is routed through a proxy powered by [Xray-core](https://github.com/XTLS/Xray-core); the on-device TUN is handled by [libbox](https://sing-box.sagernet.org/) (sing-box) or, in experimental mode, directly by Xray TUN.

Supports **VLESS** and **Hysteria2**, flexible routing (per-app, domains, IP), provider subscriptions, profile import/export, and a dedicated Android TV interface.

### About

Void//Lex is a full VPN client with its own UI — not a thin shell over a static config. Connection state, server list, routing presets, and tunnel settings are stored locally and managed from the home screen and Settings.

On Android it uses the system `VpnService`: traffic (all apps or a selected subset, depending on policy) goes through a local TUN, then into the Xray/libbox core with your routing rules.

**Shipped version:** 1.0.1-beta · **Xray-core:** 26.5.9 · **libbox (sing-box):** 1.14.0-alpha.24

### Features

#### Connection

- Single connect / disconnect control with state (preparing, connecting, connected, error).
- Pick the active node from manual servers or a subscription.
- **Exit node** — separate outbound server for chained (two-hop) setups.
- **Global proxy** — route all traffic through the VPN without per-app split (button can be hidden in settings).
- External IP after connect; optional speed in the notification.
- Auto-connect on launch, keep screen awake during a session, optional tunnel restart when settings change.

#### Protocols & transports

| Protocol | Support |
|----------|---------|
| **VLESS** | TCP, WebSocket, gRPC, HTTP, HTTPUpgrade, **xHTTP** |
| VLESS security | none, TLS, **REALITY**, **XTLS-Vision** flow |
| **Hysteria2** | Salamander obfuscation, **port hopping** |

Add servers manually, from clipboard, QR, file, `voidlex://…` deep links, or subscriptions. **Edit**, **duplicate**, **share** as a link, or **delete**. Full **profile** import/export (servers, subscriptions, routing presets).

#### Servers & subscriptions

- **Manual servers** — reorder (drag-and-drop), favorites, pin.
- **Subscriptions** — URL with auto-refresh (1 h … never), refresh on launch, ping after update.
- Subscription headers: expiry, traffic limits (upload/download/total), HWID when requested by the provider.
- Optional protection against accidental edit/delete of subscription nodes.
- **Latency probe** to the server endpoint or via local proxy; bulk scan; auto-sort by ping.

#### Routing

- **Routing presets** — multiple rule sets; “Main” applies by default, others bind to chosen servers.
- **Rules** (Xray-like): domains, IP/CIDR, ports, network (tcp/udp), protocols; outbounds: proxy, direct, block.
- Import/export rules from clipboard or file.
- **Per-app routing**: proxy-only or bypass lists, per preset.
- Installed-apps picker with search.

#### Tunnel & network

- TUN engine: **libbox** (default, stable) or **Xray TUN** (experimental).
- Packet fragmentation (length, interval, max split) and **noise** for DPI scenarios.
- **Multiplex** (TCP/XUDP connections, QUIC: reject / allow / passthrough).
- DNS: local DNS, remote resolving, Xray TUN DNS.
- Network stack: system / gVisor / mixed; IP mode: IPv4 / IPv6 / mixed; MTU; UDP block.
- Optional proxy username/password.
- **GeoIP / Geosite** — bundled `geoip.dat` & `geosite.dat` (~28 MB) or slim build with on-first-launch download (Settings → GeoData).

#### UI & platforms

- Dark and light theme; Geist / Geist Mono fonts.
- **English** and **Russian** UI (follows system locale).
- **Android TV / Google TV** — full-screen D-pad UI, same controller and subscriptions; layout: vertical, horizontal, or auto-rotate.
- In-app log journal with level filter and retention.

### Architecture (brief)

```
┌─────────────────┐     MethodChannel / EventChannel     ┌──────────────────────────┐
│  Flutter (Dart) │ ◄──────────────────────────────────► │  Android VPN Service     │
│  UI + VpnController                                  │  libbox and/or Xray JNI  │
└─────────────────┘                                      └───────────┬──────────────┘
                                                                     │
                                                            TUN → rules → outbound
```

- **Dart:** UI, VLESS/Hysteria2 parsers, repository, `VpnController` state machine.
- **Kotlin:** `VpnService`, libbox/Xray config builders, native bridges.
- **Native:** `libxray.so` (arm64-v8a, x86_64), JNI for Xray TUN mode.

### Project layout

| Path | Contents |
|------|----------|
| `lib/` | Dart UI, controllers, parsers, repositories. |
| `lib/core/vpn_controller.dart` | VPN state machine — single source of truth for the UI. |
| `lib/screens/` | Home, server/subscription editor, QR, settings, TV. |
| `android/app/src/main/kotlin/com/voidlex/voidlex/` | VPN service, libbox/Xray runtimes, MethodChannel. |
| `android/app/src/main/cpp/xray_process.cpp` | JNI launcher for Xray TUN mode. |
| `android/app/src/main/jniLibs/` | Pre-built `libxray.so` per ABI. |
| `android/app/src/main/assets/xray/` | `geoip.dat` / `geosite.dat` (exclude with `-PslimGeoData=true`). |
| `test/` | Dart unit tests (parsers, import, ping, controller). |
| `android/app/src/test/` | Kotlin unit tests (config builders, native process). |

---

<a id="russian"></a>

## Русский

VPN-клиент для Android на Flutter. Трафик устройства направляется через прокси на базе [Xray-core](https://github.com/XTLS/Xray-core); на устройстве TUN поднимается через [libbox](https://sing-box.sagernet.org/) (sing-box) или, в экспериментальном режиме, напрямую через Xray TUN.

Поддерживаются протоколы **VLESS** и **Hysteria2**, гибкая маршрутизация (по приложениям, доменам, IP), подписки провайдеров, импорт профилей и отдельный интерфейс для Android TV.

### О приложении

Void//Lex — полноценный VPN-клиент с собственным UI, а не оболочка над готовым конфигом. Состояние подключения, список узлов, пресеты маршрутизации и настройки туннеля хранятся локально и управляются с главного экрана и из «Настроек».

На Android используется системный `VpnService`: весь трафик (или выбранные приложения — по политике) проходит через локальный TUN, затем в ядро Xray/libbox с вашими правилами маршрутизации.

**Версия в сборке:** 1.0.1-beta · **Xray-core:** 26.5.9 · **libbox (sing-box):** 1.14.0-alpha.24

### Возможности

#### Подключение

- Одна кнопка подключения / отключения с отображением состояния (подготовка, подключение, активен, ошибка).
- Выбор активного узла из ручного списка или подписки.
- **Выходной туннель (exit node)** — отдельный узел для исходящего трафика в цепочке (двухступенчатый сценарий).
- **Глобальный прокси** — весь трафик через VPN без разбиения по приложениям (кнопку можно скрыть в настройках).
- Внешний IP после подключения; опционально — скорость в уведомлении.
- Автоподключение при запуске, удержание экрана включённым, перезапуск туннеля при смене настроек (по желанию).

#### Протоколы и транспорты

| Протокол | Поддержка |
|----------|-----------|
| **VLESS** | TCP, WebSocket, gRPC, HTTP, HTTPUpgrade, **xHTTP** |
| Безопасность VLESS | без TLS, TLS, **REALITY**, flow **XTLS-Vision** |
| **Hysteria2** | обфускация Salamander, **port hopping** |

Узлы добавляются вручную, из буфера, QR, файла, deep link `voidlex://…` или из подписки. **Редактирование**, **дублирование**, **экспорт** в share-ссылку, **удаление**. Импорт/экспорт **полного профиля** (узлы, подписки, пресеты).

#### Узлы и подписки

- **Ручные узлы** — порядок drag-and-drop, избранное, закрепление.
- **Подписки** — URL с автообновлением (от 1 часа до «никогда»), обновление при старте, пинг после обновления.
- Заголовки: срок действия, лимиты трафика (upload/download/total), HWID для провайдера.
- Защита подписок от случайного редактирования/удаления узлов.
- **Замер задержки** к endpoint или через локальный прокси; массовое сканирование; автосортировка по ping.

#### Маршрутизация

- **Пресеты правил** — несколько наборов; «Main» по умолчанию, остальные — для выбранных серверов.
- **Правила** (как в Xray): домены, IP/CIDR, порты, сеть (tcp/udp), протоколы; исходящие: proxy, direct, block.
- Импорт/экспорт правил из буфера или файла.
- **Маршрутизация по приложениям**: только выбранные через VPN или исключения (bypass), в рамках пресета.
- Экран выбора приложений с поиском.

#### Туннель и сеть

- Движок TUN: **libbox** (по умолчанию) или **Xray TUN** (экспериментальный).
- Фрагментация пакетов и **noise** для обхода DPI.
- **Multiplex** (TCP/XUDP, QUIC: reject / allow / passthrough).
- DNS: локальный, резолвинг на сервере, DNS для Xray TUN.
- Стек: system / gVisor / mixed; IP: IPv4 / IPv6 / mixed; MTU; блокировка UDP.
- Прокси-аутентификация при необходимости.
- **GeoIP / Geosite** — встроенные файлы (~28 MB) или slim-сборка с загрузкой при первом запуске (Настройки → GeoData).

#### Интерфейс и платформы

- Тёмная и светлая тема; шрифты Geist / Geist Mono.
- Интерфейс на **русском** и **английском** (по системному языку).
- **Android TV / Google TV** — полноэкранный UI с D-pad, те же контроллер и подписки; раскладка: вертикальная, горизонтальная, авто-поворот.
- Журнал с фильтром по уровням и сроком хранения.

### Архитектура (кратко)

```
┌─────────────────┐     MethodChannel / EventChannel     ┌──────────────────────────┐
│  Flutter (Dart) │ ◄──────────────────────────────────► │  Android VPN Service     │
│  UI + VpnController                                  │  libbox и/или Xray JNI   │
└─────────────────┘                                      └───────────┬──────────────┘
                                                                     │
                                                            TUN → правила → outbound
```

- **Dart:** UI, парсеры VLESS/Hysteria2, репозиторий, `VpnController`.
- **Kotlin:** `VpnService`, сборка конфигов libbox/Xray, мосты в нативный код.
- **Native:** `libxray.so` (arm64-v8a, x86_64), JNI для Xray TUN.

### Структура проекта

| Путь | Назначение |
|------|------------|
| `lib/` | Dart: UI, контроллеры, парсеры, репозитории. |
| `lib/core/vpn_controller.dart` | Машина состояний VPN — единый источник правды для UI. |
| `lib/screens/` | Домой, редактор узла/подписки, QR, настройки, TV. |
| `android/app/src/main/kotlin/com/voidlex/voidlex/` | VPN-сервис, libbox/Xray, MethodChannel. |
| `android/app/src/main/cpp/xray_process.cpp` | JNI-запуск Xray в режиме TUN. |
| `android/app/src/main/jniLibs/` | `libxray.so` по ABI. |
| `android/app/src/main/assets/xray/` | `geoip.dat` / `geosite.dat` (исключить: `-PslimGeoData=true`). |
| `test/` | Dart unit-тесты. |
| `android/app/src/test/` | Kotlin unit-тесты. |

---

## Build · Сборка

### Development · Разработка

```bash
flutter pub get
flutter run                       # debug build / отладочная сборка
```

### Release APK

```bash
# Per-ABI APKs for sideload. Gradle filters output to arm64-v8a/x86_64.
# APK по ABI для sideload. Gradle ограничивает сборку arm64-v8a/x86_64.
flutter build apk --release \
    --target-platform android-arm64,android-x64 \
    --split-per-abi

# Play Store bundle (Google splits per ABI server-side)
# App Bundle для Play Store
flutter build appbundle --release

# Slim build without bundled geoip/geosite (~28 MB smaller;
# download on first launch: Settings → GeoData)
# Slim-сборка без geoip/geosite (скачивание: Настройки → GeoData)
flutter build apk --release \
    --target-platform android-arm64,android-x64 \
    --split-per-abi \
    -PslimGeoData=true
```

> **EN:** `armeabi-v7a` is intentionally excluded — `libxray.so` is built only for 64-bit ABIs. See `android/app/build.gradle.kts`.
>
> **RU:** `armeabi-v7a` не собирается — `libxray.so` только для 64-bit ABI. См. `android/app/build.gradle.kts`.

### Release signing · Подпись release

**EN:** Copy `android/key.properties.example` to `android/key.properties` and fill in the keystore fields. Both `key.properties` and `*.jks` are gitignored. Without `key.properties`, release packaging fails fast. For a local smoke build only, pass `-PallowDebugReleaseSigning=true`.

**RU:** Скопируйте `android/key.properties.example` в `android/key.properties` и заполните поля. `key.properties` и `*.jks` в `.gitignore`. Без `key.properties` release-сборка падает до упаковки. Только для локальной smoke-сборки можно передать `-PallowDebugReleaseSigning=true`.

---

## Tests · Тесты

```bash
flutter test                                  # Dart
./gradlew :app:testReleaseUnitTest --console plain   # Kotlin (from android/)
```

---

## License · Лицензия

**EN:** Void//Lex application code is licensed under **GPL-3.0-or-later**; see `LICENSE`. Bundled and integrated third-party components remain under their own upstream licenses, including Xray-core under MPL-2.0 and sing-box/libbox under GPL-3.0-or-later; see `THIRD_PARTY_NOTICES.md`.

**RU:** Код приложения Void//Lex лицензируется по **GPL-3.0-or-later**; см. `LICENSE`. Встроенные и интегрированные сторонние компоненты остаются под своими upstream-лицензиями, включая Xray-core под MPL-2.0 и sing-box/libbox под GPL-3.0-or-later; см. `THIRD_PARTY_NOTICES.md`.
