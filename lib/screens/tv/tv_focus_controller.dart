import 'package:flutter/foundation.dart';

/// Logical focus columns for the TV home screen.
///
/// The design treats focus as a coordinate `(col, row)` rather than as a
/// "closest neighbour" graph, so we model it explicitly instead of
/// relying on `FocusTraversalPolicy`.
enum TvFocusColumn {
  /// The triangle CONNECT hub on the left panel.
  hub,

  /// The action cards under the hub.
  side,

  /// The node list rail on the right panel.
  list,
}

/// Which modal overlay (if any) is currently up.
enum TvOverlay { none, subscriptions, preset }

/// Pure-logic focus state machine driven by D-pad shortcuts. The widget
/// tree reads `(column, row)` and `overlay` and rebuilds — no widget owns
/// focus directly, which keeps the navigation rules in one auditable
/// place and makes them trivial to unit-test.
///
/// Range invariants:
///   * `column == hub` keeps `row` at 0.
///   * `column == side` clamps `row` to `sideRailLength`.
///   * `column == list` clamps `row` to `listLength`; when the list is empty
///     the controller falls back to `hub`.
class TvFocusController extends ChangeNotifier {
  TvFocusController({int listLength = 0, this.sideRailLength = 3})
    : _listLength = listLength;

  TvFocusColumn _column = TvFocusColumn.hub;
  int _row = 0;
  TvOverlay _overlay = TvOverlay.none;
  int _overlayRow = 0;
  int _overlayLength = 0;

  int _listLength;
  final int sideRailLength;

  TvFocusColumn get column => _column;
  int get row => _row;
  TvOverlay get overlay => _overlay;
  int get overlayRow => _overlayRow;
  int get listLength => _listLength;

  bool get isOverlayOpen => _overlay != TvOverlay.none;

  bool isFocused(TvFocusColumn col, int row) {
    if (isOverlayOpen) return false;
    return _column == col && _row == row;
  }

  bool isOverlayFocused(int row) => isOverlayOpen && _overlayRow == row;

  void updateListLength(int length) {
    if (length == _listLength) return;
    _listLength = length;
    // Clamp focus row if the list shrank under us.
    if (_column == TvFocusColumn.list) {
      if (length == 0) {
        _column = TvFocusColumn.hub;
        _row = 0;
        notifyListeners();
        return;
      }
      if (_row >= length) {
        _row = length - 1;
        notifyListeners();
      }
    }
  }

  void moveLeft() {
    if (isOverlayOpen) return;
    switch (_column) {
      case TvFocusColumn.list:
        _column = TvFocusColumn.hub;
        _row = 0;
        notifyListeners();
        break;
      case TvFocusColumn.side:
        if (_row > 0) {
          _row -= 1;
          notifyListeners();
        }
        break;
      case TvFocusColumn.hub:
        // Already at the leftmost column — swallow.
        break;
    }
  }

  void moveRight() {
    if (isOverlayOpen) return;
    switch (_column) {
      case TvFocusColumn.hub:
        if (_listLength == 0) return;
        _column = TvFocusColumn.list;
        _row = 0;
        notifyListeners();
        break;
      case TvFocusColumn.side:
        if (_row < sideRailLength - 1) {
          _row += 1;
          notifyListeners();
          break;
        }
        // Hand off to node list only from the last side action (Settings).
        if (_listLength == 0) return;
        _column = TvFocusColumn.list;
        _row = 0;
        notifyListeners();
        break;
      case TvFocusColumn.list:
        // Already at the rightmost column — swallow.
        break;
    }
  }

  void moveUp() {
    if (isOverlayOpen) {
      // Overlays stack rows vertically; let the overlay clamp itself.
      if (_overlayRow > 0) {
        _overlayRow -= 1;
        notifyListeners();
      }
      return;
    }
    switch (_column) {
      case TvFocusColumn.side:
        _column = TvFocusColumn.hub;
        _row = 0;
        notifyListeners();
        break;
      case TvFocusColumn.list:
        if (_row > 0) {
          _row -= 1;
          notifyListeners();
        }
        break;
      case TvFocusColumn.hub:
        break;
    }
  }

  void moveDown() {
    if (isOverlayOpen) {
      if (_overlayRow < _overlayLength - 1) {
        _overlayRow += 1;
        notifyListeners();
      }
      return;
    }
    switch (_column) {
      case TvFocusColumn.hub:
        _column = TvFocusColumn.side;
        _row = 0;
        notifyListeners();
        break;
      case TvFocusColumn.list:
        if (_row < _listLength - 1) {
          _row += 1;
          notifyListeners();
        }
        break;
      case TvFocusColumn.side:
        break;
    }
  }

  void openOverlay(TvOverlay overlay, {int length = 0, int initialRow = 0}) {
    if (overlay == TvOverlay.none) {
      closeOverlay();
      return;
    }
    _overlay = overlay;
    _overlayLength = length;
    _overlayRow = length == 0 ? 0 : initialRow.clamp(0, length - 1);
    notifyListeners();
  }

  void updateOverlayLength(int length) {
    if (_overlay == TvOverlay.none) return;
    if (length == _overlayLength) return;
    _overlayLength = length;
    if (length == 0) {
      _overlayRow = 0;
    } else if (_overlayRow >= length) {
      _overlayRow = length - 1;
    }
    notifyListeners();
  }

  void closeOverlay() {
    if (_overlay == TvOverlay.none) return;
    _overlay = TvOverlay.none;
    _overlayRow = 0;
    _overlayLength = 0;
    notifyListeners();
  }

  /// Forces the focused cell directly. Used when external state changes
  /// (e.g. tap-fallback on a phone in landscape) need to keep the focus
  /// state coherent with the rebuilt tree.
  void setFocus(TvFocusColumn column, {int row = 0}) {
    final clampedRow = switch (column) {
      TvFocusColumn.hub => 0,
      TvFocusColumn.side => row.clamp(0, sideRailLength - 1),
      TvFocusColumn.list =>
        _listLength == 0 ? 0 : row.clamp(0, _listLength - 1),
    };
    if (_column == column && _row == clampedRow) return;
    _column = column;
    _row = clampedRow;
    notifyListeners();
  }
}
