import 'dart:async';

import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';
import 'package:bazaar_sort/features/gameplay/controller/board_event.dart';
import 'package:flutter/foundation.dart';

/// Runs a solver search off the UI thread (an isolate in the app, inline in
/// tests).
typedef SolveRunner = Future<SolveResult> Function(BoardState board);

/// Owns one level attempt: the immutable [GameSession], the tap-to-select
/// interaction, hints and dead-end detection. Rendering subscribes to
/// [events]; widgets listen to it as a [ChangeNotifier].
///
/// Economy concerns (paying for boosters) live outside: the controller only
/// exposes the actions once they are paid for.
class GameController extends ChangeNotifier {
  /// Creates a controller for [level].
  new({
    required this.level,
    required this.solve,
    this.freeUndos = 3,
    this.rules = GameRules.standard,
    this.detectDeadEnds = true,
  }) : _session = GameSession.start(
         level.board,
         rules: rules,
         moveLimit: level.moveLimit,
         freeUndos: freeUndos,
       );

  /// Level being played.
  final GeneratedLevel level;

  /// Background solver.
  final SolveRunner solve;

  /// Free undos per attempt.
  final int freeUndos;

  /// Rules.
  final GameRules rules;

  /// Whether to search for dead ends (unwinnable positions that still have
  /// legal moves) after each move.
  final bool detectDeadEnds;

  final StreamController<BoardEvent> _events =
      StreamController<BoardEvent>.broadcast();
  final Stopwatch _clock = Stopwatch()..start();

  GameSession _session;
  int? _selected;
  Move? _hint;
  bool _deadEnd = false;
  int _restarts = 0;
  int _searchToken = 0;
  final Map<String, int> _boostersUsed = <String, int>{};

  /// Board events for the renderer.
  Stream<BoardEvent> get events => _events.stream;

  /// Current session.
  GameSession get session => _session;

  /// Current board.
  BoardState get board => _session.board;

  /// Selected shelf, if any.
  int? get selected => _selected;

  /// Currently highlighted hint.
  Move? get hint => _hint;

  /// Status of the attempt. A detected dead end reports as stuck.
  SessionStatus get status {
    final s = _session.status;
    if (s == SessionStatus.playing && _deadEnd) return SessionStatus.stuck;
    return s;
  }

  /// Whether the position was proven unwinnable while moves remain.
  bool get isDeadEnd => _deadEnd;

  /// Restarts so far.
  int get restarts => _restarts;

  /// Seconds since the attempt started.
  int get elapsedSeconds => _clock.elapsed.inSeconds;

  /// Boosters used this attempt, by name (analytics).
  Map<String, int> get boostersUsed => Map.unmodifiable(_boostersUsed);

  /// Handles a tap on shelf [index]: select, deselect, or move.
  void tapShelf(int index) {
    if (_session.status != SessionStatus.playing) return;
    final sel = _selected;
    if (sel == null) {
      if (rules.canPick(board, index)) {
        _selected = index;
        _events.add(ShelfSelected(index));
        notifyListeners();
      } else if (index >= 0 && index < board.shelfCount) {
        _events.add(MoveRejected(index, rules.pickRejection(board, index)!));
      }
      return;
    }
    if (sel == index) {
      _selected = null;
      _events.add(SelectionCleared(index));
      notifyListeners();
      return;
    }
    final move = Move(sel, index);
    final rejection = rules.validate(board, move);
    if (rejection != null) {
      // Tapping another pickable shelf switches the selection.
      if (rules.canPick(board, index) &&
          rejection != MoveRejection.destinationLocked) {
        _events
          ..add(SelectionCleared(sel))
          ..add(MoveRejected(index, rejection))
          ..add(ShelfSelected(index));
        _selected = index;
      } else {
        _events.add(MoveRejected(index, rejection));
      }
      notifyListeners();
      return;
    }
    play(move);
  }

  /// Plays [move] directly (drag-and-drop, hints, tests). Returns whether
  /// it was legal.
  bool play(Move move) {
    final result = _session.play(move);
    if (result == null) {
      _events.add(MoveRejected(move.to, rules.validate(board, move)!));
      return false;
    }
    final (next, outcome) = result;
    _session = next;
    _selected = null;
    _hint = null;
    _deadEnd = false;
    _events.add(ItemsMoved(outcome));
    if (_session.status == SessionStatus.won) {
      _clock.stop();
      _events.add(const LevelWon());
    } else {
      _checkDeadEnd();
    }
    notifyListeners();
    return true;
  }

  /// Reverts the last move. Returns whether it happened.
  bool undo() {
    final s = _session.undo();
    if (s == null) return false;
    _apply(s, BoardResetReason.undo);
    _count('undo');
    return true;
  }

  /// Adds undo charges (after an ad or purchase).
  void grantUndos(int count) {
    _session = _session.addUndos(count);
    notifyListeners();
  }

  /// Adds one empty shelf. Returns whether it happened.
  bool addExtraShelf() {
    final s = _session.addExtraShelf();
    if (s == null) return false;
    _apply(s, BoardResetReason.extraShelf);
    _count('extra_shelf');
    return true;
  }

  /// Adds moves on a move-limited level.
  void addMoves(int count) {
    _session = _session.addMoves(count);
    _count('extra_moves');
    notifyListeners();
  }

  /// Replaces the board with a shuffled one.
  void applyShuffle(BoardState shuffled) {
    _apply(_session.replaceBoard(shuffled), BoardResetReason.shuffle);
    _count('shuffle');
  }

  /// Computes and shows the next solver move. Returns `null` when no hint
  /// could be found (dead end or search budget exhausted).
  Future<Move?> requestHint() async {
    final token = ++_searchToken;
    final result = await solve(board);
    if (token != _searchToken || result.moves.isEmpty) return null;
    _hint = result.moves.first;
    _events.add(HintShown(_hint!));
    _count('hint');
    notifyListeners();
    return _hint;
  }

  /// Starts the level over (same board, fresh undos).
  void restart() {
    _restarts++;
    _clock
      ..reset()
      ..start();
    _boostersUsed.clear();
    _apply(
      GameSession.start(
        level.board,
        rules: rules,
        moveLimit: level.moveLimit,
        freeUndos: freeUndos,
      ),
      BoardResetReason.restart,
    );
  }

  void _apply(GameSession s, BoardResetReason reason) {
    _searchToken++;
    _session = s;
    _selected = null;
    _hint = null;
    _deadEnd = false;
    _events.add(BoardReset(s.board, reason: reason));
    _checkDeadEnd();
    notifyListeners();
  }

  void _count(String booster) =>
      _boostersUsed.update(booster, (v) => v + 1, ifAbsent: () => 1);

  void _checkDeadEnd() {
    if (!detectDeadEnds || _session.status != SessionStatus.playing) return;
    final token = ++_searchToken;
    final snapshot = board;
    unawaited(
      solve(snapshot).then((r) {
        if (token != _searchToken || _events.isClosed) return;
        if (r.status == SolveStatus.unsolvable) {
          _deadEnd = true;
          notifyListeners();
        }
      }),
    );
  }

  @override
  void dispose() {
    _searchToken++;
    unawaited(_events.close());
    super.dispose();
  }
}
