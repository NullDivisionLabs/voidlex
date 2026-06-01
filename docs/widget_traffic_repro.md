# Widget no-traffic repro (страница не грузится)

## Перед началом

1. Подключите устройство по USB, проверьте ADB:
   ```sh
   adb devices
   ```
2. Соберите и установите **debug‑APK** с последними правками:
   ```sh
   flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
3. Снесите все виджеты с домашнего экрана, перезагрузите устройство, поставьте виджеты обратно (это гарантирует свежие `PendingIntent`).

## Запись логов

В **отдельной вкладке терминала** запустите фильтр и **не закрывайте** его до конца теста:

```sh
adb logcat -c
adb logcat -v threadtime \
  VoidLexAppWidget:V \
  WidgetAction:V \
  QSVpnConfigStore:V \
  VoidVpnService:V \
  LibboxTunRuntime:V \
  XrayRuntime:V \
  VpnServiceConfigParser:V \
  ConnectivityManager:V \
  AndroidRuntime:E \
  flutter:W \
  *:S
```

`ConnectivityManager:V` подхватит системные network events.

## Сценарий A: контрольный UI-connect (работает у вас)

В отдельной вкладке выполните:

```sh
adb shell am force-stop com.voidlex.voidlex
adb logcat -c
```

Затем **на устройстве**:

1. Откройте приложение.
2. Нажмите CONNECT в UI на ваш тестовый узел (тот же, на котором ловится баг через виджет).
3. Дождитесь индикатора Connected.
4. Откройте Chrome → **новая вкладка** → `https://api.ipify.org` → подождите загрузку.

После того как страница загрузилась с правильным IP — **в терминале**:

```sh
adb shell ip route get 1.1.1.1
adb shell ip rule list
adb shell cat /proc/net/dev | grep -E "tun0|rmnet"
adb shell dumpsys connectivity short
adb logcat -d -v threadtime > ui_works.log
adb logcat -c
```

Сохраните `ui_works.log` — это **рабочая** база.

## Сценарий B: widget-connect (не работает)

```sh
adb shell am force-stop com.voidlex.voidlex
adb logcat -c
```

На устройстве:

1. **Не открывая приложение**, тапните 1×1 connect-виджет.
2. Дождитесь системной иконки VPN.
3. Откройте Chrome → **новая вкладка** → `https://api.ipify.org` → **подождите 30 секунд** даже если страница висит.

После этого в терминале:

```sh
adb shell ip route get 1.1.1.1
adb shell ip rule list
adb shell cat /proc/net/dev | grep -E "tun0|rmnet"
adb shell dumpsys connectivity short
adb logcat -d -v threadtime > widget_broken.log
```

Сохраните `widget_broken.log`.

## Что мы будем сравнивать

Диф между `ui_works.log` и `widget_broken.log` ищем по этим ключевым строкам — они **должны совпадать**, и если не совпадают, мы увидим где:

| Строка                                                | Зачем                                                  |
| ----------------------------------------------------- | ------------------------------------------------------ |
| `QSVpnConfigStore: buildStartConfig OUTER: …`         | что виджет положил в Intent                            |
| `VpnServiceConfigParser: Parsed VPN config: …`        | что сервис прочитал                                    |
| `LibboxTunRuntime: openTun setUnderlyingNetworks: …`  | какая underlay сеть выбрана                            |
| `LibboxTunRuntime: openTun addresses=…`               | какие IP-адреса навешаны на tun0                       |
| `LibboxTunRuntime: openTun dns=…`                     | DNS-серверы туннеля                                    |
| `LibboxTunRuntime: openTun routes added=… excluded=…` | реально проброшенные маршруты в tun0                   |
| `LibboxTunRuntime: openTun package routing: …`        | список disallowed/allowed apps                         |
| `LibboxTunRuntime: openTun TUN established: …`        | финальный fd, MTU, underlay                            |

Также от shell-команд:

| Команда                                  | Что показывает                                              |
| ---------------------------------------- | ----------------------------------------------------------- |
| `ip route get 1.1.1.1`                   | через какой `dev` пойдёт IP-пакет на 1.1.1.1 (tun0 или нет) |
| `ip rule list`                           | per-uid routing rules — там должно быть правило для VPN     |
| `/proc/net/dev` (tun0 RX/TX)             | реально ли идут байты через tun0                            |
| `dumpsys connectivity short`             | какие сети система знает, какая default для каждой uid      |

## Что прислать мне

В одном архиве:
- `ui_works.log`
- `widget_broken.log`
- Вывод `ip route get` / `ip rule list` / `dumpsys connectivity` для обоих сценариев (можно сразу в текстовый файл).

С этими данными я точно покажу, на каком конкретно шаге widget-сессия теряет route, и подберу таргетированный фикс. Без них я гадаю.

## Дополнительная проверка (если есть время)

Если у вас включена в Samsung настройка **"Allow apps to use Internet without VPN"** или **"Always-on VPN"** — отключите её и повторите сценарий B. На некоторых сборках One UI этот тогл ломает default-routing для не-первого VPN-старта.

Зайти: Settings → Connections → More connections → VPN → ⚙ возле Void//Lex.

Если после отключения этих тоглов виджет начинает работать — это не баг приложения, это Samsung-овский тогл.
