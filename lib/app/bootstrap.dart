import 'dart:async';

import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/services/storage/hive_storage_service.dart';
import 'package:bazaar_sort/services/storage/memory_storage_service.dart';
import 'package:bazaar_sort/services/storage/storage_service.dart';
import 'package:flutter/foundation.dart';
// Riverpod 3 exposes Override from the misc library.
import 'package:flutter_riverpod/misc.dart' show Override;

/// Creates the real services and returns the provider overrides that swap
/// them in for the fakes. Only work that must finish before the first frame
/// happens here (opening the save file); everything slow runs later in
/// `Startup` behind the splash screen.
Future<List<Override>> bootstrap() async {
  StorageService storage = HiveStorageService();
  try {
    await storage.initialize();
  } on Object catch (e) {
    // Never block the game on storage: play with an in-memory save and
    // report the problem.
    debugPrint('storage init failed: $e');
    storage = MemoryStorageService();
  }

  final feedback = FlameFeedbackService();
  unawaited(feedback.initialize());

  return [
    storageServiceProvider.overrideWithValue(storage),
    feedbackServiceProvider.overrideWithValue(feedback),
  ];
}
