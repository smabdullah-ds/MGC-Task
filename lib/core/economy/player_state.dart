import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:meta/meta.dart';

/// Player settings.
@immutable
final class PlayerSettings {
  /// Creates settings.
  const new({
    this.sound = true,
    this.music = true,
    this.haptics = true,
    this.colorblind = false,
    this.localeCode,
    this.notificationsOptIn = false,
    this.notificationsAsked = false,
  });

  /// Decodes settings.
  factory fromJson(Map<String, Object?> j) => PlayerSettings(
    sound: j['sound'] as bool? ?? true,
    music: j['music'] as bool? ?? true,
    haptics: j['haptics'] as bool? ?? true,
    colorblind: j['colorblind'] as bool? ?? false,
    localeCode: j['locale'] as String?,
    notificationsOptIn: j['notif'] as bool? ?? false,
    notificationsAsked: j['notifAsked'] as bool? ?? false,
  );

  /// SFX on.
  final bool sound;

  /// Music on.
  final bool music;

  /// Haptics on.
  final bool haptics;

  /// Shapes/patterns on every item.
  final bool colorblind;

  /// Chosen language, `null` = follow the device.
  final String? localeCode;

  /// Player opted into reminders.
  final bool notificationsOptIn;

  /// Opt-in prompt already shown.
  final bool notificationsAsked;

  /// Copy with changes. Pass [clearLocale] to go back to the device locale.
  PlayerSettings copyWith({
    bool? sound,
    bool? music,
    bool? haptics,
    bool? colorblind,
    String? localeCode,
    bool clearLocale = false,
    bool? notificationsOptIn,
    bool? notificationsAsked,
  }) => PlayerSettings(
    sound: sound ?? this.sound,
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
    colorblind: colorblind ?? this.colorblind,
    localeCode: clearLocale ? null : localeCode ?? this.localeCode,
    notificationsOptIn: notificationsOptIn ?? this.notificationsOptIn,
    notificationsAsked: notificationsAsked ?? this.notificationsAsked,
  );

  /// Encodes settings.
  Map<String, Object?> toJson() => {
    'sound': sound,
    'music': music,
    'haptics': haptics,
    'colorblind': colorblind,
    'locale': localeCode,
    'notif': notificationsOptIn,
    'notifAsked': notificationsAsked,
  };
}

/// Daily login, daily challenge and free spin bookkeeping. Dates are local
/// calendar days formatted `yyyy-mm-dd`.
@immutable
final class DailyState {
  /// Creates daily state.
  const new({
    this.lastLoginClaim,
    this.loginDay = 0,
    this.lastChallengeWin,
    this.challengeStreak = 0,
    this.lastFreeSpin,
  });

  /// Decodes daily state.
  factory fromJson(Map<String, Object?> j) => DailyState(
    lastLoginClaim: j['lastLogin'] as String?,
    loginDay: j['loginDay'] as int? ?? 0,
    lastChallengeWin: j['lastChallenge'] as String?,
    challengeStreak: j['challengeStreak'] as int? ?? 0,
    lastFreeSpin: j['lastSpin'] as String?,
  );

  /// Day the login reward was last claimed.
  final String? lastLoginClaim;

  /// Index (0–6) of the next calendar reward.
  final int loginDay;

  /// Day the daily challenge was last won.
  final String? lastChallengeWin;

  /// Consecutive days the challenge was won.
  final int challengeStreak;

  /// Day the free spin was last used.
  final String? lastFreeSpin;

  /// Copy with changes.
  DailyState copyWith({
    String? lastLoginClaim,
    int? loginDay,
    String? lastChallengeWin,
    int? challengeStreak,
    String? lastFreeSpin,
  }) => DailyState(
    lastLoginClaim: lastLoginClaim ?? this.lastLoginClaim,
    loginDay: loginDay ?? this.loginDay,
    lastChallengeWin: lastChallengeWin ?? this.lastChallengeWin,
    challengeStreak: challengeStreak ?? this.challengeStreak,
    lastFreeSpin: lastFreeSpin ?? this.lastFreeSpin,
  );

  /// Encodes daily state.
  Map<String, Object?> toJson() => {
    'lastLogin': lastLoginClaim,
    'loginDay': loginDay,
    'lastChallenge': lastChallengeWin,
    'challengeStreak': challengeStreak,
    'lastSpin': lastFreeSpin,
  };
}

/// Purchases and entitlements. [grantedTransactions] makes grants
/// idempotent: a transaction id is granted at most once, ever.
@immutable
final class PurchaseState {
  /// Creates purchase state.
  const new({
    this.grantedTransactions = const <String>{},
    this.removeAds = false,
    this.vipExpiresAt,
    this.lastVipGrant,
    this.starterPackBought = false,
    this.starterOfferStartedAt,
    this.isPayer = false,
  });

  /// Decodes purchase state.
  factory fromJson(Map<String, Object?> j) => PurchaseState(
    grantedTransactions: {
      for (final t in (j['tx'] as List<Object?>?) ?? const <Object?>[])
        t! as String,
    },
    removeAds: j['removeAds'] as bool? ?? false,
    vipExpiresAt: _date(j['vipUntil']),
    lastVipGrant: j['lastVipGrant'] as String?,
    starterPackBought: j['starterBought'] as bool? ?? false,
    starterOfferStartedAt: _date(j['starterStart']),
    isPayer: j['payer'] as bool? ?? false,
  );

  /// Transaction ids already granted.
  final Set<String> grantedTransactions;

  /// Interstitials and banners are off.
  final bool removeAds;

  /// End of the current VIP period.
  final DateTime? vipExpiresAt;

  /// Day the VIP daily bonus was last granted.
  final String? lastVipGrant;

  /// Starter pack already bought.
  final bool starterPackBought;

  /// When the 48 h starter-pack window opened.
  final DateTime? starterOfferStartedAt;

  /// Has ever paid.
  final bool isPayer;

  /// Whether VIP is active at [now].
  bool vipActiveAt(DateTime now) =>
      vipExpiresAt != null && now.isBefore(vipExpiresAt!);

  /// Copy with changes.
  PurchaseState copyWith({
    Set<String>? grantedTransactions,
    bool? removeAds,
    DateTime? vipExpiresAt,
    bool clearVip = false,
    String? lastVipGrant,
    bool? starterPackBought,
    DateTime? starterOfferStartedAt,
    bool? isPayer,
  }) => PurchaseState(
    grantedTransactions: grantedTransactions ?? this.grantedTransactions,
    removeAds: removeAds ?? this.removeAds,
    vipExpiresAt: clearVip ? null : vipExpiresAt ?? this.vipExpiresAt,
    lastVipGrant: lastVipGrant ?? this.lastVipGrant,
    starterPackBought: starterPackBought ?? this.starterPackBought,
    starterOfferStartedAt: starterOfferStartedAt ?? this.starterOfferStartedAt,
    isPayer: isPayer ?? this.isPayer,
  );

  /// Encodes purchase state.
  Map<String, Object?> toJson() => {
    'tx': grantedTransactions.toList()..sort(),
    'removeAds': removeAds,
    'vipUntil': vipExpiresAt?.toIso8601String(),
    'lastVipGrant': lastVipGrant,
    'starterBought': starterPackBought,
    'starterStart': starterOfferStartedAt?.toIso8601String(),
    'payer': isPayer,
  };

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}

/// The most recent win, kept so the "2× coins" offer can be honoured once
/// even if the app is killed on the win screen.
@immutable
final class LastWin {
  /// Creates a record.
  const new({required this.level, required this.coins, this.doubled = false});

  /// Decodes a record.
  factory fromJson(Map<String, Object?> j) => LastWin(
    level: j['level']! as int,
    coins: j['coins']! as int,
    doubled: j['doubled'] as bool? ?? false,
  );

  /// Level number.
  final int level;

  /// Coins already granted for it.
  final int coins;

  /// Whether the 2× bonus was claimed.
  final bool doubled;

  /// Encodes the record.
  Map<String, Object?> toJson() => {
    'level': level,
    'coins': coins,
    'doubled': doubled,
  };
}

/// Everything persisted for a player. Immutable; saved as one JSON document
/// so each save is atomic.
@immutable
final class PlayerState {
  /// Creates a state.
  const new({
    this.nextLevel = 1,
    this.stars = const <int, int>{},
    this.coins = 0,
    this.boosters = const <BoosterType, int>{},
    this.restoredItems = const <String>{},
    this.claimedAreas = const <String>{},
    this.daily = const DailyState(),
    this.purchases = const PurchaseState(),
    this.settings = const PlayerSettings(),
    this.lastWin,
    this.installedAt,
    this.levelsCompleted = 0,
    this.tutorialStepsSeen = const <String>{},
  });

  /// Decodes a state already migrated to [schemaVersion].
  factory fromJson(Map<String, Object?> j) {
    Map<String, Object?> obj(String k) =>
        ((j[k] as Map<Object?, Object?>?) ?? const <Object?, Object?>{})
            .cast<String, Object?>();
    final boosterJson = obj('boosters');
    final starsJson = obj('stars');
    return PlayerState(
      nextLevel: j['nextLevel'] as int? ?? 1,
      stars: {
        for (final e in starsJson.entries) int.parse(e.key): e.value! as int,
      },
      coins: j['coins'] as int? ?? 0,
      boosters: {
        for (final b in BoosterType.values)
          if (boosterJson[b.name] case final int v) b: v,
      },
      restoredItems: _strings(j['restored']),
      claimedAreas: _strings(j['areas']),
      daily: DailyState.fromJson(obj('daily')),
      purchases: PurchaseState.fromJson(obj('purchases')),
      settings: PlayerSettings.fromJson(obj('settings')),
      lastWin: j['lastWin'] == null ? null : LastWin.fromJson(obj('lastWin')),
      installedAt: j['installedAt'] is String
          ? DateTime.tryParse(j['installedAt']! as String)
          : null,
      levelsCompleted: j['levelsCompleted'] as int? ?? 0,
      tutorialStepsSeen: _strings(j['tutorial']),
    );
  }

  /// Current save schema version. Bump it and add a migration in
  /// `save_migrations.dart` whenever the JSON shape changes.
  static const int schemaVersion = 2;

  /// Highest unlocked level (1-based).
  final int nextLevel;

  /// Best stars per completed level.
  final Map<int, int> stars;

  /// Coin balance.
  final int coins;

  /// Owned booster charges.
  final Map<BoosterType, int> boosters;

  /// Restored bazaar item ids.
  final Set<String> restoredItems;

  /// Bazaar areas whose completion reward was claimed.
  final Set<String> claimedAreas;

  /// Daily systems.
  final DailyState daily;

  /// Purchases and entitlements.
  final PurchaseState purchases;

  /// Settings.
  final PlayerSettings settings;

  /// Most recent win (for the 2× coins offer).
  final LastWin? lastWin;

  /// First launch time.
  final DateTime? installedAt;

  /// Levels completed (including replays).
  final int levelsCompleted;

  /// Tutorial steps already shown.
  final Set<String> tutorialStepsSeen;

  /// Booster charges owned of [type].
  int boosterCount(BoosterType type) => boosters[type] ?? 0;

  /// Total stars earned.
  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  /// Copy with changes.
  PlayerState copyWith({
    int? nextLevel,
    Map<int, int>? stars,
    int? coins,
    Map<BoosterType, int>? boosters,
    Set<String>? restoredItems,
    Set<String>? claimedAreas,
    DailyState? daily,
    PurchaseState? purchases,
    PlayerSettings? settings,
    LastWin? lastWin,
    DateTime? installedAt,
    int? levelsCompleted,
    Set<String>? tutorialStepsSeen,
  }) => PlayerState(
    nextLevel: nextLevel ?? this.nextLevel,
    stars: stars ?? this.stars,
    coins: coins ?? this.coins,
    boosters: boosters ?? this.boosters,
    restoredItems: restoredItems ?? this.restoredItems,
    claimedAreas: claimedAreas ?? this.claimedAreas,
    daily: daily ?? this.daily,
    purchases: purchases ?? this.purchases,
    settings: settings ?? this.settings,
    lastWin: lastWin ?? this.lastWin,
    installedAt: installedAt ?? this.installedAt,
    levelsCompleted: levelsCompleted ?? this.levelsCompleted,
    tutorialStepsSeen: tutorialStepsSeen ?? this.tutorialStepsSeen,
  );

  /// Encodes the state, stamped with [schemaVersion].
  Map<String, Object?> toJson() => {
    'v': schemaVersion,
    'nextLevel': nextLevel,
    'stars': {for (final e in stars.entries) '${e.key}': e.value},
    'coins': coins,
    'boosters': {for (final e in boosters.entries) e.key.name: e.value},
    'restored': restoredItems.toList()..sort(),
    'areas': claimedAreas.toList()..sort(),
    'daily': daily.toJson(),
    'purchases': purchases.toJson(),
    'settings': settings.toJson(),
    'lastWin': lastWin?.toJson(),
    'installedAt': installedAt?.toIso8601String(),
    'levelsCompleted': levelsCompleted,
    'tutorial': tutorialStepsSeen.toList()..sort(),
  };

  static Set<String> _strings(Object? v) => {
    for (final s in (v as List<Object?>?) ?? const <Object?>[]) s! as String,
  };
}
