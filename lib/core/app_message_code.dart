/// Keys matching [AppLocalizations] getters returned from [VpnController]
/// validation methods and stored in [VpnController.lastError].
abstract final class Msg {
  static const editServerNameDuplicate = 'editServerNameDuplicate';
  static const editServerNotFound = 'editServerNotFound';

  static const subscriptionNotFound = 'subscriptionNotFound';
  static const subscriptionNameRequired = 'subscriptionNameRequired';
  static const subscriptionInvalidUrl = 'subscriptionInvalidUrl';

  static const presetNameRequired = 'presetNameRequired';
  static const presetNameDuplicate = 'presetNameDuplicate';
  static const presetNotFound = 'presetNotFound';
  static const presetMainCannotRename = 'presetMainCannotRename';
  static const presetMainCannotDelete = 'presetMainCannotDelete';

  static const vpnNoServerSelected = 'vpnNoServerSelected';
  static const vpnPermissionDenied = 'vpnPermissionDenied';
  static const vpnPlatformError = 'vpnPlatformError';
  static const vpnFailedToStop = 'vpnFailedToStop';
  static const vpnFailedToReconnect = 'vpnFailedToReconnect';
  static const vpnUnknownError = 'vpnUnknownError';
  static const vpnConnectionTimedOut = 'vpnConnectionTimedOut';

  static const subImportInvalidUrl = 'subImportInvalidUrl';
  static const subImportTimeout = 'subImportTimeout';
  static const subImportEmpty = 'subImportEmpty';
  static const subImportNoNodes = 'subImportNoNodes';
  static const subImportUnsupportedJson = 'subImportUnsupportedJson';
  static const subImportTooLarge = 'subImportTooLarge';

  static String subImportHttpStatus(int code) => 'subImportHttpStatus:$code';

  static String subImportRequestFailed(String detail) =>
      'subImportRequestFailed:$detail';

  static String vpnEventChannelError(String detail) =>
      'vpnEventChannelError:$detail';
}
