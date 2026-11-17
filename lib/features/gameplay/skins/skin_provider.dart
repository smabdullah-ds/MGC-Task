import 'package:bazaar_sort/features/gameplay/skins/item_skin.dart';
import 'package:bazaar_sort/features/gameplay/skins/vector_item_skin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The active item art. Override this provider to ship a different skin
/// (e.g. sprite art) without touching game logic.
final itemSkinProvider = Provider<ItemSkin>((ref) => const VectorItemSkin());
