import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/server_config.dart';
import '../../core/server_importer.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';

enum JsonValidationStatus {
  empty,
  syntaxError,
  incomplete,
  valid,
}

class JsonValidationResult {
  const JsonValidationResult({
    required this.status,
    this.message,
    this.errorLine,
    this.errorColumn,
    this.errorOffset,
    this.parsedServer,
  });

  final JsonValidationStatus status;
  final String? message;
  final int? errorLine; // 1-indexed
  final int? errorColumn; // 1-indexed
  final int? errorOffset;
  final ServerConfig? parsedServer;

  bool get isValid => status == JsonValidationStatus.valid;
  bool get hasSyntaxError => status == JsonValidationStatus.syntaxError;
  bool get isIncomplete => status == JsonValidationStatus.incomplete;
}

/// Validates raw JSON string:
/// 1. Checks JSON syntax (`json.decode`).
/// 2. If invalid syntax, extracts exact 1-indexed line and column.
/// 3. If syntax is valid, validates that it parses into a supported [ServerConfig].
JsonValidationResult validateJsonConfig(String rawText, AppLocalizations l) {
  final trimmed = rawText.trim();
  if (trimmed.isEmpty) {
    return const JsonValidationResult(status: JsonValidationStatus.empty);
  }

  try {
    json.decode(rawText);
  } on FormatException catch (e) {
    final offset = (e.offset ?? 0).clamp(0, rawText.length);
    var line = 1;
    var column = 1;
    var lineStart = 0;
    for (var i = 0; i < offset; i++) {
      if (rawText[i] == '\n') {
        line++;
        lineStart = i + 1;
      }
    }
    column = offset - lineStart + 1;
    final cleanMessage = _cleanJsonErrorMessage(e.message);
    final formattedMessage = l.jsonEditorSyntaxError(line, column, cleanMessage);
    return JsonValidationResult(
      status: JsonValidationStatus.syntaxError,
      message: formattedMessage,
      errorLine: line,
      errorColumn: column,
      errorOffset: offset,
    );
  } catch (e) {
    return JsonValidationResult(
      status: JsonValidationStatus.syntaxError,
      message: e.toString(),
      errorLine: 1,
      errorColumn: 1,
      errorOffset: 0,
    );
  }

  final importResult = const ServerImporter().parse(rawText);
  if (importResult.isOk && importResult.configs.length == 1) {
    final server = importResult.configs.single;
    final protocolName = server.serverProtocol.wireName.toUpperCase();
    final details =
        '${server.name} ($protocolName · ${server.address}:${server.port})';
    return JsonValidationResult(
      status: JsonValidationStatus.valid,
      message: l.jsonEditorValid(details),
      parsedServer: server,
    );
  }

  return JsonValidationResult(
    status: JsonValidationStatus.incomplete,
    message: l.jsonEditorIncomplete,
  );
}

String _cleanJsonErrorMessage(String raw) {
  final atIndex = raw.indexOf(' (at character');
  if (atIndex != -1) {
    return raw.substring(0, atIndex).trim();
  }
  return raw.trim();
}

class LinedJsonEditor extends StatefulWidget {
  const LinedJsonEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.externalError,
    this.textFieldKey = const ValueKey('edit-server-json-editor'),
  });

  final TextEditingController controller;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String? externalError;
  final Key textFieldKey;

  @override
  State<LinedJsonEditor> createState() => _LinedJsonEditorState();
}

class _LinedJsonEditorState extends State<LinedJsonEditor> {
  static const double _fontSize = 13.0;
  static const double _lineHeightMultiplier = 1.5;
  static const double _lineHeight = 20.0;

  late final ScrollController _verticalScroll;
  late final ScrollController _horizontalScroll;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  bool _wordWrap = false;
  int _activeLine = 1;

  @override
  void initState() {
    super.initState();
    _verticalScroll = ScrollController();
    _horizontalScroll = ScrollController();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    widget.controller.addListener(_handleControllerChange);
    _updateActiveLine();
  }

  @override
  void didUpdateWidget(covariant LinedJsonEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _updateActiveLine();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (_ownsFocusNode) {
        _focusNode.dispose();
        _ownsFocusNode = false;
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleControllerChange() {
    _updateActiveLine();
  }

  void _updateActiveLine() {
    final text = widget.controller.text;
    final offset = widget.controller.selection.baseOffset;
    if (offset < 0) {
      if (_activeLine != 1) setState(() => _activeLine = 1);
      return;
    }
    final clamped = offset.clamp(0, text.length);
    var line = 1;
    for (var i = 0; i < clamped; i++) {
      if (text[i] == '\n') line++;
    }
    if (_activeLine != line) {
      setState(() => _activeLine = line);
    } else {
      setState(() {});
    }
  }

  void _formatJson() {
    try {
      final decoded = json.decode(widget.controller.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: const TextSelection.collapsed(offset: 0),
      );
      widget.onChanged?.call(formatted);
    } catch (_) {
      // Syntax error prevents formatting
    }
  }

  void _jumpToError(int? offset, int? line) {
    if (offset != null && offset <= widget.controller.text.length) {
      widget.controller.selection = TextSelection.collapsed(offset: offset);
      _focusNode.requestFocus();
    }
    if (line != null && _verticalScroll.hasClients) {
      final targetScroll = ((line - 1) * _lineHeight) - 40.0;
      _verticalScroll.animateTo(
        targetScroll.clamp(0.0, _verticalScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final validation = validateJsonConfig(widget.controller.text, l);

    final text = widget.controller.text;
    final lines = text.split('\n');
    final totalLines = math.max(lines.length, 1);

    // Gutter width adapts to line count digits
    final digits = totalLines.toString().length;
    final gutterWidth = math.max(38.0, (digits * 9.0) + 18.0);

    const textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
      height: _lineHeightMultiplier,
    );
    const strutStyle = StrutStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
      height: _lineHeightMultiplier,
      forceStrutHeight: true,
    );

    final totalHeight = math.max(
      totalLines * _lineHeight,
      24.0 * _lineHeight,
    );

    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: validation.hasSyntaxError || widget.externalError != null
              ? t.error.withValues(alpha: 0.8)
              : t.border,
          width: validation.hasSyntaxError || widget.externalError != null
              ? 1.5
              : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toolbar
          _buildToolbar(t, l, validation, totalLines),
          const Divider(height: 1, thickness: 1),

          // Main Editor Viewport with synchronized gutter & horizontal scroll
          SizedBox(
            height: 480,
            child: SingleChildScrollView(
              controller: _verticalScroll,
              scrollDirection: Axis.vertical,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pinned Gutter (Numbers column)
                  Container(
                    width: gutterWidth,
                    height: totalHeight,
                    color: t.surfaceAlt,
                    child: _GutterNumbers(
                      totalLines: totalLines,
                      lineHeight: _lineHeight,
                      activeLine: _activeLine,
                      errorLine: validation.errorLine,
                      tokens: t,
                    ),
                  ),

                  // Vertical divider
                  Container(
                    width: 1,
                    height: totalHeight,
                    color: t.borderStrong,
                  ),

                  // Code Text Area
                  Expanded(
                    child: _wordWrap
                        ? _buildWrappedTextArea(
                            t: t,
                            textStyle: textStyle,
                            strutStyle: strutStyle,
                            totalHeight: totalHeight,
                            totalLines: totalLines,
                            errorLine: validation.errorLine,
                          )
                        : _buildScrollableTextArea(
                            t: t,
                            textStyle: textStyle,
                            strutStyle: strutStyle,
                            totalHeight: totalHeight,
                            totalLines: totalLines,
                            lines: lines,
                            errorLine: validation.errorLine,
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Footer / Status banner
          _buildStatusFooter(t, l, validation),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    VoidTokens t,
    AppLocalizations l,
    JsonValidationResult validation,
    int totalLines,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: t.surfaceAlt,
      child: Row(
        children: [
          Text(
            'JSON',
            style: VoidType.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: t.fg2,
            ),
          ),
          const SizedBox(width: 12),

          // Validation Badge
          Expanded(child: _buildValidationBadge(t, l, validation)),

          // Lines counter
          Text(
            l.jsonEditorLinesCount(totalLines),
            style: VoidType.mono(fontSize: 11, color: t.fg3),
          ),
          const SizedBox(width: 8),

          // Format JSON button
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            tooltip: l.jsonEditorFormatTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: validation.hasSyntaxError ? t.fg3 : t.fg1,
            onPressed: widget.enabled && !validation.hasSyntaxError
                ? _formatJson
                : null,
          ),

          // Word wrap toggle button
          IconButton(
            icon: Icon(
              _wordWrap ? Icons.wrap_text_rounded : Icons.notes_rounded,
              size: 18,
            ),
            tooltip: l.jsonEditorWrapTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: _wordWrap ? t.accent : t.fg2,
            onPressed: () => setState(() => _wordWrap = !_wordWrap),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBadge(
    VoidTokens t,
    AppLocalizations l,
    JsonValidationResult validation,
  ) {
    if (validation.hasSyntaxError) {
      return InkWell(
        onTap: () => _jumpToError(validation.errorOffset, validation.errorLine),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: t.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 14, color: t.error),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'L${validation.errorLine}:C${validation.errorColumn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VoidType.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: t.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (validation.isValid) {
      final proto =
          validation.parsedServer?.serverProtocol.wireName.toUpperCase() ??
          'VALID';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.ok.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.ok.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 13, color: t.ok),
                const SizedBox(width: 5),
                Text(
                  proto,
                  style: VoidType.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: t.ok,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (validation.isIncomplete) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.warn.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.warn.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 13, color: t.warn),
                const SizedBox(width: 5),
                Text(
                  'JSON',
                  style: VoidType.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: t.warn,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildScrollableTextArea({
    required VoidTokens t,
    required TextStyle textStyle,
    required StrutStyle strutStyle,
    required double totalHeight,
    required int totalLines,
    required List<String> lines,
    required int? errorLine,
  }) {
    final maxLineLen = lines.fold<int>(0, (m, l) => math.max(m, l.length));
    final contentWidth = math.max(800.0, (maxLineLen * 8.5) + 60.0);

    return SingleChildScrollView(
      controller: _horizontalScroll,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: contentWidth,
        height: totalHeight,
        child: Stack(
          children: [
            // Ruled lines painter background
            Positioned.fill(
              child: CustomPaint(
                painter: _RuledLinesPainter(
                  totalLines: totalLines,
                  lineHeight: _lineHeight,
                  errorLine: errorLine,
                  activeLine: _activeLine,
                  tokens: t,
                ),
              ),
            ),

            // TextField
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: TextField(
                  key: widget.textFieldKey,
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  style: textStyle.copyWith(color: t.fg1),
                  strutStyle: strutStyle,
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                  onChanged: (val) {
                    widget.onChanged?.call(val);
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrappedTextArea({
    required VoidTokens t,
    required TextStyle textStyle,
    required StrutStyle strutStyle,
    required double totalHeight,
    required int totalLines,
    required int? errorLine,
  }) {
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RuledLinesPainter(
                totalLines: totalLines,
                lineHeight: _lineHeight,
                errorLine: errorLine,
                activeLine: _activeLine,
                tokens: t,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: TextField(
                key: widget.textFieldKey,
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                style: textStyle.copyWith(color: t.fg1),
                strutStyle: strutStyle,
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
                onChanged: (val) {
                  widget.onChanged?.call(val);
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFooter(
    VoidTokens t,
    AppLocalizations l,
    JsonValidationResult validation,
  ) {
    final externalError = widget.externalError;
    final isError = validation.hasSyntaxError || externalError != null;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String message;

    if (externalError != null) {
      bgColor = t.error.withValues(alpha: 0.1);
      borderColor = t.error.withValues(alpha: 0.3);
      textColor = t.error;
      icon = Icons.error_outline_rounded;
      message = externalError;
    } else if (validation.hasSyntaxError) {
      bgColor = t.error.withValues(alpha: 0.1);
      borderColor = t.error.withValues(alpha: 0.3);
      textColor = t.error;
      icon = Icons.error_outline_rounded;
      message = validation.message ?? '';
    } else if (validation.isValid) {
      bgColor = t.surfaceAlt;
      borderColor = t.border;
      textColor = t.fg2;
      icon = Icons.check_circle_outline_rounded;
      message = validation.message ?? '';
    } else if (validation.isIncomplete) {
      bgColor = t.warn.withValues(alpha: 0.08);
      borderColor = t.warn.withValues(alpha: 0.25);
      textColor = t.warn;
      icon = Icons.warning_amber_rounded;
      message = validation.message ?? '';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: VoidType.mono(
                fontSize: 11,
                fontWeight: isError ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          if (validation.hasSyntaxError && validation.errorOffset != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () =>
                  _jumpToError(validation.errorOffset, validation.errorLine),
              child: Text(
                l.jsonEditorGoToError,
                style: VoidType.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GutterNumbers extends StatelessWidget {
  const _GutterNumbers({
    required this.totalLines,
    required this.lineHeight,
    required this.activeLine,
    required this.errorLine,
    required this.tokens,
  });

  final int totalLines;
  final double lineHeight;
  final int activeLine;
  final int? errorLine;
  final VoidTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(totalLines, (index) {
        final lineNum = index + 1;
        final isError = lineNum == errorLine;
        final isActive = lineNum == activeLine;

        final Color textColor;
        final FontWeight fontWeight;
        if (isError) {
          textColor = tokens.error;
          fontWeight = FontWeight.w700;
        } else if (isActive) {
          textColor = tokens.fg1;
          fontWeight = FontWeight.w600;
        } else {
          textColor = tokens.fg3;
          fontWeight = FontWeight.w400;
        }

        return Container(
          height: lineHeight,
          padding: const EdgeInsets.only(right: 8),
          alignment: Alignment.centerRight,
          color: isError
              ? tokens.error.withValues(alpha: 0.15)
              : (isActive ? tokens.fg1.withValues(alpha: 0.04) : null),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isError)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    Icons.error_rounded,
                    size: 11,
                    color: tokens.error,
                  ),
                ),
              Text(
                '$lineNum',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.0,
                  color: textColor,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _RuledLinesPainter extends CustomPainter {
  const _RuledLinesPainter({
    required this.totalLines,
    required this.lineHeight,
    required this.errorLine,
    required this.activeLine,
    required this.tokens,
  });

  final int totalLines;
  final double lineHeight;
  final int? errorLine;
  final int activeLine;
  final VoidTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = tokens.border.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    final errorBgPaint = Paint()
      ..color = tokens.error.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    final errorBarPaint = Paint()
      ..color = tokens.error
      ..strokeWidth = 2.5;

    final activeBgPaint = Paint()
      ..color = tokens.fg1.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Draw active line highlight
    if (activeLine >= 1 && activeLine <= totalLines && activeLine != errorLine) {
      final y = (activeLine - 1) * lineHeight;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, lineHeight),
        activeBgPaint,
      );
    }

    // Draw error line highlight
    if (errorLine != null && errorLine! >= 1 && errorLine! <= totalLines) {
      final y = (errorLine! - 1) * lineHeight;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, lineHeight),
        errorBgPaint,
      );
      // Left vertical error accent bar
      canvas.drawLine(
        Offset(0, y),
        Offset(0, y + lineHeight),
        errorBarPaint,
      );
    }

    // Draw horizontal ruling lines
    for (var i = 1; i <= totalLines; i++) {
      final y = i * lineHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RuledLinesPainter oldDelegate) {
    return oldDelegate.totalLines != totalLines ||
        oldDelegate.errorLine != errorLine ||
        oldDelegate.activeLine != activeLine ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.tokens != tokens;
  }
}
