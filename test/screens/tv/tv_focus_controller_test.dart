import 'package:flutter_test/flutter_test.dart';
import 'package:voidlex/screens/tv/tv_focus_controller.dart';

void main() {
  group('TvFocusController', () {
    test('starts on the hub at row 0', () {
      final c = TvFocusController(listLength: 6);
      expect(c.column, TvFocusColumn.hub);
      expect(c.row, 0);
      expect(c.isOverlayOpen, isFalse);
    });

    test('arrowRight from hub jumps into the list when there are nodes', () {
      final c = TvFocusController(listLength: 4);
      c.moveRight();
      expect(c.column, TvFocusColumn.list);
      expect(c.row, 0);
    });

    test('arrowRight from hub is a no-op when the list is empty', () {
      final c = TvFocusController(listLength: 0);
      c.moveRight();
      expect(c.column, TvFocusColumn.hub);
      expect(c.row, 0);
    });

    test('arrowLeft from list returns to the hub', () {
      final c = TvFocusController(listLength: 3);
      c.moveRight();
      c.moveDown();
      expect(c.column, TvFocusColumn.list);
      expect(c.row, 1);
      c.moveLeft();
      expect(c.column, TvFocusColumn.hub);
      expect(c.row, 0);
    });

    test('arrowDown/Up walks the list within bounds', () {
      final c = TvFocusController(listLength: 3);
      c.moveRight();
      c.moveDown();
      c.moveDown();
      c.moveDown(); // would overflow
      expect(c.row, 2);
      c.moveUp();
      c.moveUp();
      c.moveUp(); // would underflow
      expect(c.row, 0);
    });

    test('arrowDown from hub enters the side rail at SPLIT', () {
      final c = TvFocusController(listLength: 2);
      c.moveDown();
      expect(c.column, TvFocusColumn.side);
      expect(c.row, 0);
    });

    test(
      'arrowRight inside a four-item side rail walks cards then enters list',
      () {
      final c = TvFocusController(listLength: 1, sideRailLength: 4);
      c.moveDown(); // hub -> side[0]
      c.moveRight();
      expect(c.row, 1);
      c.moveRight();
      expect(c.row, 2);
      c.moveRight();
      expect(c.row, 3);
      c.moveRight(); // settings -> list
      expect(c.column, TvFocusColumn.list);
      expect(c.row, 0);
    });

    test('arrowUp from the side rail returns to the hub', () {
      final c = TvFocusController(listLength: 1);
      c.moveDown();
      c.moveRight();
      c.moveUp();
      expect(c.column, TvFocusColumn.hub);
      expect(c.row, 0);
    });

    test('updateListLength clamps focus when list shrinks', () {
      final c = TvFocusController(listLength: 5);
      c.moveRight();
      c.moveDown();
      c.moveDown();
      c.moveDown();
      expect(c.row, 3);
      c.updateListLength(2);
      expect(c.row, 1);
    });

    test('updateListLength to 0 evacuates focus to the hub', () {
      final c = TvFocusController(listLength: 2);
      c.moveRight();
      c.updateListLength(0);
      expect(c.column, TvFocusColumn.hub);
      expect(c.row, 0);
    });

    test('opening an overlay disables main focus and tracks overlay row', () {
      final c = TvFocusController(listLength: 4);
      c.openOverlay(TvOverlay.subscriptions, length: 3, initialRow: 1);
      expect(c.isOverlayOpen, isTrue);
      expect(c.overlayRow, 1);
      expect(c.isFocused(TvFocusColumn.hub, 0), isFalse);
      c.moveDown();
      expect(c.overlayRow, 2);
      c.moveDown(); // clamped
      expect(c.overlayRow, 2);
      c.moveUp();
      expect(c.overlayRow, 1);
      c.closeOverlay();
      expect(c.isOverlayOpen, isFalse);
    });
  });
}
