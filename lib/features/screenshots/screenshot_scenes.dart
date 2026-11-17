import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';
import 'package:bazaar_sort/features/daily/daily_screen.dart';
import 'package:bazaar_sort/features/gameplay/board/board_game.dart';
import 'package:bazaar_sort/features/gameplay/controller/game_controller.dart';
import 'package:bazaar_sort/features/gameplay/skins/vector_item_skin.dart';
import 'package:bazaar_sort/features/gameplay/widgets/booster_bar.dart';
import 'package:bazaar_sort/features/meta/bazaar_screen.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Whether the screenshot route is available: always in debug/profile
/// builds, and in release only with `--dart-define=SCREENSHOTS=true`.
const bool screenshotsEnabled =
    !kReleaseMode || bool.fromEnvironment('SCREENSHOTS');

/// Staged scenes for store screenshots. Swipe between them and capture the
/// screen at the store's required sizes (e.g. 1290×2796 on iOS, 1080×1920
/// on Android). Captions are English marketing copy; localise per store.
class ScreenshotScenesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        children: [
          _BoardScene(
            caption: 'Sort the goods of a historic bazaar',
            board: _stagedBoard,
          ),
          const _ScreenScene(
            caption: 'Restore market stalls, street by street',
            child: BazaarScreen(),
          ),
          _BoardScene(
            caption: 'Hidden, frozen and locked twists',
            board: _obstacleBoard,
          ),
          const _ScreenScene(
            caption: 'Daily rewards and challenges',
            child: DailyScreen(),
          ),
          _BoardScene(
            caption: '1,000+ levels, every one solvable',
            board: _nearlyDone,
            colorblind: true,
          ),
        ],
      ),
    );
  }
}

Item _i(int t, {bool hidden = false, bool frozen = false}) =>
    Item.of(t, hidden: hidden, frozen: frozen);

final BoardState _stagedBoard = BoardState(
  capacity: 4,
  shelves: [
    Shelf([_i(0), _i(0), _i(0), _i(0)]),
    Shelf([_i(1), _i(3), _i(2), _i(2)]),
    Shelf([_i(4), _i(5), _i(1), _i(3)]),
    Shelf([_i(5), _i(4), _i(6), _i(1)]),
    Shelf([_i(7), _i(7), _i(7), _i(7)]),
    Shelf([_i(3), _i(6), _i(5), _i(4)]),
    Shelf([_i(2), _i(2), _i(6), _i(6)]),
    Shelf([_i(1), _i(5), _i(4), _i(3)]),
    Shelf(const []),
    Shelf(const []),
  ],
);

final BoardState _obstacleBoard = BoardState(
  capacity: 4,
  shelves: [
    Shelf([_i(2, hidden: true), _i(8, hidden: true), _i(3), _i(9)]),
    Shelf([_i(9), _i(2, frozen: true), _i(8), _i(3)]),
    Shelf([_i(8), _i(9), _i(2), _i(3, hidden: true)]),
    Shelf([_i(3), _i(2), _i(9), _i(8)], unlockAfter: 2),
    Shelf([_i(10), _i(10), _i(10)]),
    Shelf([_i(10)]),
    Shelf(const []),
  ],
);

final BoardState _nearlyDone = BoardState(
  capacity: 4,
  shelves: [
    Shelf([_i(0), _i(0), _i(0), _i(0)]),
    Shelf([_i(1), _i(1), _i(1), _i(1)]),
    Shelf([_i(2), _i(2), _i(2)]),
    Shelf([_i(3), _i(3), _i(3), _i(3)]),
    Shelf([_i(4), _i(4), _i(4), _i(2)]),
    Shelf([_i(5), _i(5), _i(5), _i(5)]),
    Shelf([_i(4)]),
    Shelf(const []),
  ],
);

class _BoardScene extends StatefulWidget {
  const new({
    required this.caption,
    required this.board,
    this.colorblind = false,
  });

  final String caption;
  final BoardState board;
  final bool colorblind;

  @override
  State<_BoardScene> createState() => _BoardSceneState();
}

class _BoardSceneState extends State<_BoardScene> {
  late final GameController _controller = GameController(
    level: GeneratedLevel(
      level: 42,
      seed: 0,
      spec: const LevelSpec(
        level: 42,
        kind: LevelKind.normal,
        itemTypes: 8,
        capacity: 4,
        emptyShelves: 2,
        minOptimalMoves: 0,
      ),
      board: widget.board,
      optimalMoves: 20,
      provenOptimal: true,
    ),
    solve: (b) async => const Solver().solve(b, limits: SolverLimits.hint),
    detectDeadEnds: false,
  );

  late final BoardGame _game = BoardGame(
    controller: _controller,
    skin: const VectorItemSkin(),
    colorblind: () => widget.colorblind,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      caption: widget.caption,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 56),
              Expanded(
                child: Text(
                  'Level 42',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const CoinPill(coins: 1840),
              const SizedBox(width: 8),
            ],
          ),
          Expanded(child: GameWidget<BoardGame>(game: _game)),
          BoosterBar(
            buttons: const [
              BoosterButtonState(BoosterType.undo, CountBadge(3)),
              BoosterButtonState(BoosterType.extraShelf, CountBadge(1)),
              BoosterButtonState(BoosterType.hint, CountBadge(2)),
              BoosterButtonState(BoosterType.shuffle, PayBadge()),
            ],
            onPressed: (_) {},
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ScreenScene extends StatelessWidget {
  const new({required this.caption, required this.child});

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) => _Frame(caption: caption, child: child);
}

class _Frame extends StatelessWidget {
  const new({required this.caption, required this.child});

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BazaarBackground(
      dark: true,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Palette.saffron,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: ColoredBox(color: Palette.ivory, child: child),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
