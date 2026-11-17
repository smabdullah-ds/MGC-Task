// Flame's Component.add returns FutureOr and is fire-and-forget by design.
// ignore_for_file: discarded_futures

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:bazaar_sort/config/constants.dart';
import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/features/gameplay/board/board_layout.dart';
import 'package:bazaar_sort/features/gameplay/board/confetti.dart';
import 'package:bazaar_sort/features/gameplay/board/guide_hand.dart';
import 'package:bazaar_sort/features/gameplay/board/item_component.dart';
import 'package:bazaar_sort/features/gameplay/board/shelf_component.dart';
import 'package:bazaar_sort/features/gameplay/controller/board_event.dart';
import 'package:bazaar_sort/features/gameplay/controller/game_controller.dart';
import 'package:bazaar_sort/features/gameplay/skins/item_skin.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

/// The Flame layer: renders the controller's board and turns its events
/// into animations. It never changes game state itself — taps go back to
/// the controller as intents.
class BoardGame extends FlameGame {
  /// Creates the board renderer.
  new({
    required this.controller,
    required this.skin,
    required this.colorblind,
    this.guide = false,
  });

  /// Whether a pointing hand walks the player through solver moves
  /// (tutorial levels).
  final bool guide;

  GuideHand? _hand;
  Move? _guideMove;
  int _guideToken = 0;

  /// Source of truth.
  final GameController controller;

  /// Art.
  final ItemSkin skin;

  /// Colourblind mode getter (settings can change mid-level).
  final bool Function() colorblind;

  late BoardLayout _layout;
  final List<ShelfComponent> _shelves = [];
  final List<List<ItemComponent>> _stacks = [];
  StreamSubscription<BoardEvent>? _sub;
  int _lifted = -1;
  int _liftedCount = 0;
  Move? _hint;

  static double get _moveSeconds =>
      AppConstants.moveAnimation.inMilliseconds / 1000;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _rebuild(controller.board);
    _sub = controller.events.listen(_onEvent);
    unawaited(_updateGuide());
  }

  Future<void> _updateGuide() async {
    if (!guide) return;
    final token = ++_guideToken;
    final result = await controller.solve(controller.board);
    if (token != _guideToken || !isMounted) return;
    _guideMove = result.moves.isEmpty ? null : result.moves.first;
    _placeHand();
  }

  void _placeHand() {
    final move = _guideMove;
    if (!guide || move == null || controller.rules.isWon(controller.board)) {
      _hand?.removeFromParent();
      _hand = null;
      return;
    }
    final target = controller.selected == move.from ? move.to : move.from;
    if (target >= _layout.shelfRects.length) return;
    final hand = _hand ??= GuideHand(side: _layout.itemSize * 0.9);
    if (!hand.isMounted && hand.parent == null) add(hand);
    final rect = _layout.shelfRects[target];
    hand.pointAt(Vector2(rect.center.dx, rect.bottom - _layout.itemSize * 0.2));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _relayout();
  }

  @override
  void onRemove() {
    unawaited(_sub?.cancel());
    super.onRemove();
  }

  /// Current layout (tests and screenshot scenes).
  BoardLayout get layout => _layout;

  BoardLayout _computeLayout(BoardState board) => BoardLayout.compute(
    area: Size(size.x, size.y),
    shelfCount: board.shelfCount,
    capacity: board.capacity,
  );

  Vector2 _slotCenter(int shelf, int slot, {bool lifted = false}) {
    final r = _layout.itemRect(shelf, slot);
    return Vector2(
      r.center.dx,
      r.center.dy - (lifted ? _layout.liftHeight : 0),
    );
  }

  void _rebuild(BoardState board) {
    for (final s in _shelves) {
      s.removeFromParent();
    }
    for (final stack in _stacks) {
      for (final i in stack) {
        i.removeFromParent();
      }
    }
    _shelves.clear();
    _stacks.clear();
    _lifted = -1;
    _hint = null;
    _layout = _computeLayout(board);

    for (var s = 0; s < board.shelfCount; s++) {
      final shelf = ShelfComponent(
        index: s,
        rect: _layout.shelfRects[s],
        hitRect: _layout.hitRect(s),
        onTap: controller.tapShelf,
        onDropAt: _onDragEnd,
      );
      _shelves.add(shelf);
      add(shelf);
      final stack = <ItemComponent>[];
      final items = board.shelves[s].items;
      for (var slot = 0; slot < items.length; slot++) {
        final comp = ItemComponent(
          item: items[slot],
          skin: skin,
          colorblind: colorblind,
          center: _slotCenter(s, slot),
          side: _layout.itemSize,
        )..priority = 1;
        stack.add(comp);
        add(comp);
      }
      _stacks.add(stack);
    }
    _syncShelfStates(board);
  }

  void _relayout() {
    _layout = _computeLayout(controller.board);
    for (var s = 0; s < _shelves.length; s++) {
      _shelves[s].relayout(_layout.shelfRects[s], _layout.hitRect(s));
      for (var slot = 0; slot < _stacks[s].length; slot++) {
        _stacks[s][slot]
          ..size.setAll(_layout.itemSize)
          ..snapTo(
            _slotCenter(
              s,
              slot,
              lifted: s == _lifted && slot >= _stacks[s].length - _liftedCount,
            ),
          );
      }
    }
  }

  void _syncShelfStates(BoardState board) {
    final completed = board.completedCount;
    for (var s = 0; s < _shelves.length && s < board.shelfCount; s++) {
      _shelves[s]
        ..completed = board.isComplete(s)
        ..locksRemaining = math.max(0, board.shelves[s].unlockAfter - completed)
        ..hinted = _hint != null && (_hint!.from == s || _hint!.to == s);
      final items = board.shelves[s].items;
      final stack = _stacks[s];
      for (var i = 0; i < stack.length && i < items.length; i++) {
        stack[i].item = items[i];
      }
    }
  }

  void _onDragEnd(int from, Vector2 globalEnd) {
    final target = _layout.shelfAt(Offset(globalEnd.x, globalEnd.y));
    if (target != null && target != from && controller.selected == from) {
      controller.tapShelf(target);
    }
  }

  void _lift(int shelf) {
    _lower();
    final run = controller.rules.movableRun(controller.board, shelf);
    final stack = _stacks[shelf];
    for (var k = 0; k < run; k++) {
      final slot = stack.length - 1 - k;
      stack[slot].moveTo(
        _slotCenter(shelf, slot, lifted: true),
        duration: 0.12,
      );
    }
    _lifted = shelf;
    _liftedCount = run;
  }

  void _lower() {
    if (_lifted < 0 || _lifted >= _stacks.length) return;
    final stack = _stacks[_lifted];
    for (var slot = 0; slot < stack.length; slot++) {
      stack[slot].moveTo(_slotCenter(_lifted, slot), duration: 0.12);
    }
    _lifted = -1;
    _liftedCount = 0;
  }

  void _onEvent(BoardEvent event) {
    switch (event) {
      case ShelfSelected(:final shelf):
        _lift(shelf);
        _placeHand();
      case SelectionCleared():
        _lower();
        _placeHand();
      case MoveRejected(:final shelf):
        if (shelf >= 0 && shelf < _shelves.length) {
          _shelves[shelf].shake();
          for (final i in _stacks[shelf]) {
            i.shake();
          }
        }
      case ItemsMoved(:final outcome):
        _animateMove(outcome);
        unawaited(_updateGuide());
      case BoardReset(:final board):
        _rebuild(board);
        _hand?.removeFromParent();
        _hand = null;
        unawaited(_updateGuide());
      case HintShown(:final move):
        _hint = move;
        _syncShelfStates(controller.board);
      case LevelWon():
        add(
          TimerComponent(
            period: _moveSeconds + 0.15,
            removeOnFinish: true,
            onTick: () => add(Confetti(area: size.clone())),
          ),
        );
    }
  }

  void _animateMove(MoveOutcome outcome) {
    final from = outcome.move.from;
    final to = outcome.move.to;
    _hint = null;
    final src = _stacks[from];
    final dst = _stacks[to];
    final moving = src.sublist(src.length - outcome.count);
    src.removeRange(src.length - outcome.count, src.length);
    final base = dst.length;
    dst.addAll(moving);
    var arrived = 0;
    for (var k = 0; k < moving.length; k++) {
      moving[k]
        ..priority = 10
        ..moveTo(
          _slotCenter(to, base + k),
          duration: _moveSeconds,
          arc: true,
          delay: k * 0.035,
          onArrive: () {
            arrived++;
            if (arrived == moving.length) _afterMove(outcome);
          },
        );
    }
    // Items of a partial run that stay behind drop back down.
    if (_lifted == from) {
      for (var slot = 0; slot < src.length; slot++) {
        src[slot].moveTo(_slotCenter(from, slot), duration: 0.12);
      }
    }
    _lifted = -1;
    _liftedCount = 0;
  }

  void _afterMove(MoveOutcome outcome) {
    for (final stack in _stacks) {
      for (final i in stack) {
        i.priority = 1;
      }
    }
    _syncShelfStates(controller.board);
    final done = outcome.completedShelf;
    if (done != null) {
      _shelves[done].celebrate();
      final stack = _stacks[done];
      for (var i = 0; i < stack.length; i++) {
        stack[i].pop(delay: i * 0.05);
      }
      final rect = _layout.shelfRects[done];
      add(
        SparkleBurst(
          center: Vector2(rect.center.dx, rect.top),
          color: skin.colorOf(outcome.itemType),
        ),
      );
    }
  }
}
