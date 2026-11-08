import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/home/presentation/cubit/profile_benefits_cubit.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:barz/features/user/domain/models/profile_benefit.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

/// Owned benefits from the authenticated backend inventory (C04-AC07).
/// Selecting a benefit only navigates; it never redeems or applies it.
class ProfileBenefitsPage extends StatelessWidget {
  const ProfileBenefitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileBenefitsCubit, ProfileBenefitsState>(
      builder: (context, state) {
        final children = <Widget>[];
        switch (state.status) {
          case BenefitsLoadStatus.loading:
            children.add(const BarzLoadingWidget());
          case BenefitsLoadStatus.unauthorized:
            children.add(
              BenefitsMessage(
                text: l10n.profile_benefits_unauthorized,
                onRetry: () => AppRoute.login.go(context),
                retryLabel: l10n.profile_sign_in_again,
              ),
            );
          case BenefitsLoadStatus.failed:
            children.add(
              BenefitsMessage(
                text: l10n.profile_benefits_load_failed,
                onRetry: () => context.read<ProfileBenefitsCubit>().load(),
                retryLabel: l10n.retry,
              ),
            );
          case BenefitsLoadStatus.loaded:
            final data = state.data!;
            if (data.activeCount == 0) {
              children.add(Text(l10n.profile_benefits_empty));
            }
            children.add(
              ProfileGroup(
                children: [
                  for (final b in data.benefits) _BenefitRow(benefit: b),
                ],
              ),
            );
            children.add(
              Text(
                l10n.profile_benefit_open_note,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.dobarColors.labelSecondary,
                ),
              ),
            );
        }
        return ProfileFrame(title: l10n.profile_benefits, children: children);
      },
    );
  }
}

class BenefitsMessage extends StatelessWidget {
  const BenefitsMessage({
    super.key,
    required this.text,
    required this.onRetry,
    required this.retryLabel,
  });
  final String text;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(liveRegion: true, child: Text(text)),
      TextButton(onPressed: onRetry, child: Text(retryLabel)),
    ],
  );
}

String benefitTitle(AppLocalizations l10n, ProfileBenefit b) =>
    b.kind == BenefitKind.cashback
    ? l10n.profile_benefit_cashback
    : l10n.profile_benefit_pro_coupon;

String? benefitReason(AppLocalizations l10n, String? reason) => switch (reason) {
  'pro_required' => l10n.profile_benefit_unavailable_pro_required,
  'allowance_exhausted' => l10n.profile_benefit_unavailable_allowance_exhausted,
  'no_eligible_venues' => l10n.profile_benefit_unavailable_no_eligible_venues,
  'zero_balance' => l10n.profile_benefit_unavailable_zero_balance,
  'pending_clearance' => l10n.profile_benefit_unavailable_pending_clearance,
  _ => null,
};

/// Unknown condition codes are skipped rather than shown raw.
String? benefitCondition(AppLocalizations l10n, String code) => switch (code) {
  'pro_required' => l10n.profile_benefit_condition_pro_required,
  'monthly_limit_no_rollover' =>
    l10n.profile_benefit_condition_monthly_limit_no_rollover,
  'cashback_promotions_only' =>
    l10n.profile_benefit_condition_cashback_promotions_only,
  'venue_funded_only' => l10n.profile_benefit_condition_venue_funded_only,
  'wallet_balance' => l10n.profile_benefit_condition_wallet_balance,
  _ => null,
};

String _money(String locale, int cents) => NumberFormat.currency(
  locale: locale,
  name: 'BRL',
  symbol: 'R\$',
).format(cents / 100);

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});
  final ProfileBenefit benefit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final b = benefit;
    final lines = <String>[
      if (b.unit == BenefitUnit.coupon)
        l10n.profile_benefit_coupons_remaining(b.remaining, b.limit ?? 0)
      else ...[
        l10n.profile_benefit_cashback_available(_money(locale, b.remaining)),
        if ((b.pending ?? 0) > 0)
          l10n.profile_benefit_cashback_pending(_money(locale, b.pending!)),
      ],
      if (!b.active) ?benefitReason(l10n, b.unavailableReason),
      if (b.expiresAt != null)
        l10n.profile_benefit_expires(
          DateFormat.yMMMd(locale).format(b.expiresAt!.toLocal()),
        ),
      if (b.active && b.kind == BenefitKind.cashback && !b.venueFilterSupported)
        l10n.profile_benefit_venues_undefined,
      for (final c in b.conditions) ?benefitCondition(l10n, c),
    ];
    return ProfileRow(
      icon: b.kind == BenefitKind.cashback
          ? LucideIcons.wallet
          : LucideIcons.ticket,
      title: benefitTitle(l10n, b),
      subtitle: lines.join('\n'),
      // Only an active benefit with an authoritative venue rule is navigable.
      onTap: b.canOpenVenues
          ? () => AppRoute.pushBenefitVenues(context, b.id)
          : null,
    );
  }
}
