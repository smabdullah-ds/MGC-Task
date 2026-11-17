import 'dart:async';
import 'dart:isolate';

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/app/routes.dart';
import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/economy_config.dart';
import 'package:bazaar_sort/core/economy/progression.dart';
import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/core/level_gen/board_shuffler.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/seeded_random.dart';
import 'package:bazaar_sort/features/gameplay/board/board_game.dart';
import 'package:bazaar_sort/features/gameplay/booster_coordinator.dart';
import 'package:bazaar_sort/features/gameplay/controller/board_event.dart';
import 'package:bazaar_sort/features/gameplay/controller/game_controller.dart';
import 'package:bazaar_sort/features/gameplay/data/level_repository.dart';
import 'package:bazaar_sort/features/gameplay/level_flow.dart';
import 'package:bazaar_sort/features/gameplay/skins/skin_provider.dart';
import 'package:bazaar_sort/features/gameplay/tutorial/tutorial_script.dart';
import 'package:bazaar_sort/features/gameplay/widgets/booster_bar.dart';
import 'package:bazaar_sort/features/gameplay/widgets/result_sheets.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

enum _Overlay { none, pause, win, fail }

/// Plays one level (or the daily challenge).
class GameplayScreen extends ConsumerStatefulWidget {
  const new({required this.level, this.daily = false, super.key});

  /// Level number (ignored for the daily challenge).
  final int level;

  /// Whether this is today's daily challenge.
  final bool daily;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> {
  GeneratedLevel? _level;
  GameController? _controller;
  BoardGame? _game;
  late BoosterCoordinator _boosters;
  StreamSubscription<BoardEvent>? _sub;
  Object? _error;

  _Overlay _overlay = _Overlay.none;
  WinResult? _win;
  String? _coachStep;
  String? _highlight;
  bool _busy = false;

  EconomyConfig get _cfg => ref.read(economyConfigProvider);
  FeedbackService get _feedback => ref.read(feedbackServiceProvider);
  LevelFlow get _flow => ref.read(levelFlowProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(levelRepositoryProvider);
      final player = ref.read(playerProvider);
      final level = widget.daily
          ? await repo.daily(DateTime.now(), playerLevel: player.nextLevel)
          : await repo.load(widget.level);
      if (!mounted) return;
      _start(level);
    } on Object catch (e, st) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .recordError(e, st, reason: 'level_load ${widget.level}'),
      );
      if (mounted) setState(() => _error = e);
    }
  }

  void _start(GeneratedLevel level) {
    final controller = GameController(
      level: level,
      solve: ref.read(solveRunnerProvider),
      freeUndos: _cfg.freeUndosPerLevel,
    )..addListener(_onControllerChanged);
    final store = ref.read(playerProvider.notifier);
    final step = widget.daily ? null : TutorialScript.forLevel(level.level);
    final firstTime = !ref.read(playerProvider).stars.containsKey(level.level);
    setState(() {
      _level = level;
      _controller = controller;
      _boosters = BoosterCoordinator(
        store: store,
        ads: ref.read(adsServiceProvider),
        analytics: ref.read(gameAnalyticsProvider),
        config: _cfg,
        level: level.level,
        onRewardedShown: _flow.onRewardedShown,
      );
      _game = BoardGame(
        controller: controller,
        skin: ref.read(itemSkinProvider),
        colorblind: () => ref.read(playerProvider).settings.colorblind,
        guide: (step?.guideMoves ?? false) && firstTime,
      );
      if (step != null &&
          !ref.read(playerProvider).tutorialStepsSeen.contains(step.id)) {
        _coachStep = step.id;
        _highlight = step.highlight;
        ref
            .read(gameAnalyticsProvider)
            .tutorialStep(step: step.id, level: level.level);
      }
    });
    _sub = controller.events.listen(_onBoardEvent);
    _flow.onLevelStart(level, daily: widget.daily);
    // A board can only start stuck in tests or with a broken level file, but
    // the player must always get the fail options rather than a frozen game.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onControllerChanged());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _controller
      ?..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  // ---- Board events → sound, haptics, win ---------------------------------

  void _onBoardEvent(BoardEvent e) {
    switch (e) {
      case ShelfSelected():
        _feedback
          ..play(Sfx.pick)
          ..haptic(Haptic.selection);
      case ItemsMoved(:final outcome):
        _feedback.play(Sfx.drop);
        if (outcome.completedShelf != null) {
          _feedback
            ..play(Sfx.complete)
            ..haptic(Haptic.medium);
        }
      case MoveRejected():
        _feedback
          ..play(Sfx.invalid)
          ..haptic(Haptic.light);
      case BoardReset(:final reason):
        _feedback.play(reason == BoardResetReason.undo ? Sfx.tap : Sfx.booster);
      case HintShown():
        _feedback.play(Sfx.booster);
      case LevelWon():
        unawaited(_handleWin());
      case SelectionCleared():
        break;
    }
  }

  void _onControllerChanged() {
    final c = _controller;
    if (c == null || !mounted) return;
    final status = c.status;
    if ((status == SessionStatus.stuck || status == SessionStatus.outOfMoves) &&
        _overlay == _Overlay.none) {
      _flow.onLevelFail(
        _level!,
        controller: c,
        reason: status == SessionStatus.outOfMoves
            ? 'out_of_moves'
            : c.isDeadEnd
            ? 'dead_end'
            : 'stuck',
      );
      setState(() => _overlay = _Overlay.fail);
    } else {
      setState(() {});
    }
  }

  Future<void> _handleWin() async {
    final level = _level!;
    final c = _controller!;
    final result = await _flow.onLevelWon(
      level,
      controller: c,
      daily: widget.daily,
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _feedback.play(Sfx.win);
    setState(() {
      _win = result;
      _overlay = _Overlay.win;
    });
  }

  // ---- Boosters ----------------------------------------------------------

  Future<PaySource?> _offer(
    BoosterType? type, {
    required String title,
    required String body,
    required IconData icon,
    required int price,
  }) async {
    final b = _boosters;
    final owned = type == null ? 0 : b.owned(type);
    final choice = await OfferSheet.show(
      context,
      OfferSheet(
        title: title,
        body: body,
        icon: icon,
        coinPrice: price,
        canAfford: b.canAfford(price),
        adAvailable: b.adReady,
        ownedCount: owned,
      ),
    );
    return choice == null ? null : PaySource.values.byName(choice);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onBooster(BoosterType type) async {
    final c = _controller;
    if (c == null || _busy || c.status == SessionStatus.won) return;
    final l10n = context.l10n;
    final analytics = ref.read(gameAnalyticsProvider);
    if (_highlight != null) setState(() => _highlight = null);

    switch (type) {
      case BoosterType.undo:
        if (!c.session.hasHistory) return;
        if (c.session.canUndo) {
          c.undo();
          analytics.boosterUsed(
            type: 'undo',
            source: 'free',
            level: c.level.level,
          );
          return;
        }
        final source = await _offer(
          type,
          title: l10n.offerUndoTitle,
          body: l10n.offerUndoBody(_cfg.undosPerAd),
          icon: Icons.undo_rounded,
          price: _cfg.priceUndoPack,
        );
        if (source == null || !mounted) return;
        if (!await _pay(type, source)) return;
        c
          ..grantUndos(_cfg.undosPerAd)
          ..undo();
      case BoosterType.extraShelf:
        if (c.session.extraShelfUsed) {
          _toast(l10n.extraShelfUsed);
          return;
        }
        final source = await _offer(
          type,
          title: l10n.offerExtraShelfTitle,
          body: l10n.offerExtraShelfBody,
          icon: Icons.add_box_rounded,
          price: _cfg.priceExtraShelf,
        );
        if (source == null || !mounted) return;
        if (!await _pay(type, source)) return;
        c.addExtraShelf();
      case BoosterType.hint:
        final source = await _offer(
          type,
          title: l10n.offerHintTitle,
          body: l10n.offerHintBody,
          icon: Icons.lightbulb_rounded,
          price: _cfg.priceHint,
        );
        if (source == null || !mounted) return;
        if (!await _pay(type, source)) return;
        setState(() => _busy = true);
        final move = await c.requestHint();
        if (!mounted) return;
        setState(() => _busy = false);
        if (move == null) {
          await _refund(type, source);
          _toast(l10n.noHint);
        }
      case BoosterType.shuffle:
        final source = await _offer(
          type,
          title: l10n.offerShuffleTitle,
          body: l10n.offerShuffleBody,
          icon: Icons.shuffle_rounded,
          price: _cfg.priceShuffle,
        );
        if (source == null || !mounted) return;
        if (!await _pay(type, source)) return;
        setState(() => _busy = true);
        final board = c.board;
        final seed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
        final shuffled = await Isolate.run(
          () => const BoardShuffler().shuffle(board, SeededRandom(seed)),
        );
        if (!mounted) return;
        setState(() => _busy = false);
        if (shuffled == null) {
          await _refund(type, source);
          _toast(l10n.shuffleFailed);
        } else {
          c.applyShuffle(shuffled);
        }
    }
  }

  Future<bool> _pay(BoosterType type, PaySource source) async {
    final ok = await _boosters.payFor(type, source);
    if (!ok && mounted) {
      _toast(
        source == PaySource.ad
            ? context.l10n.adUnavailable
            : context.l10n.notEnoughCoins,
      );
    }
    return ok;
  }

  Future<void> _refund(BoosterType type, PaySource source) async {
    final store = ref.read(playerProvider.notifier);
    final progression = Progression(_cfg);
    switch (source) {
      case PaySource.coins:
        await store.update((p) => progression.earn(p, _cfg.priceOf(type)));
      case PaySource.inventory:
        await store.update((p) => progression.addBooster(p, type, 1));
      case PaySource.ad:
        break; // An ad can't be refunded; the player loses nothing.
    }
  }

  List<BoosterButtonState> _boosterStates() {
    final c = _controller!;
    final owned = ref.watch(playerProvider).boosters;
    BoosterBadge paid(BoosterType t) =>
        (owned[t] ?? 0) > 0 ? CountBadge(owned[t]!) : const PayBadge();
    return [
      BoosterButtonState(
        BoosterType.undo,
        !c.session.hasHistory && c.session.undosLeft > 0
            ? CountBadge(c.session.undosLeft)
            : c.session.undosLeft > 0
            ? CountBadge(c.session.undosLeft)
            : const PayBadge(),
        highlighted: _highlight == 'undo',
      ),
      BoosterButtonState(
        BoosterType.extraShelf,
        c.session.extraShelfUsed
            ? const DisabledBadge()
            : paid(BoosterType.extraShelf),
        highlighted: _highlight == 'extra_shelf',
      ),
      BoosterButtonState(
        BoosterType.hint,
        paid(BoosterType.hint),
        highlighted: _highlight == 'hint',
      ),
      BoosterButtonState(
        BoosterType.shuffle,
        paid(BoosterType.shuffle),
        highlighted: _highlight == 'shuffle',
      ),
    ];
  }

  // ---- Fail options --------------------------------------------------------

  List<FailOption> _failOptions() {
    final c = _controller!;
    final l10n = context.l10n;
    return [
      if (c.status == SessionStatus.outOfMoves)
        FailOption(
          key: 'moves',
          label: l10n.extraMoves(_cfg.extraMovesAmount),
          icon: Icons.add_circle_rounded,
          onTap: () async {
            final source = await _offer(
              null,
              title: l10n.offerExtraMovesTitle,
              body: l10n.offerExtraMovesBody(_cfg.extraMovesAmount),
              icon: Icons.add_circle_rounded,
              price: _cfg.priceExtraMoves,
            );
            if (source == null || !mounted) return;
            if (!await _boosters.payForExtraMoves(source)) {
              if (mounted) _toast(l10n.adUnavailable);
              return;
            }
            setState(() => _overlay = _Overlay.none);
            c.addMoves(_cfg.extraMovesAmount);
          },
        ),
      if (!c.session.extraShelfUsed && c.status != SessionStatus.outOfMoves)
        FailOption(
          key: 'extra_shelf',
          label: l10n.offerExtraShelfTitle,
          icon: Icons.add_box_rounded,
          onTap: () => _continueWith(BoosterType.extraShelf),
        ),
      if (c.session.hasHistory)
        FailOption(
          key: 'undo',
          label: l10n.boosterUndo,
          icon: Icons.undo_rounded,
          onTap: () => _continueWith(BoosterType.undo),
        ),
    ];
  }

  Future<void> _continueWith(BoosterType type) async {
    setState(() => _overlay = _Overlay.none);
    await _onBooster(type);
    final c = _controller;
    if (!mounted || c == null) return;
    final s = c.status;
    if (s == SessionStatus.stuck || s == SessionStatus.outOfMoves) {
      setState(() => _overlay = _Overlay.fail);
    }
  }

  void _restart() {
    final c = _controller!;
    _flow.onRestart(_level!, controller: c);
    c.restart();
    setState(() => _overlay = _Overlay.none);
  }

  void _home() {
    final c = _controller;
    if (c != null && c.status != SessionStatus.won && c.session.movesMade > 0) {
      _flow.onLevelFail(_level!, controller: c, reason: 'quit');
    }
    context.go(Routes.home);
  }

  Future<void> _continueAfterWin() async {
    final level = _level!;
    await _flow.beforeLeavingWin(level, daily: widget.daily);
    if (!mounted) return;
    if (widget.daily) {
      context.go(Routes.daily);
    } else {
      context.go(Routes.playLevel(level.level + 1));
    }
  }

  // ---- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorGeneric),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: Text(l10n.home),
              ),
            ],
          ),
        ),
      );
    }
    final level = _level;
    final c = _controller;
    final game = _game;
    if (level == null || c == null || game == null) {
      return Scaffold(
        body: BazaarBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Palette.terracotta),
                const SizedBox(height: 16),
                Text(l10n.loading),
              ],
            ),
          ),
        ),
      );
    }
    final coins = ref.watch(playerProvider.select((p) => p.coins));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _overlay == _Overlay.none) {
          setState(() => _overlay = _Overlay.pause);
        }
      },
      child: Scaffold(
        body: BazaarBackground(
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      title: widget.daily
                          ? l10n.levelKindDaily
                          : l10n.level(level.level),
                      tag: level.isBoss
                          ? l10n.levelKindBoss
                          : level.kind.name == 'hard'
                          ? l10n.levelKindHard
                          : null,
                      coins: coins,
                      onPause: () => setState(() => _overlay = _Overlay.pause),
                      onCoins: () => context.push(Routes.shop),
                    ),
                    _MovesLine(
                      moves: c.session.movesMade,
                      movesLeft: c.session.movesLeft,
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Semantics(
                              label: l10n.boardLabel(c.board.shelfCount),
                              child: GameWidget<BoardGame>(game: game),
                            ),
                          ),
                          if (_coachStep != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 8,
                              child: CoachBubble(
                                text: l10n.tutorial(_coachStep!),
                                onDismiss: _dismissCoach,
                              ),
                            ),
                          if (_busy)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Palette.terracotta,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: BoosterBar(
                        buttons: _boosterStates(),
                        onPressed: (t) => unawaited(_onBooster(t)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_overlay == _Overlay.pause)
                PausePanel(
                  onResume: () => setState(() => _overlay = _Overlay.none),
                  onRestart: _restart,
                  onSettings: () => context.push(Routes.settings),
                  onHome: _home,
                ),
              if (_overlay == _Overlay.win && _win != null)
                WinPanel(
                  stars: _win!.stars,
                  coins: _win!.coins,
                  moves: _win!.moves,
                  targetMoves: _win!.threeStarMoves,
                  boss: level.isBoss,
                  canDouble: ref.read(adsServiceProvider).isRewardedReady,
                  onDouble: () => _flow.doubleCoins(level),
                  onContinue: () => unawaited(_continueAfterWin()),
                ),
              if (_overlay == _Overlay.fail)
                FailPanel(
                  status: c.status,
                  deadEnd: c.isDeadEnd,
                  options: _failOptions(),
                  onRetry: _restart,
                  onHome: _home,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _dismissCoach() {
    final id = _coachStep;
    setState(() => _coachStep = null);
    if (id == null) return;
    unawaited(
      ref
          .read(playerProvider.notifier)
          .update(
            (p) => p.copyWith(tutorialStepsSeen: {...p.tutorialStepsSeen, id}),
          ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const new({
    required this.title,
    required this.tag,
    required this.coins,
    required this.onPause,
    required this.onCoins,
  });

  final String title;
  final String? tag;
  final int coins;
  final VoidCallback onPause;
  final VoidCallback onCoins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton.filled(
            key: const ValueKey('pause_button'),
            tooltip: context.l10n.pause,
            style: IconButton.styleFrom(backgroundColor: Palette.woodDark),
            onPressed: onPause,
            icon: const Icon(Icons.pause_rounded, color: Palette.ivory),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  key: const ValueKey('level_title'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.terracotta,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tag!,
                      style: const TextStyle(
                        color: Palette.ivory,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          CoinPill(coins: coins, onTap: onCoins),
        ],
      ),
    );
  }
}

class _MovesLine extends StatelessWidget {
  const new({required this.moves, required this.movesLeft});

  final int moves;
  final int? movesLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final left = movesLeft;
    final low = left != null && left <= 3;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        left == null ? l10n.movesMade(moves) : l10n.movesLeft(left),
        key: const ValueKey('moves_line'),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: left == null ? 14 : 18,
          color: low ? Palette.terracotta : Palette.wood,
        ),
      ),
    );
  }
}
