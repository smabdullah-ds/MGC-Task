import 'package:flutter/foundation.dart';

/// Ad formats the game uses.
enum AdFormat { rewarded, interstitial, banner, appOpen }

/// Where a rewarded ad is offered. Logged as the `placement` parameter.
enum RewardedPlacement {
  hint,
  extraShelf,
  undoRefill,
  doubleCoins,
  dailySpin,
  extraMoves,
  shuffle,
}

/// Lifecycle events emitted by [AdFormat] loads and shows, for analytics.
enum AdEventType {
  request,
  loaded,
  failedToLoad,
  impression,
  rewardGranted,
  failedToShow,
  dismissed,
}

/// An ad lifecycle event.
@immutable
class AdEvent {
  /// Creates an event.
  const new({
    required this.type,
    required this.format,
    required this.placement,
    this.network,
    this.valueMicros,
    this.currency,
    this.errorMessage,
  });

  /// What happened.
  final AdEventType type;

  /// Which format.
  final AdFormat format;

  /// Placement name (e.g. `hint`, `level_complete`).
  final String placement;

  /// Mediation network that served the ad, if known.
  final String? network;

  /// Impression value in micros (from the paid-event callback).
  final int? valueMicros;

  /// ISO currency of [valueMicros].
  final String? currency;

  /// Error description for failures.
  final String? errorMessage;
}

/// Whether ads may be personalised; result of the consent flow.
enum AdPersonalization { personalized, nonPersonalized, none }
