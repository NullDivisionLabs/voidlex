import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'VoidTunnel'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @append.
  ///
  /// In en, this message translates to:
  /// **'Append'**
  String get append;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @keepPrefix.
  ///
  /// In en, this message translates to:
  /// **'Keep: {label}'**
  String keepPrefix(String label);

  /// No description provided for @levelsSelectedNone.
  ///
  /// In en, this message translates to:
  /// **'No levels selected — {retention}'**
  String levelsSelectedNone(String retention);

  /// No description provided for @levelsSelectedSome.
  ///
  /// In en, this message translates to:
  /// **'{levels} — {retention}'**
  String levelsSelectedSome(String levels, String retention);

  /// No description provided for @applicationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Application settings'**
  String get applicationSettingsTitle;

  /// No description provided for @themeSection.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSection;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguageTitle;

  /// No description provided for @appLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the interface language.'**
  String get appLanguageSubtitle;

  /// No description provided for @appLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get appLanguageAuto;

  /// No description provided for @appLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get appLanguageEnglish;

  /// No description provided for @appLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get appLanguageRussian;

  /// No description provided for @autoConnectOnLaunchTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect on launch'**
  String get autoConnectOnLaunchTitle;

  /// No description provided for @autoConnectOnLaunchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'May not work on some devices.'**
  String get autoConnectOnLaunchSubtitle;

  /// No description provided for @restartOnSettingsChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart on changes'**
  String get restartOnSettingsChangeTitle;

  /// No description provided for @showSpeedInNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Show connection speed in notifications'**
  String get showSpeedInNotificationTitle;

  /// No description provided for @keepAwakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep VPN awake'**
  String get keepAwakeTitle;

  /// No description provided for @keepAwakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hold a partial wake lock while connected. Uses more battery.'**
  String get keepAwakeSubtitle;

  /// No description provided for @verboseXrayLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Verbose Xray logs'**
  String get verboseXrayLogsTitle;

  /// No description provided for @verboseXrayLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture xray-core info-level errors (dial failures, Reality auth, ALPN) and dump the generated config once at startup. Use only for diagnostics; sensitive fields are masked.'**
  String get verboseXrayLogsSubtitle;

  /// No description provided for @applicationSettingsPingTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Ping server'**
  String get applicationSettingsPingTargetTitle;

  /// No description provided for @applicationSettingsPingTargetDefault.
  ///
  /// In en, this message translates to:
  /// **'Node address'**
  String get applicationSettingsPingTargetDefault;

  /// No description provided for @applicationSettingsPingTargetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Ping server'**
  String get applicationSettingsPingTargetDialogTitle;

  /// No description provided for @applicationSettingsPingTargetFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Host or URL'**
  String get applicationSettingsPingTargetFieldLabel;

  /// No description provided for @applicationSettingsPingTargetHint.
  ///
  /// In en, this message translates to:
  /// **'example.com:443'**
  String get applicationSettingsPingTargetHint;

  /// No description provided for @applicationSettingsPingTargetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a host, URL, or host:port.'**
  String get applicationSettingsPingTargetInvalid;

  /// No description provided for @applicationSettingsPingTargetReset.
  ///
  /// In en, this message translates to:
  /// **'Use node address'**
  String get applicationSettingsPingTargetReset;

  /// No description provided for @logSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Log options'**
  String get logSettingsTitle;

  /// No description provided for @logSettingsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log options'**
  String get logSettingsDialogTitle;

  /// No description provided for @logLevelsLabel.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get logLevelsLabel;

  /// No description provided for @logStorageTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage time'**
  String get logStorageTimeLabel;

  /// No description provided for @logStorageTimeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Storage time'**
  String get logStorageTimeTooltip;

  /// No description provided for @applicationSettingsShowGlobalProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Split/Global widget'**
  String get applicationSettingsShowGlobalProxyTitle;

  /// No description provided for @applicationSettingsGlobalProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the full-tunnel button on the home screen.'**
  String get applicationSettingsGlobalProxySubtitle;

  /// No description provided for @applicationSettingsAutoSortServersByPingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by ping'**
  String get applicationSettingsAutoSortServersByPingTitle;

  /// No description provided for @applicationSettingsAutoSortServersByPingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Put faster servers higher after a latency scan.'**
  String get applicationSettingsAutoSortServersByPingSubtitle;

  /// No description provided for @profileExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export profile'**
  String get profileExportTitle;

  /// No description provided for @profileExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save manual nodes, subscriptions, and routing presets as a JSON file.'**
  String get profileExportSubtitle;

  /// No description provided for @profileExportedText.
  ///
  /// In en, this message translates to:
  /// **'Profile exported.'**
  String get profileExportedText;

  /// No description provided for @profileExportProtectedSubscriptionsSkipped.
  ///
  /// In en, this message translates to:
  /// **'Profile exported. Protected subscriptions cannot be exported.'**
  String get profileExportProtectedSubscriptionsSkipped;

  /// No description provided for @profileExportProtectedSubscriptionsEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Profile exported. Protected subscriptions are stored as encrypted codes.'**
  String get profileExportProtectedSubscriptionsEncrypted;

  /// No description provided for @profileExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export profile: {error}'**
  String profileExportFailed(String error);

  /// No description provided for @profileImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import profile'**
  String get profileImportTitle;

  /// No description provided for @profileImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Load a VoidTunnel profile JSON file.'**
  String get profileImportSubtitle;

  /// No description provided for @profileImportModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Import profile'**
  String get profileImportModeTitle;

  /// No description provided for @profileImportModeBody.
  ///
  /// In en, this message translates to:
  /// **'Replace current manual nodes, subscriptions, and routing presets, or append this profile to the current data?'**
  String get profileImportModeBody;

  /// No description provided for @profileImportFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Profile file is empty.'**
  String get profileImportFileEmpty;

  /// No description provided for @profileImportReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read profile file.'**
  String get profileImportReadFailed;

  /// No description provided for @profileImportReadFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Failed to read profile file: {error}'**
  String profileImportReadFailedDetail(String error);

  /// No description provided for @profileImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import profile: {error}'**
  String profileImportFailed(String error);

  /// No description provided for @profileImportInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Profile JSON is malformed.'**
  String get profileImportInvalidJson;

  /// No description provided for @profileImportUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'File is not a VoidTunnel profile.'**
  String get profileImportUnsupportedFormat;

  /// No description provided for @profileImportUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'Profile version is not supported.'**
  String get profileImportUnsupportedVersion;

  /// No description provided for @profileImportEmptyProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile does not contain importable data.'**
  String get profileImportEmptyProfile;

  /// No description provided for @profileImportedText.
  ///
  /// In en, this message translates to:
  /// **'Profile imported: {manualNodes} manual, {subscriptions} subscriptions, {presets} presets.'**
  String profileImportedText(int manualNodes, int subscriptions, int presets);

  /// No description provided for @profileImportedWithProtectedFailures.
  ///
  /// In en, this message translates to:
  /// **'Profile imported: {manualNodes} manual, {subscriptions} subscriptions, {presets} presets. Failed protected subscriptions: {failed}.'**
  String profileImportedWithProtectedFailures(
    int manualNodes,
    int subscriptions,
    int presets,
    int failed,
  );

  /// No description provided for @profileImportedAppRoutingMissingSuffix.
  ///
  /// In en, this message translates to:
  /// **' Skipped {dropped} per-app entries for apps not installed on this device.'**
  String profileImportedAppRoutingMissingSuffix(int dropped);

  /// No description provided for @serverMenuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get serverMenuEdit;

  /// No description provided for @serverMenuInDevelopment.
  ///
  /// In en, this message translates to:
  /// **'In development'**
  String get serverMenuInDevelopment;

  /// No description provided for @serverMenuAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get serverMenuAddFavorite;

  /// No description provided for @serverMenuRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get serverMenuRemoveFavorite;

  /// No description provided for @favoriteMenuMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get favoriteMenuMove;

  /// No description provided for @serverMenuSetExitNode.
  ///
  /// In en, this message translates to:
  /// **'Exit Tunnel'**
  String get serverMenuSetExitNode;

  /// No description provided for @serverMenuResetExitNode.
  ///
  /// In en, this message translates to:
  /// **'Reset exit tunnel'**
  String get serverMenuResetExitNode;

  /// No description provided for @serverExitNodeLabel.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get serverExitNodeLabel;

  /// No description provided for @serverMenuRulePreset.
  ///
  /// In en, this message translates to:
  /// **'Rule preset'**
  String get serverMenuRulePreset;

  /// No description provided for @editServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get editServerTitle;

  /// No description provided for @addServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServerTitle;

  /// No description provided for @editServerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editServerSave;

  /// No description provided for @editServerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete server'**
  String get editServerDelete;

  /// No description provided for @editServerDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this server?'**
  String get editServerDeleteConfirmTitle;

  /// No description provided for @editServerDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from your list.'**
  String get editServerDeleteConfirmBody;

  /// No description provided for @editServerDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editServerDeleteCancel;

  /// No description provided for @editServerDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get editServerDeleteConfirmAction;

  /// No description provided for @editServerAliasLabel.
  ///
  /// In en, this message translates to:
  /// **'Alias'**
  String get editServerAliasLabel;

  /// No description provided for @editServerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get editServerAddressLabel;

  /// No description provided for @editServerPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get editServerPortLabel;

  /// No description provided for @editServerUuidLabel.
  ///
  /// In en, this message translates to:
  /// **'UUID / Password'**
  String get editServerUuidLabel;

  /// No description provided for @editServerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password / Auth'**
  String get editServerPasswordLabel;

  /// No description provided for @editServerProtocolLabel.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get editServerProtocolLabel;

  /// No description provided for @editServerTransportLabel.
  ///
  /// In en, this message translates to:
  /// **'Transport type'**
  String get editServerTransportLabel;

  /// No description provided for @editServerSecurityLabel.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get editServerSecurityLabel;

  /// No description provided for @editServerSniLabel.
  ///
  /// In en, this message translates to:
  /// **'SNI'**
  String get editServerSniLabel;

  /// No description provided for @editServerPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get editServerPathLabel;

  /// No description provided for @editServerServiceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get editServerServiceNameLabel;

  /// No description provided for @editServerHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host header'**
  String get editServerHostLabel;

  /// No description provided for @editServerShortIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Short ID'**
  String get editServerShortIdLabel;

  /// No description provided for @editServerPublicKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get editServerPublicKeyLabel;

  /// No description provided for @editServerAlpnLabel.
  ///
  /// In en, this message translates to:
  /// **'ALPN'**
  String get editServerAlpnLabel;

  /// No description provided for @editServerAllowInsecureLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow insecure TLS'**
  String get editServerAllowInsecureLabel;

  /// No description provided for @editServerObfsPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Obfs password'**
  String get editServerObfsPasswordLabel;

  /// No description provided for @editServerHopPortsLabel.
  ///
  /// In en, this message translates to:
  /// **'Port hopping'**
  String get editServerHopPortsLabel;

  /// No description provided for @editServerAliasRequired.
  ///
  /// In en, this message translates to:
  /// **'Alias is required'**
  String get editServerAliasRequired;

  /// No description provided for @editServerAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Address is required'**
  String get editServerAddressRequired;

  /// No description provided for @editServerPortRequired.
  ///
  /// In en, this message translates to:
  /// **'Port is required'**
  String get editServerPortRequired;

  /// No description provided for @editServerPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Port must be between 1 and 65535'**
  String get editServerPortInvalid;

  /// No description provided for @editServerPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get editServerPasswordRequired;

  /// No description provided for @editServerNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Server name already exists'**
  String get editServerNameDuplicate;

  /// No description provided for @editServerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Server not found'**
  String get editServerNotFound;

  /// No description provided for @editServerSectionPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary settings'**
  String get editServerSectionPrimary;

  /// No description provided for @editServerSectionTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get editServerSectionTransport;

  /// No description provided for @editServerSectionTls.
  ///
  /// In en, this message translates to:
  /// **'TLS / Reality'**
  String get editServerSectionTls;

  /// No description provided for @editServerFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'uTLS fingerprint'**
  String get editServerFingerprintLabel;

  /// No description provided for @editServerFingerprintHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: chrome for XHTTP, none otherwise'**
  String get editServerFingerprintHelper;

  /// No description provided for @editServerFingerprintAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (none)'**
  String get editServerFingerprintAuto;

  /// No description provided for @editServerXhttpSubheading.
  ///
  /// In en, this message translates to:
  /// **'XHTTP tuning'**
  String get editServerXhttpSubheading;

  /// No description provided for @editServerXhttpModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get editServerXhttpModeLabel;

  /// No description provided for @editServerXhttpModeHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: stream-up (lowest DPI signature)'**
  String get editServerXhttpModeHelper;

  /// No description provided for @editServerXhttpModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (recommended)'**
  String get editServerXhttpModeAuto;

  /// No description provided for @editServerXhttpPaddingLabel.
  ///
  /// In en, this message translates to:
  /// **'Padding range (xPaddingBytes)'**
  String get editServerXhttpPaddingLabel;

  /// No description provided for @editServerXhttpPaddingHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: 100-1000'**
  String get editServerXhttpPaddingHelper;

  /// No description provided for @editServerXhttpMaxPostLabel.
  ///
  /// In en, this message translates to:
  /// **'Max POST bytes (scMaxEachPostBytes)'**
  String get editServerXhttpMaxPostLabel;

  /// No description provided for @editServerXhttpMaxPostHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: 500000-1000000 (packet-up only)'**
  String get editServerXhttpMaxPostHelper;

  /// No description provided for @editServerXhttpMinIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Min POST interval ms (scMinPostsIntervalMs)'**
  String get editServerXhttpMinIntervalLabel;

  /// No description provided for @editServerXhttpMinIntervalHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: 10-50 (packet-up only)'**
  String get editServerXhttpMinIntervalHelper;

  /// No description provided for @protocolVless.
  ///
  /// In en, this message translates to:
  /// **'VLESS'**
  String get protocolVless;

  /// No description provided for @protocolHysteria2.
  ///
  /// In en, this message translates to:
  /// **'Hysteria2'**
  String get protocolHysteria2;

  /// No description provided for @transportTcp.
  ///
  /// In en, this message translates to:
  /// **'TCP'**
  String get transportTcp;

  /// No description provided for @transportUdp.
  ///
  /// In en, this message translates to:
  /// **'UDP'**
  String get transportUdp;

  /// No description provided for @transportWs.
  ///
  /// In en, this message translates to:
  /// **'WebSocket'**
  String get transportWs;

  /// No description provided for @transportGrpc.
  ///
  /// In en, this message translates to:
  /// **'gRPC'**
  String get transportGrpc;

  /// No description provided for @transportHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get transportHttp;

  /// No description provided for @transportHttpUpgrade.
  ///
  /// In en, this message translates to:
  /// **'HTTP Upgrade'**
  String get transportHttpUpgrade;

  /// No description provided for @transportXhttp.
  ///
  /// In en, this message translates to:
  /// **'XHTTP'**
  String get transportXhttp;

  /// No description provided for @securityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get securityNone;

  /// No description provided for @securityTls.
  ///
  /// In en, this message translates to:
  /// **'TLS'**
  String get securityTls;

  /// No description provided for @securityReality.
  ///
  /// In en, this message translates to:
  /// **'Reality'**
  String get securityReality;

  /// No description provided for @settingsConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'CONFIG'**
  String get settingsConfigTitle;

  /// No description provided for @settingsSectionsHeading.
  ///
  /// In en, this message translates to:
  /// **'SECTIONS'**
  String get settingsSectionsHeading;

  /// No description provided for @settingsRoutingTitle.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get settingsRoutingTitle;

  /// No description provided for @settingsRoutingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Presets · rules · app routing'**
  String get settingsRoutingSubtitle;

  /// No description provided for @settingsTunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Tunnel'**
  String get settingsTunnelTitle;

  /// No description provided for @settingsTunnelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fragment · multiplex · network'**
  String get settingsTunnelSubtitle;

  /// No description provided for @settingsSubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get settingsSubscriptionsTitle;

  /// No description provided for @settingsSubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-update · request policy'**
  String get settingsSubscriptionsSubtitle;

  /// No description provided for @settingsApplicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get settingsApplicationTitle;

  /// No description provided for @settingsApplicationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme · language · launch · logs'**
  String get settingsApplicationSubtitle;

  /// No description provided for @settingsLogJournalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Captured runtime logs'**
  String get settingsLogJournalSubtitle;

  /// No description provided for @settingsAboutHeading.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsAboutHeading;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersionLabel;

  /// No description provided for @settingsHwidLabel.
  ///
  /// In en, this message translates to:
  /// **'HWID'**
  String get settingsHwidLabel;

  /// No description provided for @settingsProtocolLabel.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get settingsProtocolLabel;

  /// No description provided for @settingsProtocolValue.
  ///
  /// In en, this message translates to:
  /// **'VLESS · Hysteria2'**
  String get settingsProtocolValue;

  /// No description provided for @settingsXrayCoreLabel.
  ///
  /// In en, this message translates to:
  /// **'xray-core'**
  String get settingsXrayCoreLabel;

  /// No description provided for @settingsLibboxLabel.
  ///
  /// In en, this message translates to:
  /// **'libbox (sing-box)'**
  String get settingsLibboxLabel;

  /// No description provided for @logJournalTitle.
  ///
  /// In en, this message translates to:
  /// **'Log journal'**
  String get logJournalTitle;

  /// No description provided for @logsEmptyText.
  ///
  /// In en, this message translates to:
  /// **'No logs captured yet.'**
  String get logsEmptyText;

  /// No description provided for @logsNoCopyText.
  ///
  /// In en, this message translates to:
  /// **'No logs to copy.'**
  String get logsNoCopyText;

  /// No description provided for @logsCopiedText.
  ///
  /// In en, this message translates to:
  /// **'Logs copied.'**
  String get logsCopiedText;

  /// No description provided for @logsNoExportText.
  ///
  /// In en, this message translates to:
  /// **'No logs to export.'**
  String get logsNoExportText;

  /// No description provided for @logsExportedText.
  ///
  /// In en, this message translates to:
  /// **'Logs exported.'**
  String get logsExportedText;

  /// No description provided for @logsClearedText.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared.'**
  String get logsClearedText;

  /// No description provided for @logsCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get logsCopyTooltip;

  /// No description provided for @logsExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export TXT'**
  String get logsExportTooltip;

  /// No description provided for @logsClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logsClearTooltip;

  /// No description provided for @homeServerCopied.
  ///
  /// In en, this message translates to:
  /// **'Server copied.'**
  String get homeServerCopied;

  /// No description provided for @homeNodePresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Node preset'**
  String get homeNodePresetTitle;

  /// No description provided for @homeNodePresetCleared.
  ///
  /// In en, this message translates to:
  /// **'Node preset cleared.'**
  String get homeNodePresetCleared;

  /// No description provided for @homeNodePresetSelected.
  ///
  /// In en, this message translates to:
  /// **'Preset \"{name}\" selected for node.'**
  String homeNodePresetSelected(String name);

  /// No description provided for @homeSubscriptionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Subscription \"{name}\" updated.'**
  String homeSubscriptionUpdated(String name);

  /// No description provided for @homeDeleteSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String homeDeleteSubscriptionTitle(String name);

  /// No description provided for @homeDeleteSubscriptionBody.
  ///
  /// In en, this message translates to:
  /// **'All nodes from this subscription will be removed.'**
  String get homeDeleteSubscriptionBody;

  /// No description provided for @homeSubscriptionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Subscription \"{name}\" deleted.'**
  String homeSubscriptionDeleted(String name);

  /// No description provided for @sectionFavorites.
  ///
  /// In en, this message translates to:
  /// **'FAVORITES'**
  String get sectionFavorites;

  /// No description provided for @sectionNodes.
  ///
  /// In en, this message translates to:
  /// **'NODES'**
  String get sectionNodes;

  /// No description provided for @sectionNodesManualCount.
  ///
  /// In en, this message translates to:
  /// **'{count} MANUAL'**
  String sectionNodesManualCount(int count);

  /// No description provided for @homeNoNodesTitle.
  ///
  /// In en, this message translates to:
  /// **'NO NODES YET'**
  String get homeNoNodesTitle;

  /// No description provided for @homeNoNodesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap ADD on the dock below to import a node.'**
  String get homeNoNodesSubtitle;

  /// No description provided for @tooltipUpdateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Update subscription'**
  String get tooltipUpdateSubscription;

  /// No description provided for @tooltipScanPing.
  ///
  /// In en, this message translates to:
  /// **'Scan ping'**
  String get tooltipScanPing;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'IDLE'**
  String get statusIdle;

  /// No description provided for @statusNegotiating.
  ///
  /// In en, this message translates to:
  /// **'NEGOTIATING'**
  String get statusNegotiating;

  /// No description provided for @statusSecure.
  ///
  /// In en, this message translates to:
  /// **'SECURE'**
  String get statusSecure;

  /// No description provided for @statusClosing.
  ///
  /// In en, this message translates to:
  /// **'CLOSING'**
  String get statusClosing;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get statusError;

  /// No description provided for @statusStripLabel.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get statusStripLabel;

  /// No description provided for @statusDurationPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'— : —'**
  String get statusDurationPlaceholder;

  /// No description provided for @ipPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'———.———.———.———'**
  String get ipPlaceholder;

  /// No description provided for @nodeLabelDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get nodeLabelDash;

  /// No description provided for @pingMsSuffix.
  ///
  /// In en, this message translates to:
  /// **' ms'**
  String get pingMsSuffix;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'SCANNING'**
  String get scanning;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'SCAN'**
  String get scan;

  /// No description provided for @subscriptionMetaLine.
  ///
  /// In en, this message translates to:
  /// **'{expiry} · {count} NODES'**
  String subscriptionMetaLine(String expiry, int count);

  /// No description provided for @subscriptionExpiryUnknown.
  ///
  /// In en, this message translates to:
  /// **'EXPIRY UNKNOWN'**
  String get subscriptionExpiryUnknown;

  /// No description provided for @subscriptionExpired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED {date}'**
  String subscriptionExpired(String date);

  /// No description provided for @subscriptionExpires.
  ///
  /// In en, this message translates to:
  /// **'EXPIRES {date}'**
  String subscriptionExpires(String date);

  /// No description provided for @dockHub.
  ///
  /// In en, this message translates to:
  /// **'HUB'**
  String get dockHub;

  /// No description provided for @dockAdd.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get dockAdd;

  /// No description provided for @dockRoute.
  ///
  /// In en, this message translates to:
  /// **'ROUTE'**
  String get dockRoute;

  /// No description provided for @dockConfig.
  ///
  /// In en, this message translates to:
  /// **'CONFIG'**
  String get dockConfig;

  /// No description provided for @globalProxySplitLabel.
  ///
  /// In en, this message translates to:
  /// **'SPLIT'**
  String get globalProxySplitLabel;

  /// No description provided for @globalProxySplitHint.
  ///
  /// In en, this message translates to:
  /// **'ROUTING RULES'**
  String get globalProxySplitHint;

  /// No description provided for @globalProxyGlobalLabel.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL'**
  String get globalProxyGlobalLabel;

  /// No description provided for @globalProxyGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'ALL TRAFFIC'**
  String get globalProxyGlobalHint;

  /// No description provided for @addNodeSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD NODE'**
  String get addNodeSheetTitle;

  /// No description provided for @addNodeScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get addNodeScanQr;

  /// No description provided for @addNodeFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'From clipboard'**
  String get addNodeFromClipboard;

  /// No description provided for @addNodeFromJsonFile.
  ///
  /// In en, this message translates to:
  /// **'From JSON file'**
  String get addNodeFromJsonFile;

  /// No description provided for @addNodeManualInput.
  ///
  /// In en, this message translates to:
  /// **'Manual input'**
  String get addNodeManualInput;

  /// No description provided for @ipStatusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get ipStatusNotConnected;

  /// No description provided for @ipStatusResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving'**
  String get ipStatusResolving;

  /// No description provided for @ipStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get ipStatusUnavailable;

  /// No description provided for @subscriptionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Subscription not found.'**
  String get subscriptionNotFound;

  /// No description provided for @subscriptionNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Subscription name is required.'**
  String get subscriptionNameRequired;

  /// No description provided for @subscriptionInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS subscription URL.'**
  String get subscriptionInvalidUrl;

  /// No description provided for @presetNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a preset name.'**
  String get presetNameRequired;

  /// No description provided for @presetNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Preset with this name already exists.'**
  String get presetNameDuplicate;

  /// No description provided for @presetNotFound.
  ///
  /// In en, this message translates to:
  /// **'Preset not found.'**
  String get presetNotFound;

  /// No description provided for @presetMainCannotRename.
  ///
  /// In en, this message translates to:
  /// **'Main preset cannot be renamed.'**
  String get presetMainCannotRename;

  /// No description provided for @presetMainCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'Main preset cannot be deleted.'**
  String get presetMainCannotDelete;

  /// No description provided for @vpnNoServerSelected.
  ///
  /// In en, this message translates to:
  /// **'No server selected'**
  String get vpnNoServerSelected;

  /// No description provided for @vpnPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'VPN permission denied'**
  String get vpnPermissionDenied;

  /// No description provided for @vpnPlatformError.
  ///
  /// In en, this message translates to:
  /// **'Platform error'**
  String get vpnPlatformError;

  /// No description provided for @vpnFailedToStop.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop VPN'**
  String get vpnFailedToStop;

  /// No description provided for @vpnFailedToReconnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to reconnect VPN'**
  String get vpnFailedToReconnect;

  /// No description provided for @vpnUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown VPN error'**
  String get vpnUnknownError;

  /// No description provided for @vpnConnectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'VPN connection timed out'**
  String get vpnConnectionTimedOut;

  /// No description provided for @vpnEventChannelError.
  ///
  /// In en, this message translates to:
  /// **'Event channel error: {error}'**
  String vpnEventChannelError(String error);

  /// No description provided for @subImportInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS subscription URL'**
  String get subImportInvalidUrl;

  /// No description provided for @subImportTimeout.
  ///
  /// In en, this message translates to:
  /// **'Subscription request timed out'**
  String get subImportTimeout;

  /// No description provided for @subImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Subscription is empty'**
  String get subImportEmpty;

  /// No description provided for @subImportNoNodes.
  ///
  /// In en, this message translates to:
  /// **'Subscription does not contain supported nodes'**
  String get subImportNoNodes;

  /// No description provided for @subImportUnsupportedJson.
  ///
  /// In en, this message translates to:
  /// **'Unsupported subscription JSON'**
  String get subImportUnsupportedJson;

  /// No description provided for @subImportHttpStatus.
  ///
  /// In en, this message translates to:
  /// **'Subscription returned HTTP {code}'**
  String subImportHttpStatus(int code);

  /// No description provided for @subImportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Subscription response is too large'**
  String get subImportTooLarge;

  /// No description provided for @subImportRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Subscription request failed: {detail}'**
  String subImportRequestFailed(String detail);

  /// No description provided for @subImportGenericDetail.
  ///
  /// In en, this message translates to:
  /// **'{detail}'**
  String subImportGenericDetail(String detail);

  /// No description provided for @appRoutingTitle.
  ///
  /// In en, this message translates to:
  /// **'App routing'**
  String get appRoutingTitle;

  /// No description provided for @appRoutingViaProxy.
  ///
  /// In en, this message translates to:
  /// **'Via proxy'**
  String get appRoutingViaProxy;

  /// No description provided for @appRoutingBypass.
  ///
  /// In en, this message translates to:
  /// **'Bypass'**
  String get appRoutingBypass;

  /// No description provided for @appRoutingHideSystemApps.
  ///
  /// In en, this message translates to:
  /// **'Hide system apps'**
  String get appRoutingHideSystemApps;

  /// No description provided for @appRoutingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get appRoutingSearchHint;

  /// No description provided for @appRoutingClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get appRoutingClearTooltip;

  /// No description provided for @appRoutingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load apps: {error}'**
  String appRoutingLoadFailed(String error);

  /// No description provided for @appRoutingNoUserApps.
  ///
  /// In en, this message translates to:
  /// **'No user apps found.'**
  String get appRoutingNoUserApps;

  /// No description provided for @appRoutingNoAppList.
  ///
  /// In en, this message translates to:
  /// **'System returned no app list.'**
  String get appRoutingNoAppList;

  /// No description provided for @appRoutingNoMatchingApps.
  ///
  /// In en, this message translates to:
  /// **'No matching apps.'**
  String get appRoutingNoMatchingApps;

  /// No description provided for @routingScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'ROUTE'**
  String get routingScreenTitle;

  /// No description provided for @routingTooltipAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get routingTooltipAdd;

  /// No description provided for @routingTooltipGeoFiles.
  ///
  /// In en, this message translates to:
  /// **'Geo files'**
  String get routingTooltipGeoFiles;

  /// No description provided for @routingMenuImportClipboard.
  ///
  /// In en, this message translates to:
  /// **'Import from clipboard'**
  String get routingMenuImportClipboard;

  /// No description provided for @routingMenuImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get routingMenuImportFile;

  /// No description provided for @routingMenuExportClipboard.
  ///
  /// In en, this message translates to:
  /// **'Export to clipboard'**
  String get routingMenuExportClipboard;

  /// No description provided for @routingMenuClearRules.
  ///
  /// In en, this message translates to:
  /// **'Clear rules'**
  String get routingMenuClearRules;

  /// No description provided for @routingClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty.'**
  String get routingClipboardEmpty;

  /// No description provided for @routingReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file: {error}'**
  String routingReadFileFailed(String error);

  /// No description provided for @routingFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'File is empty.'**
  String get routingFileEmpty;

  /// No description provided for @routingParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse rules: {error}'**
  String routingParseFailed(String error);

  /// No description provided for @routingNoRulesInSource.
  ///
  /// In en, this message translates to:
  /// **'No rules found in source.'**
  String get routingNoRulesInSource;

  /// No description provided for @routingImportRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Import rules'**
  String get routingImportRulesTitle;

  /// No description provided for @routingImportRulesBody.
  ///
  /// In en, this message translates to:
  /// **'Currently saved rules: {count}. Replace them with imported rules or append to the end?'**
  String routingImportRulesBody(int count);

  /// No description provided for @routingNoRulesToExport.
  ///
  /// In en, this message translates to:
  /// **'No rules to export.'**
  String get routingNoRulesToExport;

  /// No description provided for @routingCopiedRules.
  ///
  /// In en, this message translates to:
  /// **'Copied rules to clipboard: {count}.'**
  String routingCopiedRules(int count);

  /// No description provided for @routingRulesAlreadyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Rules list is already empty.'**
  String get routingRulesAlreadyEmpty;

  /// No description provided for @routingClearRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear rules?'**
  String get routingClearRulesTitle;

  /// No description provided for @routingClearRulesBody.
  ///
  /// In en, this message translates to:
  /// **'All custom rules will be removed.'**
  String get routingClearRulesBody;

  /// No description provided for @routingDeleteRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete rule?'**
  String get routingDeleteRuleTitle;

  /// No description provided for @routingSlidableDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get routingSlidableDelete;

  /// No description provided for @routingRestartingMessage.
  ///
  /// In en, this message translates to:
  /// **'Routing changed. Restarting connection to apply it.'**
  String get routingRestartingMessage;

  /// No description provided for @routingPresetsHeading.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get routingPresetsHeading;

  /// No description provided for @routingCustomRulesHeading.
  ///
  /// In en, this message translates to:
  /// **'Custom rules'**
  String get routingCustomRulesHeading;

  /// No description provided for @routingNoCustomRulesYet.
  ///
  /// In en, this message translates to:
  /// **'No custom rules yet.'**
  String get routingNoCustomRulesYet;

  /// No description provided for @routingTileAppRouting.
  ///
  /// In en, this message translates to:
  /// **'App routing'**
  String get routingTileAppRouting;

  /// No description provided for @routingSelectPresetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select preset'**
  String get routingSelectPresetTooltip;

  /// No description provided for @routingPresetActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preset actions'**
  String get routingPresetActionsTooltip;

  /// No description provided for @routingCreatePresetMenu.
  ///
  /// In en, this message translates to:
  /// **'Create preset'**
  String get routingCreatePresetMenu;

  /// No description provided for @routingRenamePresetMenu.
  ///
  /// In en, this message translates to:
  /// **'Rename preset'**
  String get routingRenamePresetMenu;

  /// No description provided for @routingDeletePresetMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get routingDeletePresetMenu;

  /// No description provided for @routingNewPresetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New preset'**
  String get routingNewPresetDialogTitle;

  /// No description provided for @routingRenamePresetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename preset'**
  String get routingRenamePresetDialogTitle;

  /// No description provided for @routingPresetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get routingPresetNameLabel;

  /// No description provided for @routingDeletePresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete preset?'**
  String get routingDeletePresetTitle;

  /// No description provided for @logLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get logLevelDebug;

  /// No description provided for @logLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get logLevelInfo;

  /// No description provided for @logLevelWarning.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get logLevelWarning;

  /// No description provided for @logLevelError.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get logLevelError;

  /// No description provided for @logRetentionOneHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get logRetentionOneHour;

  /// No description provided for @logRetentionOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get logRetentionOneDay;

  /// No description provided for @logRetentionOneWeek.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get logRetentionOneWeek;

  /// No description provided for @logRetentionForever.
  ///
  /// In en, this message translates to:
  /// **'Never delete'**
  String get logRetentionForever;

  /// No description provided for @journalLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load logs: {error}'**
  String journalLoadFailed(String error);

  /// No description provided for @journalExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export logs: {error}'**
  String journalExportFailed(String error);

  /// No description provided for @journalClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear logs: {error}'**
  String journalClearFailed(String error);

  /// No description provided for @journalAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'LOG JOURNAL'**
  String get journalAppBarTitle;

  /// No description provided for @routingDeleteRuleBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}”'**
  String routingDeleteRuleBody(String name);

  /// No description provided for @editSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit subscription'**
  String get editSubscriptionTitle;

  /// No description provided for @editSubscriptionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get editSubscriptionSectionTitle;

  /// No description provided for @editSubscriptionDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete subscription'**
  String get editSubscriptionDeleteTooltip;

  /// No description provided for @editSubscriptionSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editSubscriptionSaveTooltip;

  /// No description provided for @editSubscriptionAutoUpdateIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-update interval'**
  String get editSubscriptionAutoUpdateIntervalLabel;

  /// No description provided for @editServerCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy server config'**
  String get editServerCopyTooltip;

  /// No description provided for @editServerCopyAsUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get editServerCopyAsUrl;

  /// No description provided for @editServerCopyAsJson.
  ///
  /// In en, this message translates to:
  /// **'JSON config'**
  String get editServerCopyAsJson;

  /// No description provided for @providerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider settings'**
  String get providerSettingsTitle;

  /// No description provided for @providerSubscriptionsHeading.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get providerSubscriptionsHeading;

  /// No description provided for @providerAutoUpdateIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-update interval'**
  String get providerAutoUpdateIntervalTitle;

  /// No description provided for @providerAutoUpdateIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh all saved provider subscriptions at the selected interval while VoidTunnel is running.'**
  String get providerAutoUpdateIntervalSubtitle;

  /// No description provided for @providerAutoUpdateIntervalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-update interval'**
  String get providerAutoUpdateIntervalTooltip;

  /// No description provided for @providerPingAfterUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Ping after update'**
  String get providerPingAfterUpdateTitle;

  /// No description provided for @providerPingAfterUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run a latency scan for provider nodes after a subscription refresh completes.'**
  String get providerPingAfterUpdateSubtitle;

  /// No description provided for @providerUpdateOnLaunchTitle.
  ///
  /// In en, this message translates to:
  /// **'Update on launch'**
  String get providerUpdateOnLaunchTitle;

  /// No description provided for @providerUpdateOnLaunchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh saved provider subscriptions once after the app starts.'**
  String get providerUpdateOnLaunchSubtitle;

  /// No description provided for @providerSendHwidTitle.
  ///
  /// In en, this message translates to:
  /// **'Send HWID'**
  String get providerSendHwidTitle;

  /// No description provided for @providerSendHwidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attach this device HWID to provider requests as the X-HWID header when required by the provider.'**
  String get providerSendHwidSubtitle;

  /// No description provided for @providerAllowInsecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip TLS errors'**
  String get providerAllowInsecureTitle;

  /// No description provided for @providerAllowInsecureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore TLS certificate validation errors during subscription downloads. Use only for trusted private providers.'**
  String get providerAllowInsecureSubtitle;

  /// No description provided for @providerProtectSubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect subscriptions'**
  String get providerProtectSubscriptionsTitle;

  /// No description provided for @providerProtectSubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disable editing of subscription nodes and export subscriptions only as encrypted codes.'**
  String get providerProtectSubscriptionsSubtitle;

  /// No description provided for @subscriptionShareEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Share encrypted code'**
  String get subscriptionShareEncrypted;

  /// No description provided for @subscriptionShareEncryptedCopied.
  ///
  /// In en, this message translates to:
  /// **'Encrypted subscription code copied to clipboard.'**
  String get subscriptionShareEncryptedCopied;

  /// No description provided for @subscriptionShareEncryptedFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate encrypted code.'**
  String get subscriptionShareEncryptedFailed;

  /// No description provided for @subscriptionImportEncryptedFailed.
  ///
  /// In en, this message translates to:
  /// **'Invalid or corrupted encrypted code.'**
  String get subscriptionImportEncryptedFailed;

  /// No description provided for @subscriptionIntervalOneHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get subscriptionIntervalOneHour;

  /// No description provided for @subscriptionIntervalThreeHours.
  ///
  /// In en, this message translates to:
  /// **'3 hours'**
  String get subscriptionIntervalThreeHours;

  /// No description provided for @subscriptionIntervalSixHours.
  ///
  /// In en, this message translates to:
  /// **'6 hours'**
  String get subscriptionIntervalSixHours;

  /// No description provided for @subscriptionIntervalTwelveHours.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get subscriptionIntervalTwelveHours;

  /// No description provided for @subscriptionIntervalDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get subscriptionIntervalDefault;

  /// No description provided for @geoFilesAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Geo files'**
  String get geoFilesAppBarTitle;

  /// No description provided for @geoUpdateFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Update {fileName}'**
  String geoUpdateFileTitle(String fileName);

  /// No description provided for @geoFileUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'File URL'**
  String get geoFileUrlLabel;

  /// No description provided for @geoFileUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/{fileName}'**
  String geoFileUrlHint(String fileName);

  /// No description provided for @geoUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS URL.'**
  String get geoUrlInvalid;

  /// No description provided for @geoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load geo files: {error}'**
  String geoLoadFailed(String error);

  /// No description provided for @geoNoSavedUrl.
  ///
  /// In en, this message translates to:
  /// **'No saved URL. Use “Update by URL” first.'**
  String get geoNoSavedUrl;

  /// No description provided for @geoUpdateFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update {fileName}: {error}'**
  String geoUpdateFileFailed(String fileName, String error);

  /// No description provided for @geoFileUpdated.
  ///
  /// In en, this message translates to:
  /// **'{fileName} updated.'**
  String geoFileUpdated(String fileName);

  /// No description provided for @geoFileImported.
  ///
  /// In en, this message translates to:
  /// **'{fileName} imported.'**
  String geoFileImported(String fileName);

  /// No description provided for @geoUpdateByUrl.
  ///
  /// In en, this message translates to:
  /// **'Update by URL'**
  String get geoUpdateByUrl;

  /// No description provided for @geoLoadFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Load from device'**
  String get geoLoadFromDevice;

  /// No description provided for @geoRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get geoRefreshTooltip;

  /// No description provided for @geoMetaSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get geoMetaSource;

  /// No description provided for @geoMetaUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get geoMetaUpdated;

  /// No description provided for @geoMetaSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get geoMetaSize;

  /// No description provided for @geoStatusInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get geoStatusInstalled;

  /// No description provided for @geoStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get geoStatusMissing;

  /// No description provided for @geoNeverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get geoNeverUpdated;

  /// No description provided for @geoSourceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get geoSourceUnknown;

  /// No description provided for @geoSourceBundled.
  ///
  /// In en, this message translates to:
  /// **'Bundled'**
  String get geoSourceBundled;

  /// No description provided for @geoSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get geoSourceUrl;

  /// No description provided for @geoSourceDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get geoSourceDevice;

  /// No description provided for @routingRuleEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get routingRuleEditorTitle;

  /// No description provided for @routingRuleSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get routingRuleSaveTooltip;

  /// No description provided for @routingRuleMatcherRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one domain, IP, port, network, or protocol.'**
  String get routingRuleMatcherRequired;

  /// No description provided for @routingRuleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get routingRuleNameLabel;

  /// No description provided for @routingRuleEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get routingRuleEnabledLabel;

  /// No description provided for @routingRuleConnectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get routingRuleConnectionLabel;

  /// No description provided for @routingRuleDomainLabel.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get routingRuleDomainLabel;

  /// No description provided for @routingRuleIpLabel.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get routingRuleIpLabel;

  /// No description provided for @routingRulePortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get routingRulePortLabel;

  /// No description provided for @routingRuleNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get routingRuleNetworkLabel;

  /// No description provided for @routingRuleProtocolLabel.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get routingRuleProtocolLabel;

  /// No description provided for @routingRuleDomainHint.
  ///
  /// In en, this message translates to:
  /// **'geosite:youtube, domain:example.com'**
  String get routingRuleDomainHint;

  /// No description provided for @routingRuleIpHint.
  ///
  /// In en, this message translates to:
  /// **'geoip:private, 1.1.1.1/32'**
  String get routingRuleIpHint;

  /// No description provided for @routingRulePortHint.
  ///
  /// In en, this message translates to:
  /// **'443, 1000-2000'**
  String get routingRulePortHint;

  /// No description provided for @protocolChipHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get protocolChipHttp;

  /// No description provided for @protocolChipTls.
  ///
  /// In en, this message translates to:
  /// **'TLS'**
  String get protocolChipTls;

  /// No description provided for @protocolChipBittorrent.
  ///
  /// In en, this message translates to:
  /// **'BITTORRENT'**
  String get protocolChipBittorrent;

  /// No description provided for @qrScanTitle.
  ///
  /// In en, this message translates to:
  /// **'SCAN QR'**
  String get qrScanTitle;

  /// No description provided for @qrScanAlignHint.
  ///
  /// In en, this message translates to:
  /// **'ALIGN QR · INSIDE FRAME'**
  String get qrScanAlignHint;

  /// No description provided for @qrFlashlightOn.
  ///
  /// In en, this message translates to:
  /// **'Turn flashlight on'**
  String get qrFlashlightOn;

  /// No description provided for @qrFlashlightOff.
  ///
  /// In en, this message translates to:
  /// **'Turn flashlight off'**
  String get qrFlashlightOff;

  /// No description provided for @qrPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera access is required to scan QR codes. Grant the permission in system settings to continue.'**
  String get qrPermissionMessage;

  /// No description provided for @qrUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'QR scanning is not supported on this device.'**
  String get qrUnsupportedMessage;

  /// No description provided for @qrCameraFailedCode.
  ///
  /// In en, this message translates to:
  /// **'Camera failed to start ({code}).'**
  String qrCameraFailedCode(String code);

  /// No description provided for @qrCameraFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Camera failed to start: {detail}'**
  String qrCameraFailedDetail(String detail);

  /// No description provided for @importReadJsonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read JSON file'**
  String get importReadJsonFailed;

  /// No description provided for @importQrPayloadEmpty.
  ///
  /// In en, this message translates to:
  /// **'QR code is empty'**
  String get importQrPayloadEmpty;

  /// No description provided for @importReadJsonFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Failed to read JSON file: {error}'**
  String importReadJsonFailedDetail(String error);

  /// No description provided for @importJsonMalformed.
  ///
  /// In en, this message translates to:
  /// **'JSON is malformed'**
  String get importJsonMalformed;

  /// No description provided for @importClipboardUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Clipboard does not contain a supported server config'**
  String get importClipboardUnsupported;

  /// No description provided for @importQrUnsupportedConfig.
  ///
  /// In en, this message translates to:
  /// **'QR code does not contain a supported server config'**
  String get importQrUnsupportedConfig;

  /// No description provided for @importFileUnsupportedConfig.
  ///
  /// In en, this message translates to:
  /// **'File does not contain a supported server config'**
  String get importFileUnsupportedConfig;

  /// No description provided for @importClipboardNoVless.
  ///
  /// In en, this message translates to:
  /// **'Clipboard does not contain a vless:// link or JSON config'**
  String get importClipboardNoVless;

  /// No description provided for @importQrNoVless.
  ///
  /// In en, this message translates to:
  /// **'QR code does not contain a vless:// link or JSON config'**
  String get importQrNoVless;

  /// No description provided for @importFileNoVless.
  ///
  /// In en, this message translates to:
  /// **'File does not contain a vless:// link or JSON config'**
  String get importFileNoVless;

  /// No description provided for @importClipboardNoHy2.
  ///
  /// In en, this message translates to:
  /// **'Clipboard does not contain a supported server link or JSON config'**
  String get importClipboardNoHy2;

  /// No description provided for @importQrNoHy2.
  ///
  /// In en, this message translates to:
  /// **'QR code does not contain a supported server link or JSON config'**
  String get importQrNoHy2;

  /// No description provided for @importFileNoHy2.
  ///
  /// In en, this message translates to:
  /// **'File does not contain a supported server link or JSON config'**
  String get importFileNoHy2;

  /// No description provided for @importHy2MalformedUri.
  ///
  /// In en, this message translates to:
  /// **'Hysteria2 link is malformed'**
  String get importHy2MalformedUri;

  /// No description provided for @importHy2MissingAuth.
  ///
  /// In en, this message translates to:
  /// **'Hysteria2 password is missing'**
  String get importHy2MissingAuth;

  /// No description provided for @importHy2MissingHost.
  ///
  /// In en, this message translates to:
  /// **'Hysteria2 host is missing'**
  String get importHy2MissingHost;

  /// No description provided for @importHy2InvalidPort.
  ///
  /// In en, this message translates to:
  /// **'Hysteria2 port is out of range'**
  String get importHy2InvalidPort;

  /// No description provided for @importHy2UnsupportedObfs.
  ///
  /// In en, this message translates to:
  /// **'Only Salamander obfuscation is supported for Hysteria2'**
  String get importHy2UnsupportedObfs;

  /// No description provided for @importHy2MissingObfsPassword.
  ///
  /// In en, this message translates to:
  /// **'Salamander obfuscation password is missing'**
  String get importHy2MissingObfsPassword;

  /// No description provided for @importVlessMalformedUri.
  ///
  /// In en, this message translates to:
  /// **'Link is malformed'**
  String get importVlessMalformedUri;

  /// No description provided for @importVlessMissingUuid.
  ///
  /// In en, this message translates to:
  /// **'UUID is missing in link'**
  String get importVlessMissingUuid;

  /// No description provided for @importVlessInvalidUuid.
  ///
  /// In en, this message translates to:
  /// **'UUID is not a valid RFC 4122 identifier'**
  String get importVlessInvalidUuid;

  /// No description provided for @importVlessMissingHost.
  ///
  /// In en, this message translates to:
  /// **'Host is missing'**
  String get importVlessMissingHost;

  /// No description provided for @importVlessInvalidPort.
  ///
  /// In en, this message translates to:
  /// **'Port is out of range'**
  String get importVlessInvalidPort;

  /// No description provided for @importVlessUnsupportedTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport is not supported'**
  String get importVlessUnsupportedTransport;

  /// No description provided for @importVlessUnsupportedSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security is not supported (none/tls/reality only)'**
  String get importVlessUnsupportedSecurity;

  /// No description provided for @importedOneServer.
  ///
  /// In en, this message translates to:
  /// **'Imported 1 server.'**
  String get importedOneServer;

  /// No description provided for @importedNServers.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} servers.'**
  String importedNServers(int count);

  /// No description provided for @importedSubscriptionOne.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\" with 1 server.'**
  String importedSubscriptionOne(String name);

  /// No description provided for @importedSubscriptionMany.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\" with {count} servers.'**
  String importedSubscriptionMany(String name, int count);

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @tunnelSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tunnel settings'**
  String get tunnelSettingsTitle;

  /// No description provided for @tunnelUseLocalDns.
  ///
  /// In en, this message translates to:
  /// **'Use local DNS'**
  String get tunnelUseLocalDns;

  /// No description provided for @tunnelEnableServerResolving.
  ///
  /// In en, this message translates to:
  /// **'Server DNS'**
  String get tunnelEnableServerResolving;

  /// No description provided for @tunnelPacketAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Packet analysis'**
  String get tunnelPacketAnalysis;

  /// No description provided for @tunnelNetworkStack.
  ///
  /// In en, this message translates to:
  /// **'Network stack'**
  String get tunnelNetworkStack;

  /// No description provided for @tunnelMtu.
  ///
  /// In en, this message translates to:
  /// **'MTU'**
  String get tunnelMtu;

  /// No description provided for @tunnelMtuHint.
  ///
  /// In en, this message translates to:
  /// **'1500'**
  String get tunnelMtuHint;

  /// No description provided for @tunnelIpMode.
  ///
  /// In en, this message translates to:
  /// **'IP mode'**
  String get tunnelIpMode;

  /// No description provided for @tunnelNetStackSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get tunnelNetStackSystem;

  /// No description provided for @tunnelNetStackGvisor.
  ///
  /// In en, this message translates to:
  /// **'gVisor'**
  String get tunnelNetStackGvisor;

  /// No description provided for @tunnelNetStackMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get tunnelNetStackMixed;

  /// No description provided for @tunnelIpModeIpv4.
  ///
  /// In en, this message translates to:
  /// **'IPv4'**
  String get tunnelIpModeIpv4;

  /// No description provided for @tunnelIpModeIpv6.
  ///
  /// In en, this message translates to:
  /// **'IPv6'**
  String get tunnelIpModeIpv6;

  /// No description provided for @tunnelIpModeMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get tunnelIpModeMixed;

  /// No description provided for @tunnelBlockUdp.
  ///
  /// In en, this message translates to:
  /// **'Block UDP'**
  String get tunnelBlockUdp;

  /// No description provided for @tunnelBlockUdpDescription.
  ///
  /// In en, this message translates to:
  /// **'Blocks app UDP traffic in the tunnel. DNS is handled separately.'**
  String get tunnelBlockUdpDescription;

  /// No description provided for @tunnelXrayTun.
  ///
  /// In en, this message translates to:
  /// **'Xray TUN'**
  String get tunnelXrayTun;

  /// No description provided for @tunnelXrayTunDescription.
  ///
  /// In en, this message translates to:
  /// **'Fullcone UDP supported. Experimental. May increase battery consumption'**
  String get tunnelXrayTunDescription;

  /// No description provided for @tunnelEnableDnsForTun.
  ///
  /// In en, this message translates to:
  /// **'Enable DNS for TUN'**
  String get tunnelEnableDnsForTun;

  /// No description provided for @tunnelTunDnsLabel.
  ///
  /// In en, this message translates to:
  /// **'TUN DNS'**
  String get tunnelTunDnsLabel;

  /// No description provided for @tunnelTunDnsHint.
  ///
  /// In en, this message translates to:
  /// **'1.1.1.1'**
  String get tunnelTunDnsHint;

  /// No description provided for @tunnelCustomSocksTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom SOCKS5 credentials'**
  String get tunnelCustomSocksTitle;

  /// No description provided for @tunnelCustomSocksOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Using credentials from this screen.'**
  String get tunnelCustomSocksOnDescription;

  /// No description provided for @tunnelCustomSocksOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Off — fresh credentials are auto-generated for every session.'**
  String get tunnelCustomSocksOffDescription;

  /// No description provided for @tunnelProxyUserLabel.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get tunnelProxyUserLabel;

  /// No description provided for @tunnelProxyPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get tunnelProxyPasswordLabel;

  /// No description provided for @tunnelProxyInboundHelp.
  ///
  /// In en, this message translates to:
  /// **'Use these credentials when connecting external apps to the local SOCKS5 (127.0.0.1:10808) or HTTP (127.0.0.1:10809) inbounds.'**
  String get tunnelProxyInboundHelp;

  /// No description provided for @tunnelRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get tunnelRegenerate;

  /// No description provided for @tunnelFragmentEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable fragmentation'**
  String get tunnelFragmentEnable;

  /// No description provided for @tunnelFragmentOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Settings are applied to Xray outbound traffic.'**
  String get tunnelFragmentOnDescription;

  /// No description provided for @tunnelFragmentOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Off — traffic goes through the proxy directly.'**
  String get tunnelFragmentOffDescription;

  /// No description provided for @tunnelFragmentPackets.
  ///
  /// In en, this message translates to:
  /// **'Fragment packets'**
  String get tunnelFragmentPackets;

  /// No description provided for @tunnelFragmentLength.
  ///
  /// In en, this message translates to:
  /// **'Fragment length (min-max)'**
  String get tunnelFragmentLength;

  /// No description provided for @tunnelFragmentInterval.
  ///
  /// In en, this message translates to:
  /// **'Fragment interval (min-max)'**
  String get tunnelFragmentInterval;

  /// No description provided for @tunnelFragmentMaxSplit.
  ///
  /// In en, this message translates to:
  /// **'Fragment max split (min-max)'**
  String get tunnelFragmentMaxSplit;

  /// No description provided for @tunnelNoiseSettings.
  ///
  /// In en, this message translates to:
  /// **'Noise settings'**
  String get tunnelNoiseSettings;

  /// No description provided for @tunnelNoiseType.
  ///
  /// In en, this message translates to:
  /// **'Noise type'**
  String get tunnelNoiseType;

  /// No description provided for @tunnelNoisePacketLengthRange.
  ///
  /// In en, this message translates to:
  /// **'Packet length range'**
  String get tunnelNoisePacketLengthRange;

  /// No description provided for @tunnelNoisePacket.
  ///
  /// In en, this message translates to:
  /// **'Noise packet'**
  String get tunnelNoisePacket;

  /// No description provided for @tunnelNoiseDelay.
  ///
  /// In en, this message translates to:
  /// **'Noise delay (min-max)'**
  String get tunnelNoiseDelay;

  /// No description provided for @tunnelNoiseApplyTo.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get tunnelNoiseApplyTo;

  /// No description provided for @tunnelNoiseTypeRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get tunnelNoiseTypeRandom;

  /// No description provided for @tunnelNoiseTypeString.
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get tunnelNoiseTypeString;

  /// No description provided for @tunnelNoiseTypeHex.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get tunnelNoiseTypeHex;

  /// No description provided for @tunnelNoiseTypeBase64.
  ///
  /// In en, this message translates to:
  /// **'Base64'**
  String get tunnelNoiseTypeBase64;

  /// No description provided for @tunnelNoiseApplyIp.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get tunnelNoiseApplyIp;

  /// No description provided for @tunnelNoiseApplyIpv4.
  ///
  /// In en, this message translates to:
  /// **'IPv4'**
  String get tunnelNoiseApplyIpv4;

  /// No description provided for @tunnelNoiseApplyIpv6.
  ///
  /// In en, this message translates to:
  /// **'IPv6'**
  String get tunnelNoiseApplyIpv6;

  /// No description provided for @tunnelMuxEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable multiplexing'**
  String get tunnelMuxEnable;

  /// No description provided for @tunnelMuxOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Multiplexing options are configured below.'**
  String get tunnelMuxOnDescription;

  /// No description provided for @tunnelMuxOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Off — each stream uses its own direct tunnel connection.'**
  String get tunnelMuxOffDescription;

  /// No description provided for @tunnelMuxTcpConnections.
  ///
  /// In en, this message translates to:
  /// **'TCP connections (-1 to 128)'**
  String get tunnelMuxTcpConnections;

  /// No description provided for @tunnelMuxXudpConnections.
  ///
  /// In en, this message translates to:
  /// **'XUDP connections (-1 to 1024)'**
  String get tunnelMuxXudpConnections;

  /// No description provided for @tunnelMuxQuicBehavior.
  ///
  /// In en, this message translates to:
  /// **'QUIC in MUX'**
  String get tunnelMuxQuicBehavior;

  /// No description provided for @tunnelMuxQuicReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get tunnelMuxQuicReject;

  /// No description provided for @tunnelMuxQuicAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get tunnelMuxQuicAllow;

  /// No description provided for @tunnelMuxQuicPassthrough.
  ///
  /// In en, this message translates to:
  /// **'Passthrough'**
  String get tunnelMuxQuicPassthrough;

  /// No description provided for @tvSectionConnect.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get tvSectionConnect;

  /// No description provided for @tvSectionNodes.
  ///
  /// In en, this message translates to:
  /// **'NODES'**
  String get tvSectionNodes;

  /// No description provided for @tvNodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{NO NODES} =1{1 NODE} other{{count} NODES}}'**
  String tvNodesCount(int count);

  /// No description provided for @tvEmptyNodes.
  ///
  /// In en, this message translates to:
  /// **'No servers yet — open the app on your phone to import a subscription.'**
  String get tvEmptyNodes;

  /// No description provided for @tvGroupManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get tvGroupManual;

  /// No description provided for @tvExitDevPreview.
  ///
  /// In en, this message translates to:
  /// **'Exit preview'**
  String get tvExitDevPreview;

  /// No description provided for @tvStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get tvStatusIdle;

  /// No description provided for @tvStatusNegotiating.
  ///
  /// In en, this message translates to:
  /// **'Negotiating…'**
  String get tvStatusNegotiating;

  /// No description provided for @tvStatusSecure.
  ///
  /// In en, this message translates to:
  /// **'Secure'**
  String get tvStatusSecure;

  /// No description provided for @tvStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get tvStatusError;

  /// No description provided for @tvHubLabelOff.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get tvHubLabelOff;

  /// No description provided for @tvHubLabelConnecting.
  ///
  /// In en, this message translates to:
  /// **'NEGOTIATING'**
  String get tvHubLabelConnecting;

  /// No description provided for @tvHubLabelOn.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get tvHubLabelOn;

  /// No description provided for @tvHubLabelError.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get tvHubLabelError;

  /// No description provided for @tvHubSubOff.
  ///
  /// In en, this message translates to:
  /// **'OK / SELECT'**
  String get tvHubSubOff;

  /// No description provided for @tvHubSubConnecting.
  ///
  /// In en, this message translates to:
  /// **'PLEASE WAIT'**
  String get tvHubSubConnecting;

  /// No description provided for @tvHubSubOn.
  ///
  /// In en, this message translates to:
  /// **'OK TO DISCONNECT'**
  String get tvHubSubOn;

  /// No description provided for @tvHubSubError.
  ///
  /// In en, this message translates to:
  /// **'OK / SELECT'**
  String get tvHubSubError;

  /// No description provided for @tvKvExitNode.
  ///
  /// In en, this message translates to:
  /// **'EXIT NODE'**
  String get tvKvExitNode;

  /// No description provided for @tvKvExitIp.
  ///
  /// In en, this message translates to:
  /// **'EXIT IP'**
  String get tvKvExitIp;

  /// No description provided for @tvKvRegion.
  ///
  /// In en, this message translates to:
  /// **'REGION'**
  String get tvKvRegion;

  /// No description provided for @tvKvDown.
  ///
  /// In en, this message translates to:
  /// **'↓ DOWN'**
  String get tvKvDown;

  /// No description provided for @tvKvUp.
  ///
  /// In en, this message translates to:
  /// **'↑ UP'**
  String get tvKvUp;

  /// No description provided for @tvKvExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get tvKvExpires;

  /// No description provided for @tvKvNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get tvKvNodes;

  /// No description provided for @tvSideSplit.
  ///
  /// In en, this message translates to:
  /// **'SPLIT'**
  String get tvSideSplit;

  /// No description provided for @tvSideSplitSub.
  ///
  /// In en, this message translates to:
  /// **'ROUTING RULES'**
  String get tvSideSplitSub;

  /// No description provided for @tvSideGlobal.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL'**
  String get tvSideGlobal;

  /// No description provided for @tvSideGlobalSub.
  ///
  /// In en, this message translates to:
  /// **'ALL TRAFFIC'**
  String get tvSideGlobalSub;

  /// No description provided for @tvSidePreset.
  ///
  /// In en, this message translates to:
  /// **'PRESET'**
  String get tvSidePreset;

  /// No description provided for @tvSidePresetSub.
  ///
  /// In en, this message translates to:
  /// **'STREAMING'**
  String get tvSidePresetSub;

  /// No description provided for @tvActionConnect.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get tvActionConnect;

  /// No description provided for @tvActionDisconnect.
  ///
  /// In en, this message translates to:
  /// **'DISCONNECT'**
  String get tvActionDisconnect;

  /// No description provided for @tvActionCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get tvActionCancel;

  /// No description provided for @tvActionToggle.
  ///
  /// In en, this message translates to:
  /// **'TOGGLE'**
  String get tvActionToggle;

  /// No description provided for @tvActionSelectNode.
  ///
  /// In en, this message translates to:
  /// **'SELECT NODE'**
  String get tvActionSelectNode;

  /// No description provided for @tvActionSelect.
  ///
  /// In en, this message translates to:
  /// **'SELECT'**
  String get tvActionSelect;

  /// No description provided for @tvActionRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get tvActionRetry;

  /// No description provided for @tvActionExit.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get tvActionExit;

  /// No description provided for @tvActionClose.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get tvActionClose;

  /// No description provided for @tvActionNodeOptions.
  ///
  /// In en, this message translates to:
  /// **'NODE OPTIONS'**
  String get tvActionNodeOptions;

  /// No description provided for @tvActionSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIPTIONS'**
  String get tvActionSubscriptions;

  /// No description provided for @tvActionPingScan.
  ///
  /// In en, this message translates to:
  /// **'PING SCAN'**
  String get tvActionPingScan;

  /// No description provided for @tvActionBackKey.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get tvActionBackKey;

  /// No description provided for @tvActionMenuKey.
  ///
  /// In en, this message translates to:
  /// **'MENU'**
  String get tvActionMenuKey;

  /// No description provided for @tvActionPlayPauseKey.
  ///
  /// In en, this message translates to:
  /// **'PLAY/PAUSE'**
  String get tvActionPlayPauseKey;

  /// No description provided for @tvHintRemoteFooter.
  ///
  /// In en, this message translates to:
  /// **'D-PAD · NAVIGATE  ·  HOLD OK FOR DETAILS'**
  String get tvHintRemoteFooter;

  /// No description provided for @tvOverlaySubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIPTIONS'**
  String get tvOverlaySubscriptionsTitle;

  /// No description provided for @tvOverlaySubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select to expand · MENU for actions'**
  String get tvOverlaySubscriptionsSubtitle;

  /// No description provided for @tvOverlaySubscriptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions imported yet.'**
  String get tvOverlaySubscriptionsEmpty;

  /// No description provided for @tvOverlayPresetTitle.
  ///
  /// In en, this message translates to:
  /// **'NODE PRESET'**
  String get tvOverlayPresetTitle;

  /// No description provided for @tvOverlayPresetSubtitleGlobal.
  ///
  /// In en, this message translates to:
  /// **'Choose routing behaviour'**
  String get tvOverlayPresetSubtitleGlobal;

  /// No description provided for @tvOverlayPresetSubtitleForNode.
  ///
  /// In en, this message translates to:
  /// **'{server} · choose routing behaviour'**
  String tvOverlayPresetSubtitleForNode(String server);

  /// No description provided for @tvOverlayFooter.
  ///
  /// In en, this message translates to:
  /// **'BACK · CLOSE   ·   OK · SELECT'**
  String get tvOverlayFooter;

  /// No description provided for @tvPresetCurrentChip.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get tvPresetCurrentChip;

  /// No description provided for @tvPresetMainDescription.
  ///
  /// In en, this message translates to:
  /// **'Default routing rules — applies to every node.'**
  String get tvPresetMainDescription;

  /// No description provided for @tvPresetSummary.
  ///
  /// In en, this message translates to:
  /// **'{rules, plural, =0{No rules} =1{1 rule} other{{rules} rules}} · {apps, plural, =0{no apps} =1{1 app} other{{apps} apps}}'**
  String tvPresetSummary(int rules, int apps);

  /// No description provided for @tvRefreshedUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get tvRefreshedUnknown;

  /// No description provided for @tvRefreshedJustNow.
  ///
  /// In en, this message translates to:
  /// **'↓ Just now'**
  String get tvRefreshedJustNow;

  /// No description provided for @tvRefreshedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'↓ Refreshed {minutes}m ago'**
  String tvRefreshedMinutesAgo(int minutes);

  /// No description provided for @tvRefreshedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'↓ Refreshed {hours}h ago'**
  String tvRefreshedHoursAgo(int hours);

  /// No description provided for @tvRefreshedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'↓ Refreshed {days}d ago'**
  String tvRefreshedDaysAgo(int days);

  /// No description provided for @tvLayoutSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Interface layout'**
  String get tvLayoutSectionTitle;

  /// No description provided for @tvLayoutSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the phone layout, the horizontal TV layout, or allow rotation.'**
  String get tvLayoutSectionSubtitle;

  /// No description provided for @tvLayoutVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get tvLayoutVertical;

  /// No description provided for @tvLayoutHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get tvLayoutHorizontal;

  /// No description provided for @tvLayoutAutoRotate.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get tvLayoutAutoRotate;

  /// No description provided for @settingsFaqLabel.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get settingsFaqLabel;

  /// No description provided for @telegramOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Telegram link.'**
  String get telegramOpenFailed;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqTitle;

  /// No description provided for @faqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Common questions'**
  String get faqSubtitle;

  /// No description provided for @faqHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a question to expand the answer.'**
  String get faqHint;

  /// No description provided for @faqQ1.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t I pick an XHTTP server as the exit node in a two-hop chain?'**
  String get faqQ1;

  /// No description provided for @faqA1.
  ///
  /// In en, this message translates to:
  /// **'In a two-hop setup the exit node\'s outbound is dialled through the entry via sockopt.dialerProxy. XHTTP is an HTTP/2 transport with its own TLS/REALITY wrapper, and its handshake doesn\'t reach across the entry tunnel cleanly — the connection comes up, but nothing flows. XHTTP servers are therefore hidden in the exit-node picker. Use such a server as the primary (entry) node, and pick a VLESS-TCP / WS / REALITY server as the exit.'**
  String get faqA1;

  /// No description provided for @faqQ2.
  ///
  /// In en, this message translates to:
  /// **'What\'s the difference between the libbox and Xray TUN engines?'**
  String get faqQ2;

  /// No description provided for @faqA2.
  ///
  /// In en, this message translates to:
  /// **'**libbox** (sing-box) is the default — stable, plays well with the system, and easier on the battery. **Xray TUN** is experimental: it pushes packets straight through the Xray core. Use it only if you need Xray-specific behaviour or if libbox misbehaves on your device. Leave it on libbox unless you have a reason.'**
  String get faqA2;

  /// No description provided for @faqQ3.
  ///
  /// In en, this message translates to:
  /// **'Why do I need «Global proxy» if the VPN is already on?'**
  String get faqQ3;

  /// No description provided for @faqA3.
  ///
  /// In en, this message translates to:
  /// **'Without it your routing preset is in charge (per-app, domains, IP, geosite/geoip) — some traffic may stay direct. «Global proxy» temporarily overrides the rules and routes everything technically possible through the tunnel. Handy as a sanity check («does my traffic reach the server at all?») or when you want a full tunnel right now. The button can be hidden in settings.'**
  String get faqA3;

  /// No description provided for @faqQ4.
  ///
  /// In en, this message translates to:
  /// **'What are routing presets and per-node presets?'**
  String get faqQ4;

  /// No description provided for @faqA4.
  ///
  /// In en, this message translates to:
  /// **'**Main** is the default rule set, applied to any node without its own preset. Extra presets can be bound to specific servers from the node menu → «Routing preset». Rules are Xray-style: outbound `proxy` / `direct` / `block` by domains, IP/CIDR, `geoip:` / `geosite:`, ports, network (tcp/udp), or protocols.'**
  String get faqA4;

  /// No description provided for @faqQ5.
  ///
  /// In en, this message translates to:
  /// **'What is an «Exit node» (EXIT)?'**
  String get faqQ5;

  /// No description provided for @faqA5.
  ///
  /// In en, this message translates to:
  /// **'A two-hop setup: the **entry** node is the one you connect to with the main button; the **exit** is a separate server the traffic egresses through (entry → exit). Useful when you want to separate «where you knock» from «where you appear on the internet». Entry and exit must be different servers — otherwise the chain collapses into an ordinary single-hop connection.'**
  String get faqA5;

  /// No description provided for @faqQ6.
  ///
  /// In en, this message translates to:
  /// **'I changed tunnel settings, but they didn\'t take effect — why?'**
  String get faqQ6;

  /// No description provided for @faqA6.
  ///
  /// In en, this message translates to:
  /// **'Some parameters (TUN engine, DNS, stack, MTU, fragmentation, multiplex, …) only apply on the next tunnel start. In tunnel settings there\'s a **«Restart tunnel on settings change»** toggle — with it on, the app re-establishes the connection when you leave the settings screen. Otherwise disconnect and reconnect by hand.'**
  String get faqA6;

  /// No description provided for @faqQ7.
  ///
  /// In en, this message translates to:
  /// **'What is HWID and why does my subscription send it?'**
  String get faqQ7;

  /// No description provided for @faqA7.
  ///
  /// In en, this message translates to:
  /// **'HWID is a stable per-device identifier, computed locally (visible in «About»). It is sent in an HTTP header on the subscription request **only when the provider explicitly asks for it** via the subscription URL. Providers use it for «one subscription — N devices» quotas. HWID is not sent anywhere else.'**
  String get faqA7;

  /// No description provided for @faqQ8.
  ///
  /// In en, this message translates to:
  /// **'What\'s the slim build, and do I have to download GeoData?'**
  String get faqQ8;

  /// No description provided for @faqA8.
  ///
  /// In en, this message translates to:
  /// **'The standard build ships `geoip.dat` / `geosite.dat` (~28 MB) inside the APK — rules like `geosite:netflix` work out of the box. The slim build omits those files and downloads them on first launch from «Settings → GeoData». If you don\'t use geo-based routing rules, you can skip the GeoData download entirely.'**
  String get faqA8;

  /// No description provided for @faqQ9.
  ///
  /// In en, this message translates to:
  /// **'Per-app routing doesn\'t apply to Push / Play Services / system apps — is that normal?'**
  String get faqQ9;

  /// No description provided for @faqA9.
  ///
  /// In en, this message translates to:
  /// **'Yes. Android refuses to route some system processes through a VPN (parts of Google Mobile Services, push, system updates). This is a `VpnService` platform limit, not the app — it can\'t be worked around without root. Their traffic will bypass the tunnel even when whitelisted.'**
  String get faqA9;

  /// No description provided for @faqQ10.
  ///
  /// In en, this message translates to:
  /// **'Network stack: system / gVisor / mixed — which one?'**
  String get faqQ10;

  /// No description provided for @faqA10.
  ///
  /// In en, this message translates to:
  /// **'**system** is the fastest — uses the kernel TCP stack, but a few exotic networks cause it to drop.\n**gVisor** is a user-space TCP stack; more reliable on «odd» networks (certain mobile carriers), slightly slower and warmer.\n**mixed** is the compromise: gVisor for TCP, system for UDP.\nIf **system** works, stay on **system**.'**
  String get faqA10;

  /// No description provided for @faqQ11.
  ///
  /// In en, this message translates to:
  /// **'The ping to the server and the ping via the local proxy differ a lot — what shows what?'**
  String get faqQ11;

  /// No description provided for @faqA11.
  ///
  /// In en, this message translates to:
  /// **'**Endpoint ping** is a plain TCP ping to the server\'s IP:port (how quickly the network reaches it). **Proxy ping** is a real HTTP request through the established proxy connection (includes TLS handshake, reverse proxy, routing). The second is always larger; it reflects how the internet actually feels. A large gap usually means your ISP is throttling the proxy itself, not the network.'**
  String get faqA11;

  /// No description provided for @faqQ12.
  ///
  /// In en, this message translates to:
  /// **'My subscription doesn\'t update, or updates but the node list doesn\'t change — what should I check?'**
  String get faqQ12;

  /// No description provided for @faqA12.
  ///
  /// In en, this message translates to:
  /// **'First — the auto-refresh interval (1 hour by default) and the «refresh on launch» toggle. To force it, hit refresh on the subscription page. If the content still doesn\'t change, your provider returned the same node set. If the «protect subscriptions» switch is on, manual edits inside subscription nodes are overwritten on the next refresh.'**
  String get faqA12;

  /// No description provided for @faqQ13.
  ///
  /// In en, this message translates to:
  /// **'Calls / games / streaming are slow over the VPN — what can I try?'**
  String get faqQ13;

  /// No description provided for @faqA13.
  ///
  /// In en, this message translates to:
  /// **'Most of those apps run over UDP / QUIC. Check:\n1. Stack — try **mixed** (gVisor for TCP, system for UDP).\n2. **Multiplex → QUIC** — set `passthrough` or `reject`; `allow` wraps QUIC over mux and adds latency.\n3. If your protocol is Hysteria2, the carrier itself is UDP — make sure your ISP doesn\'t throttle UDP traffic to the server.'**
  String get faqA13;

  /// No description provided for @faqQ14.
  ///
  /// In en, this message translates to:
  /// **'What does «Multiplex: QUIC — reject / allow / passthrough» mean?'**
  String get faqQ14;

  /// No description provided for @faqA14.
  ///
  /// In en, this message translates to:
  /// **'Multiplex packs many logical streams into a single TCP/XUDP connection. QUIC rides on UDP, and its handling is configured separately:\n**reject** — block QUIC, apps fall back to TCP/HTTPS on their own (safe default).\n**passthrough** — QUIC bypasses mux on its own UDP channel (faster, but no multiplexing).\n**allow** — QUIC is wrapped into mux (exotic, for pattern hiding; usually slower).'**
  String get faqA14;

  /// No description provided for @faqQ15.
  ///
  /// In en, this message translates to:
  /// **'Why does the screen show «———» instead of an external IP?'**
  String get faqQ15;

  /// No description provided for @faqA15.
  ///
  /// In en, this message translates to:
  /// **'The external IP is looked up after the tunnel comes up — through a separate HTTPS request via the local proxy. If the network is unstable or the lookup is blocked, the app falls back to «Unavailable». That doesn\'t mean the tunnel itself is broken — it can still be working.'**
  String get faqA15;

  /// No description provided for @faqQ16.
  ///
  /// In en, this message translates to:
  /// **'Why doesn\'t auto-connect on launch fire?'**
  String get faqQ16;

  /// No description provided for @faqA16.
  ///
  /// In en, this message translates to:
  /// **'The toggle lives in **Settings → Application**, but on a number of Android skins the OS battery policy blocks background service auto-start. Disable battery optimisation for VoidTunnel, and consider Android\'s system **Always-on VPN** (Settings → Network → VPN → VoidTunnel) — it brings the tunnel up reliably at boot.'**
  String get faqA16;

  /// No description provided for @faqQ17.
  ///
  /// In en, this message translates to:
  /// **'Can I point another app at the local proxy?'**
  String get faqQ17;

  /// No description provided for @faqA17.
  ///
  /// In en, this message translates to:
  /// **'Yes — while the tunnel is up the app listens on **SOCKS5** `127.0.0.1:10808` and **HTTP** `127.0.0.1:10809`. By default the username and password are regenerated every session. To pin your own, go to **Settings → Tunnel → SOCKS5 credentials** — flip the switch and enter (or generate) a fixed pair.'**
  String get faqA17;

  /// No description provided for @faqQ18.
  ///
  /// In en, this message translates to:
  /// **'Is there a built-in kill switch?'**
  String get faqQ18;

  /// No description provided for @faqA18.
  ///
  /// In en, this message translates to:
  /// **'There\'s no dedicated «kill switch» toggle in the UI. If the VPN drops, traffic may leak directly until you reconnect. For hard blocking of unprotected traffic, use Android\'s system **Always-on VPN** in the OS settings — the same screen lets you turn on «Block connections without VPN».'**
  String get faqA18;

  /// No description provided for @faqQ19.
  ///
  /// In en, this message translates to:
  /// **'Where are my data and logs stored — is that safe?'**
  String get faqQ19;

  /// No description provided for @faqA19.
  ///
  /// In en, this message translates to:
  /// **'Nodes, subscriptions, presets, and the journal are all local on the device; nothing leaves it except subscription requests and the traffic going through your chosen server. The journal can be cleared from «Settings → Journal». In verbose mode the log will contain sensitive fields (UUIDs, hosts, keys) — **don\'t publish verbose dumps as-is.** The app itself is not an anonymiser; the privacy level depends on your servers and your rules.'**
  String get faqA19;

  /// No description provided for @faqQ20.
  ///
  /// In en, this message translates to:
  /// **'Is there TV and iOS support?'**
  String get faqQ20;

  /// No description provided for @faqA20.
  ///
  /// In en, this message translates to:
  /// **'**Android TV / Google TV** — yes, a dedicated full-screen UI with D-pad support; the nodes and subscriptions are shared with the mobile version. **iOS / iPadOS** — a full client is in development.'**
  String get faqA20;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
