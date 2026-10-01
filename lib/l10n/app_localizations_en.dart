// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Void//Lex';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get clear => 'Clear';

  @override
  String get retry => 'Retry';

  @override
  String get append => 'Append';

  @override
  String get replace => 'Replace';

  @override
  String get loading => 'Loading…';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get more => 'More';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get untitled => 'Untitled';

  @override
  String keepPrefix(String label) {
    return 'Keep: $label';
  }

  @override
  String levelsSelectedNone(String retention) {
    return 'No levels selected — $retention';
  }

  @override
  String levelsSelectedSome(String levels, String retention) {
    return '$levels — $retention';
  }

  @override
  String get applicationSettingsTitle => 'Application settings';

  @override
  String get themeSection => 'Theme';

  @override
  String get settingsGroupInterface => 'Interface';

  @override
  String get settingsGroupConnection => 'Connection';

  @override
  String get settingsGroupNodes => 'Diagnostics';

  @override
  String get settingsGroupProfile => 'Profile';

  @override
  String get settingsGroupAdvanced => 'Advanced';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appLanguageTitle => 'App language';

  @override
  String get appLanguageSubtitle => 'Choose the interface language.';

  @override
  String get appLanguageAuto => 'Auto';

  @override
  String get appLanguageEnglish => 'English';

  @override
  String get appLanguageRussian => 'Русский';

  @override
  String get autoConnectOnLaunchTitle => 'Auto-connect on launch';

  @override
  String get autoConnectOnLaunchSubtitle => 'May not work on some devices.';

  @override
  String get allowDeepLinkVpnAutomationTitle => 'Allow VPN automation links';

  @override
  String get allowDeepLinkVpnAutomationSubtitle =>
      'When enabled, voidlex://connect and similar links can change the connection without asking each time.';

  @override
  String get startHomeWidgetsCollapsedTitle => 'Start with widgets collapsed';

  @override
  String get startHomeWidgetsCollapsedSubtitle =>
      'Open the home screen in compact mode by default.';

  @override
  String get restartOnSettingsChangeTitle => 'Restart on changes';

  @override
  String get showSpeedInNotificationTitle =>
      'Show connection speed in notifications';

  @override
  String get keepAwakeTitle => 'Keep VPN awake';

  @override
  String get keepAwakeSubtitle =>
      'Hold a partial wake lock while connected. Uses more battery.';

  @override
  String get verboseXrayLogsTitle => 'Verbose Xray logs';

  @override
  String get verboseXrayLogsSubtitle =>
      'Capture xray-core info-level errors (dial failures, Reality auth, ALPN) and dump the generated config once at startup. Use only for diagnostics; sensitive fields are masked.';

  @override
  String get applicationSettingsPingTargetTitle => 'TCP diagnostic address';

  @override
  String get applicationSettingsPingTargetDefault => 'Node address';

  @override
  String get applicationSettingsPingTargetDialogTitle =>
      'TCP diagnostic address';

  @override
  String get applicationSettingsPingTargetFieldLabel => 'Host or URL';

  @override
  String get applicationSettingsPingTargetHint => 'example.com:443';

  @override
  String get applicationSettingsPingTargetInvalid =>
      'Enter a host, URL, or host:port.';

  @override
  String get applicationSettingsPingTargetReset => 'Use node address';

  @override
  String get logSettingsTitle => 'Log options';

  @override
  String get logSettingsDialogTitle => 'Log options';

  @override
  String get logLevelsLabel => 'Levels';

  @override
  String get logStorageTimeLabel => 'Storage time';

  @override
  String get logStorageTimeTooltip => 'Storage time';

  @override
  String get applicationSettingsShowGlobalProxyTitle => 'Split/Global widget';

  @override
  String get applicationSettingsGlobalProxySubtitle =>
      'Show the full-tunnel button on the home screen.';

  @override
  String get applicationSettingsShowExitNodeTitle => 'Exit/Node widget';

  @override
  String get applicationSettingsShowExitNodeSubtitle =>
      'Show connection details on the home screen.';

  @override
  String get exitInfoSpeedLabel => 'SPEED';

  @override
  String get exitInfoDownLabel => 'DOWN';

  @override
  String get exitInfoUpLabel => 'UP';

  @override
  String get exitInfoMemoryLabel => 'MEM';

  @override
  String get applicationSettingsAutoSortServersByPingTitle => 'Sort by ping';

  @override
  String get applicationSettingsAutoSortServersByPingSubtitle =>
      'Put faster servers higher after a latency scan.';

  @override
  String get profileExportTitle => 'Export profile';

  @override
  String get profileExportSubtitle =>
      'Save manual nodes, subscriptions, and routing presets as a JSON file.';

  @override
  String get profileExportedText => 'Profile exported.';

  @override
  String get profileExportProtectedSubscriptionsSkipped =>
      'Profile exported. Protected subscriptions cannot be exported.';

  @override
  String get profileExportProtectedSubscriptionsEncrypted =>
      'Profile exported. Protected subscriptions are saved as obfuscated codes — hidden from casual viewing, not strong encryption.';

  @override
  String get profileExportWarningTitle => 'Export profile?';

  @override
  String get profileExportWarningBody =>
      'The exported JSON contains your manual nodes in full, including UUIDs and passwords, in plain text. Store and share the file carefully.';

  @override
  String get profileExportWarningConfirm => 'Export';

  @override
  String profileExportFailed(String error) {
    return 'Failed to export profile: $error';
  }

  @override
  String get profileImportTitle => 'Import profile';

  @override
  String get profileImportSubtitle => 'Load a Void//Lex profile JSON file.';

  @override
  String get profileImportModeTitle => 'Import profile';

  @override
  String get profileImportModeBody =>
      'Replace current manual nodes, subscriptions, and routing presets, or append this profile to the current data?';

  @override
  String get profileImportFileEmpty => 'Profile file is empty.';

  @override
  String get profileImportReadFailed => 'Failed to read profile file.';

  @override
  String profileImportReadFailedDetail(String error) {
    return 'Failed to read profile file: $error';
  }

  @override
  String profileImportFailed(String error) {
    return 'Failed to import profile: $error';
  }

  @override
  String get profileImportInvalidJson => 'Profile JSON is malformed.';

  @override
  String get profileImportUnsupportedFormat =>
      'File is not a Void//Lex profile.';

  @override
  String get profileImportUnsupportedVersion =>
      'Profile version is not supported.';

  @override
  String get profileImportEmptyProfile =>
      'Profile does not contain importable data.';

  @override
  String get profileImportTooLarge => 'Profile file is too large (max 4 MB).';

  @override
  String get secureStorageWriteFailed =>
      'Could not save the password to secure storage. Try again.';

  @override
  String get deepLinkVpnControlColdStart =>
      'Open Void//Lex and use Connect in the app. VPN control links are ignored on cold start.';

  @override
  String get deepLinkConsentTitle => 'Open external link?';

  @override
  String get deepLinkConsentImportServers =>
      'This link wants to add one or more servers to Void//Lex.';

  @override
  String get deepLinkConsentImportRuleset =>
      'This link wants to download routing rules and add them. This may restart your active connection.';

  @override
  String get deepLinkConsentImportSubscription =>
      'This link wants to import a subscription or server into Void//Lex.';

  @override
  String get deepLinkConsentVpnControlConnect =>
      'This link wants to connect Void//Lex to your selected server.';

  @override
  String get deepLinkConsentVpnControlDisconnect =>
      'This link wants to disconnect Void//Lex.';

  @override
  String get deepLinkConsentVpnControlToggle =>
      'This link wants to toggle the Void//Lex connection.';

  @override
  String get deepLinkConsentVpnControlRestart =>
      'This link wants to restart the active Void//Lex connection.';

  @override
  String get deepLinkConsentVpnControlConfirm => 'Allow';

  @override
  String get deepLinkConsentSourceLabel => 'Source';

  @override
  String get deepLinkConsentHttpWarning =>
      'This link uses plain HTTP (no TLS). Its contents can be read or modified in transit.';

  @override
  String get deepLinkConsentConfirm => 'Import';

  @override
  String get deepLinkRulesetInvalidUrl =>
      'Ruleset URL must be a valid https address on a public host.';

  @override
  String get deepLinkImportTooLarge => 'Import payload is too large.';

  @override
  String get deepLinkRulesetTimeout => 'Ruleset download timed out.';

  @override
  String get deepLinkRulesetTooLarge => 'Ruleset file is too large.';

  @override
  String get deepLinkRulesetEmpty => 'Ruleset file is empty.';

  @override
  String get deepLinkRulesetNoRules =>
      'No supported routing rules found in the file.';

  @override
  String get deepLinkRulesetInvalidJson => 'Ruleset JSON is malformed.';

  @override
  String deepLinkRulesetHttpStatus(int code) {
    return 'Ruleset download returned HTTP $code';
  }

  @override
  String deepLinkRulesetRequestFailed(String detail) {
    return 'Ruleset download failed: $detail';
  }

  @override
  String deepLinkRulesetImported(int count) {
    return 'Imported $count routing rules from link.';
  }

  @override
  String profileImportedText(int manualNodes, int subscriptions, int presets) {
    return 'Profile imported: $manualNodes manual, $subscriptions subscriptions, $presets presets.';
  }

  @override
  String profileImportedWithProtectedFailures(
    int manualNodes,
    int subscriptions,
    int presets,
    int failed,
  ) {
    return 'Profile imported: $manualNodes manual, $subscriptions subscriptions, $presets presets. Failed protected subscriptions: $failed.';
  }

  @override
  String profileImportedAppRoutingMissingSuffix(int dropped) {
    return ' Skipped $dropped per-app entries for apps not installed on this device.';
  }

  @override
  String get serverMenuEdit => 'Edit';

  @override
  String get serverMenuInDevelopment => 'In development';

  @override
  String get serverMenuAddFavorite => 'Add to favorites';

  @override
  String get serverMenuRemoveFavorite => 'Remove from favorites';

  @override
  String get favoriteMenuMove => 'Move';

  @override
  String get serverMenuSetExitNode => 'Exit Tunnel';

  @override
  String get serverMenuResetExitNode => 'Reset exit tunnel';

  @override
  String get serverExitNodeLabel => 'EXIT';

  @override
  String get serverMenuRulePreset => 'Rule preset';

  @override
  String get editServerTitle => 'Edit Server';

  @override
  String get addServerTitle => 'Add Server';

  @override
  String get editServerSave => 'Save';

  @override
  String get editServerDelete => 'Delete server';

  @override
  String get editServerDeleteConfirmTitle => 'Delete this server?';

  @override
  String get editServerDeleteConfirmBody =>
      'It will be removed from your list.';

  @override
  String get editServerDeleteCancel => 'Cancel';

  @override
  String get editServerDeleteConfirmAction => 'Delete';

  @override
  String get editServerAliasLabel => 'Alias';

  @override
  String get editServerAddressLabel => 'Server address';

  @override
  String get editServerPortLabel => 'Port';

  @override
  String get editServerUuidLabel => 'UUID / Password';

  @override
  String get editServerPasswordLabel => 'Password / Auth';

  @override
  String get editServerNaiveUsernameLabel => 'NaiveProxy username (optional)';

  @override
  String get editServerNaivePasswordLabel => 'NaiveProxy password (optional)';

  @override
  String get editServerNaiveModeLabel => 'NaiveProxy transport';

  @override
  String get editServerNaiveModeHttps => 'HTTPS / HTTP2';

  @override
  String get editServerNaiveModeQuic => 'QUIC';

  @override
  String get editServerNaiveCongestionControlLabel => 'QUIC congestion control';

  @override
  String get editServerNaiveCongestionControlAuto => 'Auto (BBR)';

  @override
  String get editServerProtocolLabel => 'Protocol';

  @override
  String get editServerTransportLabel => 'Transport type';

  @override
  String get editServerSecurityLabel => 'Security';

  @override
  String get editServerSniLabel => 'SNI';

  @override
  String get editServerPathLabel => 'Path';

  @override
  String get editServerServiceNameLabel => 'Service name';

  @override
  String get editServerHostLabel => 'Host header';

  @override
  String get editServerShortIdLabel => 'Short ID';

  @override
  String get editServerPublicKeyLabel => 'Public key';

  @override
  String get editServerAlpnLabel => 'ALPN';

  @override
  String get editServerAllowInsecureLabel => 'Allow insecure TLS';

  @override
  String get editServerObfsPasswordLabel => 'Obfs password';

  @override
  String get editServerHopPortsLabel => 'Port hopping';

  @override
  String get editServerAliasRequired => 'Alias is required';

  @override
  String get editServerAddressRequired => 'Address is required';

  @override
  String get editServerPortRequired => 'Port is required';

  @override
  String get editServerPortInvalid => 'Port must be between 1 and 65535';

  @override
  String get editServerPasswordRequired => 'Password is required';

  @override
  String get editServerUuidRequired => 'UUID is required';

  @override
  String get editServerNameDuplicate => 'Server name already exists';

  @override
  String get editServerNotFound => 'Server not found';

  @override
  String get editServerSectionPrimary => 'Primary settings';

  @override
  String get editServerSectionTransport => 'Transport';

  @override
  String get editServerSectionTls => 'TLS / Reality';

  @override
  String get editServerFingerprintLabel => 'uTLS fingerprint';

  @override
  String get editServerFingerprintHelper =>
      'Auto uses the runtime default. Older profiles may reduce ClientHello size; speed and energy savings are not guaranteed.';

  @override
  String get editServerFingerprintAuto => 'Auto (none)';

  @override
  String get editServerXhttpSubheading => 'XHTTP tuning';

  @override
  String get editServerXhttpModeLabel => 'Mode';

  @override
  String get editServerXhttpModeHelper => 'Blank uses the Xray-core default';

  @override
  String get editServerXhttpModeAuto => 'Core default';

  @override
  String get editServerXhttpPaddingLabel => 'Padding range (xPaddingBytes)';

  @override
  String get editServerXhttpPaddingHelper =>
      'Optional positive value or range, for example 100-1000';

  @override
  String get editServerXhttpMaxPostLabel =>
      'Max POST bytes (scMaxEachPostBytes)';

  @override
  String get editServerXhttpMaxPostHelper => 'Optional; packet-up only';

  @override
  String get editServerXhttpMinIntervalLabel =>
      'Min POST interval ms (scMinPostsIntervalMs)';

  @override
  String get editServerXhttpMinIntervalHelper => 'Optional; packet-up only';

  @override
  String get editServerXhttpObfsTitle => 'Advanced padding obfuscation';

  @override
  String get editServerXhttpObfsHelper =>
      'Off keeps the stock Xray-core padding behavior';

  @override
  String get editServerXhttpPaddingPlacementLabel => 'Padding placement';

  @override
  String get editServerXhttpPaddingKeyLabel => 'Padding key';

  @override
  String get editServerXhttpPaddingHeaderLabel => 'Padding header';

  @override
  String get editServerXhttpPaddingMethodLabel => 'Padding method';

  @override
  String get editServerXhttpSessionPlacementLabel => 'Session ID placement';

  @override
  String get editServerXhttpSessionKeyLabel => 'Session ID key';

  @override
  String get editServerXhttpSeqPlacementLabel => 'Sequence placement';

  @override
  String get editServerXhttpSeqKeyLabel => 'Sequence key';

  @override
  String get editServerXhttpCdnWafPreset => 'CDN/WAF compatibility';

  @override
  String get editServerXhttpStockDefault => 'Core default';

  @override
  String get editServerXhttpRangeInvalid =>
      'Use a positive number or range up to 2147483647';

  @override
  String get editServerXhttpTokenInvalid =>
      'Contains characters not allowed in an HTTP token';

  @override
  String get editServerXhttpValueRequired =>
      'Required for the selected placement';

  @override
  String get editServerAdvancedTitle => 'Advanced';

  @override
  String get editServerAuto => 'Auto';

  @override
  String get editServerFlowLabel => 'VLESS flow';

  @override
  String get editServerFlowHelper =>
      'XTLS Vision flow. Usually used with TCP + TLS/Reality.';

  @override
  String get editServerEncryptionLabel => 'VLESS encryption';

  @override
  String get editServerEncryptionHelper =>
      'Leave blank for none. Advanced values may be long.';

  @override
  String get editServerRealitySpiderXLabel => 'Reality spiderX';

  @override
  String get editServerRealitySpiderXHelper => 'Optional initial crawler path.';

  @override
  String get editServerRealityMldsaLabel => 'Reality ML-DSA-65 verify';

  @override
  String get editServerRealityMldsaHelper =>
      'Optional post-quantum verification key.';

  @override
  String get editServerHysteriaObfsTypeLabel => 'Obfuscation';

  @override
  String get editServerHysteriaObfsNone => 'None';

  @override
  String get editServerHysteriaObfsMinPacketLabel =>
      'Gecko minimum packet size';

  @override
  String get editServerHysteriaObfsMaxPacketLabel =>
      'Gecko maximum packet size';

  @override
  String get editServerHysteriaHopIntervalLabel => 'Port hopping interval';

  @override
  String get editServerHysteriaHopIntervalMaxLabel =>
      'Maximum port hopping interval';

  @override
  String get editServerHysteriaUpMbpsLabel => 'Upload bandwidth (Mbps)';

  @override
  String get editServerHysteriaDownMbpsLabel => 'Download bandwidth (Mbps)';

  @override
  String get editServerHysteriaNetworkLabel => 'Proxied network';

  @override
  String get editServerHysteriaNetworkBoth => 'TCP and UDP';

  @override
  String get editServerHysteriaBbrProfileLabel => 'BBR profile';

  @override
  String get editServerNaiveInsecureConcurrencyLabel => 'Insecure concurrency';

  @override
  String get editServerNaiveInsecureConcurrencyHelper =>
      'Extra parallel connections used before authentication is confirmed.';

  @override
  String get editServerNaiveExtraHeadersLabel => 'Extra HTTP headers';

  @override
  String get editServerNaiveAddHeader => 'Add header';

  @override
  String get editServerNaiveHeaderNameLabel => 'Header';

  @override
  String get editServerNaiveHeaderValueLabel => 'Value';

  @override
  String get editServerNaiveUdpOverTcpLabel => 'UDP over TCP';

  @override
  String get editServerNaiveUdpOverTcpVersionLabel => 'UDP over TCP version';

  @override
  String get editServerAdvancedObfsPasswordRequired =>
      'Obfs password is required';

  @override
  String get editServerAdvancedRangeOrder =>
      'Maximum must be greater than or equal to minimum';

  @override
  String get editServerAdvancedPositiveInteger => 'Enter a positive integer';

  @override
  String get editServerAdvancedIntegerMax =>
      'Enter a positive integer up to 2048';

  @override
  String get editServerAdvancedDurationInvalid =>
      'Use a Go duration such as 30s or 1m30s';

  @override
  String get editServerAdvancedHeaderRequired => 'Header name is required';

  @override
  String get editServerAdvancedHeaderDuplicate => 'Header names must be unique';

  @override
  String get editServerAdvancedHeaderNewline => 'New lines are not allowed';

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
  String get securityNone => 'None';

  @override
  String get securityTls => 'TLS';

  @override
  String get securityReality => 'Reality';

  @override
  String get settingsConfigTitle => 'CONFIG';

  @override
  String get settingsSectionsHeading => 'SECTIONS';

  @override
  String get settingsRoutingTitle => 'Routing';

  @override
  String get settingsRoutingSubtitle => 'Presets · rules · app routing';

  @override
  String get settingsTunnelTitle => 'Tunnel';

  @override
  String get settingsTunnelSubtitle => 'Fragment · multiplex · network';

  @override
  String get settingsSubscriptionsTitle => 'Subscriptions';

  @override
  String get settingsSubscriptionsSubtitle => 'Auto-update · request policy';

  @override
  String get settingsApplicationTitle => 'Application';

  @override
  String get settingsApplicationSubtitle => 'Theme · language · launch · logs';

  @override
  String get settingsLogJournalSubtitle => 'Captured runtime logs';

  @override
  String get settingsAboutHeading => 'ABOUT';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsHwidLabel => 'HWID';

  @override
  String get settingsProtocolLabel => 'Protocol';

  @override
  String get settingsProtocolValue => 'VLESS · Hysteria2 · NaiveProxy';

  @override
  String get settingsXrayCoreLabel => 'xray-core';

  @override
  String get settingsLibboxLabel => 'libbox (sing-box)';

  @override
  String get logJournalTitle => 'Log journal';

  @override
  String get logsEmptyText => 'No logs captured yet.';

  @override
  String get logsNoCopyText => 'No logs to copy.';

  @override
  String get logsCopiedText =>
      'Logs copied. They may contain sensitive details — keep them private.';

  @override
  String get logsNoExportText => 'No logs to export.';

  @override
  String get logsExportedText => 'Logs exported.';

  @override
  String get logsClearedText => 'Logs cleared.';

  @override
  String get logsCopyTooltip => 'Copy';

  @override
  String get logsExportTooltip => 'Export TXT';

  @override
  String get logsClearTooltip => 'Clear';

  @override
  String get homeServerCopied =>
      'Server link copied. It contains your credentials — keep it private.';

  @override
  String get homeNodePresetTitle => 'Node preset';

  @override
  String get homeNodePresetCleared => 'Node preset cleared.';

  @override
  String homeNodePresetSelected(String name) {
    return 'Preset \"$name\" selected for node.';
  }

  @override
  String homeSubscriptionUpdated(String name) {
    return 'Subscription \"$name\" updated.';
  }

  @override
  String homeDeleteSubscriptionTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get homeDeleteSubscriptionBody =>
      'All nodes from this subscription will be removed.';

  @override
  String homeSubscriptionDeleted(String name) {
    return 'Subscription \"$name\" deleted.';
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
  String get homeNoNodesTitle => 'NO NODES YET';

  @override
  String get homeNoNodesSubtitle =>
      'Tap ADD on the dock below to import a node.';

  @override
  String get tooltipUpdateSubscription => 'Update subscription';

  @override
  String get tooltipScanPing => 'Scan ping';

  @override
  String get tooltipSearchNodes => 'Search nodes';

  @override
  String get tooltipCloseSearch => 'Close search';

  @override
  String get tooltipCollapseTopWidgets => 'Hide widgets';

  @override
  String get tooltipExpandTopWidgets => 'Show widgets';

  @override
  String get searchNodesHint => 'Search by name';

  @override
  String get searchNoResults => 'No matches';

  @override
  String get statusIdle => 'IDLE';

  @override
  String get statusReconnecting => 'Reconnecting';

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
  String get subscriptionExpiryUnknown => 'EXPIRY UNKNOWN';

  @override
  String subscriptionExpired(String date) {
    return 'EXPIRED $date';
  }

  @override
  String subscriptionExpires(String date) {
    return 'EXPIRES $date';
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
  String get globalProxySplitLabel => 'SPLIT';

  @override
  String get globalProxySplitHint => 'ROUTING RULES';

  @override
  String get globalProxyGlobalLabel => 'GLOBAL';

  @override
  String get globalProxyGlobalHint => 'ALL TRAFFIC';

  @override
  String get addNodeSheetTitle => 'ADD NODE';

  @override
  String get addNodeScanQr => 'Scan QR code';

  @override
  String get addNodeFromClipboard => 'From clipboard';

  @override
  String get addNodeFromJsonFile => 'From JSON file';

  @override
  String get addNodeManualInput => 'Manual input';

  @override
  String get ipStatusNotConnected => 'Not Connected';

  @override
  String get ipStatusResolving => 'Resolving';

  @override
  String get ipStatusUnavailable => 'Unavailable';

  @override
  String get subscriptionNotFound => 'Subscription not found.';

  @override
  String get subscriptionNameRequired => 'Subscription name is required.';

  @override
  String get subscriptionInvalidUrl =>
      'Enter a valid HTTP or HTTPS subscription URL.';

  @override
  String get insecureSubscriptionTitle => 'Use an insecure subscription?';

  @override
  String get insecureSubscriptionBody =>
      'This subscription uses plain HTTP. Its node list can be read or modified in transit, which could redirect your VPN traffic through an attacker-controlled server.';

  @override
  String get insecureSubscriptionConfirm => 'Use HTTP anyway';

  @override
  String get discardChangesTitle => 'Discard unsaved changes?';

  @override
  String get discardChangesBody =>
      'Your changes have not been saved and will be lost.';

  @override
  String get discardChangesAction => 'Discard';

  @override
  String get presetNameRequired => 'Enter a preset name.';

  @override
  String get presetNameDuplicate => 'Preset with this name already exists.';

  @override
  String get presetNotFound => 'Preset not found.';

  @override
  String get presetMainCannotRename => 'Main preset cannot be renamed.';

  @override
  String get presetMainCannotDelete => 'Main preset cannot be deleted.';

  @override
  String get vpnNoServerSelected => 'No server selected';

  @override
  String get vpnPermissionDenied => 'VPN permission denied';

  @override
  String get vpnPlatformError => 'Platform error';

  @override
  String get vpnFailedToStop => 'Failed to stop VPN';

  @override
  String get vpnFailedToReconnect => 'Failed to reconnect VPN';

  @override
  String get vpnUnknownError => 'Unknown VPN error';

  @override
  String get vpnConnectionTimedOut => 'VPN connection timed out';

  @override
  String get vpnLibboxNetworkUnavailable =>
      'libbox could not access an underlying network';

  @override
  String get vpnNaiveRequiresLibbox =>
      'NaiveProxy requires the libbox TUN engine';

  @override
  String get vpnNaiveTunOnly =>
      'NaiveProxy is not available in proxy-only mode';

  @override
  String get vpnNaiveBridgeUnsupported =>
      'NaiveProxy cannot be used in a two-hop chain';

  @override
  String get vpnNaiveExitUnsupported =>
      'NaiveProxy cannot be selected as an exit node';

  @override
  String get vpnDirectLibboxBridgeUnsupported =>
      'Hysteria2 and NaiveProxy cannot be used in a two-hop chain';

  @override
  String get vpnDirectLibboxRequiresLibbox =>
      'Hysteria2 and NaiveProxy require the libbox TUN engine';

  @override
  String get vpnDirectLibboxTunOnly =>
      'Hysteria2 and NaiveProxy are not available in proxy-only mode';

  @override
  String vpnEventChannelError(String error) {
    return 'Event channel error: $error';
  }

  @override
  String get subImportInvalidUrl =>
      'Enter a valid HTTP or HTTPS subscription URL';

  @override
  String get subImportTimeout => 'Subscription request timed out';

  @override
  String get subImportEmpty => 'Subscription is empty';

  @override
  String get subImportNoNodes =>
      'Subscription does not contain supported nodes';

  @override
  String get subImportUnsupportedJson => 'Unsupported subscription JSON';

  @override
  String subImportHttpStatus(int code) {
    return 'Subscription returned HTTP $code';
  }

  @override
  String get subImportTooLarge => 'Subscription response is too large';

  @override
  String subImportRequestFailed(String detail) {
    return 'Subscription request failed: $detail';
  }

  @override
  String subImportGenericDetail(String detail) {
    return '$detail';
  }

  @override
  String get appRoutingTitle => 'App routing';

  @override
  String get appRoutingViaProxy => 'Via proxy';

  @override
  String get appRoutingBypass => 'Bypass';

  @override
  String get appRoutingHideSystemApps => 'Hide system apps';

  @override
  String get appRoutingSearchHint => 'Search apps';

  @override
  String get appRoutingClearTooltip => 'Clear';

  @override
  String appRoutingLoadFailed(String error) {
    return 'Failed to load apps: $error';
  }

  @override
  String get appRoutingNoUserApps => 'No user apps found.';

  @override
  String get appRoutingNoAppList => 'System returned no app list.';

  @override
  String get appRoutingNoMatchingApps => 'No matching apps.';

  @override
  String get routingScreenTitle => 'ROUTE';

  @override
  String get routingTooltipAdd => 'Add';

  @override
  String get routingTooltipGeoFiles => 'Geo files';

  @override
  String get routingMenuImportClipboard => 'Import from clipboard';

  @override
  String get routingMenuImportFile => 'Import from file';

  @override
  String get routingMenuExportClipboard => 'Export to clipboard';

  @override
  String get routingMenuClearRules => 'Clear rules';

  @override
  String get routingClipboardEmpty => 'Clipboard is empty.';

  @override
  String routingReadFileFailed(String error) {
    return 'Failed to read file: $error';
  }

  @override
  String get routingFileEmpty => 'File is empty.';

  @override
  String routingParseFailed(String error) {
    return 'Failed to parse rules: $error';
  }

  @override
  String get routingNoRulesInSource => 'No rules found in source.';

  @override
  String get routingImportRulesTitle => 'Import rules';

  @override
  String routingImportRulesBody(int count) {
    return 'Currently saved rules: $count. Replace them with imported rules or append to the end?';
  }

  @override
  String get routingNoRulesToExport => 'No rules to export.';

  @override
  String routingCopiedRules(int count) {
    return 'Copied rules to clipboard: $count.';
  }

  @override
  String get routingRulesAlreadyEmpty => 'Rules list is already empty.';

  @override
  String get routingClearRulesTitle => 'Clear rules?';

  @override
  String get routingClearRulesBody => 'All custom rules will be removed.';

  @override
  String get routingDeleteRuleTitle => 'Delete rule?';

  @override
  String get routingSlidableDelete => 'Delete';

  @override
  String get routingRestartingMessage =>
      'Routing changed. Restarting connection to apply it.';

  @override
  String get routingPresetsHeading => 'Presets';

  @override
  String get routingCustomRulesHeading => 'Custom rules';

  @override
  String get routingNoCustomRulesYet => 'No custom rules yet.';

  @override
  String get routingTileAppRouting => 'App routing';

  @override
  String get routingSelectPresetTooltip => 'Select preset';

  @override
  String get routingPresetActionsTooltip => 'Preset actions';

  @override
  String get routingCreatePresetMenu => 'Create preset';

  @override
  String get routingRenamePresetMenu => 'Rename preset';

  @override
  String get routingDeletePresetMenu => 'Delete preset';

  @override
  String get routingNewPresetDialogTitle => 'New preset';

  @override
  String get routingRenamePresetDialogTitle => 'Rename preset';

  @override
  String get routingPresetNameLabel => 'Preset name';

  @override
  String get routingDeletePresetTitle => 'Delete preset?';

  @override
  String get logLevelDebug => 'Debug';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelWarning => 'Warnings';

  @override
  String get logLevelError => 'Errors';

  @override
  String get logRetentionOneHour => '1 hour';

  @override
  String get logRetentionOneDay => '1 day';

  @override
  String get logRetentionOneWeek => '1 week';

  @override
  String get logRetentionForever => 'Never delete';

  @override
  String journalLoadFailed(String error) {
    return 'Failed to load logs: $error';
  }

  @override
  String journalExportFailed(String error) {
    return 'Failed to export logs: $error';
  }

  @override
  String journalClearFailed(String error) {
    return 'Failed to clear logs: $error';
  }

  @override
  String get journalAppBarTitle => 'LOG JOURNAL';

  @override
  String routingDeleteRuleBody(String name) {
    return '“$name”';
  }

  @override
  String get editSubscriptionTitle => 'Edit subscription';

  @override
  String get editSubscriptionSectionTitle => 'Subscription';

  @override
  String get editSubscriptionDeleteTooltip => 'Delete subscription';

  @override
  String get editSubscriptionSaveTooltip => 'Save';

  @override
  String get editSubscriptionAutoUpdateIntervalLabel => 'Auto-update interval';

  @override
  String get editServerCopyTooltip => 'Copy server config';

  @override
  String get editServerCopyAsUrl => 'URL';

  @override
  String get editServerCopyAsJson => 'JSON config';

  @override
  String get editServerCopyAsQr => 'QR code';

  @override
  String get editServerQrTitle => 'Server QR code';

  @override
  String get editServerQrHint => 'Scan to import this server';

  @override
  String get editServerUrlCopied =>
      'Server URL copied. It contains your credentials — keep it private.';

  @override
  String get editServerJsonCopied =>
      'Server JSON copied. It contains your credentials — keep it private.';

  @override
  String get editServerAdvancedUrlOmitted =>
      'URL/QR omits non-standard advanced tuning. Use JSON or a Voidlex profile for a complete export.';

  @override
  String get editServerShowJson => 'Edit as JSON';

  @override
  String get editServerShowForm => 'Return to form';

  @override
  String get editServerJsonEditorLabel => 'Voidlex server JSON';

  @override
  String get editServerJsonEditorHelper =>
      'Edit one supported server configuration. Saving applies the JSON to this server.';

  @override
  String get editServerJsonInvalid =>
      'JSON must contain exactly one valid supported server configuration.';

  @override
  String jsonEditorSyntaxError(int line, int column, String error) {
    return 'Line $line, col $column: Syntax error ($error)';
  }

  @override
  String jsonEditorValid(String details) {
    return 'Valid configuration: $details';
  }

  @override
  String get jsonEditorIncomplete =>
      'Valid JSON syntax, but server configuration is incomplete';

  @override
  String get jsonEditorFormatTooltip => 'Format JSON';

  @override
  String get jsonEditorWrapTooltip => 'Toggle line wrap';

  @override
  String get jsonEditorGoToError => 'Go to error';

  @override
  String jsonEditorLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0';
  }

  @override
  String get settingsHwidLoading => 'Loading…';

  @override
  String get settingsHwidUnavailable => 'Unavailable';

  @override
  String get providerSettingsTitle => 'Provider settings';

  @override
  String get providerSubscriptionsHeading => 'Subscriptions';

  @override
  String get providerAutoUpdateIntervalTitle => 'Auto-update interval';

  @override
  String get providerAutoUpdateIntervalSubtitle =>
      'Refresh all saved provider subscriptions at the selected interval while Void//Lex is running.';

  @override
  String get providerAutoUpdateIntervalTooltip => 'Auto-update interval';

  @override
  String get providerPingAfterUpdateTitle => 'Ping after update';

  @override
  String get providerPingAfterUpdateSubtitle =>
      'Run a latency scan for provider nodes after a subscription refresh completes.';

  @override
  String get providerUpdateOnLaunchTitle => 'Update on launch';

  @override
  String get providerUpdateOnLaunchSubtitle =>
      'Refresh saved provider subscriptions once after the app starts.';

  @override
  String get providerSendHwidTitle => 'Send HWID';

  @override
  String get providerSendHwidSubtitle =>
      'Attach this device HWID to provider requests as the X-HWID header when required by the provider.';

  @override
  String get providerAllowInsecureTitle => 'Skip TLS errors';

  @override
  String get providerAllowInsecureSubtitle =>
      'Ignore TLS certificate validation errors during subscription downloads. Use only for trusted private providers.';

  @override
  String get providerProtectSubscriptionsTitle => 'Protect subscriptions';

  @override
  String get providerProtectSubscriptionsSubtitle =>
      'Disable editing of subscription nodes and export subscriptions only as obfuscated codes (hidden from casual viewing, not strong encryption).';

  @override
  String get subscriptionShareEncrypted => 'Share obfuscated code';

  @override
  String get subscriptionShareEncryptedCopied =>
      'Obfuscated subscription code copied. It still contains your subscription URL — keep it private.';

  @override
  String get subscriptionShareEncryptedFailed =>
      'Failed to generate obfuscated code.';

  @override
  String get subscriptionHideNa => 'Hide N/A';

  @override
  String get subscriptionShowNa => 'Show N/A';

  @override
  String get subscriptionImportEncryptedFailed => 'Invalid or corrupted code.';

  @override
  String get subscriptionIntervalOneHour => '1 hour';

  @override
  String get subscriptionIntervalThreeHours => '3 hours';

  @override
  String get subscriptionIntervalSixHours => '6 hours';

  @override
  String get subscriptionIntervalTwelveHours => '12 hours';

  @override
  String get subscriptionIntervalDefault => 'Default';

  @override
  String get geoFilesAppBarTitle => 'Geo files';

  @override
  String get geoAutoUpdateTitle => 'Geo file auto-update';

  @override
  String get geoAutoUpdateSubtitle =>
      'Automatically updates Geo files that use saved URLs.';

  @override
  String get geoAutoUpdateDisabled => 'Disabled';

  @override
  String get geoAutoUpdateOneDay => 'Every day';

  @override
  String get geoAutoUpdateThreeDays => 'Every 3 days';

  @override
  String get geoAutoUpdateSevenDays => 'Every 7 days';

  @override
  String geoUpdateFileTitle(String fileName) {
    return 'Update $fileName';
  }

  @override
  String get geoFileUrlLabel => 'File URL';

  @override
  String geoFileUrlHint(String fileName) {
    return 'https://example.com/$fileName';
  }

  @override
  String get geoUrlInvalid => 'Enter a valid HTTP or HTTPS URL.';

  @override
  String geoLoadFailed(String error) {
    return 'Failed to load geo files: $error';
  }

  @override
  String get geoNoSavedUrl => 'No saved URL. Use “Update by URL” first.';

  @override
  String geoUpdateFileFailed(String fileName, String error) {
    return 'Failed to update $fileName: $error';
  }

  @override
  String geoFileUpdated(String fileName) {
    return '$fileName updated.';
  }

  @override
  String geoFileImported(String fileName) {
    return '$fileName imported.';
  }

  @override
  String get geoUpdateByUrl => 'Update by URL';

  @override
  String get geoLoadFromDevice => 'Load from device';

  @override
  String get geoRefreshTooltip => 'Refresh';

  @override
  String get geoMetaSource => 'Source';

  @override
  String get geoMetaUpdated => 'Updated';

  @override
  String get geoMetaSize => 'Size';

  @override
  String get geoStatusInstalled => 'Installed';

  @override
  String get geoStatusMissing => 'Missing';

  @override
  String get geoNeverUpdated => 'Never';

  @override
  String get geoSourceUnknown => 'Unknown';

  @override
  String get geoSourceBundled => 'Bundled';

  @override
  String get geoSourceUrl => 'URL';

  @override
  String get geoSourceDevice => 'Device';

  @override
  String get routingRuleEditorTitle => 'Rule';

  @override
  String get routingRuleSaveTooltip => 'Save';

  @override
  String get routingRuleMatcherRequired =>
      'Add at least one domain, IP, port, network, or protocol.';

  @override
  String get routingRuleNameLabel => 'Name';

  @override
  String get routingRuleEnabledLabel => 'Enabled';

  @override
  String get routingRuleConnectionLabel => 'Connection';

  @override
  String get routingRuleDomainLabel => 'Domain';

  @override
  String get routingRuleIpLabel => 'IP';

  @override
  String get routingRulePortLabel => 'Port';

  @override
  String get routingRulePortInvalid =>
      'Enter ports from 1 to 65535, separated by commas; ranges must use start-end.';

  @override
  String get routingRuleNetworkLabel => 'Network';

  @override
  String get routingRuleProtocolLabel => 'Protocol';

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
  String get qrScanTitle => 'SCAN QR';

  @override
  String get qrScanAlignHint => 'ALIGN QR · INSIDE FRAME';

  @override
  String get qrFlashlightOn => 'Turn flashlight on';

  @override
  String get qrFlashlightOff => 'Turn flashlight off';

  @override
  String get qrPermissionMessage =>
      'Camera access is required to scan QR codes. Grant the permission in system settings to continue.';

  @override
  String get qrUnsupportedMessage =>
      'QR scanning is not supported on this device.';

  @override
  String qrCameraFailedCode(String code) {
    return 'Camera failed to start ($code).';
  }

  @override
  String qrCameraFailedDetail(String detail) {
    return 'Camera failed to start: $detail';
  }

  @override
  String get importReadJsonFailed => 'Failed to read JSON file';

  @override
  String get importQrPayloadEmpty => 'QR code is empty';

  @override
  String importReadJsonFailedDetail(String error) {
    return 'Failed to read JSON file: $error';
  }

  @override
  String get importJsonMalformed => 'JSON is malformed';

  @override
  String get importClipboardUnsupported =>
      'Clipboard does not contain a supported server config';

  @override
  String get importQrUnsupportedConfig =>
      'QR code does not contain a supported server config';

  @override
  String get importFileUnsupportedConfig =>
      'File does not contain a supported server config';

  @override
  String get importClipboardNoVless =>
      'Clipboard does not contain a vless:// link or JSON config';

  @override
  String get importQrNoVless =>
      'QR code does not contain a vless:// link or JSON config';

  @override
  String get importFileNoVless =>
      'File does not contain a vless:// link or JSON config';

  @override
  String get importClipboardNoHy2 =>
      'Clipboard does not contain a supported server link or JSON config';

  @override
  String get importQrNoHy2 =>
      'QR code does not contain a supported server link or JSON config';

  @override
  String get importFileNoHy2 =>
      'File does not contain a supported server link or JSON config';

  @override
  String get importHy2MalformedUri => 'Hysteria2 link is malformed';

  @override
  String get importHy2MissingAuth => 'Hysteria2 password is missing';

  @override
  String get importHy2MissingHost => 'Hysteria2 host is missing';

  @override
  String get importHy2InvalidPort => 'Hysteria2 port is out of range';

  @override
  String get importHy2UnsupportedObfs =>
      'Only Salamander obfuscation is supported for Hysteria2';

  @override
  String get importHy2MissingObfsPassword =>
      'Salamander obfuscation password is missing';

  @override
  String get importNaiveWrongScheme =>
      'Link is not a supported NaiveProxy link';

  @override
  String get importNaiveMalformedUri => 'NaiveProxy link is malformed';

  @override
  String get importNaiveMissingHost => 'NaiveProxy host is missing';

  @override
  String get importNaiveInvalidPort => 'NaiveProxy port is out of range';

  @override
  String get importNaiveInvalidMode => 'NaiveProxy mode must be HTTPS or QUIC';

  @override
  String get importNaiveInvalidCongestionControl =>
      'NaiveProxy QUIC congestion control is not supported';

  @override
  String get importVlessMalformedUri => 'Link is malformed';

  @override
  String get importVlessMissingUuid => 'UUID is missing in link';

  @override
  String get importVlessInvalidUuid =>
      'UUID is not a valid RFC 4122 identifier';

  @override
  String get importVlessMissingHost => 'Host is missing';

  @override
  String get importVlessInvalidPort => 'Port is out of range';

  @override
  String get importVlessUnsupportedTransport => 'Transport is not supported';

  @override
  String get importVlessUnsupportedSecurity =>
      'Security is not supported (none/tls/reality only)';

  @override
  String get importedOneServer => 'Imported 1 server.';

  @override
  String importedNServers(int count) {
    return 'Imported $count servers.';
  }

  @override
  String importedSubscriptionOne(String name) {
    return 'Imported \"$name\" with 1 server.';
  }

  @override
  String importedSubscriptionMany(String name, int count) {
    return 'Imported \"$name\" with $count servers.';
  }

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get tunnelSettingsTitle => 'Tunnel settings';

  @override
  String get tunnelGroupNetwork => 'Network';

  @override
  String get tunnelGroupTrafficDns => 'Traffic and DNS';

  @override
  String get tunnelGroupOptimization => 'Optimization';

  @override
  String get tunnelGroupAdvanced => 'Advanced';

  @override
  String get tunnelGroupLocalProxy => 'Local proxy';

  @override
  String get tunnelUseLocalDns => 'Use local DNS';

  @override
  String get tunnelUseLocalDnsDescription =>
      'Use the device\'s system resolver instead of a remote DNS server.';

  @override
  String get tunnelEnableServerResolving => 'Server DNS';

  @override
  String get tunnelEnableServerResolvingDescription =>
      'Resolve proxy server domain names to IP addresses before connecting.';

  @override
  String get tunnelPacketAnalysis => 'Packet analysis';

  @override
  String get tunnelPacketAnalysisDescription =>
      'Inspect HTTP, TLS, and QUIC metadata to route traffic by destination domain.';

  @override
  String get tunnelNetworkStack => 'Network stack';

  @override
  String get tunnelNetworkStackDescription =>
      'Select the TCP and UDP implementation used by the TUN engine. gVisor is the recommended default on Android.';

  @override
  String get tunnelMtu => 'MTU';

  @override
  String get tunnelMtuDescription =>
      'Maximum packet size on the TUN interface. Allowed range: 1280–9000.';

  @override
  String get tunnelMtuHint => '1500';

  @override
  String get tunnelIpMode => 'IP mode';

  @override
  String get tunnelIpModeDescription =>
      'Choose which IP families are routed through the tunnel.';

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
  String get tunnelBlockUdp => 'Block UDP';

  @override
  String get tunnelBlockUdpDescription =>
      'Blocks app UDP traffic in the tunnel. DNS is handled separately.';

  @override
  String get tunnelXrayTun => 'Xray TUN';

  @override
  String get tunnelXrayTunDescription =>
      'Fullcone UDP supported. Experimental. May increase battery consumption';

  @override
  String get tunnelEnableDnsForTun => 'Enable DNS for TUN';

  @override
  String get tunnelEnableDnsForTunDescription =>
      'Override the upstream DNS server used by Xray TUN with the address below.';

  @override
  String get tunnelTunDnsLabel => 'TUN DNS';

  @override
  String get tunnelTunDnsHint => '1.1.1.1';

  @override
  String get tunnelCustomSocksTitle => 'Custom SOCKS5 credentials';

  @override
  String get tunnelCustomSocksOnDescription =>
      'Using credentials from this screen.';

  @override
  String get tunnelCustomSocksOffDescription =>
      'Off — fresh credentials are auto-generated for every session.';

  @override
  String get tunnelProxyUserLabel => 'User';

  @override
  String get tunnelProxyPasswordLabel => 'Password';

  @override
  String get tunnelProxyInboundHelp =>
      'Use these credentials when connecting external apps to the local SOCKS5 (127.0.0.1:10808) or HTTP (127.0.0.1:10809) inbounds.';

  @override
  String get tunnelRegenerate => 'Regenerate';

  @override
  String get tunnelFragmentEnable => 'Enable fragmentation';

  @override
  String get tunnelFragmentOnDescription =>
      'Settings are applied to Xray outbound traffic.';

  @override
  String get tunnelFragmentOffDescription =>
      'Off — traffic goes through the proxy directly.';

  @override
  String get tunnelFragmentPackets => 'Fragment packets';

  @override
  String get tunnelFragmentPacketsDescription =>
      'Choose which initial TCP writes are split; tlshello targets the TLS ClientHello.';

  @override
  String get tunnelFragmentLength => 'Fragment length (min-max)';

  @override
  String get tunnelFragmentLengthDescription =>
      'Random size range for each fragment, in bytes.';

  @override
  String get tunnelFragmentInterval => 'Fragment interval (min-max)';

  @override
  String get tunnelFragmentIntervalDescription =>
      'Random delay between fragments, in milliseconds.';

  @override
  String get tunnelFragmentMaxSplit => 'Fragment max split (min-max)';

  @override
  String get tunnelFragmentMaxSplitDescription =>
      'Random limit for the number of fragments created from one write.';

  @override
  String get tunnelNoiseSettings => 'Noise settings';

  @override
  String get tunnelNoiseSettingsDescription =>
      'Send UDP noise before the first real packet. This may disrupt some connections.';

  @override
  String get tunnelNoiseType => 'Noise type';

  @override
  String get tunnelNoiseTypeDescription =>
      'Select how the noise packet contents are generated or encoded.';

  @override
  String get tunnelNoisePacketLengthRange => 'Packet length range';

  @override
  String get tunnelNoisePacketLengthRangeDescription =>
      'Random byte-length range for generated noise.';

  @override
  String get tunnelNoisePacket => 'Noise packet';

  @override
  String get tunnelNoisePacketDescription =>
      'Packet contents in the format selected above.';

  @override
  String get tunnelNoiseDelay => 'Noise delay (min-max)';

  @override
  String get tunnelNoiseDelayDescription =>
      'Random delay after the noise packet, in milliseconds.';

  @override
  String get tunnelNoiseApplyTo => 'Apply to';

  @override
  String get tunnelNoiseApplyToDescription =>
      'Limit noise to all IP traffic, IPv4, or IPv6.';

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
  String get tunnelMuxEnable => 'Enable multiplexing';

  @override
  String get tunnelMuxOnDescription =>
      'Multiplexing options are configured below.';

  @override
  String get tunnelMuxOffDescription =>
      'Off — each stream uses its own direct tunnel connection.';

  @override
  String get tunnelMuxTcpConnections => 'TCP connections (-1 to 128)';

  @override
  String get tunnelMuxTcpConnectionsDescription =>
      'Maximum TCP sub-connections per MUX connection. -1 disables MUX for TCP.';

  @override
  String get tunnelMuxXudpConnections => 'XUDP connections (-1 to 1024)';

  @override
  String get tunnelMuxXudpConnectionsDescription =>
      'Maximum UDP sub-connections per XUDP tunnel. -1 disables MUX for UDP.';

  @override
  String get tunnelMuxQuicBehavior => 'QUIC in MUX';

  @override
  String get tunnelMuxQuicBehaviorDescription =>
      'Reject, carry through MUX, or pass UDP/443 outside MUX.';

  @override
  String get tunnelMuxQuicReject => 'Reject';

  @override
  String get tunnelMuxQuicAllow => 'Allow';

  @override
  String get tunnelMuxQuicPassthrough => 'Passthrough';

  @override
  String get tvSectionConnect => 'CONNECT';

  @override
  String get tvSectionNodes => 'NODES';

  @override
  String tvNodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count NODES',
      one: '1 NODE',
      zero: 'NO NODES',
    );
    return '$_temp0';
  }

  @override
  String get tvEmptyNodes =>
      'No servers yet — open the app on your phone to import a subscription.';

  @override
  String get tvGroupManual => 'Manual';

  @override
  String get tvExitDevPreview => 'Exit preview';

  @override
  String get tvStatusIdle => 'Idle';

  @override
  String get tvStatusNegotiating => 'Negotiating…';

  @override
  String get tvStatusSecure => 'Secure';

  @override
  String get tvStatusError => 'Error';

  @override
  String get tvHubLabelOff => 'CONNECT';

  @override
  String get tvHubLabelConnecting => 'NEGOTIATING';

  @override
  String get tvHubLabelOn => 'ACTIVE';

  @override
  String get tvHubLabelError => 'RETRY';

  @override
  String get tvHubSubOff => 'OK / SELECT';

  @override
  String get tvHubSubConnecting => 'PLEASE WAIT';

  @override
  String get tvHubSubOn => 'OK TO DISCONNECT';

  @override
  String get tvHubSubError => 'OK / SELECT';

  @override
  String get tvKvExitNode => 'EXIT NODE';

  @override
  String get tvKvExitIp => 'EXIT IP';

  @override
  String get tvKvRegion => 'REGION';

  @override
  String get tvKvDown => '↓ DOWN';

  @override
  String get tvKvUp => '↑ UP';

  @override
  String get tvKvExpires => 'Expires';

  @override
  String get tvKvNodes => 'Nodes';

  @override
  String get tvSideSplit => 'SPLIT';

  @override
  String get tvSideSplitSub => 'ROUTING RULES';

  @override
  String get tvSideGlobal => 'GLOBAL';

  @override
  String get tvSideGlobalSub => 'ALL TRAFFIC';

  @override
  String get tvSidePreset => 'PRESET';

  @override
  String get tvSidePresetSub => 'RULE SET';

  @override
  String get tvSideSettings => 'SETTINGS';

  @override
  String get tvSideSettingsSub => 'CONFIG';

  @override
  String get tvActionConnect => 'CONNECT';

  @override
  String get tvActionDisconnect => 'DISCONNECT';

  @override
  String get tvActionCancel => 'CANCEL';

  @override
  String get tvActionToggle => 'TOGGLE';

  @override
  String get tvActionSelectNode => 'SELECT NODE';

  @override
  String get tvActionSelect => 'SELECT';

  @override
  String get tvActionRetry => 'RETRY';

  @override
  String get tvActionExit => 'EXIT';

  @override
  String get tvActionClose => 'CLOSE';

  @override
  String get tvActionNodeOptions => 'NODE OPTIONS';

  @override
  String get tvActionSubscriptions => 'SUBSCRIPTIONS';

  @override
  String get tvActionPingScan => 'PING SCAN';

  @override
  String get tvActionBackKey => 'BACK';

  @override
  String get tvActionMenuKey => 'MENU';

  @override
  String get tvActionPlayPauseKey => 'PLAY/PAUSE';

  @override
  String get tvHintRemoteFooter => 'D-PAD · NAVIGATE';

  @override
  String get tvOverlaySubscriptionsTitle => 'SUBSCRIPTIONS';

  @override
  String get tvOverlaySubscriptionsSubtitle =>
      'Imported subscriptions · BACK to close';

  @override
  String get tvOverlaySubscriptionsEmpty => 'No subscriptions imported yet.';

  @override
  String get tvOverlayPresetTitle => 'NODE PRESET';

  @override
  String get tvOverlayPresetSubtitleGlobal => 'Choose routing behaviour';

  @override
  String tvOverlayPresetSubtitleForNode(String server) {
    return '$server · choose routing behaviour';
  }

  @override
  String get tvOverlayFooter => 'BACK · CLOSE   ·   OK · SELECT';

  @override
  String get tvPresetCurrentChip => 'CURRENT';

  @override
  String get tvPresetMainDescription =>
      'Default routing rules — applies to every node.';

  @override
  String tvPresetSummary(int rules, int apps) {
    String _temp0 = intl.Intl.pluralLogic(
      rules,
      locale: localeName,
      other: '$rules rules',
      one: '1 rule',
      zero: 'No rules',
    );
    String _temp1 = intl.Intl.pluralLogic(
      apps,
      locale: localeName,
      other: '$apps apps',
      one: '1 app',
      zero: 'no apps',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get tvRefreshedUnknown => '—';

  @override
  String get tvRefreshedJustNow => '↓ Just now';

  @override
  String tvRefreshedMinutesAgo(int minutes) {
    return '↓ Refreshed ${minutes}m ago';
  }

  @override
  String tvRefreshedHoursAgo(int hours) {
    return '↓ Refreshed ${hours}h ago';
  }

  @override
  String tvRefreshedDaysAgo(int days) {
    return '↓ Refreshed ${days}d ago';
  }

  @override
  String get tvLayoutSectionTitle => 'Interface layout';

  @override
  String get tvLayoutSectionSubtitle =>
      'Choose the phone layout, the horizontal TV layout, or allow rotation.';

  @override
  String get tvLayoutVertical => 'Vertical';

  @override
  String get tvLayoutHorizontal => 'Horizontal';

  @override
  String get tvLayoutAutoRotate => 'Auto';

  @override
  String get settingsFaqLabel => 'FAQ';

  @override
  String get telegramOpenFailed => 'Couldn\'t open Telegram link.';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqSubtitle => 'Common questions';

  @override
  String get faqHint => 'Tap a question to expand the answer.';

  @override
  String get faqQ1 =>
      'Which servers cannot be used in a two-hop chain (entry → exit)?';

  @override
  String get faqA1 =>
      'The two-hop chain is handled by the Xray core via `sockopt.dialerProxy`. This introduces two key limits:\n1. **Hysteria2 and NaiveProxy** cannot be used in a chain at all (neither as entry nor as exit) because they run directly via the libbox engine.\n2. **XHTTP** is not recommended as an exit node: due to HTTP/2 transport specifics, the handshake often fails to complete across the entry tunnel. Use XHTTP as the primary (entry) node, and choose VLESS-TCP, WS, or REALITY for the exit.';

  @override
  String get faqQ2 =>
      'What\'s the difference between the libbox and Xray TUN engines?';

  @override
  String get faqA2 =>
      '**libbox** (sing-box) is the default — stable, plays well with the system, and easier on the battery. **Xray TUN** is experimental: it pushes packets straight through the Xray core. Use it only if you need Xray-specific behaviour or if libbox misbehaves on your device. Leave it on libbox unless you have a reason.';

  @override
  String get faqQ3 => 'Why do I need «Global proxy» if the VPN is already on?';

  @override
  String get faqA3 =>
      'Without it your routing preset is in charge (per-app, domains, IP, geosite/geoip) — some traffic may stay direct. «Global proxy» temporarily overrides the rules and routes everything technically possible through the tunnel. Handy as a sanity check («does my traffic reach the server at all?») or when you want a full tunnel right now. The button can be hidden in settings.';

  @override
  String get faqQ4 => 'What are routing presets and per-node presets?';

  @override
  String get faqA4 =>
      '**Main** is the default rule set, applied to any node without its own preset. Extra presets can be bound to specific servers from the node menu → «Routing preset». Rules are Xray-style: outbound `proxy` / `direct` / `block` by domains, IP/CIDR, `geoip:` / `geosite:`, ports, network (tcp/udp), or protocols.';

  @override
  String get faqQ5 => 'What is an «Exit node» (EXIT)?';

  @override
  String get faqA5 =>
      'A two-hop setup: the **entry** node is the one you connect to with the main button; the **exit** is a separate server the traffic egresses through (entry → exit). Useful when you want to separate «where you knock» from «where you appear on the internet». Entry and exit must be different servers — otherwise the chain collapses into an ordinary single-hop connection.';

  @override
  String get faqQ6 =>
      'I changed tunnel settings, but they didn\'t take effect — why?';

  @override
  String get faqA6 =>
      'Some parameters (TUN engine, network stack, DNS, MTU, fragmentation, multiplex, etc.) only take effect on the next tunnel start. In **«Settings → Application»** there is a **«Restart on changes»** toggle — when enabled, the app automatically reconnects when you leave settings. If it is disabled, disconnect and reconnect manually.';

  @override
  String get faqQ7 => 'What is HWID and why does my subscription send it?';

  @override
  String get faqA7 =>
      'HWID is a stable anonymous device identifier computed locally (visible in «About»). It is sent in the `X-HWID` header on subscription requests if **«Send HWID»** is enabled under **«Settings → Subscription provider»**. Some providers require it to enforce device quotas. You can turn off HWID transmission at any time. HWID is never sent anywhere else.';

  @override
  String get faqQ8 =>
      'What\'s the slim build, and do I have to download GeoData?';

  @override
  String get faqA8 =>
      'The standard build ships `geoip.dat` and `geosite.dat` (~28 MB) inside the APK — routing rules like `geosite:google` or `geoip:ru` work immediately. The slim build omits them to reduce APK size. You can download the files, configure auto-updates (1, 3, or 7 days), or load custom files from storage in **«Settings → Routing → GeoData files»**. If you do not use geo-based rules, you can skip downloading GeoData entirely.';

  @override
  String get faqQ9 =>
      'Per-app routing doesn\'t apply to Push / Play Services / system apps — is that normal?';

  @override
  String get faqA9 =>
      'Yes. Android refuses to route some system processes through a VPN (parts of Google Mobile Services, push, system updates). This is a `VpnService` platform limit, not the app — it can\'t be worked around without root. Their traffic will bypass the tunnel even when whitelisted.';

  @override
  String get faqQ10 => 'Network stack: system / gVisor / mixed — which one?';

  @override
  String get faqA10 =>
      '**gVisor** is the default on Android. It handles TUN traffic in user space and works reliably with libbox 1.14.\n**system** uses the platform kernel stack and should only be selected on environments where that TUN path is known to work.\n**mixed** uses gVisor for TCP and system for UDP.';

  @override
  String get faqQ11 =>
      'How do node URL tests, connection latency and TCP diagnostics differ?';

  @override
  String get faqA11 =>
      '**Node URL tests** make an HTTP request through that node\'s own outbound after a warm-up. **Connection latency** tests the running tunnel and its entire selected chain. **TCP diagnostics** only test port reachability and do not confirm a working proxy. Choose TCP or URL on the home screen; both tools remain available under Application → Diagnostics in settings. Enabling diagnostics in the node menu adds the opposite test. Standalone checks do not change list latency. The default URL is http://cp.cloudflare.com/ and requires HTTP 204; custom URLs require 2xx. Redirects fail. A failed test can also mean the target website is unavailable.';

  @override
  String get faqQ12 =>
      'My subscription doesn\'t update, or updates but the node list doesn\'t change — what should I check?';

  @override
  String get faqA12 =>
      '1. Check the auto-refresh interval (by default **6 hours**; configured under «Settings → Subscription provider» or per-subscription) and the «Refresh on launch» toggle.\n2. Force a refresh using the update button on the subscription card.\n3. If the list does not change, your provider is returning the exact same node set.\n4. If «Protect subscriptions» is enabled, manual edits inside subscription nodes will be overwritten during updates.';

  @override
  String get faqQ13 =>
      'Calls / games / streaming are slow over the VPN — what can I try?';

  @override
  String get faqA13 =>
      'Most of those apps run over UDP / QUIC. Check:\n1. Stack — try **mixed** (gVisor for TCP, system for UDP).\n2. **Multiplex → QUIC** — set `passthrough` or `reject`; `allow` wraps QUIC over mux and adds latency.\n3. If your protocol is Hysteria2, the carrier itself is UDP — make sure your ISP doesn\'t throttle UDP traffic to the server.';

  @override
  String get faqQ14 =>
      'What does «Multiplex: QUIC — reject / allow / passthrough» mean?';

  @override
  String get faqA14 =>
      'Multiplex packs many logical streams into a single TCP/XUDP connection. QUIC rides on UDP, and its handling is configured separately:\n**reject** — block QUIC, apps fall back to TCP/HTTPS on their own (safe default).\n**passthrough** — QUIC bypasses mux on its own UDP channel (faster, but no multiplexing).\n**allow** — QUIC is wrapped into mux (exotic, for pattern hiding; usually slower).';

  @override
  String get faqQ15 =>
      'Why does the screen show «———» instead of an external IP?';

  @override
  String get faqA15 =>
      'The external IP is looked up after the tunnel comes up — through a separate HTTPS request via the local proxy. If the network is unstable or the lookup is blocked, the app falls back to «Unavailable». That doesn\'t mean the tunnel itself is broken — it can still be working.';

  @override
  String get faqQ16 => 'Why doesn\'t auto-connect on launch fire?';

  @override
  String get faqA16 =>
      'The toggle lives in **Settings → Application**, but on a number of Android skins the OS battery policy blocks background service auto-start. Disable battery optimisation for Void//Lex, and consider Android\'s system **Always-on VPN** (Settings → Network → VPN → Void//Lex) — it brings the tunnel up reliably at boot.';

  @override
  String get faqQ17 => 'Can I point another app at the local proxy?';

  @override
  String get faqA17 =>
      'Yes — while the tunnel is up the app listens on **SOCKS5** `127.0.0.1:10808` and **HTTP** `127.0.0.1:10809`. By default the username and password are regenerated every session. To pin your own, go to **Settings → Tunnel → SOCKS5 credentials** — flip the switch and enter (or generate) a fixed pair.';

  @override
  String get faqQ18 => 'Is there a built-in kill switch?';

  @override
  String get faqA18 =>
      'Yes. A built-in **«Kill Switch»** toggle is available under **«Settings → Application»**. When active, an unexpected VPN drop immediately blocks all unprotected internet traffic and posts a notification allowing you to restore connectivity or reconnect. Manually disconnecting the tunnel restores normal network access.\nFor strict system-level protection, you can also enable Android\'s native **Always-on VPN** with «Block connections without VPN» via the «Auto-connect on device boot» shortcut.';

  @override
  String get faqQ19 => 'Where are my data and logs stored — is that safe?';

  @override
  String get faqA19 =>
      'Nodes, subscriptions, presets, and the journal are all local on the device; nothing leaves it except subscription requests and the traffic going through your chosen server. The journal can be cleared from «Settings → Journal». In verbose mode the log will contain sensitive fields (UUIDs, hosts, keys) — **don\'t publish verbose dumps as-is.** The app itself is not an anonymiser; the privacy level depends on your servers and your rules.';

  @override
  String get faqQ20 => 'Is there TV and iOS support?';

  @override
  String get faqA20 =>
      '**Android TV / Google TV** — yes, a dedicated full-screen UI with D-pad support; the nodes and subscriptions are shared with the mobile version. **iOS / iPadOS** — a full client is in development.';

  @override
  String get faqQ21 =>
      'What is the difference between «Proxy-only» and «VPN tunnel (TUN)» mode?';

  @override
  String get faqA21 =>
      'Configured in **«Settings → Tunnel → Run mode»**:\n• **VPN tunnel (TUN)** is the default mode: all device traffic is routed via Android\'s VpnService (key icon in the status bar).\n• **Hide icon (proxy-only)** starts a local SOCKS5/HTTP proxy without creating a system TUN interface. No VPN icon is displayed, and the OS VPN slot remains free for other apps. Traffic is routed through the proxy only from apps configured manually (e.g. Telegram, custom browsers).';

  @override
  String get faqQ22 =>
      'Are Hysteria2 and NaiveProxy supported, and what are their requirements?';

  @override
  String get faqA22 =>
      'Yes, VoidLex supports importing `hy2://` / `hysteria2://` and `naive+https://` / `naive+quic://` links.\nKey requirements:\n1. They require the **libbox** TUN engine (they cannot run with Xray TUN).\n2. They cannot be used in two-hop chains (exit node).\n3. NaiveProxy supports both HTTPS and QUIC transports.';

  @override
  String get faqQ23 =>
      'Can I share the proxy with other devices over Wi-Fi or hotspot?';

  @override
  String get faqA23 =>
      'Yes. In **«Settings → Tunnel → Local proxy»** (and in Proxy-only mode), the proxy can listen on the local network. Devices connected to the same Wi-Fi or your mobile hotspot can use SOCKS5 (`port 10808`) and HTTP (`port 10809`) by targeting your phone\'s IP. For security, enable authentication and configure a username and password under SOCKS5/HTTP credentials.';

  @override
  String get faqQ24 =>
      'The tunnel disconnects on its own after 10–20 minutes in the background — how to fix it?';

  @override
  String get faqA24 =>
      'This is caused by aggressive OS power management on certain Android skins (HyperOS/MIUI, ColorOS, EMUI, OneUI):\n1. In Android app info for VoidLex, disable **«Battery optimisation»** (set to «Unrestricted»).\n2. Enable **«Auto-start»** and allow background activity.\n3. In the recent apps overview, lock VoidLex with the lock icon.\n4. For uninterrupted operation, configure Android\'s native **Always-on VPN** in system network settings.';

  @override
  String get autoConnectOnBootTitle => 'Auto-connect on device boot';

  @override
  String get autoConnectOnBootSubtitle =>
      'Open the system \"Always-on VPN\" settings page — enable «Always-on VPN» + «Block connections without VPN» so the tunnel comes up at boot.';

  @override
  String get killSwitchTitle => 'Kill Switch';

  @override
  String get killSwitchSubtitle =>
      'Block internet if the tunnel drops unexpectedly. Manual disconnect still restores the network.';

  @override
  String get runModeSectionTitle => 'Run mode';

  @override
  String get runModeTunTitle => 'VPN tunnel (TUN)';

  @override
  String get runModeTunSubtitle =>
      'Standard mode. Routes all traffic via the VPN service; the Android key icon is visible in the status bar.';

  @override
  String get runModeProxyOnlyTitle => 'Hide icon (proxy-only)';

  @override
  String get runModeProxyOnlySubtitle =>
      'Run a local HTTP/SOCKS5 proxy without the VPN icon. Only apps that support a proxy will use it; mobile data routes directly. Configure the proxy manually in Wi-Fi / browser. Note: the proxy port is reachable by other devices on the same Wi-Fi / hotspot (a username and password are required).';

  @override
  String get httpProxyAuthTitle => 'HTTP proxy authorization';

  @override
  String get httpProxyAuthSubtitle =>
      'Protect the HTTP proxy on port 10809 with the same username and password as SOCKS5.';

  @override
  String get tunnelRouteOnlyTitle => 'Domain-only routing (routeOnly)';

  @override
  String get tunnelRouteOnlySubtitle =>
      'Use SNI/host from sniffing only for routing — do not rewrite the destination. Keep on unless sniffing breaks the network.';

  @override
  String get connectionPolicySectionTitle => 'Advanced settings';

  @override
  String get connectionPolicySectionSubtitle =>
      'Idle timeout. TCP / UDP connection limits.';

  @override
  String get connectionPolicyConnectionsGroup => 'Connections';

  @override
  String get connectionPolicyIdleTitle => 'Idle timeout';

  @override
  String get connectionPolicyIdleSubtitle =>
      'Wait time for inactive connections, seconds.';

  @override
  String get connectionPolicyMaxTcpTitle => 'TCP connections';

  @override
  String get connectionPolicyMaxTcpSubtitle =>
      'Maximum concurrent TCP connections.';

  @override
  String get connectionPolicyMaxUdpTitle => 'UDP connections';

  @override
  String get connectionPolicyMaxUdpSubtitle =>
      'Maximum concurrent UDP connections.';

  @override
  String get urlSchemesTitle => 'URL schemes';

  @override
  String get urlSchemesSubtitle =>
      'Automate VoidLex via Shortcuts, Tasker, and other apps.';

  @override
  String get urlSchemesNote =>
      'Use these schemes to automate via Shortcuts, Tasker or other apps. Tap a scheme to copy.';

  @override
  String get urlSchemesNoteHeader => 'Note';

  @override
  String get urlSchemesStartSection => 'START TUNNEL';

  @override
  String get urlSchemesStopSection => 'STOP CONNECTION';

  @override
  String get urlSchemesToggleSection => 'TOGGLE CONNECTION';

  @override
  String get urlSchemesRestartSection => 'RESTART CONNECTION';

  @override
  String get urlSchemesImportSection => 'ADD CONFIGURATION';

  @override
  String get urlSchemesImportRulesetSection => 'IMPORT RULESET';

  @override
  String get urlSchemeCopied => 'Copied to clipboard';

  @override
  String get additionalTlsFingerprintsTitle => 'Additional TLS fingerprints';

  @override
  String get additionalTlsFingerprintsSubtitle =>
      'Show Safari 16.0, Chrome 120 and iOS 14. Saved choices remain active when hidden.';

  @override
  String get urlProbeTargetTitle => 'Node URL test address';

  @override
  String get urlProbeTargetHelp =>
      'Requests go through each node. A failed test can also mean the target site is unavailable.';

  @override
  String get urlProbeTargetInvalid =>
      'Enter a full HTTP/HTTPS URL without credentials or a fragment.';

  @override
  String get tcpDiagnosticTitle => 'TCP diagnostic';

  @override
  String get tcpDiagnosticSubtitle =>
      'Checks only the port, without proxy authorization. Does not change home screen latency.';

  @override
  String get nodeDiagnosticModeTitle => 'Default node diagnostic';

  @override
  String get nodeDiagnosticModeHelp =>
      'Choose TCP or URL for node latency on the home screen.';

  @override
  String get nodeDiagnosticMenuTitle => 'Diagnostic in node menu';

  @override
  String get nodeDiagnosticMenuHelp =>
      'Add the other test to the node menu: URL when TCP is the default, or TCP when URL is the default.';

  @override
  String get urlDiagnosticTitle => 'URL diagnostic';

  @override
  String get urlDiagnosticSubtitle =>
      'Test an individual node through its outbound without changing home screen results.';
}
