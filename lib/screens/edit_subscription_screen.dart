import 'package:flutter/material.dart';

import '../core/models/server_subscription.dart';
import '../core/subscription_provider_settings.dart';
import '../core/vpn_controller.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'widgets/orientation_gate.dart';

class EditSubscriptionScreen extends StatefulWidget {
  const EditSubscriptionScreen({
    super.key,
    required this.controller,
    required this.subscription,
  });

  final VpnController controller;
  final ServerSubscription subscription;

  @override
  State<EditSubscriptionScreen> createState() => _EditSubscriptionScreenState();
}

class _EditSubscriptionScreenState extends State<EditSubscriptionScreen> {
  static const _defaultUpdateIntervalSelection = 'default';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late String _updateIntervalSelection;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isBusy => _isSaving || _isDeleting;

  SubscriptionUpdateInterval? get _updateIntervalOverride {
    if (_updateIntervalSelection == _defaultUpdateIntervalSelection) {
      return null;
    }
    return SubscriptionUpdateInterval.tryParse(_updateIntervalSelection);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subscription.name);
    _urlController = TextEditingController(text: widget.subscription.url);
    _updateIntervalSelection =
        widget.subscription.updateIntervalOverride?.name ??
        _defaultUpdateIntervalSelection;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSaving = true);
    final error = await widget.controller.updateSubscription(
      id: widget.subscription.id,
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      updateIntervalOverride: _updateIntervalOverride,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      _showMessage(error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        final d = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(d.homeDeleteSubscriptionTitle(widget.subscription.name)),
          content: Text(d.homeDeleteSubscriptionBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(d.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.error,
                foregroundColor: dialogTheme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(d.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    await widget.controller.deleteSubscription(widget.subscription.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return OrientationGate(
      controller: widget.controller,
      child: Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(l.editSubscriptionTitle),
              actions: [
                IconButton(
                  tooltip: l.editSubscriptionDeleteTooltip,
                  onPressed: _isBusy ? null : _confirmAndDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: _isBusy
                        ? theme.disabledColor
                        : theme.colorScheme.error,
                  ),
                ),
                IconButton(
                  tooltip: l.editSubscriptionSaveTooltip,
                  onPressed: _isBusy ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                ),
              ],
            ),
          ];
        },
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: _SectionCard(
              title: l.editSubscriptionSectionTitle,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_isBusy,
                  decoration: InputDecoration(
                    labelText: l.routingRuleNameLabel,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l.subscriptionNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _urlController,
                  enabled: !_isBusy,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(labelText: l.editServerCopyAsUrl),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    final uri = Uri.tryParse(raw);
                    if (uri == null ||
                        uri.host.isEmpty ||
                        (uri.scheme != 'http' && uri.scheme != 'https')) {
                      return l.subscriptionInvalidUrl;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _updateIntervalSelection,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.editSubscriptionAutoUpdateIntervalLabel,
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: _defaultUpdateIntervalSelection,
                      child: Text(l.subscriptionIntervalDefault),
                    ),
                    for (final interval in SubscriptionUpdateInterval.values)
                      DropdownMenuItem<String>(
                        value: interval.name,
                        child: Text(
                          _subscriptionUpdateIntervalLabel(l, interval),
                        ),
                      ),
                  ],
                  onChanged: _isBusy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _updateIntervalSelection = value);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

String _subscriptionUpdateIntervalLabel(
  AppLocalizations l,
  SubscriptionUpdateInterval interval,
) {
  switch (interval) {
    case SubscriptionUpdateInterval.oneHour:
      return l.subscriptionIntervalOneHour;
    case SubscriptionUpdateInterval.threeHours:
      return l.subscriptionIntervalThreeHours;
    case SubscriptionUpdateInterval.sixHours:
      return l.subscriptionIntervalSixHours;
    case SubscriptionUpdateInterval.twelveHours:
      return l.subscriptionIntervalTwelveHours;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = VoidTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
