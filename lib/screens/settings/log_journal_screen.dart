part of '../settings_screen.dart';

class _LogJournalScreen extends StatefulWidget {
  const _LogJournalScreen({required this.controller});

  final VpnController controller;

  @override
  State<_LogJournalScreen> createState() => _LogJournalScreenState();
}

class _LogJournalScreenState extends State<_LogJournalScreen> {
  static const _bridge = AppLogBridge();

  String _logs = '';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final logs = await _bridge.read(
        levels: widget.controller.logLevels,
        retention: widget.controller.logRetention,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logs = AppLocalizations.of(context).journalLoadFailed(e.toString());
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyLogs() async {
    final l = AppLocalizations.of(context);
    if (_logs.trim().isEmpty) {
      _showMessage(l.logsNoCopyText);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _logs));
    _showMessage(l.logsCopiedText);
  }

  Future<void> _exportLogs() async {
    final l = AppLocalizations.of(context);
    if (_logs.trim().isEmpty) {
      _showMessage(l.logsNoExportText);
      return;
    }
    setState(() => _busy = true);
    try {
      final exported = await _bridge.export(
        content: _logs,
        fileName: _defaultExportName(),
      );
      if (!mounted) return;
      if (exported) {
        _showMessage(l.logsExportedText);
      }
    } catch (e) {
      _showMessage(l.journalExportFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearLogs() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _bridge.clear();
      if (!mounted) return;
      setState(() => _logs = '');
      _showMessage(l.logsClearedText);
    } catch (e) {
      _showMessage(l.journalClearFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _defaultExportName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${now.year}${two(now.month)}${two(now.day)}';
    final time = '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'voidtunnel-logs-$date-$time.txt';
  }

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    final l = AppLocalizations.of(context);
    final content = _logs.trim().isEmpty ? l.logsEmptyText : _logs;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          l.journalAppBarTitle,
          style: VoidType.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: t.fg1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l.logsCopyTooltip,
            onPressed: _loading || _busy ? null : _copyLogs,
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            tooltip: l.logsExportTooltip,
            onPressed: _loading || _busy ? null : _exportLogs,
            icon: const Icon(Icons.file_download_rounded),
          ),
          IconButton(
            tooltip: l.logsClearTooltip,
            onPressed: _loading || _busy ? null : _clearLogs,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: t.fg2,
                  ),
                ),
              )
            : Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: SelectableText(
                    content,
                    style: VoidType.mono(
                      fontSize: 11,
                      color: t.fg2,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
