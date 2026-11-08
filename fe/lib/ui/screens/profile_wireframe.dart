import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/presentation/cubit/profile_benefits_cubit.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Profile translation of pixel-perfect-replica; see the C04 source handoff.
class ProfileWireframe extends StatefulWidget {
  const ProfileWireframe({super.key});

  @override
  State<ProfileWireframe> createState() => _ProfileWireframeState();
}

class _ProfileWireframeState extends State<ProfileWireframe> {
  bool _signingOut = false;

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await confirmProfileAction(
      context,
      l10n.profile_logout,
      l10n.profile_logout_body,
    )) {
      return;
    }
    setState(() => _signingOut = true);
    try {
      await getItInjector<SessionBloc>().signOut();
      if (mounted) AppRoute.login.go(context);
    } catch (_) {
      if (mounted) {
        setState(() => _signingOut = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profile_action_failed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ProfileFrame(
      title: l10n.profile_bnb_item_title,
      root: true,
      children: [
        ProfileGroup(
          accent: true,
          children: [
            ProfileRow(
              icon: LucideIcons.user_round,
              title: l10n.profile_account,
              subtitle: l10n.profile_account_subtitle,
              accent: true,
              onTap: () => AppRoute.profileEdit.push(context),
            ),
          ],
        ),
        ProfileGroup(
          title: l10n.profile_activity,
          children: [
            ProfileRow(
              icon: LucideIcons.receipt,
              title: l10n.profile_orders,
              onTap: () => AppRoute.orders.push(context),
            ),
            const _BenefitsEntry(),
          ],
        ),
        ProfileGroup(
          title: l10n.profile_preferences,
          children: [
            ProfileRow(
              icon: LucideIcons.credit_card,
              title: l10n.profile_payments,
              onTap: () => AppRoute.profilePayments.push(context),
            ),
            ProfileRow(
              icon: LucideIcons.settings,
              title: l10n.profile_settings,
              onTap: () => AppRoute.profileSettings.push(context),
            ),
          ],
        ),
        ProfileGroup(
          children: [
            ProfileRow(
              icon: LucideIcons.file_text,
              title: l10n.profile_terms,
              onTap: () => AppRoute.termsOfService.push(context),
            ),
            ProfileRow(
              icon: LucideIcons.shield,
              title: l10n.profile_privacy,
              onTap: () => AppRoute.privacyPolicy.push(context),
            ),
            ProfileRow(
              icon: LucideIcons.log_out,
              title: l10n.profile_logout,
              destructive: true,
              onTap: _signingOut ? null : _logout,
            ),
          ],
        ),
      ],
    );
  }
}

/// Benefits row showing the real active count once the authenticated
/// inventory answers; no count while loading, failed or unavailable.
class _BenefitsEntry extends StatefulWidget {
  const _BenefitsEntry();
  @override
  State<_BenefitsEntry> createState() => _BenefitsEntryState();
}

class _BenefitsEntryState extends State<_BenefitsEntry> {
  ProfileBenefitsCubit? _cubit;

  @override
  void initState() {
    super.initState();
    if (getItInjector.isRegistered<UserUsecase>()) {
      _cubit = ProfileBenefitsCubit(getItInjector<UserUsecase>())..load();
    }
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget row(int? count) => ProfileRow(
      icon: LucideIcons.gift,
      title: l10n.profile_benefits,
      subtitle: count == null ? null : l10n.profile_benefits_count(count),
      onTap: () async {
        await AppRoute.profileBenefits.push(context);
        _cubit?.load();
      },
    );
    final cubit = _cubit;
    if (cubit == null) return row(null);
    return BlocBuilder<ProfileBenefitsCubit, ProfileBenefitsState>(
      bloc: cubit,
      builder: (_, state) => row(state.activeCount),
    );
  }
}
