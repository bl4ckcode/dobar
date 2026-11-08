import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/home/presentation/cubit/profile_benefits_cubit.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_benefits_page.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:barz/features/user/domain/models/profile_benefit.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Venues eligible for the selected benefit only. Opening a venue never
/// redeems, reserves or applies the benefit.
class ProfileBenefitVenuesPage extends StatelessWidget {
  const ProfileBenefitVenuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<BenefitVenuesCubit, BenefitVenuesState>(
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
                onRetry: () => context.read<BenefitVenuesCubit>().load(),
                retryLabel: l10n.retry,
              ),
            );
          case BenefitsLoadStatus.loaded:
            final data = state.data!;
            final conditions = [
              for (final c in data.conditions) ?benefitCondition(l10n, c),
            ];
            if (conditions.isNotEmpty) {
              children.add(
                Semantics(
                  container: true,
                  child: Text(
                    conditions.join('\n'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.dobarColors.labelSecondary,
                    ),
                  ),
                ),
              );
            }
            if (data.venues.isEmpty) {
              children.add(Text(l10n.profile_benefit_venues_empty));
            } else {
              children.add(
                ProfileGroup(
                  children: [
                    for (final v in data.venues) _VenueRow(venue: v),
                  ],
                ),
              );
            }
            children.add(
              Text(
                l10n.profile_benefit_open_note,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.dobarColors.labelSecondary,
                ),
              ),
            );
        }
        return ProfileFrame(
          title: l10n.profile_benefit_venues_title,
          children: children,
        );
      },
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venue});
  final BenefitVenue venue;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (venue.address != null) venue.address!,
      for (final p in venue.promotions) ...[
        p.benefitText ?? p.title,
        if (p.terms != null) p.terms!,
      ],
    ];
    return ProfileRow(
      icon: LucideIcons.store,
      title: venue.name ?? '',
      subtitle: lines.join('\n'),
      onTap: () => AppRoute.pushBar(context, venue.barId),
    );
  }
}
