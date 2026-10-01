// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Void//Lex';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get done => 'Готово';

  @override
  String get add => 'Добавить';

  @override
  String get edit => 'Изменить';

  @override
  String get create => 'Создать';

  @override
  String get clear => 'Очистить';

  @override
  String get retry => 'Повторить';

  @override
  String get append => 'Добавить в конец';

  @override
  String get replace => 'Заменить';

  @override
  String get loading => 'Загрузка…';

  @override
  String get unavailable => 'Недоступно';

  @override
  String get more => 'Ещё';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get untitled => 'Без названия';

  @override
  String keepPrefix(String label) {
    return 'Хранить: $label';
  }

  @override
  String levelsSelectedNone(String retention) {
    return 'Уровни не выбраны — $retention';
  }

  @override
  String levelsSelectedSome(String levels, String retention) {
    return '$levels — $retention';
  }

  @override
  String get applicationSettingsTitle => 'Настройки приложения';

  @override
  String get themeSection => 'Тема';

  @override
  String get settingsGroupInterface => 'Интерфейс';

  @override
  String get settingsGroupConnection => 'Подключение';

  @override
  String get settingsGroupNodes => 'Диагностика';

  @override
  String get settingsGroupProfile => 'Профиль';

  @override
  String get settingsGroupAdvanced => 'Расширенные';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get appLanguageTitle => 'Язык приложения';

  @override
  String get appLanguageSubtitle => 'Выберите язык интерфейса.';

  @override
  String get appLanguageAuto => 'Авто';

  @override
  String get appLanguageEnglish => 'English';

  @override
  String get appLanguageRussian => 'Русский';

  @override
  String get autoConnectOnLaunchTitle => 'Автоподключение при запуске';

  @override
  String get autoConnectOnLaunchSubtitle =>
      'На некоторых устройствах может не работать.';

  @override
  String get allowDeepLinkVpnAutomationTitle =>
      'Разрешить ссылки автоматизации VPN';

  @override
  String get allowDeepLinkVpnAutomationSubtitle =>
      'Если включено, voidlex://connect и похожие ссылки могут менять подключение без запроса каждый раз.';

  @override
  String get startHomeWidgetsCollapsedTitle =>
      'Запускать со свернутыми виджетами';

  @override
  String get startHomeWidgetsCollapsedSubtitle =>
      'Открывать главный экран сразу в компактном режиме.';

  @override
  String get restartOnSettingsChangeTitle => 'Перезапуск при изменениях';

  @override
  String get showSpeedInNotificationTitle =>
      'Показывать скорость в уведомлении';

  @override
  String get keepAwakeTitle => 'Не усыплять VPN';

  @override
  String get keepAwakeSubtitle =>
      'Держит частичную блокировку сна при подключении. Расходует больше батареи.';

  @override
  String get verboseXrayLogsTitle => 'Подробные логи Xray';

  @override
  String get verboseXrayLogsSubtitle =>
      'Включает info-уровень ядра xray (ошибки dial, Reality-auth, ALPN) и однократный дамп сгенерированной конфигурации при старте. Только для диагностики; чувствительные поля маскируются.';

  @override
  String get applicationSettingsPingTargetTitle => 'Адрес диагностики TCP';

  @override
  String get applicationSettingsPingTargetDefault => 'Адрес узла';

  @override
  String get applicationSettingsPingTargetDialogTitle =>
      'Адрес диагностики TCP';

  @override
  String get applicationSettingsPingTargetFieldLabel => 'Хост или URL';

  @override
  String get applicationSettingsPingTargetHint => 'example.com:443';

  @override
  String get applicationSettingsPingTargetInvalid =>
      'Введите хост, URL или host:port.';

  @override
  String get applicationSettingsPingTargetReset => 'Использовать адрес узла';

  @override
  String get logSettingsTitle => 'Параметры логов';

  @override
  String get logSettingsDialogTitle => 'Параметры логов';

  @override
  String get logLevelsLabel => 'Уровни';

  @override
  String get logStorageTimeLabel => 'Время хранения';

  @override
  String get logStorageTimeTooltip => 'Время хранения';

  @override
  String get applicationSettingsShowGlobalProxyTitle => 'Виджет Split/Global';

  @override
  String get applicationSettingsGlobalProxySubtitle =>
      'Показывать кнопку полного туннеля на главном экране.';

  @override
  String get applicationSettingsShowExitNodeTitle => 'Виджет Exit/Node';

  @override
  String get applicationSettingsShowExitNodeSubtitle =>
      'Показывать сведения о подключении на главном экране.';

  @override
  String get exitInfoSpeedLabel => 'SPEED';

  @override
  String get exitInfoDownLabel => 'DOWN';

  @override
  String get exitInfoUpLabel => 'UP';

  @override
  String get exitInfoMemoryLabel => 'MEM';

  @override
  String get applicationSettingsAutoSortServersByPingTitle =>
      'Сортировка по пингу';

  @override
  String get applicationSettingsAutoSortServersByPingSubtitle =>
      'Приоритет более скоростным серверам';

  @override
  String get profileExportTitle => 'Экспорт профиля';

  @override
  String get profileExportSubtitle =>
      'Сохранить ручные узлы, подписки и пресеты маршрутизации в JSON-файл.';

  @override
  String get profileExportedText => 'Профиль экспортирован.';

  @override
  String get profileExportProtectedSubscriptionsSkipped =>
      'Профиль экспортирован. Защищённые подписки невозможно экспортировать.';

  @override
  String get profileExportProtectedSubscriptionsEncrypted =>
      'Профиль экспортирован. Защищённые подписки сохранены в виде обфусцированных кодов — скрыты от случайного просмотра, это не стойкое шифрование.';

  @override
  String get profileExportWarningTitle => 'Экспортировать профиль?';

  @override
  String get profileExportWarningBody =>
      'Экспортируемый JSON содержит ваши ручные узлы целиком, включая UUID и пароли, в открытом виде. Храните и передавайте файл осторожно.';

  @override
  String get profileExportWarningConfirm => 'Экспортировать';

  @override
  String profileExportFailed(String error) {
    return 'Не удалось экспортировать профиль: $error';
  }

  @override
  String get profileImportTitle => 'Импорт профиля';

  @override
  String get profileImportSubtitle => 'Загрузить JSON-файл профиля Void//Lex.';

  @override
  String get profileImportModeTitle => 'Импорт профиля';

  @override
  String get profileImportModeBody =>
      'Заменить текущие ручные узлы, подписки и пресеты маршрутизации или добавить этот профиль к текущим данным?';

  @override
  String get profileImportFileEmpty => 'Файл профиля пуст.';

  @override
  String get profileImportReadFailed => 'Не удалось прочитать файл профиля.';

  @override
  String profileImportReadFailedDetail(String error) {
    return 'Не удалось прочитать файл профиля: $error';
  }

  @override
  String profileImportFailed(String error) {
    return 'Не удалось импортировать профиль: $error';
  }

  @override
  String get profileImportInvalidJson => 'Некорректный JSON профиля.';

  @override
  String get profileImportUnsupportedFormat =>
      'Файл не является профилем Void//Lex.';

  @override
  String get profileImportUnsupportedVersion =>
      'Версия профиля не поддерживается.';

  @override
  String get profileImportEmptyProfile => 'В профиле нет данных для импорта.';

  @override
  String get profileImportTooLarge =>
      'Файл профиля слишком большой (макс. 4 МБ).';

  @override
  String get secureStorageWriteFailed =>
      'Не удалось сохранить пароль в защищённое хранилище. Повторите попытку.';

  @override
  String get deepLinkVpnControlColdStart =>
      'Откройте Void//Lex и подключитесь из приложения. Ссылки connect/disconnect при холодном запуске игнорируются.';

  @override
  String get deepLinkConsentTitle => 'Открыть внешнюю ссылку?';

  @override
  String get deepLinkConsentImportServers =>
      'Эта ссылка хочет добавить один или несколько серверов в Void//Lex.';

  @override
  String get deepLinkConsentImportRuleset =>
      'Эта ссылка хочет скачать правила маршрутизации и добавить их. Это может перезапустить активное подключение.';

  @override
  String get deepLinkConsentImportSubscription =>
      'Эта ссылка хочет импортировать подписку или сервер в Void//Lex.';

  @override
  String get deepLinkConsentVpnControlConnect =>
      'Эта ссылка хочет подключить Void//Lex к выбранному серверу.';

  @override
  String get deepLinkConsentVpnControlDisconnect =>
      'Эта ссылка хочет отключить Void//Lex.';

  @override
  String get deepLinkConsentVpnControlToggle =>
      'Эта ссылка хочет переключить подключение Void//Lex.';

  @override
  String get deepLinkConsentVpnControlRestart =>
      'Эта ссылка хочет перезапустить активное подключение Void//Lex.';

  @override
  String get deepLinkConsentVpnControlConfirm => 'Разрешить';

  @override
  String get deepLinkConsentSourceLabel => 'Источник';

  @override
  String get deepLinkConsentHttpWarning =>
      'Ссылка использует обычный HTTP (без TLS). Её содержимое можно прочитать или изменить при передаче.';

  @override
  String get deepLinkConsentConfirm => 'Импортировать';

  @override
  String get deepLinkRulesetInvalidUrl =>
      'URL ruleset должен быть корректным https-адресом на публичном хосте.';

  @override
  String get deepLinkImportTooLarge => 'Слишком большой payload для импорта.';

  @override
  String get deepLinkRulesetTimeout => 'Превышено время загрузки ruleset.';

  @override
  String get deepLinkRulesetTooLarge => 'Файл ruleset слишком большой.';

  @override
  String get deepLinkRulesetEmpty => 'Файл ruleset пуст.';

  @override
  String get deepLinkRulesetNoRules =>
      'В файле нет поддерживаемых правил маршрутизации.';

  @override
  String get deepLinkRulesetInvalidJson => 'Некорректный JSON ruleset.';

  @override
  String deepLinkRulesetHttpStatus(int code) {
    return 'Загрузка ruleset вернула HTTP $code';
  }

  @override
  String deepLinkRulesetRequestFailed(String detail) {
    return 'Не удалось загрузить ruleset: $detail';
  }

  @override
  String deepLinkRulesetImported(int count) {
    return 'Импортировано правил из ссылки: $count.';
  }

  @override
  String profileImportedText(int manualNodes, int subscriptions, int presets) {
    return 'Профиль импортирован: ручных узлов: $manualNodes, подписок: $subscriptions, пресетов: $presets.';
  }

  @override
  String profileImportedWithProtectedFailures(
    int manualNodes,
    int subscriptions,
    int presets,
    int failed,
  ) {
    return 'Профиль импортирован: ручных узлов: $manualNodes, подписок: $subscriptions, пресетов: $presets. Не удалось восстановить защищённых подписок: $failed.';
  }

  @override
  String profileImportedAppRoutingMissingSuffix(int dropped) {
    return ' Пропущено правил per-app для не установленных приложений: $dropped.';
  }

  @override
  String get serverMenuEdit => 'Изменить';

  @override
  String get serverMenuInDevelopment => 'В разработке';

  @override
  String get serverMenuAddFavorite => 'В избранное';

  @override
  String get serverMenuRemoveFavorite => 'Убрать из избранного';

  @override
  String get favoriteMenuMove => 'Переместить';

  @override
  String get serverMenuSetExitNode => 'Выходной туннель';

  @override
  String get serverMenuResetExitNode => 'Сбросить выходной туннель';

  @override
  String get serverExitNodeLabel => 'EXIT';

  @override
  String get serverMenuRulePreset => 'Пресет правил';

  @override
  String get editServerTitle => 'Сервер';

  @override
  String get addServerTitle => 'Добавить сервер';

  @override
  String get editServerSave => 'Сохранить';

  @override
  String get editServerDelete => 'Удалить сервер';

  @override
  String get editServerDeleteConfirmTitle => 'Удалить этот сервер?';

  @override
  String get editServerDeleteConfirmBody => 'Он будет удалён из списка.';

  @override
  String get editServerDeleteCancel => 'Отмена';

  @override
  String get editServerDeleteConfirmAction => 'Удалить';

  @override
  String get editServerAliasLabel => 'Имя';

  @override
  String get editServerAddressLabel => 'Адрес сервера';

  @override
  String get editServerPortLabel => 'Порт';

  @override
  String get editServerUuidLabel => 'UUID / пароль';

  @override
  String get editServerPasswordLabel => 'Пароль / авторизация';

  @override
  String get editServerNaiveUsernameLabel => 'Логин NaiveProxy (необязательно)';

  @override
  String get editServerNaivePasswordLabel =>
      'Пароль NaiveProxy (необязательно)';

  @override
  String get editServerNaiveModeLabel => 'Транспорт NaiveProxy';

  @override
  String get editServerNaiveModeHttps => 'HTTPS / HTTP2';

  @override
  String get editServerNaiveModeQuic => 'QUIC';

  @override
  String get editServerNaiveCongestionControlLabel =>
      'Управление перегрузкой QUIC';

  @override
  String get editServerNaiveCongestionControlAuto => 'Авто (BBR)';

  @override
  String get editServerProtocolLabel => 'Протокол';

  @override
  String get editServerTransportLabel => 'Транспорт';

  @override
  String get editServerSecurityLabel => 'Безопасность';

  @override
  String get editServerSniLabel => 'SNI';

  @override
  String get editServerPathLabel => 'Путь';

  @override
  String get editServerServiceNameLabel => 'Имя сервиса';

  @override
  String get editServerHostLabel => 'Заголовок Host';

  @override
  String get editServerShortIdLabel => 'Short ID';

  @override
  String get editServerPublicKeyLabel => 'Публичный ключ';

  @override
  String get editServerAlpnLabel => 'ALPN';

  @override
  String get editServerAllowInsecureLabel => 'Разрешить небезопасный TLS';

  @override
  String get editServerObfsPasswordLabel => 'Пароль obfs';

  @override
  String get editServerHopPortsLabel => 'Прыжки по портам';

  @override
  String get editServerAliasRequired => 'Укажите имя';

  @override
  String get editServerAddressRequired => 'Укажите адрес';

  @override
  String get editServerPortRequired => 'Укажите порт';

  @override
  String get editServerPortInvalid => 'Порт от 1 до 65535';

  @override
  String get editServerPasswordRequired => 'Укажите пароль';

  @override
  String get editServerUuidRequired => 'Укажите UUID';

  @override
  String get editServerNameDuplicate => 'Сервер с таким именем уже есть';

  @override
  String get editServerNotFound => 'Сервер не найден';

  @override
  String get editServerSectionPrimary => 'Основные';

  @override
  String get editServerSectionTransport => 'Транспорт';

  @override
  String get editServerSectionTls => 'TLS / Reality';

  @override
  String get editServerFingerprintLabel => 'uTLS fingerprint';

  @override
  String get editServerFingerprintHelper =>
      'Auto использует выбор ядра. Старые профили могут уменьшать ClientHello; ускорение и экономия энергии не гарантированы.';

  @override
  String get editServerFingerprintAuto => 'Авто (нет)';

  @override
  String get editServerXhttpSubheading => 'Настройки XHTTP';

  @override
  String get editServerXhttpModeLabel => 'Режим';

  @override
  String get editServerXhttpModeHelper =>
      'Пустое значение использует настройку Xray-core';

  @override
  String get editServerXhttpModeAuto => 'По умолчанию ядра';

  @override
  String get editServerXhttpPaddingLabel => 'Диапазон паддинга (xPaddingBytes)';

  @override
  String get editServerXhttpPaddingHelper =>
      'Необязательное положительное число или диапазон, например 100-1000';

  @override
  String get editServerXhttpMaxPostLabel =>
      'Макс. размер POST (scMaxEachPostBytes)';

  @override
  String get editServerXhttpMaxPostHelper =>
      'Необязательно; только для packet-up';

  @override
  String get editServerXhttpMinIntervalLabel =>
      'Мин. интервал POST мс (scMinPostsIntervalMs)';

  @override
  String get editServerXhttpMinIntervalHelper =>
      'Необязательно; только для packet-up';

  @override
  String get editServerXhttpObfsTitle => 'Расширенная маскировка padding';

  @override
  String get editServerXhttpObfsHelper =>
      'В выключенном состоянии используется стандартное поведение Xray-core';

  @override
  String get editServerXhttpPaddingPlacementLabel => 'Размещение padding';

  @override
  String get editServerXhttpPaddingKeyLabel => 'Ключ padding';

  @override
  String get editServerXhttpPaddingHeaderLabel => 'Заголовок padding';

  @override
  String get editServerXhttpPaddingMethodLabel => 'Метод padding';

  @override
  String get editServerXhttpSessionPlacementLabel => 'Размещение session ID';

  @override
  String get editServerXhttpSessionKeyLabel => 'Ключ session ID';

  @override
  String get editServerXhttpSeqPlacementLabel => 'Размещение sequence';

  @override
  String get editServerXhttpSeqKeyLabel => 'Ключ sequence';

  @override
  String get editServerXhttpCdnWafPreset => 'Совместимость с CDN/WAF';

  @override
  String get editServerXhttpStockDefault => 'По умолчанию ядра';

  @override
  String get editServerXhttpRangeInvalid =>
      'Укажите положительное число или диапазон до 2147483647';

  @override
  String get editServerXhttpTokenInvalid =>
      'Содержит недопустимые для HTTP-токена символы';

  @override
  String get editServerXhttpValueRequired =>
      'Обязательно для выбранного размещения';

  @override
  String get editServerAdvancedTitle => 'Расширенные';

  @override
  String get editServerAuto => 'Авто';

  @override
  String get editServerFlowLabel => 'Flow VLESS';

  @override
  String get editServerFlowHelper =>
      'Flow XTLS Vision. Обычно используется с TCP + TLS/Reality.';

  @override
  String get editServerEncryptionLabel => 'Шифрование VLESS';

  @override
  String get editServerEncryptionHelper =>
      'Оставьте пустым для none. Расширенное значение может быть длинным.';

  @override
  String get editServerRealitySpiderXLabel => 'Reality spiderX';

  @override
  String get editServerRealitySpiderXHelper =>
      'Необязательный начальный путь краулера.';

  @override
  String get editServerRealityMldsaLabel => 'Reality ML-DSA-65 verify';

  @override
  String get editServerRealityMldsaHelper =>
      'Необязательный ключ постквантовой проверки.';

  @override
  String get editServerHysteriaObfsTypeLabel => 'Обфускация';

  @override
  String get editServerHysteriaObfsNone => 'Нет';

  @override
  String get editServerHysteriaObfsMinPacketLabel =>
      'Минимальный размер пакета Gecko';

  @override
  String get editServerHysteriaObfsMaxPacketLabel =>
      'Максимальный размер пакета Gecko';

  @override
  String get editServerHysteriaHopIntervalLabel => 'Интервал прыжков по портам';

  @override
  String get editServerHysteriaHopIntervalMaxLabel =>
      'Максимальный интервал прыжков';

  @override
  String get editServerHysteriaUpMbpsLabel => 'Скорость отправки (Мбит/с)';

  @override
  String get editServerHysteriaDownMbpsLabel => 'Скорость загрузки (Мбит/с)';

  @override
  String get editServerHysteriaNetworkLabel => 'Проксируемая сеть';

  @override
  String get editServerHysteriaNetworkBoth => 'TCP и UDP';

  @override
  String get editServerHysteriaBbrProfileLabel => 'Профиль BBR';

  @override
  String get editServerNaiveInsecureConcurrencyLabel => 'Insecure concurrency';

  @override
  String get editServerNaiveInsecureConcurrencyHelper =>
      'Дополнительные параллельные соединения до подтверждения авторизации.';

  @override
  String get editServerNaiveExtraHeadersLabel =>
      'Дополнительные HTTP-заголовки';

  @override
  String get editServerNaiveAddHeader => 'Добавить заголовок';

  @override
  String get editServerNaiveHeaderNameLabel => 'Заголовок';

  @override
  String get editServerNaiveHeaderValueLabel => 'Значение';

  @override
  String get editServerNaiveUdpOverTcpLabel => 'UDP поверх TCP';

  @override
  String get editServerNaiveUdpOverTcpVersionLabel => 'Версия UDP поверх TCP';

  @override
  String get editServerAdvancedObfsPasswordRequired => 'Укажите пароль obfs';

  @override
  String get editServerAdvancedRangeOrder =>
      'Максимум должен быть не меньше минимума';

  @override
  String get editServerAdvancedPositiveInteger =>
      'Введите положительное целое число';

  @override
  String get editServerAdvancedIntegerMax =>
      'Введите положительное целое число до 2048';

  @override
  String get editServerAdvancedDurationInvalid =>
      'Используйте длительность Go, например 30s или 1m30s';

  @override
  String get editServerAdvancedHeaderRequired => 'Укажите имя заголовка';

  @override
  String get editServerAdvancedHeaderDuplicate =>
      'Имена заголовков должны быть уникальны';

  @override
  String get editServerAdvancedHeaderNewline => 'Переносы строк запрещены';

  @override
  String get protocolVless => 'VLESS';

  @override
  String get protocolHysteria2 => 'Hysteria2';

  @override
  String get protocolNaive => 'NaiveProxy';

  @override
  String get transportTcp => 'TCP';

  @override
  String get transportUdp => 'UDP';

  @override
  String get transportWs => 'WebSocket';

  @override
  String get transportGrpc => 'gRPC';

  @override
  String get transportHttp => 'HTTP';

  @override
  String get transportHttpUpgrade => 'HTTP Upgrade';

  @override
  String get transportXhttp => 'XHTTP';

  @override
  String get securityNone => 'Нет';

  @override
  String get securityTls => 'TLS';

  @override
  String get securityReality => 'Reality';

  @override
  String get settingsConfigTitle => 'CONFIG';

  @override
  String get settingsSectionsHeading => 'РАЗДЕЛЫ';

  @override
  String get settingsRoutingTitle => 'Маршрутизация';

  @override
  String get settingsRoutingSubtitle => 'Пресеты · правила · приложения';

  @override
  String get settingsTunnelTitle => 'Туннель';

  @override
  String get settingsTunnelSubtitle => 'Фрагментация · мультиплекс · сеть';

  @override
  String get settingsSubscriptionsTitle => 'Подписки';

  @override
  String get settingsSubscriptionsSubtitle =>
      'Автообновление · политика запросов';

  @override
  String get settingsApplicationTitle => 'Приложение';

  @override
  String get settingsApplicationSubtitle => 'Тема · язык · запуск · логи';

  @override
  String get settingsLogJournalSubtitle => 'Сохраненные логи';

  @override
  String get settingsAboutHeading => 'О ПРОГРАММЕ';

  @override
  String get settingsVersionLabel => 'Версия';

  @override
  String get settingsHwidLabel => 'HWID';

  @override
  String get settingsProtocolLabel => 'Протокол';

  @override
  String get settingsProtocolValue => 'VLESS · Hysteria2 · NaiveProxy';

  @override
  String get settingsXrayCoreLabel => 'xray-core';

  @override
  String get settingsLibboxLabel => 'libbox (sing-box)';

  @override
  String get logJournalTitle => 'Журнал';

  @override
  String get logsEmptyText => 'Пока нет записей.';

  @override
  String get logsNoCopyText => 'Нечего копировать.';

  @override
  String get logsCopiedText =>
      'Логи скопированы. Они могут содержать чувствительные данные — храните в тайне.';

  @override
  String get logsNoExportText => 'Нечего экспортировать.';

  @override
  String get logsExportedText => 'Экспорт выполнен.';

  @override
  String get logsClearedText => 'Журнал очищен.';

  @override
  String get logsCopyTooltip => 'Копировать';

  @override
  String get logsExportTooltip => 'Экспорт TXT';

  @override
  String get logsClearTooltip => 'Очистить';

  @override
  String get homeServerCopied =>
      'Ссылка на сервер скопирована. Она содержит ваши учётные данные — храните в тайне.';

  @override
  String get homeNodePresetTitle => 'Пресет узла';

  @override
  String get homeNodePresetCleared => 'Пресет узла сброшен.';

  @override
  String homeNodePresetSelected(String name) {
    return 'Для узла выбран пресет «$name».';
  }

  @override
  String homeSubscriptionUpdated(String name) {
    return 'Подписка «$name» обновлена.';
  }

  @override
  String homeDeleteSubscriptionTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get homeDeleteSubscriptionBody =>
      'Все узлы из этой подписки будут удалены.';

  @override
  String homeSubscriptionDeleted(String name) {
    return 'Подписка «$name» удалена.';
  }

  @override
  String get sectionFavorites => 'FAVORITES';

  @override
  String get sectionNodes => 'NODES';

  @override
  String sectionNodesManualCount(int count) {
    return '$count MANUAL';
  }

  @override
  String get homeNoNodesTitle => 'ПОКА НЕТ УЗЛОВ';

  @override
  String get homeNoNodesSubtitle =>
      'Нажмите ДОБАВИТЬ на панели внизу, чтобы импортировать узел.';

  @override
  String get tooltipUpdateSubscription => 'Обновить подписку';

  @override
  String get tooltipScanPing => 'Scan ping';

  @override
  String get tooltipSearchNodes => 'Поиск нод';

  @override
  String get tooltipCloseSearch => 'Закрыть поиск';

  @override
  String get tooltipCollapseTopWidgets => 'Скрыть виджеты';

  @override
  String get tooltipExpandTopWidgets => 'Показать виджеты';

  @override
  String get searchNodesHint => 'Поиск по имени';

  @override
  String get searchNoResults => 'Ничего не найдено';

  @override
  String get statusIdle => 'IDLE';

  @override
  String get statusReconnecting => 'Переподключение';

  @override
  String get statusNegotiating => 'NEGOTIATING';

  @override
  String get statusSecure => 'SECURE';

  @override
  String get statusClosing => 'CLOSING';

  @override
  String get statusError => 'ERROR';

  @override
  String get statusStripLabel => 'STATUS';

  @override
  String get statusDurationPlaceholder => '— : —';

  @override
  String get ipPlaceholder => '———.———.———.———';

  @override
  String get nodeLabelDash => '—';

  @override
  String get pingMsSuffix => ' ms';

  @override
  String get scanning => 'SCANNING';

  @override
  String get scan => 'SCAN';

  @override
  String subscriptionMetaLine(String expiry, int count) {
    return '$expiry · $count NODES';
  }

  @override
  String get subscriptionExpiryUnknown => 'СРОК НЕИЗВЕСТЕН';

  @override
  String subscriptionExpired(String date) {
    return 'ИСТЕКЛО $date';
  }

  @override
  String subscriptionExpires(String date) {
    return 'ДО $date';
  }

  @override
  String get dockHub => 'HUB';

  @override
  String get dockAdd => 'ADD';

  @override
  String get dockRoute => 'ROUTE';

  @override
  String get dockConfig => 'CONFIG';

  @override
  String get globalProxySplitLabel => 'СПЛИТ';

  @override
  String get globalProxySplitHint => 'ПРАВИЛА';

  @override
  String get globalProxyGlobalLabel => 'ГЛОБАЛ';

  @override
  String get globalProxyGlobalHint => 'ВЕСЬ ТРАФИК';

  @override
  String get addNodeSheetTitle => 'ДОБАВИТЬ УЗЕЛ';

  @override
  String get addNodeScanQr => 'Сканировать QR';

  @override
  String get addNodeFromClipboard => 'Из буфера';

  @override
  String get addNodeFromJsonFile => 'Из JSON-файла';

  @override
  String get addNodeManualInput => 'Вручную';

  @override
  String get ipStatusNotConnected => 'Не подключено';

  @override
  String get ipStatusResolving => 'Определение…';

  @override
  String get ipStatusUnavailable => 'Недоступно';

  @override
  String get subscriptionNotFound => 'Подписка не найдена.';

  @override
  String get subscriptionNameRequired => 'Укажите имя подписки.';

  @override
  String get subscriptionInvalidUrl =>
      'Введите корректный URL подписки (HTTP или HTTPS).';

  @override
  String get insecureSubscriptionTitle => 'Использовать небезопасную подписку?';

  @override
  String get insecureSubscriptionBody =>
      'Подписка использует обычный HTTP. Список узлов можно прочитать или изменить при передаче, направив VPN-трафик через сервер злоумышленника.';

  @override
  String get insecureSubscriptionConfirm => 'Всё равно использовать HTTP';

  @override
  String get discardChangesTitle => 'Отменить несохранённые изменения?';

  @override
  String get discardChangesBody => 'Изменения не сохранены и будут потеряны.';

  @override
  String get discardChangesAction => 'Отменить изменения';

  @override
  String get presetNameRequired => 'Введите имя пресета.';

  @override
  String get presetNameDuplicate => 'Пресет с таким именем уже существует.';

  @override
  String get presetNotFound => 'Пресет не найден.';

  @override
  String get presetMainCannotRename => 'Главный пресет нельзя переименовать.';

  @override
  String get presetMainCannotDelete => 'Главный пресет нельзя удалить.';

  @override
  String get vpnNoServerSelected => 'Сервер не выбран';

  @override
  String get vpnPermissionDenied => 'Разрешение VPN не выдано';

  @override
  String get vpnPlatformError => 'Ошибка платформы';

  @override
  String get vpnFailedToStop => 'Не удалось остановить VPN';

  @override
  String get vpnFailedToReconnect => 'Не удалось переподключить VPN';

  @override
  String get vpnUnknownError => 'Неизвестная ошибка VPN';

  @override
  String get vpnConnectionTimedOut => 'Таймаут подключения VPN';

  @override
  String get vpnLibboxNetworkUnavailable =>
      'libbox не получил доступ к основной сети';

  @override
  String get vpnNaiveRequiresLibbox => 'NaiveProxy требует движок TUN libbox';

  @override
  String get vpnNaiveTunOnly => 'NaiveProxy недоступен в режиме только прокси';

  @override
  String get vpnNaiveBridgeUnsupported =>
      'NaiveProxy нельзя использовать в двухступенчатой цепочке';

  @override
  String get vpnNaiveExitUnsupported =>
      'NaiveProxy нельзя выбрать выходным узлом';

  @override
  String get vpnDirectLibboxBridgeUnsupported =>
      'Hysteria2 и NaiveProxy нельзя использовать в двухступенчатой цепочке';

  @override
  String get vpnDirectLibboxRequiresLibbox =>
      'Hysteria2 и NaiveProxy требуют движок TUN libbox';

  @override
  String get vpnDirectLibboxTunOnly =>
      'Hysteria2 и NaiveProxy недоступны в режиме только прокси';

  @override
  String vpnEventChannelError(String error) {
    return 'Ошибка канала событий: $error';
  }

  @override
  String get subImportInvalidUrl =>
      'Введите корректный URL подписки (HTTP или HTTPS)';

  @override
  String get subImportTimeout => 'Истекло время ожидания ответа подписки';

  @override
  String get subImportEmpty => 'Подписка пуста';

  @override
  String get subImportNoNodes => 'В подписке нет поддерживаемых узлов';

  @override
  String get subImportUnsupportedJson => 'Неподдерживаемый JSON подписки';

  @override
  String subImportHttpStatus(int code) {
    return 'Подписка вернула HTTP $code';
  }

  @override
  String get subImportTooLarge => 'Ответ подписки слишком большой';

  @override
  String subImportRequestFailed(String detail) {
    return 'Ошибка запроса подписки: $detail';
  }

  @override
  String subImportGenericDetail(String detail) {
    return '$detail';
  }

  @override
  String get appRoutingTitle => 'Маршрутизация приложений';

  @override
  String get appRoutingViaProxy => 'Через прокси';

  @override
  String get appRoutingBypass => 'В обход';

  @override
  String get appRoutingHideSystemApps => 'Скрыть системные приложения';

  @override
  String get appRoutingSearchHint => 'Поиск приложений';

  @override
  String get appRoutingClearTooltip => 'Очистить';

  @override
  String appRoutingLoadFailed(String error) {
    return 'Не удалось загрузить приложения: $error';
  }

  @override
  String get appRoutingNoUserApps => 'Пользовательских приложений не найдено.';

  @override
  String get appRoutingNoAppList => 'Система не вернула список приложений.';

  @override
  String get appRoutingNoMatchingApps => 'Нет подходящих приложений.';

  @override
  String get routingScreenTitle => 'МАРШРУТ';

  @override
  String get routingTooltipAdd => 'Добавить';

  @override
  String get routingTooltipGeoFiles => 'Geo-файлы';

  @override
  String get routingMenuImportClipboard => 'Импорт из буфера';

  @override
  String get routingMenuImportFile => 'Импорт из файла';

  @override
  String get routingMenuExportClipboard => 'Экспорт в буфер';

  @override
  String get routingMenuClearRules => 'Очистить';

  @override
  String get routingClipboardEmpty => 'Буфер обмена пуст.';

  @override
  String routingReadFileFailed(String error) {
    return 'Не удалось прочитать файл: $error';
  }

  @override
  String get routingFileEmpty => 'Файл пуст.';

  @override
  String routingParseFailed(String error) {
    return 'Не удалось разобрать правила: $error';
  }

  @override
  String get routingNoRulesInSource => 'В источнике правил не найдено.';

  @override
  String get routingImportRulesTitle => 'Импорт правил';

  @override
  String routingImportRulesBody(int count) {
    return 'Сейчас сохранено правил: $count. Заменить их импортом или добавить в конец?';
  }

  @override
  String get routingNoRulesToExport => 'Нечего экспортировать.';

  @override
  String routingCopiedRules(int count) {
    return 'Скопировано правил в буфер: $count.';
  }

  @override
  String get routingRulesAlreadyEmpty => 'Список правил уже пуст.';

  @override
  String get routingClearRulesTitle => 'Очистить правила?';

  @override
  String get routingClearRulesBody =>
      'Все пользовательские правила будут удалены.';

  @override
  String get routingDeleteRuleTitle => 'Удалить правило?';

  @override
  String get routingSlidableDelete => 'Удалить';

  @override
  String get routingRestartingMessage =>
      'Маршрутизация изменена. Перезапуск соединения для применения.';

  @override
  String get routingPresetsHeading => 'Пресеты';

  @override
  String get routingCustomRulesHeading => 'Пользовательские правила';

  @override
  String get routingNoCustomRulesYet => 'Пользовательских правил пока нет.';

  @override
  String get routingTileAppRouting => 'Маршрутизация приложений';

  @override
  String get routingSelectPresetTooltip => 'Выбрать пресет';

  @override
  String get routingPresetActionsTooltip => 'Действия с пресетом';

  @override
  String get routingCreatePresetMenu => 'Создать пресет';

  @override
  String get routingRenamePresetMenu => 'Переименовать пресет';

  @override
  String get routingDeletePresetMenu => 'Удалить пресет';

  @override
  String get routingNewPresetDialogTitle => 'Новый пресет';

  @override
  String get routingRenamePresetDialogTitle => 'Переименовать пресет';

  @override
  String get routingPresetNameLabel => 'Имя пресета';

  @override
  String get routingDeletePresetTitle => 'Удалить пресет?';

  @override
  String get logLevelDebug => 'DEBUG';

  @override
  String get logLevelInfo => 'INFO';

  @override
  String get logLevelWarning => 'WARN';

  @override
  String get logLevelError => 'ERROR';

  @override
  String get logRetentionOneHour => '1 час';

  @override
  String get logRetentionOneDay => '1 день';

  @override
  String get logRetentionOneWeek => '1 неделя';

  @override
  String get logRetentionForever => 'Не удалять';

  @override
  String journalLoadFailed(String error) {
    return 'Не удалось загрузить журнал: $error';
  }

  @override
  String journalExportFailed(String error) {
    return 'Не удалось экспортировать журнал: $error';
  }

  @override
  String journalClearFailed(String error) {
    return 'Не удалось очистить журнал: $error';
  }

  @override
  String get journalAppBarTitle => 'ЖУРНАЛ';

  @override
  String routingDeleteRuleBody(String name) {
    return '«$name»';
  }

  @override
  String get editSubscriptionTitle => 'Подписка';

  @override
  String get editSubscriptionSectionTitle => 'Подписка';

  @override
  String get editSubscriptionDeleteTooltip => 'Удалить подписку';

  @override
  String get editSubscriptionSaveTooltip => 'Сохранить';

  @override
  String get editSubscriptionAutoUpdateIntervalLabel =>
      'Интервал автообновления';

  @override
  String get editServerCopyTooltip => 'Копировать конфигурацию сервера';

  @override
  String get editServerCopyAsUrl => 'URL';

  @override
  String get editServerCopyAsJson => 'JSON';

  @override
  String get editServerCopyAsQr => 'QR-код';

  @override
  String get editServerQrTitle => 'QR-код сервера';

  @override
  String get editServerQrHint => 'Отсканируйте, чтобы импортировать сервер';

  @override
  String get editServerUrlCopied =>
      'Ссылка на сервер скопирована. Она содержит ваши учётные данные — храните в тайне.';

  @override
  String get editServerJsonCopied =>
      'JSON-конфиг сервера скопирован. Он содержит ваши учётные данные — храните в тайне.';

  @override
  String get editServerAdvancedUrlOmitted =>
      'URL/QR не содержит нестандартные расширенные настройки. Для полного экспорта используйте JSON или профиль Voidlex.';

  @override
  String get editServerShowJson => 'Редактировать как JSON';

  @override
  String get editServerShowForm => 'Вернуться к форме';

  @override
  String get editServerJsonEditorLabel => 'JSON сервера Voidlex';

  @override
  String get editServerJsonEditorHelper =>
      'Отредактируйте конфигурацию одного поддерживаемого сервера. При сохранении JSON будет применён к этому серверу.';

  @override
  String get editServerJsonInvalid =>
      'JSON должен содержать ровно одну корректную конфигурацию поддерживаемого сервера.';

  @override
  String jsonEditorSyntaxError(int line, int column, String error) {
    return 'Строка $line, колонка $column: Ошибка синтаксиса ($error)';
  }

  @override
  String jsonEditorValid(String details) {
    return 'Корректная конфигурация: $details';
  }

  @override
  String get jsonEditorIncomplete =>
      'Синтаксис JSON корректен, но конфигурация сервера не полная';

  @override
  String get jsonEditorFormatTooltip => 'Форматировать JSON';

  @override
  String get jsonEditorWrapTooltip => 'Перенос строк';

  @override
  String get jsonEditorGoToError => 'К ошибке';

  @override
  String jsonEditorLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count строк',
      many: '$count строк',
      few: '$count строки',
      one: '$count строка',
    );
    return '$_temp0';
  }

  @override
  String get settingsHwidLoading => 'Загрузка…';

  @override
  String get settingsHwidUnavailable => 'Недоступно';

  @override
  String get providerSettingsTitle => 'Параметры провайдера';

  @override
  String get providerSubscriptionsHeading => 'Подписки';

  @override
  String get providerAutoUpdateIntervalTitle => 'Интервал автообновления';

  @override
  String get providerAutoUpdateIntervalSubtitle =>
      'Обновлять все сохранённые подписки провайдера с выбранным интервалом, пока Void//Lex запущен.';

  @override
  String get providerAutoUpdateIntervalTooltip => 'Интервал автообновления';

  @override
  String get providerPingAfterUpdateTitle => 'Пинг после обновления';

  @override
  String get providerPingAfterUpdateSubtitle =>
      'После успешного обновления подписки выполнить замер задержек для узлов провайдера.';

  @override
  String get providerUpdateOnLaunchTitle => 'Обновлять при запуске';

  @override
  String get providerUpdateOnLaunchSubtitle =>
      'Один раз обновить сохранённые подписки провайдера после старта приложения.';

  @override
  String get providerSendHwidTitle => 'Отправлять HWID';

  @override
  String get providerSendHwidSubtitle =>
      'Добавлять HWID устройства в запросы к провайдеру в заголовке X-HWID, если провайдер этого требует.';

  @override
  String get providerAllowInsecureTitle => 'Пропускать ошибки TLS';

  @override
  String get providerAllowInsecureSubtitle =>
      'Игнорировать ошибки проверки TLS при загрузке подписок. Включайте только для доверенных частных провайдеров.';

  @override
  String get providerProtectSubscriptionsTitle => 'Защитить подписки';

  @override
  String get providerProtectSubscriptionsSubtitle =>
      'Запретить редактирование узлов подписок и экспортировать подписки только как обфусцированные коды (скрыты от случайного просмотра, это не стойкое шифрование).';

  @override
  String get subscriptionShareEncrypted => 'Поделиться обфусцированным кодом';

  @override
  String get subscriptionShareEncryptedCopied =>
      'Обфусцированный код подписки скопирован. Он всё ещё содержит URL вашей подписки — храните в тайне.';

  @override
  String get subscriptionShareEncryptedFailed =>
      'Не удалось сгенерировать обфусцированный код.';

  @override
  String get subscriptionHideNa => 'Не отображать N/A';

  @override
  String get subscriptionShowNa => 'Отображать N/A';

  @override
  String get subscriptionImportEncryptedFailed =>
      'Неверный или повреждённый код.';

  @override
  String get subscriptionIntervalOneHour => '1 час';

  @override
  String get subscriptionIntervalThreeHours => '3 часа';

  @override
  String get subscriptionIntervalSixHours => '6 часов';

  @override
  String get subscriptionIntervalTwelveHours => '12 часов';

  @override
  String get subscriptionIntervalDefault => 'По умолчанию';

  @override
  String get geoFilesAppBarTitle => 'Geo-файлы';

  @override
  String get geoAutoUpdateTitle => 'Автообновление Geo-файлов';

  @override
  String get geoAutoUpdateSubtitle =>
      'Автоматически обновляет Geo-файлы с сохранёнными URL.';

  @override
  String get geoAutoUpdateDisabled => 'Отключено';

  @override
  String get geoAutoUpdateOneDay => 'Каждый день';

  @override
  String get geoAutoUpdateThreeDays => 'Каждые 3 дня';

  @override
  String get geoAutoUpdateSevenDays => 'Каждые 7 дней';

  @override
  String geoUpdateFileTitle(String fileName) {
    return 'Обновить $fileName';
  }

  @override
  String get geoFileUrlLabel => 'URL файла';

  @override
  String geoFileUrlHint(String fileName) {
    return 'https://example.com/$fileName';
  }

  @override
  String get geoUrlInvalid => 'Введите корректный URL (http или https).';

  @override
  String geoLoadFailed(String error) {
    return 'Не удалось загрузить geo-файлы: $error';
  }

  @override
  String get geoNoSavedUrl =>
      'Нет сохранённого URL. Сначала используйте «Обновить по URL».';

  @override
  String geoUpdateFileFailed(String fileName, String error) {
    return 'Не удалось обновить $fileName: $error';
  }

  @override
  String geoFileUpdated(String fileName) {
    return '$fileName обновлён.';
  }

  @override
  String geoFileImported(String fileName) {
    return '$fileName импортирован.';
  }

  @override
  String get geoUpdateByUrl => 'Обновить по URL';

  @override
  String get geoLoadFromDevice => 'Загрузить с устройства';

  @override
  String get geoRefreshTooltip => 'Обновить';

  @override
  String get geoMetaSource => 'Источник';

  @override
  String get geoMetaUpdated => 'Обновлено';

  @override
  String get geoMetaSize => 'Размер';

  @override
  String get geoStatusInstalled => 'Установлен';

  @override
  String get geoStatusMissing => 'Нет файла';

  @override
  String get geoNeverUpdated => 'Никогда';

  @override
  String get geoSourceUnknown => 'Неизвестно';

  @override
  String get geoSourceBundled => 'В комплекте';

  @override
  String get geoSourceUrl => 'URL';

  @override
  String get geoSourceDevice => 'Устройство';

  @override
  String get routingRuleEditorTitle => 'Правило';

  @override
  String get routingRuleSaveTooltip => 'Сохранить';

  @override
  String get routingRuleMatcherRequired =>
      'Укажите хотя бы один домен, IP, порт, сеть или протокол.';

  @override
  String get routingRuleNameLabel => 'Имя';

  @override
  String get routingRuleEnabledLabel => 'Включено';

  @override
  String get routingRuleConnectionLabel => 'Соединение';

  @override
  String get routingRuleDomainLabel => 'Домен';

  @override
  String get routingRuleIpLabel => 'IP';

  @override
  String get routingRulePortLabel => 'Порт';

  @override
  String get routingRulePortInvalid =>
      'Укажите порты от 1 до 65535 через запятую; диапазоны должны иметь вид начало-конец.';

  @override
  String get routingRuleNetworkLabel => 'Сеть';

  @override
  String get routingRuleProtocolLabel => 'Протокол';

  @override
  String get routingRuleDomainHint => 'geosite:youtube, domain:example.com';

  @override
  String get routingRuleIpHint => 'geoip:private, 1.1.1.1/32';

  @override
  String get routingRulePortHint => '443, 1000-2000';

  @override
  String get protocolChipHttp => 'HTTP';

  @override
  String get protocolChipTls => 'TLS';

  @override
  String get protocolChipBittorrent => 'BITTORRENT';

  @override
  String get qrScanTitle => 'СКАН QR';

  @override
  String get qrScanAlignHint => 'ВЫРОВНЯЙТЕ QR · В РАМКУ';

  @override
  String get qrFlashlightOn => 'Включить вспышку';

  @override
  String get qrFlashlightOff => 'Выключить вспышку';

  @override
  String get qrPermissionMessage =>
      'Для сканирования QR нужен доступ к камере. Разрешите его в настройках системы.';

  @override
  String get qrUnsupportedMessage =>
      'Сканирование QR на этом устройстве недоступно.';

  @override
  String qrCameraFailedCode(String code) {
    return 'Не удалось запустить камеру ($code).';
  }

  @override
  String qrCameraFailedDetail(String detail) {
    return 'Не удалось запустить камеру: $detail';
  }

  @override
  String get importReadJsonFailed => 'Не удалось прочитать JSON-файл';

  @override
  String get importQrPayloadEmpty => 'QR-код пуст';

  @override
  String importReadJsonFailedDetail(String error) {
    return 'Не удалось прочитать JSON-файл: $error';
  }

  @override
  String get importJsonMalformed => 'Некорректный JSON';

  @override
  String get importClipboardUnsupported =>
      'В буфере обмена нет поддерживаемой конфигурации сервера';

  @override
  String get importQrUnsupportedConfig =>
      'В QR нет поддерживаемой конфигурации сервера';

  @override
  String get importFileUnsupportedConfig =>
      'В файле нет поддерживаемой конфигурации сервера';

  @override
  String get importClipboardNoVless =>
      'В буфере нет ссылки vless:// или JSON-конфигурации';

  @override
  String get importQrNoVless =>
      'В QR нет ссылки vless:// или JSON-конфигурации';

  @override
  String get importFileNoVless =>
      'В файле нет ссылки vless:// или JSON-конфигурации';

  @override
  String get importClipboardNoHy2 =>
      'В буфере нет поддерживаемой ссылки или JSON-конфигурации';

  @override
  String get importQrNoHy2 =>
      'В QR нет поддерживаемой ссылки или JSON-конфигурации';

  @override
  String get importFileNoHy2 =>
      'В файле нет поддерживаемой ссылки или JSON-конфигурации';

  @override
  String get importHy2MalformedUri => 'Некорректная ссылка Hysteria2';

  @override
  String get importHy2MissingAuth => 'Не указан пароль Hysteria2';

  @override
  String get importHy2MissingHost => 'Не указан хост Hysteria2';

  @override
  String get importHy2InvalidPort => 'Порт Hysteria2 вне допустимого диапазона';

  @override
  String get importHy2UnsupportedObfs =>
      'Для Hysteria2 поддерживается только обфускация Salamander';

  @override
  String get importHy2MissingObfsPassword =>
      'Не указан пароль обфускации Salamander';

  @override
  String get importNaiveWrongScheme =>
      'Ссылка не является поддерживаемой ссылкой NaiveProxy';

  @override
  String get importNaiveMalformedUri => 'Некорректная ссылка NaiveProxy';

  @override
  String get importNaiveMissingHost => 'Не указан хост NaiveProxy';

  @override
  String get importNaiveInvalidPort =>
      'Порт NaiveProxy вне допустимого диапазона';

  @override
  String get importNaiveInvalidMode =>
      'Режим NaiveProxy должен быть HTTPS или QUIC';

  @override
  String get importNaiveInvalidCongestionControl =>
      'Управление перегрузкой QUIC для NaiveProxy не поддерживается';

  @override
  String get importVlessMalformedUri => 'Некорректная ссылка';

  @override
  String get importVlessMissingUuid => 'В ссылке нет UUID';

  @override
  String get importVlessInvalidUuid => 'UUID не соответствует RFC 4122';

  @override
  String get importVlessMissingHost => 'Не указан хост';

  @override
  String get importVlessInvalidPort => 'Порт вне допустимого диапазона';

  @override
  String get importVlessUnsupportedTransport => 'Транспорт не поддерживается';

  @override
  String get importVlessUnsupportedSecurity =>
      'Тип безопасности не поддерживается (только none/tls/reality)';

  @override
  String get importedOneServer => 'Импортирован 1 сервер.';

  @override
  String importedNServers(int count) {
    return 'Импортировано серверов: $count.';
  }

  @override
  String importedSubscriptionOne(String name) {
    return 'Импортирована подписка «$name» с 1 сервером.';
  }

  @override
  String importedSubscriptionMany(String name, int count) {
    return 'Импортирована подписка «$name» с $count серверами.';
  }

  @override
  String get show => 'Показать';

  @override
  String get hide => 'Скрыть';

  @override
  String get decrease => 'Уменьшить';

  @override
  String get increase => 'Увеличить';

  @override
  String get tunnelSettingsTitle => 'Туннель';

  @override
  String get tunnelGroupNetwork => 'Сеть';

  @override
  String get tunnelGroupTrafficDns => 'Трафик и DNS';

  @override
  String get tunnelGroupOptimization => 'Оптимизация';

  @override
  String get tunnelGroupAdvanced => 'Расширенные';

  @override
  String get tunnelGroupLocalProxy => 'Локальный прокси';

  @override
  String get tunnelUseLocalDns => 'Локальный DNS';

  @override
  String get tunnelUseLocalDnsDescription =>
      'Использовать системный DNS-резолвер устройства вместо удалённого DNS-сервера.';

  @override
  String get tunnelEnableServerResolving => 'DNS для серверов';

  @override
  String get tunnelEnableServerResolvingDescription =>
      'Разрешать доменные имена прокси-серверов в IP-адреса перед подключением.';

  @override
  String get tunnelPacketAnalysis => 'Анализ пакетов';

  @override
  String get tunnelPacketAnalysisDescription =>
      'Анализировать метаданные HTTP, TLS и QUIC для маршрутизации по домену назначения.';

  @override
  String get tunnelNetworkStack => 'Сетевой стек';

  @override
  String get tunnelNetworkStackDescription =>
      'Выбрать реализацию TCP и UDP, которую использует движок TUN. На Android по умолчанию рекомендуется gVisor.';

  @override
  String get tunnelMtu => 'MTU';

  @override
  String get tunnelMtuDescription =>
      'Максимальный размер пакета интерфейса TUN. Допустимый диапазон: 1280–9000.';

  @override
  String get tunnelMtuHint => '1500';

  @override
  String get tunnelIpMode => 'Режим IP';

  @override
  String get tunnelIpModeDescription =>
      'Выбрать семейства IP-адресов, маршрутизируемые через туннель.';

  @override
  String get tunnelNetStackSystem => 'System';

  @override
  String get tunnelNetStackGvisor => 'gVisor';

  @override
  String get tunnelNetStackMixed => 'Mixed';

  @override
  String get tunnelIpModeIpv4 => 'IPv4';

  @override
  String get tunnelIpModeIpv6 => 'IPv6';

  @override
  String get tunnelIpModeMixed => 'Mixed';

  @override
  String get tunnelBlockUdp => 'Блокировать UDP';

  @override
  String get tunnelBlockUdpDescription =>
      'Блокирует UDP приложений в туннеле. DNS обрабатывается отдельно.';

  @override
  String get tunnelXrayTun => 'Xray TUN';

  @override
  String get tunnelXrayTunDescription =>
      'Поддержка fullcone UDP. Экспериментально. Может увеличить расход батареи';

  @override
  String get tunnelEnableDnsForTun => 'DNS для TUN';

  @override
  String get tunnelEnableDnsForTunDescription =>
      'Заменить DNS-сервер Xray TUN на адрес, указанный ниже.';

  @override
  String get tunnelTunDnsLabel => 'DNS TUN';

  @override
  String get tunnelTunDnsHint => '1.1.1.1';

  @override
  String get tunnelCustomSocksTitle => 'Учётные данные SOCKS5';

  @override
  String get tunnelCustomSocksOnDescription =>
      'Используются данные с этого экрана.';

  @override
  String get tunnelCustomSocksOffDescription =>
      'Выкл. — для каждой сессии генерируются новые данные.';

  @override
  String get tunnelProxyUserLabel => 'Пользователь';

  @override
  String get tunnelProxyPasswordLabel => 'Пароль';

  @override
  String get tunnelProxyInboundHelp =>
      'Используйте эти данные для подключения внешних приложений к локальным SOCKS5 (127.0.0.1:10808) или HTTP (127.0.0.1:10809).';

  @override
  String get tunnelRegenerate => 'Сгенерировать';

  @override
  String get tunnelFragmentEnable => 'Фрагментация';

  @override
  String get tunnelFragmentOnDescription =>
      'Параметры применяются к исходящему трафику Xray.';

  @override
  String get tunnelFragmentOffDescription =>
      'Выкл. — трафик идёт через прокси напрямую.';

  @override
  String get tunnelFragmentPackets => 'Пакеты фрагментации';

  @override
  String get tunnelFragmentPacketsDescription =>
      'Выбрать начальные записи TCP для разбиения; tlshello нацелен на TLS ClientHello.';

  @override
  String get tunnelFragmentLength => 'Длина фрагмента (min-max)';

  @override
  String get tunnelFragmentLengthDescription =>
      'Случайный диапазон размера каждого фрагмента в байтах.';

  @override
  String get tunnelFragmentInterval => 'Интервал фрагмента (min-max)';

  @override
  String get tunnelFragmentIntervalDescription =>
      'Случайная задержка между фрагментами в миллисекундах.';

  @override
  String get tunnelFragmentMaxSplit => 'Макс. разбиение (min-max)';

  @override
  String get tunnelFragmentMaxSplitDescription =>
      'Случайный предел количества фрагментов, создаваемых из одной записи.';

  @override
  String get tunnelNoiseSettings => 'Шум';

  @override
  String get tunnelNoiseSettingsDescription =>
      'Отправлять UDP-шум перед первым реальным пакетом. Может нарушить работу некоторых соединений.';

  @override
  String get tunnelNoiseType => 'Тип шума';

  @override
  String get tunnelNoiseTypeDescription =>
      'Выбрать способ генерации или кодирования содержимого шумового пакета.';

  @override
  String get tunnelNoisePacketLengthRange => 'Диапазон длины пакета';

  @override
  String get tunnelNoisePacketLengthRangeDescription =>
      'Случайный диапазон длины генерируемого шума в байтах.';

  @override
  String get tunnelNoisePacket => 'Пакет шума';

  @override
  String get tunnelNoisePacketDescription =>
      'Содержимое пакета в формате, выбранном выше.';

  @override
  String get tunnelNoiseDelay => 'Задержка шума (min-max)';

  @override
  String get tunnelNoiseDelayDescription =>
      'Случайная задержка после шумового пакета в миллисекундах.';

  @override
  String get tunnelNoiseApplyTo => 'Применить к';

  @override
  String get tunnelNoiseApplyToDescription =>
      'Ограничить шум всем IP-трафиком, только IPv4 или только IPv6.';

  @override
  String get tunnelNoiseTypeRandom => 'Random';

  @override
  String get tunnelNoiseTypeString => 'String';

  @override
  String get tunnelNoiseTypeHex => 'Hex';

  @override
  String get tunnelNoiseTypeBase64 => 'Base64';

  @override
  String get tunnelNoiseApplyIp => 'IP';

  @override
  String get tunnelNoiseApplyIpv4 => 'IPv4';

  @override
  String get tunnelNoiseApplyIpv6 => 'IPv6';

  @override
  String get tunnelMuxEnable => 'Мультиплексирование';

  @override
  String get tunnelMuxOnDescription => 'Параметры настраиваются ниже.';

  @override
  String get tunnelMuxOffDescription =>
      'Выкл. — каждый поток использует своё соединение с туннелем.';

  @override
  String get tunnelMuxTcpConnections => 'TCP-соединения (-1…128)';

  @override
  String get tunnelMuxTcpConnectionsDescription =>
      'Максимум TCP-подключений в одном MUX-соединении. -1 отключает MUX для TCP.';

  @override
  String get tunnelMuxXudpConnections => 'XUDP-соединения (-1…1024)';

  @override
  String get tunnelMuxXudpConnectionsDescription =>
      'Максимум UDP-подключений в одном XUDP-туннеле. -1 отключает MUX для UDP.';

  @override
  String get tunnelMuxQuicBehavior => 'QUIC в MUX';

  @override
  String get tunnelMuxQuicBehaviorDescription =>
      'Блокировать, передавать через MUX или пропускать UDP/443 в обход MUX.';

  @override
  String get tunnelMuxQuicReject => 'Reject';

  @override
  String get tunnelMuxQuicAllow => 'Allow';

  @override
  String get tunnelMuxQuicPassthrough => 'Passthrough';

  @override
  String get tvSectionConnect => 'ПОДКЛЮЧЕНИЕ';

  @override
  String get tvSectionNodes => 'НОДЫ';

  @override
  String tvNodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count НОД',
      many: '$count НОД',
      few: '$count НОДЫ',
      one: '$count НОДА',
      zero: 'НЕТ НОД',
    );
    return '$_temp0';
  }

  @override
  String get tvEmptyNodes =>
      'Серверов пока нет — откройте приложение на телефоне, чтобы импортировать подписку.';

  @override
  String get tvGroupManual => 'Вручную';

  @override
  String get tvExitDevPreview => 'Выйти из TV-режима';

  @override
  String get tvStatusIdle => 'ОЖИДАНИЕ';

  @override
  String get tvStatusNegotiating => 'СОГЛАСОВАНИЕ…';

  @override
  String get tvStatusSecure => 'ЗАЩИЩЕНО';

  @override
  String get tvStatusError => 'ОШИБКА';

  @override
  String get tvHubLabelOff => 'ПОДКЛЮЧИТЬ';

  @override
  String get tvHubLabelConnecting => 'СОГЛАСОВАНИЕ';

  @override
  String get tvHubLabelOn => 'АКТИВНО';

  @override
  String get tvHubLabelError => 'ПОВТОРИТЬ';

  @override
  String get tvHubSubOff => 'OK / ВЫБОР';

  @override
  String get tvHubSubConnecting => 'ПОДОЖДИТЕ';

  @override
  String get tvHubSubOn => 'OK — ОТКЛЮЧИТЬ';

  @override
  String get tvHubSubError => 'OK — ПОВТОР';

  @override
  String get tvKvExitNode => 'ВЫХОДНАЯ НОДА';

  @override
  String get tvKvExitIp => 'ВЫХОДНОЙ IP';

  @override
  String get tvKvRegion => 'РЕГИОН';

  @override
  String get tvKvDown => '↓ ВНИЗ';

  @override
  String get tvKvUp => '↑ ВВЕРХ';

  @override
  String get tvKvExpires => 'Истекает';

  @override
  String get tvKvNodes => 'Ноды';

  @override
  String get tvSideSplit => 'SPLIT';

  @override
  String get tvSideSplitSub => 'ПО ПРАВИЛАМ';

  @override
  String get tvSideGlobal => 'GLOBAL';

  @override
  String get tvSideGlobalSub => 'ВЕСЬ ТРАФИК';

  @override
  String get tvSidePreset => 'PRESET';

  @override
  String get tvSidePresetSub => 'НАБОР ПРАВИЛ';

  @override
  String get tvSideSettings => 'SETTINGS';

  @override
  String get tvSideSettingsSub => 'НАСТРОЙКИ';

  @override
  String get tvActionConnect => 'ПОДКЛЮЧИТЬ';

  @override
  String get tvActionDisconnect => 'ОТКЛЮЧИТЬ';

  @override
  String get tvActionCancel => 'ОТМЕНА';

  @override
  String get tvActionToggle => 'ПЕРЕКЛЮЧИТЬ';

  @override
  String get tvActionSelectNode => 'ВЫБРАТЬ НОДУ';

  @override
  String get tvActionSelect => 'ВЫБРАТЬ';

  @override
  String get tvActionRetry => 'ПОВТОР';

  @override
  String get tvActionExit => 'ВЫХОД';

  @override
  String get tvActionClose => 'ЗАКРЫТЬ';

  @override
  String get tvActionNodeOptions => 'ПРЕСЕТ НОДЫ';

  @override
  String get tvActionSubscriptions => 'ПОДПИСКИ';

  @override
  String get tvActionPingScan => 'СКАН PING';

  @override
  String get tvActionBackKey => 'BACK';

  @override
  String get tvActionMenuKey => 'MENU';

  @override
  String get tvActionPlayPauseKey => 'PLAY/PAUSE';

  @override
  String get tvHintRemoteFooter => 'D-PAD · НАВИГАЦИЯ';

  @override
  String get tvOverlaySubscriptionsTitle => 'ПОДПИСКИ';

  @override
  String get tvOverlaySubscriptionsSubtitle =>
      'Импортированные подписки · BACK — закрыть';

  @override
  String get tvOverlaySubscriptionsEmpty => 'Подписки ещё не импортированы.';

  @override
  String get tvOverlayPresetTitle => 'ПРЕСЕТ НОДЫ';

  @override
  String get tvOverlayPresetSubtitleGlobal => 'Выберите режим маршрутизации';

  @override
  String tvOverlayPresetSubtitleForNode(String server) {
    return '$server · выбор пресета маршрутизации';
  }

  @override
  String get tvOverlayFooter => 'BACK · ЗАКРЫТЬ   ·   OK · ВЫБРАТЬ';

  @override
  String get tvPresetCurrentChip => 'ТЕКУЩИЙ';

  @override
  String get tvPresetMainDescription =>
      'Базовые правила маршрутизации — применяются ко всем нодам.';

  @override
  String tvPresetSummary(int rules, int apps) {
    String _temp0 = intl.Intl.pluralLogic(
      rules,
      locale: localeName,
      other: '$rules правил',
      many: '$rules правил',
      few: '$rules правила',
      one: '$rules правило',
      zero: 'Без правил',
    );
    String _temp1 = intl.Intl.pluralLogic(
      apps,
      locale: localeName,
      other: '$apps приложений',
      many: '$apps приложений',
      few: '$apps приложения',
      one: '$apps приложение',
      zero: 'нет приложений',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get tvRefreshedUnknown => '—';

  @override
  String get tvRefreshedJustNow => '↓ Только что';

  @override
  String tvRefreshedMinutesAgo(int minutes) {
    return '↓ Обновлено $minutes мин назад';
  }

  @override
  String tvRefreshedHoursAgo(int hours) {
    return '↓ Обновлено $hours ч назад';
  }

  @override
  String tvRefreshedDaysAgo(int days) {
    return '↓ Обновлено $days дн назад';
  }

  @override
  String get tvLayoutSectionTitle => 'Макет интерфейса';

  @override
  String get tvLayoutSectionSubtitle =>
      'Выберите телефонный макет, горизонтальный TV-макет или автоповорот.';

  @override
  String get tvLayoutVertical => 'Вертикальный';

  @override
  String get tvLayoutHorizontal => 'Горизонтальный';

  @override
  String get tvLayoutAutoRotate => 'Авто';

  @override
  String get settingsFaqLabel => 'FAQ';

  @override
  String get telegramOpenFailed => 'Не удалось открыть ссылку Telegram.';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqSubtitle => 'Частые вопросы';

  @override
  String get faqHint => 'Нажмите на вопрос, чтобы раскрыть ответ.';

  @override
  String get faqQ1 =>
      'Какие серверы нельзя использовать в двухступенчатой цепочке (entry → exit)?';

  @override
  String get faqA1 =>
      'Двухступенчатая цепочка строится ядром Xray через `sockopt.dialerProxy`. Из-за этого действуют ограничения:\n1. **Hysteria2 и NaiveProxy** вообще не поддерживаются в цепочке (ни как входной, ни как выходной узел), так как работают напрямую через движок libbox.\n2. **XHTTP** не рекомендуется ставить выходным узлом (exit): из-за специфики HTTP/2-транспорта рукопожатие может не пройти через entry-туннель. Серверы XHTTP надёжно работают как входной (entry) узел, а на выход лучше ставить VLESS-TCP, WS или REALITY.';

  @override
  String get faqQ2 =>
      'Чем отличаются движки TUN — libbox и Xray TUN? Что выбрать?';

  @override
  String get faqA2 =>
      '**libbox** (sing-box) — основной режим, стабильный, лучше дружит с системой и оптимально расходует батарею. **Xray TUN** — экспериментальный, прокидывает пакеты напрямую через ядро Xray; нужен, если используете специфичные возможности Xray или libbox даёт сбой на вашем устройстве. По умолчанию — libbox.';

  @override
  String get faqQ3 =>
      'Зачем нужен «Глобальный прокси», если VPN и так включён?';

  @override
  String get faqA3 =>
      'Без него действуют ваши правила пресета маршрутизации (per-app, домены, IP, geosite/geoip) — часть трафика может идти напрямую. «Глобальный прокси» временно обходит правила и направляет в туннель всё, что технически возможно. Удобно для теста («доходит ли трафик до сервера вообще?») или когда нужен полный туннель прямо сейчас. Кнопку можно скрыть в настройках.';

  @override
  String get faqQ4 => 'Что такое пресеты маршрутизации и пресет узла?';

  @override
  String get faqA4 =>
      '**Main** — базовый набор правил, применяется ко всем узлам без своего пресета. Дополнительные пресеты можно привязать к конкретным серверам через меню узла → «Пресет правил». Правила в духе Xray: outbound `proxy` / `direct` / `block` по доменам, IP/CIDR, `geoip:` / `geosite:`, портам, сети (tcp/udp), протоколам.';

  @override
  String get faqQ5 => 'Что такое «Выходной туннель» (EXIT)?';

  @override
  String get faqA5 =>
      'Двухступенчатая схема: **входной** узел — тот, что выбран кнопкой подключения; **выходной** — отдельный сервер, через который трафик уходит дальше (entry → exit). Полезно для разделения «куда стучимся» и «откуда выходим в интернет». Входной и выходной узлы должны быть разными — иначе цепочка вырождается в обычное одношаговое подключение.';

  @override
  String get faqQ6 =>
      'Изменил настройки туннеля, но они не применились — почему?';

  @override
  String get faqA6 =>
      'Часть параметров (движок TUN, стек, DNS, MTU, фрагментация, multiplex и др.) применяются только при следующем поднятии туннеля. В **«Настройки → Приложение»** есть переключатель **«Перезапуск при изменениях»** — с ним приложение само переподключит соединение при выходе из настроек. Иначе — отключите и подключите туннель вручную.';

  @override
  String get faqQ7 => 'Что такое HWID и зачем подписка его передаёт?';

  @override
  String get faqA7 =>
      'HWID — стабильный анонимный идентификатор устройства, вычисляемый локально (его можно увидеть в «О приложении»). Он передаётся в заголовке `X-HWID` при запросе подписки, если включена опция **«Отправлять HWID»** в **«Настройки → Провайдер подписки»**. Это нужно некоторым провайдерам для контроля лимита подключённых устройств. Вы можете отключить его отправку в любой момент. Никуда больше HWID не передаётся.';

  @override
  String get faqQ8 =>
      'Чем отличается slim-сборка и нужно ли мне качать GeoData?';

  @override
  String get faqA8 =>
      'Стандартная сборка содержит базы `geoip.dat` и `geosite.dat` (~28 МБ) внутри APK — правила маршрутизации вида `geosite:google` или `geoip:ru` работают сразу. Slim-сборка не включает эти файлы для уменьшения размера APK. Загрузить базы, настроить их автообновление (1, 3 или 7 дней) либо выбрать файл с устройства можно в **«Настройки → Маршрутизация → Файлы GeoData»**. Если geo-правила не используются, базы можно не скачивать.';

  @override
  String get faqQ9 =>
      'Правила «по приложениям» не работают для Push / Play Services / системных служб — это нормально?';

  @override
  String get faqA9 =>
      'Да. Android не пускает VPN внутрь некоторых системных приложений (часть Google Mobile Services, push, обновления системы). Это ограничение системного `VpnService`, а не приложения — обойти его без root нельзя. Их трафик пойдёт мимо туннеля, даже если они в whitelist.';

  @override
  String get faqQ10 => 'Сетевой стек: system / gVisor / mixed — что выбрать?';

  @override
  String get faqA10 =>
      '**gVisor** — стек по умолчанию на Android. Он обрабатывает TUN-трафик в user-space и надёжно работает с libbox 1.14.\n**system** использует системный стек ядра и подходит только для окружений, где такой путь TUN заведомо работает.\n**mixed** использует gVisor для TCP и system для UDP.';

  @override
  String get faqQ11 =>
      'Чем отличаются URL-тест ноды, пинг подключения и диагностика TCP?';

  @override
  String get faqA11 =>
      '**URL-тест ноды** выполняет HTTP-запрос через её собственный outbound после прогрева. **Пинг подключения** проверяет действующий туннель и всю выбранную цепочку. **Диагностика TCP** проверяет только доступность порта и не подтверждает работу прокси. На главном экране можно выбрать TCP или URL; оба инструмента всегда доступны в настройках «Приложение → Диагностика». Переключатель диагностики в меню ноды добавляет проверку противоположного типа. Разовые проверки не меняют пинг в списке. По умолчанию URL-тест обращается к http://cp.cloudflare.com/ и ожидает HTTP 204; для своего адреса — 2xx. Перенаправления считаются ошибкой. Неудача также может означать недоступность целевого сайта.';

  @override
  String get faqQ12 =>
      'Подписка не обновляется или обновилась, но список не изменился — что проверить?';

  @override
  String get faqA12 =>
      '1. Проверьте интервал автообновления (по умолчанию **6 часов**; настраивается в «Настройки → Провайдер подписки» или индивидуально в карточке подписки) и тумблер «Обновлять при запуске».\n2. Обновите вручную кнопкой на карточке подписки.\n3. Если состав серверов не меняется, значит провайдер возвращает прежний список.\n4. Если включена «Защита подписок», локальные правки внутри узлов подписки перезаписываются при обновлении.';

  @override
  String get faqQ13 =>
      'Звонки / игры / онлайн-видео тормозят через VPN — что попробовать?';

  @override
  String get faqA13 =>
      'Большая часть таких приложений работает по UDP / QUIC. Проверьте:\n1. Стек — попробуйте **mixed** (gVisor для TCP, system для UDP).\n2. **Multiplex → QUIC** — поставьте `passthrough` или `reject`; `allow` оборачивает QUIC поверх mux и даёт лишнюю задержку.\n3. Если протокол — Hysteria2, он сам по UDP: проверьте, что провайдер не режет UDP-трафик к серверу.';

  @override
  String get faqQ14 =>
      'Что значит «Multiplex: QUIC — reject / allow / passthrough»?';

  @override
  String get faqA14 =>
      'Multiplex объединяет много логических соединений в одно TCP/XUDP. QUIC — поверх UDP, и поведение mux к нему задаётся отдельно:\n**reject** — блокировать QUIC, приложения сами откатятся на TCP/HTTPS (безопасный дефолт).\n**passthrough** — QUIC идёт мимо mux, отдельным UDP-каналом (быстрее, но без объединения).\n**allow** — QUIC заворачивается в mux (экзотика, ради сокрытия паттерна; обычно медленнее).';

  @override
  String get faqQ15 => 'Почему на экране «———» вместо внешнего IP?';

  @override
  String get faqA15 =>
      'Внешний IP запрашивается уже после подъёма туннеля — отдельным HTTPS-запросом через локальный прокси. Если сеть нестабильна или DNS-запрос блокируется, приложение показывает «Недоступно». На сам факт подключения это не влияет — туннель может работать нормально.';

  @override
  String get faqQ16 => 'Почему автоподключение при запуске не срабатывает?';

  @override
  String get faqA16 =>
      'Опция включается в **Настройки → Приложение**, но Android на ряде прошивок ограничивает автозапуск фоновых сервисов политикой батареи. Снимите оптимизацию батареи для Void//Lex и проверьте системный **«Всегда включённый VPN»** (Android: Настройки → Сеть → VPN → Void//Lex) — он гарантированно поднимает туннель при загрузке устройства.';

  @override
  String get faqQ17 =>
      'Можно ли подключить другое приложение к локальному прокси?';

  @override
  String get faqA17 =>
      'Да: при поднятом туннеле приложение слушает **SOCKS5** на `127.0.0.1:10808` и **HTTP** на `127.0.0.1:10809`. По умолчанию логин/пароль генерируются на каждую сессию заново. Чтобы зафиксировать свои — **Настройки → Туннель → Учётные данные SOCKS5** (включить переключатель и задать пользователя/пароль вручную или сгенерировать).';

  @override
  String get faqQ18 => 'Есть ли встроенный kill switch?';

  @override
  String get faqA18 =>
      'Да. В **«Настройки → Приложение»** доступен встроенный переключатель **«Kill Switch»**. При его включении неожиданный обрыв VPN моментально блокирует весь незащищённый трафик устройства и отображает служебное уведомление для восстановления сети или переподключения. Ручное отключение туннеля пользователем восстанавливает сеть штатно.\nДля максимальной защиты на системном уровне Android также можно включить системный **Always-on VPN** («Блокировать подключения без VPN») через пункт «Автоподключение при загрузке устройства».';

  @override
  String get faqQ19 => 'Куда пишутся данные и логи — это безопасно?';

  @override
  String get faqA19 =>
      'Узлы, подписки, пресеты, журнал — всё локально на устройстве; наружу ничего не уходит, кроме самих запросов к подписке и трафика через выбранный сервер. Журнал можно очистить из «Настройки → Журнал». В verbose-режиме лог содержит чувствительные поля (UUID, host, ключи) — **не публикуйте verbose-дампы как есть.** Приложение не является анонимайзером само по себе — уровень приватности зависит от ваших серверов и правил.';

  @override
  String get faqQ20 => 'Есть ли поддержка ТВ и iOS?';

  @override
  String get faqA20 =>
      '**Android TV / Google TV** — да, отдельный полноэкранный интерфейс с поддержкой пульта (D-pad), общие с мобильной версией узлы и подписки. **iOS / iPadOS** — полноценный клиент в разработке.';

  @override
  String get faqQ21 =>
      'Чем отличается режим «Только прокси» от «VPN-туннель (TUN)»?';

  @override
  String get faqA21 =>
      'Режим выбирается в **«Настройки → Туннель → Режим работы»**:\n• **VPN-туннель (TUN)** — стандартный режим: весь трафик устройства перехватывается через системный VpnService (значок ключа в статусной строке).\n• **Скрыть значок (proxy-only)** — запускает локальный прокси без создания виртуального сетевого интерфейса Android. Значок VPN отсутствует, а системный VPN-слот остаётся свободным для других приложений. Трафик через туннель направляется только из тех программ, где прокси настроен вручную (Telegram, браузер и т.д.).';

  @override
  String get faqQ22 =>
      'Поддерживаются ли протоколы Hysteria2 и NaiveProxy и как их настроить?';

  @override
  String get faqA22 =>
      'Да, VoidLex поддерживает импорт ссылок `hy2://` / `hysteria2://` и `naive+https://` / `naive+quic://`.\nОсобенности работы:\n1. Для них требуется TUN-движок **libbox** (с Xray TUN они не работают).\n2. Они не поддерживают двухступенчатую цепочку (Exit-узел).\n3. В NaiveProxy поддерживаются режимы HTTPS и QUIC.';

  @override
  String get faqQ23 =>
      'Можно ли раздать прокси на другие устройства через точку доступа или Wi-Fi?';

  @override
  String get faqA23 =>
      'Да. В **«Настройки → Туннель → Локальный прокси»** (а также в режиме Proxy-only) можно включить раздачу прокси в локальную сеть. Устройства в одной Wi-Fi сети или подключённые к вашей точке доступа могут использовать SOCKS5 (`порт 10808`) и HTTP (`порт 10809`), указав IP-адрес вашего телефона. Для защиты обязательно включите аутентификацию и задайте логин и пароль в учетных данных SOCKS5/HTTP.';

  @override
  String get faqQ24 =>
      'Туннель выключается в фоне через 10–20 минут — как исправить?';

  @override
  String get faqA24 =>
      'Причиной является агрессивное управление питанием в ряде оболочек Android (HyperOS/MIUI, ColorOS, EMUI, OneUI):\n1. В свойствах приложения VoidLex отключите **«Оптимизацию батареи»** (выберите «Без ограничений»).\n2. Разрешите **«Автозапуск»** и работу в фоновом режиме.\n3. В меню запущенных приложений закрепите карточку VoidLex «замочком».\n4. Для гарантии постоянной работы используйте системный **Always-on VPN** в настройках сети Android.';

  @override
  String get autoConnectOnBootTitle =>
      'Автоподключение при загрузке устройства';

  @override
  String get autoConnectOnBootSubtitle =>
      'Открыть системные настройки «Always-on VPN» — включите «Постоянная VPN» + «Блокировать подключения без VPN», и туннель будет подниматься при загрузке.';

  @override
  String get killSwitchTitle => 'Kill Switch';

  @override
  String get killSwitchSubtitle =>
      'Блокировать интернет при неожиданном падении туннеля. Ручное отключение восстанавливает сеть.';

  @override
  String get runModeSectionTitle => 'Режим работы';

  @override
  String get runModeTunTitle => 'VPN-туннель (TUN)';

  @override
  String get runModeTunSubtitle =>
      'Стандартный режим. Весь трафик идёт через VPN-сервис; в статусной строке виден значок VPN.';

  @override
  String get runModeProxyOnlyTitle => 'Скрыть значок (proxy-only)';

  @override
  String get runModeProxyOnlySubtitle =>
      'Запускать локальный HTTP/SOCKS5-прокси без значка VPN. Работают только приложения с поддержкой прокси, мобильные данные идут напрямую. Прокси настройте вручную в Wi-Fi / браузере. Внимание: порт прокси доступен другим устройствам в той же сети Wi-Fi / точке доступа (требуются логин и пароль).';

  @override
  String get httpProxyAuthTitle => 'HTTP-прокси авторизация';

  @override
  String get httpProxyAuthSubtitle =>
      'Защитить HTTP-прокси на порту 10809 теми же логином/паролем, что и SOCKS5.';

  @override
  String get tunnelRouteOnlyTitle => 'Маршрутизация по домену (routeOnly)';

  @override
  String get tunnelRouteOnlySubtitle =>
      'Использовать SNI/host из сниффинга только для выбора маршрута, не подменяя адрес соединения. Оставьте включённым, если только сниффинг не мешает работе сети.';

  @override
  String get connectionPolicySectionTitle => 'Расширенные настройки';

  @override
  String get connectionPolicySectionSubtitle =>
      'Таймаут. Количество TCP, UDP-соединений.';

  @override
  String get connectionPolicyConnectionsGroup => 'Соединения';

  @override
  String get connectionPolicyIdleTitle => 'Таймаут простоя';

  @override
  String get connectionPolicyIdleSubtitle =>
      'Время ожидания для неактивных соединений, секунды.';

  @override
  String get connectionPolicyMaxTcpTitle => 'TCP соединений';

  @override
  String get connectionPolicyMaxTcpSubtitle =>
      'Максимум одновременных TCP-соединений.';

  @override
  String get connectionPolicyMaxUdpTitle => 'UDP соединений';

  @override
  String get connectionPolicyMaxUdpSubtitle =>
      'Максимум одновременных UDP-соединений.';

  @override
  String get urlSchemesTitle => 'Схемы URL-адресов';

  @override
  String get urlSchemesSubtitle =>
      'Автоматизация VoidLex через Shortcuts, Tasker и другие приложения.';

  @override
  String get urlSchemesNote =>
      'Используйте эти схемы для автоматизации через Shortcuts, Tasker или другие приложения. Нажмите на схему, чтобы скопировать.';

  @override
  String get urlSchemesNoteHeader => 'Примечание';

  @override
  String get urlSchemesStartSection => 'ЗАПУСТИТЬ ТУННЕЛЬ';

  @override
  String get urlSchemesStopSection => 'ОСТАНОВИТЬ СОЕДИНЕНИЕ';

  @override
  String get urlSchemesToggleSection => 'ПЕРЕКЛЮЧИТЬ СОЕДИНЕНИЕ';

  @override
  String get urlSchemesRestartSection => 'ПЕРЕЗАПУСТИТЬ СОЕДИНЕНИЕ';

  @override
  String get urlSchemesImportSection => 'ДОБАВИТЬ КОНФИГУРАЦИЮ';

  @override
  String get urlSchemesImportRulesetSection => 'ИМПОРТ ПРАВИЛ';

  @override
  String get urlSchemeCopied => 'Скопировано в буфер';

  @override
  String get additionalTlsFingerprintsTitle => 'Дополнительные TLS-отпечатки';

  @override
  String get additionalTlsFingerprintsSubtitle =>
      'Показывать Safari 16.0, Chrome 120 и iOS 14. Сохранённый выбор работает и после отключения.';

  @override
  String get urlProbeTargetTitle => 'Адрес URL-теста нод';

  @override
  String get urlProbeTargetHelp =>
      'Запрос проходит через каждую ноду. Ошибка теста также может означать недоступность выбранного сайта.';

  @override
  String get urlProbeTargetInvalid =>
      'Введите полный HTTP/HTTPS URL без логина, пароля и фрагмента.';

  @override
  String get tcpDiagnosticTitle => 'Диагностика TCP';

  @override
  String get tcpDiagnosticSubtitle =>
      'Проверяет только порт, без авторизации прокси. Не меняет пинг на главном экране.';

  @override
  String get nodeDiagnosticModeTitle => 'Диагностика нод по умолчанию';

  @override
  String get nodeDiagnosticModeHelp =>
      'Выбор TCP или URL для пинга нод на главном экране.';

  @override
  String get nodeDiagnosticMenuTitle => 'Диагностика в меню ноды';

  @override
  String get nodeDiagnosticMenuHelp =>
      'Добавить другую проверку в меню ноды: URL при выборе TCP по умолчанию, или TCP при выборе URL.';

  @override
  String get urlDiagnosticTitle => 'Диагностика URL';

  @override
  String get urlDiagnosticSubtitle =>
      'Проверить отдельную ноду через её outbound, не меняя результаты на главном экране.';
}
