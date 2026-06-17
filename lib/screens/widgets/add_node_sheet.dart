import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/hysteria2_parser.dart';
import '../../core/naive_parser.dart';
import '../../core/server_importer.dart';
import '../../core/text_file_picker.dart';
import '../../core/vless_parser.dart';
import '../../core/vpn_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../manual_server_input_screen.dart';
import '../qr_scan_screen.dart';

/// Bottom sheet that lets the user add a new node via QR / clipboard / file
/// import or open the manual-input screen. Public so it can be invoked from
/// the bottom dock on any screen.
Future<void> showAddNodeSheet(
  BuildContext context,
  VpnController controller,
) async {
  final t = VoidTokens.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.bgRaised,
    barrierColor: t.bg.withValues(alpha: 0.55),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l.addNodeSheetTitle,
                    style: VoidType.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: t.fg1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _AddSheetTile(
                icon: Icons.qr_code_scanner_rounded,
                title: l.addNodeScanQr,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _importFromQrCode(context, controller);
                },
              ),
              _AddSheetTile(
                icon: Icons.content_paste_rounded,
                title: l.addNodeFromClipboard,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _importFromClipboard(context, controller);
                },
              ),
              _AddSheetTile(
                icon: Icons.upload_file_outlined,
                title: l.addNodeFromJsonFile,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _importFromFile(context, controller);
                },
              ),
              _AddSheetTile(
                icon: Icons.edit_rounded,
                title: l.addNodeManualInput,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ManualServerInputScreen(controller: controller),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showError(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6),
      ),
    );
}

Future<void> _importFromClipboard(
  BuildContext context,
  VpnController controller,
) async {
  final result = await controller.importFromClipboard();
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  _showImportResult(context, result, l, source: 'clipboard');
}

Future<void> _importFromQrCode(
  BuildContext context,
  VpnController controller,
) async {
  final scanned = await Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (_) => QrScanScreen(controller: controller),
      fullscreenDialog: true,
    ),
  );
  if (!context.mounted) return;
  if (scanned == null) return;

  final trimmed = scanned.trim();
  if (trimmed.isEmpty) {
    _showError(context, AppLocalizations.of(context).importQrPayloadEmpty);
    return;
  }

  final result = await controller.importServersFromString(trimmed);
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  _showImportResult(context, result, l, source: 'qr');
}

Future<void> _importFromFile(
  BuildContext context,
  VpnController controller,
) async {
  const filePicker = TextFilePicker();
  final String? text;
  try {
    text = await filePicker.pickJson();
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    _showError(context, e.message ?? l.importReadJsonFailed);
    return;
  } catch (e) {
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    _showError(context, l.importReadJsonFailedDetail(e.toString()));
    return;
  }
  if (!context.mounted || text == null) return;

  final result = await controller.importServersFromString(text);
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  _showImportResult(context, result, l, source: 'file');
}

void _showImportResult(
  BuildContext context,
  ServerImportResult result,
  AppLocalizations l, {
  required String source,
}) {
  if (result.isOk) {
    final subscription = result.subscription;
    final String message;
    if (subscription != null) {
      message = result.importedCount == 1
          ? l.importedSubscriptionOne(subscription.name)
          : l.importedSubscriptionMany(subscription.name, result.importedCount);
    } else {
      message = result.importedCount == 1
          ? l.importedOneServer
          : l.importedNServers(result.importedCount);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  final error = result.error;
  if (error != null) {
    final msg = _humanizeImportError(error, l, source: source);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

String _humanizeImportError(
  ServerImportException error,
  AppLocalizations l, {
  required String source,
}) {
  // Encrypted-code decode failures are surfaced via this prefix from
  // [VpnController.importServersFromString] under [invalidSubscription].
  if (error.message.startsWith('subImportEncryptedFailed:')) {
    return l.subscriptionImportEncryptedFailed;
  }
  final vlessError = error.vlessError;
  if (vlessError != null) return _humanizeVlessError(vlessError, l, source);
  final hysteria2Error = error.hysteria2Error;
  if (hysteria2Error != null) {
    return _humanizeHysteria2Error(hysteria2Error, l, source);
  }
  final naiveError = error.naiveError;
  if (naiveError != null) return _humanizeNaiveError(naiveError, l, source);

  switch (error.code) {
    case ServerImportError.empty:
      switch (source) {
        case 'clipboard':
          return l.routingClipboardEmpty;
        case 'qr':
          return l.importQrPayloadEmpty;
        default:
          return l.routingFileEmpty;
      }
    case ServerImportError.invalidJson:
      return l.importJsonMalformed;
    case ServerImportError.unsupportedFormat:
      switch (source) {
        case 'clipboard':
          return l.importClipboardUnsupported;
        case 'qr':
          return l.importQrUnsupportedConfig;
        default:
          return l.importFileUnsupportedConfig;
      }
    case ServerImportError.invalidVless:
    case ServerImportError.invalidHysteria2:
    case ServerImportError.invalidNaive:
      return error.message;
    case ServerImportError.invalidSubscription:
    case ServerImportError.subscriptionNetwork:
      return error.message;
  }
}

String _humanizeNaiveError(
  NaiveParseException e,
  AppLocalizations l,
  String source,
) {
  switch (e.code) {
    case NaiveParseError.notNaiveScheme:
      return l.importNaiveWrongScheme;
    case NaiveParseError.malformedUri:
      return l.importNaiveMalformedUri;
    case NaiveParseError.missingHost:
      return l.importNaiveMissingHost;
    case NaiveParseError.invalidPort:
      return l.importNaiveInvalidPort;
    case NaiveParseError.invalidMode:
      return l.importNaiveInvalidMode;
    case NaiveParseError.invalidCongestionControl:
      return l.importNaiveInvalidCongestionControl;
  }
}

String _humanizeHysteria2Error(
  Hysteria2ParseException e,
  AppLocalizations l,
  String source,
) {
  switch (e.code) {
    case Hysteria2ParseError.notHysteria2Scheme:
      switch (source) {
        case 'clipboard':
          return l.importClipboardNoHy2;
        case 'qr':
          return l.importQrNoHy2;
        default:
          return l.importFileNoHy2;
      }
    case Hysteria2ParseError.malformedUri:
      return l.importHy2MalformedUri;
    case Hysteria2ParseError.missingAuth:
      return l.importHy2MissingAuth;
    case Hysteria2ParseError.missingHost:
      return l.importHy2MissingHost;
    case Hysteria2ParseError.invalidPort:
      return l.importHy2InvalidPort;
    case Hysteria2ParseError.unsupportedObfs:
      return l.importHy2UnsupportedObfs;
    case Hysteria2ParseError.missingObfsPassword:
      return l.importHy2MissingObfsPassword;
  }
}

String _humanizeVlessError(
  VlessParseException e,
  AppLocalizations l,
  String source,
) {
  switch (e.code) {
    case VlessParseError.notVlessScheme:
      switch (source) {
        case 'clipboard':
          return l.importClipboardNoVless;
        case 'qr':
          return l.importQrNoVless;
        default:
          return l.importFileNoVless;
      }
    case VlessParseError.malformedUri:
      return l.importVlessMalformedUri;
    case VlessParseError.missingUuid:
      return l.importVlessMissingUuid;
    case VlessParseError.invalidUuid:
      return l.importVlessInvalidUuid;
    case VlessParseError.missingHost:
      return l.importVlessMissingHost;
    case VlessParseError.invalidPort:
      return l.importVlessInvalidPort;
    case VlessParseError.unsupportedTransport:
      return l.importVlessUnsupportedTransport;
    case VlessParseError.unsupportedSecurity:
      return l.importVlessUnsupportedSecurity;
  }
}

class _AddSheetTile extends StatelessWidget {
  const _AddSheetTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: t.fg2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: VoidType.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.fg1,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: t.fg3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
