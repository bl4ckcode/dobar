import 'package:flutter/material.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/advertising/presentation/bloc/subscription_trial_cubit.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

class ProPlanSheet extends StatelessWidget {
  const ProPlanSheet({super.key});

  /// Displays the Dobar Pro Upgrade bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProPlanSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF141414) : surfaceWhite;
    final textColor = dobar.labelPrimary;
    final mutedTextColor = dobar.labelSecondary;

    final l10n = AppLocalizations.of(context)!;

    return BlocProvider(
      create: (_) => getItInjector<SubscriptionTrialCubit>(),
      child: Container(
        padding: const EdgeInsets.only(top: 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Stack(
                    children: [
                      const Align(alignment: Alignment.center, child: _ProBadge()),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            color: mutedTextColor,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    l10n.pro_sheet_title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontFamily: 'Space Grotesk',
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    l10n.pro_sheet_description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Benefits List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _BenefitItem(
                        icon: LucideIcons.trendingUp,
                        title: 'Advanced Analytics',
                        description:
                            'Get deep insights into your audience demographics, popular times, and menu performance.',
                      ),
                      const SizedBox(height: 16),
                      _BenefitItem(
                        icon: LucideIcons.megaphone,
                        title: 'Targeted Campaigns',
                        description:
                            'Send custom push notifications directly to patrons who are near or have favorited your bar.',
                      ),
                      const SizedBox(height: 16),
                      _BenefitItem(
                        icon: LucideIcons.star,
                        title: 'Priority Placement',
                        description:
                            'Stand out in user searches and interactive maps as a promoted venue.',
                      ),
                      const SizedBox(height: 16),
                      _BenefitItem(
                        icon: LucideIcons.scanLine,
                        title: 'Unlimited Table QR',
                        description:
                            'Generate unlimited active tables and dynamic QR codes for direct ordering.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Upgrade CTA Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : surfaceDim,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? const Color(0xFF262626)
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      RichText(
                        text: TextSpan(
                          text: '\$49',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            fontFamily: 'Space Grotesk',
                          ),
                          children: [
                            TextSpan(
                              text: ' / month',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                color: mutedTextColor,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        l10n.pro_modal_footer_note,
                        style: TextStyle(fontSize: 13, color: mutedTextColor),
                      ),
                      const SizedBox(height: 20),
                      BlocConsumer<SubscriptionTrialCubit, SubscriptionTrialState>(
                        listener: (context, state) {
                          if (state.error != null && state.error!.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(state.error!),
                                  backgroundColor: errorRed),
                            );
                          } else if (state.result != null) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(l10n.subscription_upgrade_success),
                                  backgroundColor: successGreen),
                            );
                          }
                        },
                        builder: (context, state) {
                          return SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: barzGold,
                                foregroundColor: barzDark,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: state.isLoading
                                  ? null
                                  : () {
                                      final sessionState =
                                          context.read<SessionBloc>().state;
                                      if (sessionState is SessionReady &&
                                          sessionState.session.activeBar != null) {
                                        final user = sessionState.session.user;
                                        context.read<SubscriptionTrialCubit>().setupTrial(
                                              barId: sessionState
                                                  .session.activeBar!.barId,
                                              ownerId: user.id ?? 0,
                                              plan: 'MASTER', // Default to Master for trial
                                              paymentMethodId:
                                                  'pm_card_visa', // Placeholder or real ID
                                              customerEmail: user.email ?? '',
                                              customerName: user.displayName ?? '',
                                            );
                                      }
                                    },
                              child: state.isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: barzDark,
                                      ),
                                    )
                                  : Text(
                                      l10n.pro_modal_cta,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: barzGold.withValues(alpha: 0.15),
        border: Border.all(color: barzGold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.crown, size: 16, color: barzGold),
          SizedBox(width: 8),
          Text(
            'PRO',
            style: TextStyle(
              color: barzGold,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;

    final iconBg = isDark ? const Color(0xFF1E1E1E) : dobar.surfaceElevated;
    final textColor = dobar.labelPrimary;
    final descColor = dobar.labelSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: barzGold, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 14, height: 1.4, color: descColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
