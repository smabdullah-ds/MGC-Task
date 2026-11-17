import 'dart:async';

import 'package:bazaar_sort/app/router.dart';
import 'package:bazaar_sort/app/theme.dart';
import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/features/daily/reminder_scheduler.dart';
import 'package:bazaar_sort/features/gameplay/level_flow.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/features/player/session_tasks.dart';
import 'package:bazaar_sort/features/settings/locales.dart';
import 'package:bazaar_sort/l10n/gen/app_localizations.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Root widget: theme, localisation (with an in-game language override) and
/// app lifecycle hooks.
class BazaarSortApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BazaarSortApp> createState() => _BazaarSortAppState();
}

class _BazaarSortAppState extends ConsumerState<BazaarSortApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _onPause, onResume: _onResume);
  }

  void _onPause() {
    ref.read(feedbackServiceProvider).pauseMusic();
    unawaited(ref.read(playerProvider.notifier).flush());
    unawaited(ref.read(reminderSchedulerProvider).reschedule());
  }

  void _onResume() {
    ref.read(feedbackServiceProvider).resumeMusic();
    unawaited(ref.read(sessionTasksProvider).onAppOpen());
    unawaited(_maybeShowAppOpenAd());
  }

  /// App-open ads (Remote Config switch, off by default): only for returning
  /// players past the tutorial, never for ad-free players, and never within
  /// the interstitial cooldown.
  Future<void> _maybeShowAppOpenAd() async {
    final rc = ref.read(remoteConfigServiceProvider);
    if (!rc.getBool(RcKeys.appOpenEnabled)) return;
    final player = ref.read(playerProvider);
    final now = DateTime.now();
    if (player.purchases.removeAds || player.purchases.vipActiveAt(now)) return;
    final policy = ref.read(levelFlowProvider).policy;
    if (player.nextLevel <= policy.config.minLevel) return;
    final last = policy.lastRewardedAt;
    if (last != null && now.difference(last) < policy.config.afterRewarded) {
      return;
    }
    if (await ref.read(adsServiceProvider).showAppOpen()) {
      policy.recordShown(DateTime.now());
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(
      playerProvider.select((p) => p.settings.localeCode),
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: localeCode == null ? null : Locale(localeCode),
      // Material widgets come from material_ui, whose localizations live in
      // its own GlobalMaterialLocalizations (the generated list points at
      // flutter_localizations' copies, which material_ui widgets don't read).
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: appSupportedLocales,
    );
  }
}
