import 'package:bazaar_sort/core/game_logic/game_logic.dart';

/// A test board and its known optimal solution length (-2 = unsolvable).
typedef HandMadeBoard = ({String name, BoardState board, int optimal});

Item _h(int t) => Item.of(t, hidden: true);
Item _f(int t) => Item.of(t, frozen: true);
Shelf _s(List<int> types, {int unlockAfter = 0}) =>
    Shelf([for (final t in types) Item.of(t)], unlockAfter: unlockAfter);

/// 20 hand-made boards. Optimal values were derived by exhaustive
/// breadth-first search (see `bfsOptimal` in solver_test.dart, which
/// re-checks them).
final List<HandMadeBoard> handMadeBoards = [
  (
    name: 'already solved',
    board: BoardState.fromTypes(const [
      [0, 0, 0, 0],
      [],
    ]),
    optimal: 0,
  ),
  (
    name: 'one move',
    board: BoardState.fromTypes(const [
      [0, 0, 0],
      [0],
    ]),
    optimal: 1,
  ),
  (
    name: 'swap two tops',
    board: BoardState.fromTypes(const [
      [0, 0, 0, 1],
      [1, 1, 1, 0],
      [],
    ]),
    optimal: 3,
  ),
  (
    name: 'k2 interleaved',
    board: BoardState.fromTypes(const [
      [0, 1, 0, 1],
      [1, 0, 1, 0],
      [],
      [],
    ]),
    optimal: 7,
  ),
  (
    name: 'k2 halves',
    board: BoardState.fromTypes(const [
      [0, 0, 1, 1],
      [1, 1, 0, 0],
      [],
      [],
    ]),
    optimal: 3,
  ),
  (
    name: 'k3 rotated',
    board: BoardState.fromTypes(const [
      [0, 1, 2, 0],
      [1, 2, 0, 1],
      [2, 0, 1, 2],
      [],
      [],
    ]),
    optimal: 10,
  ),
  (
    name: 'k3 stacked',
    board: BoardState.fromTypes(const [
      [0, 0, 1, 2],
      [1, 1, 2, 0],
      [2, 2, 0, 1],
      [],
      [],
    ]),
    optimal: 7,
  ),
  (
    name: 'k3 one empty',
    board: BoardState.fromTypes(const [
      [0, 0, 0, 1],
      [1, 1, 1, 2],
      [2, 2, 2, 0],
      [],
    ]),
    optimal: 4,
  ),
  (
    name: 'k4 bands',
    board: BoardState.fromTypes(const [
      [0, 1, 2, 3],
      [0, 1, 2, 3],
      [3, 2, 1, 0],
      [3, 2, 1, 0],
      [],
      [],
    ]),
    optimal: 15,
  ),
  (
    name: 'k4 mixed',
    board: BoardState.fromTypes(const [
      [2, 0, 1, 3],
      [1, 3, 0, 2],
      [3, 2, 2, 0],
      [0, 1, 3, 1],
      [],
      [],
    ]),
    optimal: 12,
  ),
  (
    name: 'capacity 3',
    board: BoardState.fromTypes(const [
      [0, 1, 2],
      [2, 0, 1],
      [1, 2, 0],
      [],
      [],
    ], capacity: 3),
    optimal: 7,
  ),
  (
    name: 'capacity 2',
    board: BoardState.fromTypes(const [
      [0, 1],
      [1, 2],
      [2, 0],
      [],
    ], capacity: 2),
    optimal: 4,
  ),
  (
    name: 'partial shelves',
    board: BoardState.fromTypes(const [
      [0, 1],
      [1, 0, 0],
      [1, 1, 0],
      [],
    ]),
    optimal: 4,
  ),
  (
    name: 'hidden run split',
    board: BoardState(
      capacity: 4,
      shelves: [
        Shelf([Item.of(0), _h(1), _h(1), Item.of(1)]),
        Shelf([Item.of(1), Item.of(0), Item.of(0), Item.of(0)]),
        Shelf.empty(),
        Shelf.empty(),
      ],
    ),
    optimal: 5,
  ),
  (
    name: 'hidden k3',
    board: BoardState(
      capacity: 4,
      shelves: [
        Shelf([_h(2), _h(0), Item.of(1), Item.of(0)]),
        Shelf([_h(1), _h(2), Item.of(0), Item.of(2)]),
        Shelf([_h(0), _h(1), Item.of(2), Item.of(1)]),
        Shelf.empty(),
        Shelf.empty(),
      ],
    ),
    optimal: 10,
  ),
  (
    name: 'locked spare shelf',
    board: BoardState(
      capacity: 4,
      shelves: [
        _s([0, 0, 0, 1]),
        _s([1, 1, 1, 0]),
        _s([], unlockAfter: 1),
        _s([]),
      ],
    ),
    optimal: 3,
  ),
  (
    name: 'locked full shelf',
    board: BoardState(
      capacity: 4,
      shelves: [
        _s([0, 1, 0, 1]),
        _s([1, 0, 1, 0]),
        _s([2, 2, 3, 3], unlockAfter: 1),
        _s([3, 3, 2, 2]),
        _s([]),
        _s([]),
      ],
    ),
    optimal: 10,
  ),
  (
    name: 'frozen needs neighbour',
    board: BoardState(
      capacity: 4,
      shelves: [
        Shelf([Item.of(1), _f(1), Item.of(1), Item.of(0)]),
        Shelf([Item.of(0), Item.of(0), Item.of(0), Item.of(1)]),
        Shelf.empty(),
        Shelf.empty(),
      ],
    ),
    optimal: 3,
  ),
  (
    name: 'frozen far side',
    board: BoardState(
      capacity: 4,
      shelves: [
        Shelf.empty(),
        Shelf([Item.of(0), Item.of(1), Item.of(0), Item.of(1)]),
        Shelf([Item.of(1), Item.of(0), Item.of(1), Item.of(0)]),
        Shelf([_f(2), Item.of(2), Item.of(2), Item.of(2)]),
        Shelf.empty(),
      ],
    ),
    optimal: 7,
  ),
  (
    name: 'unsolvable',
    board: BoardState.fromTypes(const [
      [0, 1, 0, 1],
      [1, 0, 1, 0],
    ]),
    optimal: -2,
  ),
];
