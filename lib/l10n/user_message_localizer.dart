import 'package:flutter/widgets.dart';

import '../core/app_message_code.dart' show Msg;
import 'app_localizations.dart';

/// Maps stable [Msg] keys (and a few structured `name:payload` forms) to
/// localized strings. Unknown strings are returned as-is (native errors).
String localizeUserMessage(BuildContext context, String message) {
  final l = AppLocalizations.of(context);
  const httpPrefix = 'subImportHttpStatus:';
  if (message.startsWith(httpPrefix)) {
    final code = int.tryParse(message.substring(httpPrefix.length));
    if (code != null) return l.subImportHttpStatus(code);
  }
  if (message.startsWith('subImportRequestFailed:')) {
    return l.subImportRequestFailed(
      message.substring('subImportRequestFailed:'.length),
    );
  }
  if (message.startsWith('vpnEventChannelError:')) {
    return l.vpnEventChannelError(
      message.substring('vpnEventChannelError:'.length),
    );
  }
  if (message.startsWith('subImportGenericDetail:')) {
    return l.subImportGenericDetail(
      message.substring('subImportGenericDetail:'.length),
    );
  }
  const rulesetHttpPrefix = 'deepLinkRulesetHttpStatus:';
  if (message.startsWith(rulesetHttpPrefix)) {
    final code = int.tryParse(message.substring(rulesetHttpPrefix.length));
    if (code != null) return l.deepLinkRulesetHttpStatus(code);
  }
  if (message.startsWith('deepLinkRulesetRequestFailed:')) {
    return l.deepLinkRulesetRequestFailed(
      message.substring('deepLinkRulesetRequestFailed:'.length),
    );
  }
  const rulesetImportedPrefix = 'deepLinkRulesetImported:';
  if (message.startsWith(rulesetImportedPrefix)) {
    final count = int.tryParse(message.substring(rulesetImportedPrefix.length));
    if (count != null) return l.deepLinkRulesetImported(count);
  }

  return switch (message) {
    Msg.editServerNameDuplicate => l.editServerNameDuplicate,
    Msg.editServerNotFound => l.editServerNotFound,
    Msg.subscriptionNotFound => l.subscriptionNotFound,
    Msg.subscriptionNameRequired => l.subscriptionNameRequired,
    Msg.subscriptionInvalidUrl => l.subscriptionInvalidUrl,
    Msg.presetNameRequired => l.presetNameRequired,
    Msg.presetNameDuplicate => l.presetNameDuplicate,
    Msg.presetNotFound => l.presetNotFound,
    Msg.presetMainCannotRename => l.presetMainCannotRename,
    Msg.presetMainCannotDelete => l.presetMainCannotDelete,
    Msg.vpnNoServerSelected => l.vpnNoServerSelected,
    Msg.vpnPermissionDenied => l.vpnPermissionDenied,
    Msg.vpnPlatformError => l.vpnPlatformError,
    Msg.vpnFailedToStop => l.vpnFailedToStop,
    Msg.vpnFailedToReconnect => l.vpnFailedToReconnect,
    Msg.vpnUnknownError => l.vpnUnknownError,
    Msg.vpnConnectionTimedOut => l.vpnConnectionTimedOut,
    Msg.vpnNaiveRequiresLibbox => l.vpnNaiveRequiresLibbox,
    Msg.vpnNaiveTunOnly => l.vpnNaiveTunOnly,
    Msg.vpnNaiveBridgeUnsupported => l.vpnNaiveBridgeUnsupported,
    Msg.vpnNaiveExitUnsupported => l.vpnNaiveExitUnsupported,
    Msg.subImportInvalidUrl => l.subImportInvalidUrl,
    Msg.subImportTimeout => l.subImportTimeout,
    Msg.subImportEmpty => l.subImportEmpty,
    Msg.subImportNoNodes => l.subImportNoNodes,
    Msg.subImportUnsupportedJson => l.subImportUnsupportedJson,
    Msg.subImportTooLarge => l.subImportTooLarge,
    Msg.deepLinkVpnControlColdStart => l.deepLinkVpnControlColdStart,
    Msg.deepLinkRulesetInvalidUrl => l.deepLinkRulesetInvalidUrl,
    Msg.deepLinkRulesetTimeout => l.deepLinkRulesetTimeout,
    Msg.deepLinkRulesetTooLarge => l.deepLinkRulesetTooLarge,
    Msg.deepLinkRulesetEmpty => l.deepLinkRulesetEmpty,
    Msg.deepLinkRulesetNoRules => l.deepLinkRulesetNoRules,
    Msg.deepLinkRulesetInvalidJson => l.deepLinkRulesetInvalidJson,
    _ => message,
  };
}
