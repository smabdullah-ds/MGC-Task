import 'dart:async';

import 'package:bazaar_sort/app/app.dart';
import 'package:bazaar_sort/app/bootstrap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final overrides = await bootstrap();
  runApp(ProviderScope(overrides: overrides, child: const BazaarSortApp()));
}
