import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/locale/locale_cubit.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/presentation/cubit/profile_privacy_cubit.dart';
import 'package:barz/features/home/presentation/cubit/profile_settings_cubit.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});
  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage>
    with WidgetsBindingObserver {
  PermissionStatus? _permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (kIsWeb ||
        !{
          TargetPlatform.iOS,
          TargetPlatform.android,
        }.contains(defaultTargetPlatform)) {
      return;
    }
    try {
      final permission = await Permission.notification.status;
      if (mounted) setState(() => _permission = permission);
    } catch (_) {
      /* Permission status is unavailable on unsupported runtimes. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileSettingsCubit, ProfileSettingsState>(
      builder: (context, state) {
        final cubit = context.read<ProfileSettingsCubit>();
        final prefs = state.preferences;
        return ProfileFrame(
          title: l10n.profile_settings,
          children: [
            if (_permission != null &&
                !_permission!.isGranted &&
                !_permission!.isProvisional)
              ProfileGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(BarzSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.profile_os_permission),
                        TextButton(
                          onPressed: () => openAppSettings(),
                          child: Text(l10n.profile_open_settings),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (state.loading)
              const BarzLoadingWidget()
            else if (prefs == null) ...[
              Text(l10n.profile_load_failed),
              TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
            ] else ...[
              ProfileGroup(
                title: l10n.profile_notifications,
                children: [
                  SwitchListTile.adaptive(
                    title: Text(l10n.profile_push),
                    value: prefs.pushNotificationsEnabled,
                    onChanged: state.saving
                        ? null
                        : (value) => cubit.change(
                            prefs.copyWith(pushNotificationsEnabled: value),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(l10n.profile_order_updates),
                    value: prefs.orderUpdatesEnabled,
                    onChanged: state.saving || !prefs.pushNotificationsEnabled
                        ? null
                        : (value) => cubit.change(
                            prefs.copyWith(orderUpdatesEnabled: value),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(l10n.profile_promotions),
                    value: prefs.promotionsEnabled,
                    onChanged: state.saving || !prefs.pushNotificationsEnabled
                        ? null
                        : (value) => cubit.change(
                            prefs.copyWith(promotionsEnabled: value),
                          ),
                  ),
                ],
              ),
              if (state.failed)
                Semantics(
                  liveRegion: true,
                  child: Text(l10n.profile_action_failed),
                ),
              if (state.saved)
                Semantics(liveRegion: true, child: Text(l10n.profile_saved)),
              ProfilePrimaryButton(
                label: l10n.save,
                busy: state.saving,
                onPressed: cubit.save,
              ),
            ],
            const _PrivacySection(),
            BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) => ProfileGroup(
                title: l10n.settings_language,
                children: [
                  for (final language in [
                    ('pt', l10n.profile_portuguese),
                    ('en', 'English'),
                    ('es', 'Español'),
                  ])
                    ListTile(
                      title: Text(language.$2),
                      selected: locale.languageCode == language.$1,
                      leading: Icon(
                        locale.languageCode == language.$1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => context.read<LocaleCubit>().setLanguageCode(
                        language.$1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Persisted location/data-sharing choices. Owns its cubit so the screen works
/// without the user feature registered (tests); hidden then, never faked.
class _PrivacySection extends StatefulWidget {
  const _PrivacySection();
  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  ProfilePrivacyCubit? _cubit;

  @override
  void initState() {
    super.initState();
    if (getItInjector.isRegistered<UserUsecase>()) {
      _cubit = ProfilePrivacyCubit(getItInjector<UserUsecase>())..load();
    }
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ProfilePrivacyCubit, ProfilePrivacyState>(
      bloc: cubit,
      builder: (context, state) {
        final s = state.settings;
        if (state.loading) return const BarzLoadingWidget();
        if (s == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.profile_load_failed),
              TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileGroup(
              title: l10n.profile_privacy_preferences,
              children: [
                SwitchListTile.adaptive(
                  title: Text(l10n.profile_privacy_location),
                  value: s.locationEnabled,
                  onChanged: state.saving
                      ? null
                      : (v) => cubit.change(s.copyWith(locationEnabled: v)),
                ),
                SwitchListTile.adaptive(
                  title: Text(l10n.profile_privacy_data),
                  value: s.dataSharingEnabled,
                  onChanged: state.saving
                      ? null
                      : (v) => cubit.change(s.copyWith(dataSharingEnabled: v)),
                ),
              ],
            ),
            const SizedBox(height: BarzSpacing.md),
            if (state.failed)
              Semantics(
                liveRegion: true,
                child: Text(l10n.profile_action_failed),
              ),
            if (state.saved)
              Semantics(liveRegion: true, child: Text(l10n.profile_saved)),
            ProfilePrimaryButton(
              label: l10n.save,
              busy: state.saving,
              onPressed: cubit.save,
            ),
          ],
        );
      },
    );
  }
}
