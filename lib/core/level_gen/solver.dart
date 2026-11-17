import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/game_rules.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';

/// How a search ended.
enum SolveStatus {
  /// A solution was found ([SolveResult.moves]).
  solved,

  /// The whole reachable state space was searched: no solution exists.
  unsolvable,

  /// Node or time limit hit before an answer.
  limitReached,
}

/// Result of [Solver.solve].
final class SolveResult {
  /// Creates a result.
  const new({
    required this.status,
    required this.moves,
    required this.optimal,
    required this.nodesExpanded,
  });

  /// How the search ended.
  final SolveStatus status;

  /// Solution moves (indices refer to the board passed to `solve`), empty
  /// unless [status] is [SolveStatus.solved].
  final List<Move> moves;

  /// Whether [moves] is proven shortest.
  final bool optimal;

  /// Nodes expanded across all passes.
  final int nodesExpanded;

  /// Whether a solution was found.
  bool get isSolved => status == SolveStatus.solved;

  /// Number of moves in the solution.
  int get moveCount => moves.length;
}

/// Limits for one [Solver.solve] call.
final class SolverLimits {
  /// Creates limits.
  const new({
    this.maxNodes = 200000,
    this.maxDuration = const Duration(seconds: 5),
    this.fallbackWeights = const <double>[2, 4],
  });

  /// Nodes per pass.
  final int maxNodes;

  /// Wall-clock budget for the whole call.
  final Duration maxDuration;

  /// Heuristic weights tried after an optimal (weight 1) pass runs out of
  /// budget. Weighted A* returns near-optimal answers much faster.
  final List<double> fallbackWeights;

  /// Fast limits for interactive hints on device.
  static const SolverLimits hint = SolverLimits(
    maxNodes: 40000,
    maxDuration: Duration(milliseconds: 800),
    fallbackWeights: <double>[3],
  );
}

/// A* solver over [GameRules].
///
/// * Heuristic: `total runs − item types`. Each move removes at most one
///   run from the board and the goal has exactly one run per type, so the
///   heuristic is admissible and consistent → weight 1 gives optimal answers.
/// * States are de-duplicated with [BoardState.canonicalKey], so boards that
///   differ only by shelf order are explored once.
/// * Symmetry pruning: only the first usable empty shelf is tried as a
///   destination, and a uniform shelf is never moved wholesale into an empty
///   one (both unless frozen items make shelf positions matter).
final class Solver {
  /// Creates a solver.
  const new({this.rules = GameRules.standard});

  /// Rules to solve under.
  final GameRules rules;

  /// Heuristic value of [board]: lower bound on remaining moves.
  int heuristic(BoardState board) {
    var runs = 0;
    final types = <int>{};
    for (final shelf in board.shelves) {
      var prev = -1;
      for (final item in shelf.items) {
        types.add(item.type);
        if (item.type != prev) {
          runs++;
          prev = item.type;
        }
      }
    }
    return runs - types.length;
  }

  /// Solves [board] within [limits].
  SolveResult solve(
    BoardState board, {
    SolverLimits limits = const SolverLimits(),
  }) {
    if (rules.isWon(board)) {
      return const SolveResult(
        status: SolveStatus.solved,
        moves: <Move>[],
        optimal: true,
        nodesExpanded: 0,
      );
    }
    final stopwatch = Stopwatch()..start();
    var total = 0;
    for (final weight in [1.0, ...limits.fallbackWeights]) {
      final pass = _search(board, weight, limits, stopwatch);
      total += pass.nodesExpanded;
      if (pass.status != SolveStatus.limitReached) {
        return SolveResult(
          status: pass.status,
          moves: pass.moves,
          optimal: pass.optimal && weight == 1.0,
          nodesExpanded: total,
        );
      }
      if (stopwatch.elapsed >= limits.maxDuration) break;
    }
    return SolveResult(
      status: SolveStatus.limitReached,
      moves: const <Move>[],
      optimal: false,
      nodesExpanded: total,
    );
  }

  /// Candidate moves from [board] after symmetry pruning.
  List<Move> candidateMoves(BoardState board) {
    final positional = board.hasFrozen;
    final moves = <Move>[];
    for (var from = 0; from < board.shelfCount; from++) {
      final run = rules.movableRun(board, from);
      if (run == 0) continue;
      final wholeShelf = run == board.shelves[from].length;
      var triedEmpty = false;
      for (var to = 0; to < board.shelfCount; to++) {
        if (to == from) continue;
        final destEmpty = board.shelves[to].isEmpty;
        if (destEmpty && !positional) {
          if (wholeShelf || triedEmpty) continue;
        }
        final move = Move(from, to);
        if (!rules.isLegal(board, move)) continue;
        if (destEmpty) triedEmpty = true;
        moves.add(move);
      }
    }
    return moves;
  }

  SolveResult _search(
    BoardState start,
    double weight,
    SolverLimits limits,
    Stopwatch stopwatch,
  ) {
    final open = _MinHeap();
    final bestG = <String, int>{};
    final startNode = _Node(start, null, null, 0);
    bestG[start.canonicalKey] = 0;
    open.push(startNode, weight * heuristic(start));
    var expanded = 0;
    var exhaustedCleanly = true;

    while (open.isNotEmpty) {
      final node = open.pop();
      final key = node.board.canonicalKey;
      if ((bestG[key] ?? 1 << 30) < node.g) continue; // stale entry
      if (rules.isWon(node.board)) {
        return SolveResult(
          status: SolveStatus.solved,
          moves: node.path(),
          optimal: true,
          nodesExpanded: expanded,
        );
      }
      expanded++;
      if (expanded > limits.maxNodes ||
          (expanded & 1023) == 0 && stopwatch.elapsed > limits.maxDuration) {
        exhaustedCleanly = false;
        break;
      }
      for (final move in candidateMoves(node.board)) {
        final next = rules.apply(node.board, move).after;
        final nextKey = next.canonicalKey;
        final g = node.g + 1;
        if ((bestG[nextKey] ?? 1 << 30) <= g) continue;
        bestG[nextKey] = g;
        open.push(_Node(next, node, move, g), g + weight * heuristic(next));
      }
    }
    return SolveResult(
      status: exhaustedCleanly
          ? SolveStatus.unsolvable
          : SolveStatus.limitReached,
      moves: const <Move>[],
      optimal: false,
      nodesExpanded: expanded,
    );
  }
}

final class _Node {
  new(this.board, this.parent, this.move, this.g);
  final BoardState board;
  final _Node? parent;
  final Move? move;
  final int g;

  List<Move> path() {
    final moves = <Move>[];
    for (_Node? n = this; n?.move != null; n = n.parent) {
      moves.add(n!.move!);
    }
    return moves.reversed.toList();
  }
}

/// Binary min-heap keyed by priority, FIFO among equal priorities
/// (deterministic results).
final class _MinHeap {
  final List<_Node> _nodes = <_Node>[];
  final List<double> _prio = <double>[];
  final List<int> _order = <int>[];
  int _counter = 0;

  bool get isNotEmpty => _nodes.isNotEmpty;

  bool _less(int a, int b) =>
      _prio[a] < _prio[b] || (_prio[a] == _prio[b] && _order[a] < _order[b]);

  void _swap(int a, int b) {
    final n = _nodes[a];
    _nodes[a] = _nodes[b];
    _nodes[b] = n;
    final p = _prio[a];
    _prio[a] = _prio[b];
    _prio[b] = p;
    final o = _order[a];
    _order[a] = _order[b];
    _order[b] = o;
  }

  void push(_Node node, double priority) {
    _nodes.add(node);
    _prio.add(priority);
    _order.add(_counter++);
    var i = _nodes.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (!_less(i, parent)) break;
      _swap(i, parent);
      i = parent;
    }
  }

  _Node pop() {
    final top = _nodes.first;
    final last = _nodes.length - 1;
    _swap(0, last);
    _nodes.removeLast();
    _prio.removeLast();
    _order.removeLast();
    var i = 0;
    final n = _nodes.length;
    while (true) {
      final l = 2 * i + 1;
      final r = l + 1;
      var smallest = i;
      if (l < n && _less(l, smallest)) smallest = l;
      if (r < n && _less(r, smallest)) smallest = r;
      if (smallest == i) break;
      _swap(i, smallest);
      i = smallest;
    }
    return top;
  }
}
