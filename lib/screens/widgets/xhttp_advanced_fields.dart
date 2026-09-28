import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class XhttpAdvancedFields extends StatelessWidget {
  const XhttpAdvancedFields({
    super.key,
    required this.enabled,
    required this.mode,
    required this.onModeChanged,
    required this.obfsEnabled,
    required this.onObfsEnabledChanged,
    required this.paddingPlacement,
    required this.onPaddingPlacementChanged,
    required this.paddingMethod,
    required this.onPaddingMethodChanged,
    required this.sessionIDPlacement,
    required this.onSessionIDPlacementChanged,
    required this.seqPlacement,
    required this.onSeqPlacementChanged,
    required this.paddingKeyController,
    required this.paddingHeaderController,
    required this.paddingBytesController,
    required this.sessionIDKeyController,
    required this.seqKeyController,
    required this.maxPostController,
    required this.minIntervalController,
    required this.onApplyCdnWafPreset,
  });

  final bool enabled;
  final String mode;
  final ValueChanged<String> onModeChanged;
  final bool obfsEnabled;
  final ValueChanged<bool> onObfsEnabledChanged;
  final String paddingPlacement;
  final ValueChanged<String> onPaddingPlacementChanged;
  final String paddingMethod;
  final ValueChanged<String> onPaddingMethodChanged;
  final String sessionIDPlacement;
  final ValueChanged<String> onSessionIDPlacementChanged;
  final String seqPlacement;
  final ValueChanged<String> onSeqPlacementChanged;
  final TextEditingController paddingKeyController;
  final TextEditingController paddingHeaderController;
  final TextEditingController paddingBytesController;
  final TextEditingController sessionIDKeyController;
  final TextEditingController seqKeyController;
  final TextEditingController maxPostController;
  final TextEditingController minIntervalController;
  final VoidCallback onApplyCdnWafPreset;

  static const modeOptions = <String>[
    '',
    'stream-up',
    'packet-up',
    'stream-one',
  ];
  static const paddingPlacementOptions = <String>[
    '',
    'query',
    'header',
    'cookie',
    'query-in-header',
  ];
  static const metadataPlacementOptions = <String>[
    '',
    'path',
    'query',
    'header',
    'cookie',
  ];
  static const paddingMethodOptions = <String>['', 'repeat-x', 'tokenish'];
  static const cdnWafPreset = (
    xPaddingObfsMode: true,
    xPaddingPlacement: 'query-in-header',
    xPaddingHeader: 'Referer',
    xPaddingKey: 'v',
    xPaddingMethod: 'tokenish',
    xPaddingBytes: '100-1000',
    sessionIDPlacement: 'query',
    sessionIDKey: 'sid',
    seqPlacement: 'query',
    seqKey: 'n',
  );

  static final RegExp _httpToken = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  static bool isValidHttpToken(String value) =>
      value.isNotEmpty && _httpToken.hasMatch(value);

  static bool isValidPositiveRange(String value) {
    final match = RegExp(r'^(\d+)(?:-(\d+))?$').firstMatch(value.trim());
    if (match == null) return false;
    final from = int.tryParse(match.group(1)!);
    final to = int.tryParse(match.group(2) ?? match.group(1)!);
    return from != null &&
        to != null &&
        from > 0 &&
        to > 0 &&
        from <= to &&
        to <= 0x7fffffff;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.editServerXhttpSubheading,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _dropdown(
          context: context,
          value: mode,
          options: _withCurrent(modeOptions, mode),
          label: l.editServerXhttpModeLabel,
          helper: l.editServerXhttpModeHelper,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 14),
        _textField(
          controller: paddingBytesController,
          label: l.editServerXhttpPaddingLabel,
          helper: l.editServerXhttpPaddingHelper,
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) return null;
            return isValidPositiveRange(trimmed)
                ? null
                : l.editServerXhttpRangeInvalid;
          },
        ),
        const SizedBox(height: 14),
        _textField(
          controller: maxPostController,
          label: l.editServerXhttpMaxPostLabel,
          helper: l.editServerXhttpMaxPostHelper,
        ),
        const SizedBox(height: 14),
        _textField(
          controller: minIntervalController,
          label: l.editServerXhttpMinIntervalLabel,
          helper: l.editServerXhttpMinIntervalHelper,
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          key: const ValueKey('xhttp-obfs-switch'),
          value: obfsEnabled,
          onChanged: enabled ? onObfsEnabledChanged : null,
          title: Text(l.editServerXhttpObfsTitle),
          subtitle: Text(l.editServerXhttpObfsHelper),
          contentPadding: EdgeInsets.zero,
        ),
        if (obfsEnabled) ...[
          const SizedBox(height: 8),
          _dropdown(
            context: context,
            value: paddingPlacement,
            options: _withCurrent(paddingPlacementOptions, paddingPlacement),
            label: l.editServerXhttpPaddingPlacementLabel,
            onChanged: onPaddingPlacementChanged,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: paddingKeyController,
            label: l.editServerXhttpPaddingKeyLabel,
            validator: (value) => _keyValidator(
              value,
              required: const {
                'query',
                'cookie',
                'query-in-header',
              }.contains(paddingPlacement),
              l: l,
            ),
          ),
          const SizedBox(height: 14),
          _textField(
            controller: paddingHeaderController,
            label: l.editServerXhttpPaddingHeaderLabel,
            validator: (value) => _keyValidator(
              value,
              required: const {
                'header',
                'query-in-header',
              }.contains(paddingPlacement),
              l: l,
            ),
          ),
          const SizedBox(height: 14),
          _dropdown(
            context: context,
            value: paddingMethod,
            options: _withCurrent(paddingMethodOptions, paddingMethod),
            label: l.editServerXhttpPaddingMethodLabel,
            onChanged: onPaddingMethodChanged,
          ),
        ],
        const SizedBox(height: 16),
        _dropdown(
          context: context,
          value: sessionIDPlacement,
          options: _withCurrent(metadataPlacementOptions, sessionIDPlacement),
          label: l.editServerXhttpSessionPlacementLabel,
          onChanged: onSessionIDPlacementChanged,
        ),
        const SizedBox(height: 14),
        _textField(
          controller: sessionIDKeyController,
          label: l.editServerXhttpSessionKeyLabel,
          validator: (value) => _keyValidator(
            value,
            required:
                sessionIDPlacement.isNotEmpty && sessionIDPlacement != 'path',
            l: l,
          ),
        ),
        const SizedBox(height: 14),
        _dropdown(
          context: context,
          value: seqPlacement,
          options: _withCurrent(metadataPlacementOptions, seqPlacement),
          label: l.editServerXhttpSeqPlacementLabel,
          onChanged: onSeqPlacementChanged,
        ),
        const SizedBox(height: 14),
        _textField(
          controller: seqKeyController,
          label: l.editServerXhttpSeqKeyLabel,
          validator: (value) => _keyValidator(
            value,
            required: seqPlacement.isNotEmpty && seqPlacement != 'path',
            l: l,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('xhttp-cdn-waf-preset'),
          onPressed: enabled ? onApplyCdnWafPreset : null,
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: Text(l.editServerXhttpCdnWafPreset),
        ),
      ],
    );
  }

  String? _keyValidator(
    String? value, {
    required bool required,
    required AppLocalizations l,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? l.editServerXhttpValueRequired : null;
    }
    return isValidHttpToken(trimmed) ? null : l.editServerXhttpTokenInvalid;
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? helper,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    enabled: enabled,
    autocorrect: false,
    enableSuggestions: false,
    style: const TextStyle(fontFamily: 'monospace'),
    decoration: InputDecoration(labelText: label, helperText: helper),
    validator: validator,
  );

  Widget _dropdown({
    required BuildContext context,
    required String value,
    required List<String> options,
    required String label,
    required ValueChanged<String> onChanged,
    String? helper,
  }) {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label, helperText: helper),
      items: options
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item.isEmpty ? l.editServerXhttpStockDefault : item,
                style: TextStyle(fontFamily: item.isEmpty ? null : 'monospace'),
              ),
            ),
          )
          .toList(growable: false),
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }

  static List<String> _withCurrent(List<String> values, String current) {
    if (current.isEmpty || values.contains(current)) return values;
    return [...values, current];
  }
}
