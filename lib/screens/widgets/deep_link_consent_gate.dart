import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/deep_link_handler.dart';
import '../../core/pending_deep_link.dart';
import '../../core/vpn_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/user_message_localizer.dart';

/// Presents controller-owned deep-link notices and consent requests above
/// whichever home layout is currently active.
///
/// Keeping this above the mobile/TV layout switch prevents a pending request
/// from being lost during cold start or an orientation-driven layout change.
class DeepLinkConsentGate extends StatefulWidget {
  const DeepLinkConsentGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final VpnController controller;
  final Widget child;

  @override
  State<DeepLinkConsentGate> createState() => _DeepLinkConsentGateState();
}

class _DeepLinkConsentGateState extends State<DeepLinkConsentGate> {
  bool _dialogVisible = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _schedulePendingStateCheck();
  }

  @override
  void didUpdateWidget(covariant DeepLinkConsentGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _schedulePendingStateCheck();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() => _schedulePendingStateCheck();

  void _schedulePendingStateCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      _consumePendingState();
    });
  }

  void _consumePendingState() {
    final notice = widget.controller.consumeDeepLinkNotice();
    if (notice != null && notice.isNotEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizeUserMessage(context, notice))),
        );
    }

    final pending = widget.controller.pendingDeepLink;
    if (pending == null || _dialogVisible) return;
    _dialogVisible = true;
    unawaited(_showConsentDialog(pending));
  }

  String _description(AppLocalizations l, PendingDeepLink request) {
    if (request.kind == DeepLinkActionKind.vpnControl) {
      return switch (request.vpnCommand) {
        VpnDeepLinkCommand.connect => l.deepLinkConsentVpnControlConnect,
        VpnDeepLinkCommand.disconnect => l.deepLinkConsentVpnControlDisconnect,
        VpnDeepLinkCommand.toggle => l.deepLinkConsentVpnControlToggle,
        VpnDeepLinkCommand.restart => l.deepLinkConsentVpnControlRestart,
        null => l.deepLinkConsentVpnControlToggle,
      };
    }
    return switch (request.kind) {
      DeepLinkActionKind.importServers => l.deepLinkConsentImportServers,
      DeepLinkActionKind.importRuleset => l.deepLinkConsentImportRuleset,
      DeepLinkActionKind.importSubscription =>
        l.deepLinkConsentImportSubscription,
      DeepLinkActionKind.vpnControl => l.deepLinkConsentVpnControlToggle,
    };
  }

  String _confirmLabel(AppLocalizations l, PendingDeepLink request) {
    return request.kind == DeepLinkActionKind.vpnControl
        ? l.deepLinkConsentVpnControlConfirm
        : l.deepLinkConsentConfirm;
  }

  Future<void> _showConsentDialog(PendingDeepLink request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l = AppLocalizations.of(dialogContext);
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(l.deepLinkConsentTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_description(l, request)),
                const SizedBox(height: 12),
                Text(
                  l.deepLinkConsentSourceLabel,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  request.displayUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                if (request.isInsecureHttp) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.deepLinkConsentHttpWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_confirmLabel(l, request)),
            ),
          ],
        );
      },
    );

    _dialogVisible = false;
    if (!mounted) return;
    if (confirmed == true) {
      await widget.controller.confirmPendingDeepLink();
    } else {
      widget.controller.cancelPendingDeepLink();
    }
    _schedulePendingStateCheck();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
