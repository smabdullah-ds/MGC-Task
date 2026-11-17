import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';

/// Something to restore in an area.
final class BazaarItem {
  /// Creates an item.
  const new(this.id, this.baseCost);

  /// Stable id (save data, analytics, l10n key `item_<id>`).
  final String id;

  /// Cost before the Remote Config multiplier.
  final int baseCost;
}

/// One district of the bazaar.
final class BazaarArea {
  /// Creates an area.
  const new({
    required this.id,
    required this.items,
    required this.rewardCoins,
    required this.rewardBoosters,
  });

  /// Stable id (save data, analytics, l10n key `area_<id>`).
  final String id;

  /// Items in restoration order.
  final List<BazaarItem> items;

  /// Coins granted when the area is complete.
  final int rewardCoins;

  /// Boosters granted when the area is complete.
  final Map<BoosterType, int> rewardBoosters;

  /// Total base cost.
  int get totalBaseCost => items.fold(0, (a, i) => a + i.baseCost);
}

/// Result of restoring an item.
final class RestoreResult {
  /// Creates a result.
  const new(this.state, {required this.cost, this.completedArea});

  /// New player state.
  final PlayerState state;

  /// Coins spent.
  final int cost;

  /// Set when this restoration finished an area.
  final BazaarArea? completedArea;
}

/// The bazaar restoration meta game.
///
/// Economy target: a non-paying player finishes the Spice Market in about
/// 25 levels. At ~48 coins per level (20 base + 10 per star at ~2.3 stars,
/// plus boss bonuses) and ~100 coins a day from the login calendar, that is
/// ≈ 1,300 coins, which is the Spice Market's total.
final class BazaarCatalog {
  /// Creates the catalog with a cost [multiplier] (Remote Config).
  const new({this.multiplier = 1.0});

  /// Cost multiplier.
  final double multiplier;

  /// All areas in unlock order.
  static const List<BazaarArea> areas = [
    BazaarArea(
      id: 'spice_market',
      items: [
        BazaarItem('spice_awning', 150),
        BazaarItem('spice_sacks', 180),
        BazaarItem('spice_scales', 200),
        BazaarItem('spice_counter', 230),
        BazaarItem('spice_lamps', 250),
        BazaarItem('spice_sign', 290),
      ],
      rewardCoins: 200,
      rewardBoosters: {BoosterType.hint: 2, BoosterType.undo: 3},
    ),
    BazaarArea(
      id: 'lantern_street',
      items: [
        BazaarItem('lantern_arch', 250),
        BazaarItem('lantern_strings', 270),
        BazaarItem('lantern_stall', 290),
        BazaarItem('lantern_fountain', 310),
        BazaarItem('lantern_benches', 320),
        BazaarItem('lantern_tower', 340),
        BazaarItem('lantern_gate', 360),
      ],
      rewardCoins: 300,
      rewardBoosters: {BoosterType.shuffle: 2, BoosterType.extraShelf: 1},
    ),
    BazaarArea(
      id: 'tea_house',
      items: [
        BazaarItem('tea_carpets', 350),
        BazaarItem('tea_samovar', 370),
        BazaarItem('tea_cushions', 390),
        BazaarItem('tea_tables', 410),
        BazaarItem('tea_windows', 430),
        BazaarItem('tea_dome', 450),
        BazaarItem('tea_garden', 480),
      ],
      rewardCoins: 400,
      rewardBoosters: {BoosterType.hint: 3, BoosterType.shuffle: 2},
    ),
    BazaarArea(
      id: 'textile_lane',
      items: [
        BazaarItem('textile_looms', 450),
        BazaarItem('textile_dyes', 470),
        BazaarItem('textile_racks', 490),
        BazaarItem('textile_awnings', 510),
        BazaarItem('textile_carts', 530),
        BazaarItem('textile_well', 550),
        BazaarItem('textile_minaret', 575),
        BazaarItem('textile_gate', 600),
      ],
      rewardCoins: 600,
      rewardBoosters: {
        BoosterType.extraShelf: 2,
        BoosterType.hint: 3,
        BoosterType.shuffle: 3,
      },
    ),
  ];

  /// Cost of [item] after the multiplier, rounded to 5 coins.
  int costOf(BazaarItem item) => ((item.baseCost * multiplier) / 5).round() * 5;

  /// Area that [itemId] belongs to.
  static BazaarArea areaOf(String itemId) =>
      areas.firstWhere((a) => a.items.any((i) => i.id == itemId));

  /// Whether every item of [area] is restored.
  bool isComplete(PlayerState s, BazaarArea area) =>
      area.items.every((i) => s.restoredItems.contains(i.id));

  /// The area the player is working on (first incomplete), or the last one
  /// when everything is restored.
  BazaarArea currentArea(PlayerState s) =>
      areas.firstWhere((a) => !isComplete(s, a), orElse: () => areas.last);

  /// Whether [area] is open: the first area, or the previous one complete.
  bool isUnlocked(PlayerState s, BazaarArea area) {
    final i = areas.indexOf(area);
    return i <= 0 || isComplete(s, areas[i - 1]);
  }

  /// Restored items of [area].
  int restoredCount(PlayerState s, BazaarArea area) =>
      area.items.where((i) => s.restoredItems.contains(i.id)).length;

  /// Progress 0…1 through [area].
  double progress(PlayerState s, BazaarArea area) =>
      restoredCount(s, area) / area.items.length;

  /// Next unrestored item of the current area.
  BazaarItem? nextItem(PlayerState s) {
    final area = currentArea(s);
    for (final i in area.items) {
      if (!s.restoredItems.contains(i.id)) return i;
    }
    return null;
  }

  /// Restores [itemId], paying its cost. `null` when the item is unknown,
  /// already restored, in a locked area, or unaffordable. Completing an area
  /// grants its reward in the same state change.
  RestoreResult? restore(PlayerState s, String itemId) {
    if (s.restoredItems.contains(itemId)) return null;
    final area = areas
        .where((a) => a.items.any((i) => i.id == itemId))
        .firstOrNull;
    if (area == null) return null;
    if (!isUnlocked(s, area)) return null;
    final item = area.items.firstWhere((i) => i.id == itemId);
    final cost = costOf(item);
    if (s.coins < cost) return null;
    var next = s.copyWith(
      coins: s.coins - cost,
      restoredItems: {...s.restoredItems, itemId},
    );
    BazaarArea? completed;
    if (isComplete(next, area) && !next.claimedAreas.contains(area.id)) {
      completed = area;
      final boosters = {...next.boosters};
      area.rewardBoosters.forEach(
        (t, n) => boosters[t] = (boosters[t] ?? 0) + n,
      );
      next = next.copyWith(
        coins: next.coins + area.rewardCoins,
        boosters: boosters,
        claimedAreas: {...next.claimedAreas, area.id},
      );
    }
    return RestoreResult(next, cost: cost, completedArea: completed);
  }
}
