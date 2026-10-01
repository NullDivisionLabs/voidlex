import 'package:flutter/material.dart';

import '../../core/models/server_config.dart';
import '../../core/server_latency_probe.dart';
import '../../core/vpn_controller.dart';
import '../../l10n/app_localizations.dart';

class NodeDiagnosticModeSelector extends StatelessWidget {
  const NodeDiagnosticModeSelector({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopupMenuButton<NodeDiagnosticMode>(
      key: const ValueKey('node-diagnostic-mode-selector'),
      tooltip: AppLocalizations.of(context).nodeDiagnosticModeTitle,
      onSelected: controller.setNodeDiagnosticMode,
      itemBuilder: (_) => [
        for (final mode in NodeDiagnosticMode.values)
          CheckedPopupMenuItem(
            value: mode,
            checked: controller.nodeDiagnosticMode == mode,
            child: Text(mode.label),
          ),
      ],
      child: Padding(
        // The dropdown glyph has its own trailing whitespace.
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.nodeDiagnosticMode.label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

Future<void> showServerDiagnostic({
  required BuildContext context,
  required VpnController controller,
  required ServerConfig server,
  required NodeDiagnosticMode mode,
}) async {
  final l = AppLocalizations.of(context);
  final title = mode == NodeDiagnosticMode.url
      ? l.urlDiagnosticTitle
      : l.tcpDiagnosticTitle;
  final target = mode == NodeDiagnosticMode.url
      ? controller.urlProbeUrl
      : controller.latencyProbeTarget.usesServerEndpoint
      ? '${server.address}:${server.port}'
      : controller.latencyProbeTarget.encode();
  final result = (() async {
    if (mode == NodeDiagnosticMode.tcp) {
      return (
        label: await controller.diagnoseServerTcp(server),
        detail: null as String?,
      );
    }
    final probe = await controller.diagnoseServerUrl(server);
    return (label: probe.label, detail: probe.detail);
  })();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: FutureBuilder<({String label, String? detail})>(
        future: result,
        builder: (context, snapshot) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(server.name),
            const SizedBox(height: 8),
            SelectableText(target),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else ...[
              Text(
                snapshot.data?.label ?? 'ERR',
                key: const ValueKey('node-diagnostic-result'),
              ),
              if (snapshot.data?.detail != null) ...[
                const SizedBox(height: 8),
                Text(snapshot.data!.detail!),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.done),
        ),
      ],
    ),
  );
}
