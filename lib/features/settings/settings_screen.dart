import 'dart:async';

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/config/env.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/features/daily/reminder_scheduler.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/features/settings/locales.dart';
import 'package:bazaar_sort/features/shop/shop_controller.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// App version string; overridable in tests.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } on Object {
    return '—';
  }
});

/// Sound, music, haptics, colourblind mode, reminders, language, privacy
/// policy, consent management, support and version.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _set(
    WidgetRef ref,
    String name,
    Object value,
    PlayerSettings Function(PlayerSettings) change,
  ) async {
    final s = await ref
        .read(playerProvider.notifier)
        .update((p) => p.copyWith(settings: change(p.settings)));
    if (s != null) {
      ref
          .read(feedbackServiceProvider)
          .configure(
            sound: s.settings.sound,
            music: s.settings.music,
            haptics: s.settings.haptics,
          );
    }
    ref
        .read(gameAnalyticsProvider)
        .settingsChanged(setting: name, value: '$value');
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.couldNotOpen;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Object {
      // Fall through to the message.
    }
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(playerProvider.select((p) => p.settings));
    final version = ref.watch(appVersionProvider).value ?? '…';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: BazaarBackground(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _Header(l10n.settingsAudio),
            SwitchListTile(
              key: const ValueKey('settings_sound'),
              secondary: const Icon(Icons.volume_up_rounded),
              title: Text(l10n.settingsSound),
              value: s.sound,
              onChanged: (v) =>
                  _set(ref, 'sound', v, (x) => x.copyWith(sound: v)),
            ),
            SwitchListTile(
              key: const ValueKey('settings_music'),
              secondary: const Icon(Icons.music_note_rounded),
              title: Text(l10n.settingsMusic),
              value: s.music,
              onChanged: (v) =>
                  _set(ref, 'music', v, (x) => x.copyWith(music: v)),
            ),
            SwitchListTile(
              key: const ValueKey('settings_haptics'),
              secondary: const Icon(Icons.vibration_rounded),
              title: Text(l10n.settingsHaptics),
              value: s.haptics,
              onChanged: (v) =>
                  _set(ref, 'haptics', v, (x) => x.copyWith(haptics: v)),
            ),
            _Header(l10n.settingsGameplay),
            SwitchListTile(
              key: const ValueKey('settings_colorblind'),
              secondary: const Icon(Icons.visibility_rounded),
              title: Text(l10n.settingsColorblind),
              subtitle: Text(l10n.settingsColorblindHint),
              value: s.colorblind,
              onChanged: (v) =>
                  _set(ref, 'colorblind', v, (x) => x.copyWith(colorblind: v)),
            ),
            SwitchListTile(
              key: const ValueKey('settings_notifications'),
              secondary: const Icon(Icons.notifications_rounded),
              title: Text(l10n.settingsNotifications),
              subtitle: Text(l10n.settingsNotificationsHint),
              value: s.notificationsOptIn,
              onChanged: (v) {
                final scheduler = ref.read(reminderSchedulerProvider);
                unawaited(v ? scheduler.optIn() : scheduler.optOut());
              },
            ),
            ListTile(
              key: const ValueKey('settings_language'),
              leading: const Icon(Icons.language_rounded),
              title: Text(l10n.settingsLanguage),
              subtitle: Text(
                s.localeCode == null
                    ? l10n.settingsLanguageSystem
                    : languageName(s.localeCode!),
              ),
              onTap: () => unawaited(_pickLanguage(context, ref, s.localeCode)),
            ),
            _Header(l10n.settingsPrivacySection),
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: Text(l10n.settingsPrivacy),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _open(context, Uri.parse(Env.privacyPolicyUrl)),
            ),
            ListTile(
              key: const ValueKey('settings_consent'),
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: Text(l10n.settingsConsent),
              onTap: () async {
                final result = await ref
                    .read(consentServiceProvider)
                    .showPrivacyOptions();
                ref
                    .read(gameAnalyticsProvider)
                    .consentResult(result: result.label);
              },
            ),
            ListTile(
              key: const ValueKey('settings_restore'),
              leading: const Icon(Icons.restore_rounded),
              title: Text(l10n.settingsRestore),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final done = l10n.purchaseRestored;
                final none = l10n.purchaseNothingToRestore;
                final n = await ref.read(shopControllerProvider).restore();
                messenger.showSnackBar(
                  SnackBar(content: Text(n > 0 ? done : none)),
                );
              },
            ),
            _Header(l10n.settingsAbout),
            ListTile(
              leading: const Icon(Icons.mail_rounded),
              title: Text(l10n.settingsSupport),
              subtitle: const Text(Env.supportEmail),
              onTap: () => _open(
                context,
                Uri(
                  scheme: 'mailto',
                  path: Env.supportEmail,
                  query: 'subject=Bazaar%20Sort%20support%20($version)',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.settingsVersion(version)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final l10n = context.l10n;
    const system = '__system__';
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Palette.ivory,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            RadioGroup<String>(
              groupValue: current ?? system,
              onChanged: (v) => Navigator.pop(ctx, v),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: system,
                    title: Text(l10n.settingsLanguageSystem),
                  ),
                  for (final code in selectableLanguages())
                    RadioListTile<String>(
                      key: ValueKey('lang_$code'),
                      value: code,
                      title: Text(languageName(code)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _set(
      ref,
      'language',
      choice,
      (x) => choice == system
          ? x.copyWith(clearLocale: true)
          : x.copyWith(localeCode: choice),
    );
  }
}

class _Header extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Palette.wood,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        fontSize: 12,
      ),
    ),
  );
}
