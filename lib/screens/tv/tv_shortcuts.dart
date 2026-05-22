import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intent emitted when the user moves focus with the D-pad.
class TvMoveIntent extends Intent {
  const TvMoveIntent(this.direction);
  final TraversalDirection direction;
}

/// Intent emitted by OK / Enter / Space.
class TvActivateIntent extends Intent {
  const TvActivateIntent();
}

/// Intent emitted by Back / Escape.
class TvBackIntent extends Intent {
  const TvBackIntent();
}

/// Intent emitted by the MENU button (or `M` on the keyboard).
class TvMenuIntent extends Intent {
  const TvMenuIntent();
}

/// Intent emitted by media play/pause (or `P`) — triggers a ping scan.
class TvScanIntent extends Intent {
  const TvScanIntent();
}

/// Key-binding map for the TV home screen. Wired at the [Shortcuts]
/// boundary so the underlying widgets stay D-pad agnostic.
Map<ShortcutActivator, Intent> tvShortcuts() {
  return <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const TvMoveIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const TvMoveIntent(TraversalDirection.down),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const TvMoveIntent(TraversalDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const TvMoveIntent(TraversalDirection.right),
    const SingleActivator(LogicalKeyboardKey.enter): const TvActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const TvActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const TvActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.select): const TvActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonA):
        const TvActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const TvBackIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace): const TvBackIntent(),
    const SingleActivator(LogicalKeyboardKey.goBack): const TvBackIntent(),
    const SingleActivator(LogicalKeyboardKey.contextMenu): const TvMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.keyM): const TvMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.f10): const TvMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
        const TvScanIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaPlay): const TvScanIntent(),
    const SingleActivator(LogicalKeyboardKey.keyP): const TvScanIntent(),
  };
}
