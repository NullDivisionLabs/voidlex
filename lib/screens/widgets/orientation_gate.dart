import 'package:flutter/material.dart';

import '../../core/tv_layout_preference.dart';
import '../../core/vpn_controller.dart';

/// Wraps a mobile-only route so it auto-pops to the home screen the
/// moment the device rotates into landscape while the user is in the
/// auto-rotate layout preference.
///
/// Per spec, screens that don't have a TV equivalent (server editor,
/// subscription editor, QR scanner, manual input) must hand the user
/// back to the home screen on rotation — the TV layout then takes over
/// at the home level via [OrientationBuilder] in `main.dart`.
///
/// Routes that DO have a TV analog (everything in `lib/screens/settings`)
/// adapt their chrome via `_useTvSettingsChrome(orientation: ...)` and
/// do not need this gate.
class OrientationGate extends StatefulWidget {
  const OrientationGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final VpnController controller;
  final Widget child;

  @override
  State<OrientationGate> createState() => _OrientationGateState();
}

class _OrientationGateState extends State<OrientationGate> {
  Orientation? _lastObserved;
  bool _popScheduled = false;

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    final previous = _lastObserved;
    _lastObserved = orientation;

    final shouldPop = previous != null &&
        previous != orientation &&
        orientation == Orientation.landscape &&
        widget.controller.repository.loadTvLayoutPreference() ==
            TvLayoutPreference.autoRotate;
    if (shouldPop && !_popScheduled) {
      _popScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route.isFirst);
      });
    }
    return widget.child;
  }
}
