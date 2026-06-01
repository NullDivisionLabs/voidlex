# Widget hardware test plan

Прогоните этот сценарий на реальном устройстве после `flutter build apk --debug && flutter install`. Все логи смотрите в `adb logcat`.

## Подготовка

1. Подключите устройство по USB, включите ADB.
2. Очистите старые логи:
   ```sh
   adb logcat -c
   ```
3. Запустите фильтр для widget-логов в отдельной вкладке (оставьте его открытым на всё время тестов):
   ```sh
   adb logcat -v time \
     VoidLexAppWidget:V \
     QSVpnConfigStore:V \
     VoidVpnService:V \
     LibboxTunRuntime:V \
     XrayRuntime:V \
     VpnServiceConfigParser:V \
     AndroidRuntime:E \
     flutter:W \
     *:S
   ```
   `flutter:W` подхватит Dart-исключения — мы только что починили краш
   `_ingestThroughputSample` (`Cannot remove from a fixed-length list`),
   и если он ещё где-то проявится, увидим в этой ленте.

## Как ПРАВИЛЬНО проверять «идёт трафик»

UI-индикатор скорости в приложении может **отставать или показывать ноль**,
даже когда туннель реально несёт пакеты — это отдельный subsystem на
EventChannel `vpn_speed`. Поэтому делать выводы по нему нельзя. Проверяйте
тремя независимыми способами:

1. **Браузер.** Откройте `https://api.ipify.org` или `https://ifconfig.me`.
   Должен выдать IP выбранного экзит-узла, не локальный.
2. **`adb shell` пинг.** Через ADB:
   ```sh
   adb shell ping -c 4 -W 2 1.1.1.1
   ```
   Если 0% loss — туннель пропускает icmp.
3. **Счётчик байтов на TUN.** Прямо в логе при подключённом туннеле:
   ```sh
   adb shell cat /proc/net/dev | grep tun0
   ```
   Запустите дважды с паузой 5–10 секунд. Колонки RX/TX bytes должны
   расти.

Если хотя бы один из трёх показывает живой трафик — туннель работает.
Если UI-приложение всё равно отображает «нет трафика», то проблема в Flutter
UI, не в туннеле — отдельный баг.
4. На главном экране должны быть установлены **обе** иконки виджета:
   - **Compact 1×1** (логотип, ACTION_TOGGLE).
   - **Global Proxy 1×1** (треугольник, ACTION_TOGGLE_GLOBAL_PROXY).
   - Опционально — **Wide 4×2** для контрольной проверки.
5. В приложении выберите рабочий узел и убедитесь, что подключение из UI работает: открывает туннель, через браузер грузится `https://api.ipify.org` и виден экзит-IP.

После каждого теста сбрасывайте логи (`adb logcat -c`) и сохраняйте вывод в отдельный файл, если что-то пошло не так.

---

## Сценарии

### T0 — Контрольный прогон из UI

**Цель:** получить эталонный лог для сравнения. Все последующие сценарии
будем диффать против него — Reality-параметры, intent-extras, xray-config.

**Предусловие:** VPN отключён, приложение закрыто.

**Шаги:**
1. Откройте приложение, дождитесь загрузки главного экрана.
2. Нажмите CONNECT в UI на тот же узел, что планируете использовать в T1.
3. Дождитесь «Connected».
4. Проверьте трафик по всем трём способам выше (браузер + ping + /proc/net/dev).
5. Сохраните логи:
   ```sh
   adb logcat -d -v time > ui_baseline.log
   adb logcat -c
   ```

**Что отметить в логе T0:**
- `QSVpnConfigStore: buildStartConfig: …` — НЕ должно быть, потому что
  UI идёт через MethodChannel, а не через widget-store.
- `VpnServiceConfigParser: Parsed VPN config: …` — есть.
- Для bridge-конфига должна также быть строка `Bridge ENTRY config: …`.

### T1 — Подключение из 1×1 connect (cold start, Flutter killed)

**Предусловие:** VPN отключён. Принудительно завершите процесс приложения:
```sh
adb shell am force-stop com.voidlex.voidlex
```

**Шаги:**
1. Тапните по Compact-виджету на главном экране.
2. Дождитесь появления системной иконки VPN в статус-баре (≤ 3 c).
3. Проверьте трафик по всем трём способам, описанным выше.
4. Сохраните логи:
   ```sh
   adb logcat -d -v time > widget_t1.log
   adb logcat -c
   ```

**Ожидаемо:**
- В логах:
  - `VoidLexAppWidget: onReceive ACTION_TOGGLE …`
  - `VoidLexAppWidget: handleToggle entry state=disconnected`
  - `VoidLexAppWidget: cold start (no recent runtime), skipping defensive stop`
  - `QSVpnConfigStore: buildStartConfig: node=… runMode=tun global=false …`
  - `QSVpnConfigStore: buildStartConfig OUTER: name=… address=… transport=… security=… sni=… pbk=present sidLen=… …`
  - Для bridge-конфига: `QSVpnConfigStore: buildStartConfig ENTRY: …`
  - `VoidLexAppWidget: handleToggle: startForegroundService node=… runMode=tun`
  - `VpnServiceConfigParser: Parsed VPN config: …`
  - Для bridge-конфига: `VpnServiceConfigParser: Bridge ENTRY config: …`
  - `VoidVpnService: VPN confirmed connected by libbox engine`
- Браузер получает IP проксированного сервера, не локальный.
- НЕ должно быть `E/flutter: Cannot remove from a fixed-length list`.

**Если падает:** пришлите `widget_t1.log` + `ui_baseline.log`. Будем
диффать `buildStartConfig OUTER/ENTRY` (widget) vs `Bridge ENTRY config`
(parser) vs то, что было в T0 baseline — поле, которое отличается, и
есть причина.

---

### T2 — Отключение из 1×1 connect

**Предусловие:** VPN подключён (после T1).

**Шаги:**
1. Тапните Compact-виджет ещё раз.
2. Дождитесь исчезновения иконки VPN.

**Ожидаемо:**
- `VoidLexAppWidget: handleToggle entry state=connected`
- `VoidLexAppWidget: handleToggle: requested disconnect, exiting`
- `VoidVpnService: Stop requested` → `VPN runtime stopped: cleaned=true`
- Без рестарта/повторных стартов.

---

### T3 — Переключение split → global из 1×1 global widget

**Предусловие:** подключитесь из UI приложения в режиме SPLIT.

**Шаги:**
1. Откройте приложение в фоне (просто переключитесь на главный экран, не убивайте процесс).
2. Тапните Global-виджет.
3. Через ~3 секунды откройте приложение.

**Ожидаемо:**
- В логах:
  - `VoidLexAppWidget: onReceive ACTION_TOGGLE_GLOBAL_PROXY`
  - `VoidLexAppWidget: handleSetMode entry current=false target=true state=connected`
  - `QSVpnConfigStore: saveGlobalProxy value=true`
  - `VoidLexAppWidget: handleSetMode: sending ACTION_DISCONNECT`
  - `VoidVpnService: VPN runtime stopped: cleaned=true`
  - `VoidLexAppWidget: handleSetMode: stop settled=true`
  - `VoidLexAppWidget: handleSetMode: startForegroundService … globalProxy=true`
  - `VoidVpnService: VPN confirmed connected by libbox engine`
- На главном экране приложения пилюля «GLOBAL/СПЛИТ» подсвечивает **GLOBAL**, не split.
- В браузере грузится `https://api.ipify.org` — экзит-IP виден (трафик идёт).

**Это ключевой сценарий, на котором ловился исходный баг.** Если что‑то не так — приложите весь блок логов целиком.

---

### T4 — Обратное переключение global → split

**Предусловие:** после T3.

**Шаги:**
1. Тапните Global-виджет ещё раз.
2. Откройте приложение.

**Ожидаемо:**
- Логи симметричны T3, но `current=true target=false` и `globalProxy=false` в `startForegroundService`.
- Пилюля в UI показывает **SPLIT**.
- Трафик продолжает идти.

---

### T5 — Переключение mode пока туннель connecting

**Предусловие:** VPN отключён.

**Шаги:**
1. Тапните Compact-виджет (connect).
2. **В первую секунду** (когда показывается «Connecting…») тапните Global-виджет.

**Ожидаемо:**
- `VoidLexAppWidget: handleSetMode entry … state=connecting` → `wasActive=true` → стоп+рестарт.
- Финальное состояние: connected, global mode, трафик идёт.

Если зависает в connecting >10 секунд — это регрессия. Приложите логи.

---

### T6 — Холодный старт после долгой паузы

**Предусловие:** force-stop приложения; устройство просто полежало 5+ минут без VPN.

**Шаги:**
1. Тапните Compact-виджет.

**Ожидаемо:**
- `cold start (no recent runtime), skipping defensive stop` — это новая ветка, экономящая 500 мс на холодном старте.
- VPN подключается без ошибок, трафик идёт.

---

### T7 — Глобал режим виджетом, потом перезапуск приложения

**Шаги:**
1. Подключитесь из UI в SPLIT.
2. Переключитесь в GLOBAL через виджет (T3).
3. Force-stop приложения: `adb shell am force-stop com.voidlex.voidlex`.
4. Запустите приложение заново (например, тапом по иконке).
5. Откройте главный экран приложения, проверьте пилюлю.

**Ожидаемо:**
- Пилюля показывает **GLOBAL**, не сбрасывается обратно в SPLIT.
- В логах при старте Flutter: `_isGlobalProxy=true` (через настройки приложения → about → footer можно дополнительно проверить, но это опционально).

Это закрывает второй баг: ранее `_isGlobalProxy` сбрасывалось при инициализации, если у пользователя был выключен `_showGlobalProxyButton`. Теперь сброса нет.

---

### T8 — Wide widget (4×2): split/global сегменты

**Предусловие:** Wide widget установлен. VPN подключён в SPLIT.

**Шаги:**
1. На виджете нажмите сегмент «GLOBAL».
2. Подождите рестарта (3–5 c).
3. Нажмите сегмент «SPLIT».

**Ожидаемо:**
- Каждое нажатие → корректный stop+wait+start, трафик идёт после рестарта.
- Сегменты подсвечиваются согласно текущему режиму.

---

### T9 — Виджет при отсутствующих правах на VPN

**Предусловие:** отозвать VPN-permission через настройки Android (Privacy → Always-on VPN → отключить, или сбросить app data).

**Шаги:**
1. Тапните Compact-виджет.

**Ожидаемо:**
- Toast: «Open Void//Lex once to grant VPN permission».
- Приложение открывается.
- В логах: `handleToggle: VPN permission missing, redirecting to app`.
- НЕ должно быть `startForegroundService` и `Parsed VPN config`.

---

### T10 — XHTTP-транспорт через виджет

**Предусловие:** в подписке/конфиге есть узел с transport=xhttp, с непустыми `xhttpPadding`/`xhttpMaxPostBytes`/`xhttpMinPostInterval`. Выберите его.

**Шаги:**
1. Force-stop приложения.
2. Тапните Compact-виджет.
3. Откройте `https://api.ipify.org`.

**Ожидаемо:**
- В логах:
  - `QSVpnConfigStore: buildStartConfig: … xhttpPaddingSet=true …`
  - `VpnServiceConfigParser: Parsed VPN config: … xhttpMode=… xhttpPad=… xhttpMaxPost=… xhttpMinInt=…`
- Туннель поднимается, трафик идёт.

**Раньше:** виджет передавал пустые xhttp-extras, и xray использовал curated defaults. На сервере, ожидающем конкретные значения, соединение могло висеть.

---

## Что собрать, если что-то падает

Каждый раз, когда сценарий валит:

```sh
adb logcat -d -v time > widget_test_$(date +%Y%m%d_%H%M%S).log
adb bugreport widget_bugreport.zip   # опционально, если нужны системные данные
```

Также пришлите:
1. Имя сценария (T1–T10).
2. `flutter --version` + `adb shell getprop ro.build.version.release` (версия Android).
3. Точное время тапа по виджету (чтобы сузить логи).
4. Транспорт + security используемого узла (vless/xhttp/reality/etc).

---

## Известные ограничения тестов

- На устройствах с **Android < 9** Toast.makeText из IO-потока работал криво, но это уже починено (`withContext(Main)` в `handleToggle`). На Android 10+ ничего не меняется.
- `goAsync()` даёт ~10 секунд на receiver. Если cold-start xray занимает > 8 секунд (медленный девайс, первичный геобайт-prefetch), последняя строчка лога может оборваться — это нормально, тунель уже взведён в сервисе.
- На устройствах, где `lastRuntimeCleanupElapsedMillis` ещё не выставлен (свежеустановленное приложение, первый запуск через виджет), мы пропускаем defensive-stop и идём прямо в start — это ожидаемо.

Если что-то в плане непонятно или нужно расширить покрытие — спросите.
