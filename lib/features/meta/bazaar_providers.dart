import 'package:bazaar_sort/core/economy/bazaar_catalog.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bazaar catalog with live cost multiplier.
final bazaarCatalogProvider = Provider<BazaarCatalog>(
  (ref) => BazaarCatalog(
    multiplier: ref.watch(economyConfigProvider).bazaarCostMultiplier,
  ),
);
