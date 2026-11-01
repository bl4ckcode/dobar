import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/locale/locale_cubit.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/utils/country_helper.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/router/route_arguments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingPage extends StatelessWidget {
  final String? phoneNumber;
  const OnboardingPage({super.key, this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getItInjector<OnboardingBloc>();
        if (phoneNumber?.isNotEmpty ?? false) {
          bloc.add(DetectCountryFromPhone(phoneNumber!));
        }
        return bloc;
      },
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state.isComplete) {
          getItInjector<SessionBloc>().add(const SessionEvent.initialize());
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (state.selectedUserType == 'business') {
              context.go(
                AppRoute.createBar.path,
                extra: const CreateBarArguments(fromOnboarding: true),
              );
            } else {
              AppRoute.home.go(context);
            }
          });
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) => Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: _AtmosphericBackground()),
            const _GhostCocktail(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 480,
                        minHeight: constraints.maxHeight - 52,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: _OnboardingToolbar(),
                          ),
                          const SizedBox(height: 56),
                          const _Header()
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.08, end: 0),
                          const SizedBox(height: 36),
                          _RoleSelection(state: state),
                          const SizedBox(height: 28),
                          _CountrySelection(state: state),
                          const SizedBox(height: 28),
                          _ContinueButton(state: state),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtmosphericBackground extends StatelessWidget {
  const _AtmosphericBackground();
  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.15,
          colors: [
            barzGold.withValues(alpha: context.isDark ? 0.12 : 0.18),
            colors.background.withValues(alpha: 0),
          ],
          stops: const [0, 0.72],
        ),
      ),
    );
  }
}

class _GhostCocktail extends StatelessWidget {
  const _GhostCocktail();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: -85,
      child: IgnorePointer(
        child: Opacity(
          opacity: context.isDark ? 0.07 : 0.08,
          child: Image.asset(
            'assets/icons/cocktail-ghost.png',
            width: 380,
            height: 380,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _OnboardingToolbar extends StatelessWidget {
  const _OnboardingToolbar();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    final locale = context.watch<LocaleCubit>().state;
    final isDark = context.isDark;
    final controlStyle = IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: colors.labelSecondary,
      backgroundColor: colors.surface.withValues(alpha: 0.92),
      side: BorderSide(color: colors.surfaceElevated),
      shape: const CircleBorder(),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isDark
              ? l10n.onboarding_theme_to_light
              : l10n.onboarding_theme_to_dark,
          style: controlStyle,
          onPressed: () => context.read<ThemeCubit>().toggleTheme(),
          icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 18),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: l10n.onboarding_language_label,
          initialValue: locale.languageCode,
          onSelected: context.read<LocaleCubit>().setLanguageCode,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.surfaceElevated),
          ),
          itemBuilder: (_) => ['pt', 'en', 'es']
              .map(
                (code) => PopupMenuItem(
                  value: code,
                  child: Text(_languageName(l10n, code)),
                ),
              )
              .toList(),
          child: Semantics(
            button: true,
            label: l10n.onboarding_language_label,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.surfaceElevated),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.globe,
                    size: 17,
                    color: colors.labelSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    locale.languageCode.toUpperCase(),
                    style: TextStyle(
                      color: colors.labelPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: colors.labelSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _languageName(AppLocalizations l10n, String code) => switch (code) {
    'pt' => l10n.language_portuguese_br,
    'es' => l10n.language_spanish,
    _ => l10n.language_english,
  };
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    return Column(
      children: [
        Text(
          l10n.onboarding_welcome_title.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.oswald(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.6,
            color: colors.labelPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.onboarding_welcome_subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: colors.labelSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RoleSelection extends StatelessWidget {
  final OnboardingState state;
  const _RoleSelection({required this.state});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: l10n.onboarding_role_prompt),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final client = _RoleCard(
              icon: LucideIcons.user_round,
              title: l10n.onboarding_customer_title,
              subtitle: l10n.onboarding_customer_subtitle,
              isSelected: state.selectedUserType == 'client',
              onTap: () => context.read<OnboardingBloc>().add(
                const SelectUserType('client'),
              ),
            );
            final business = _RoleCard(
              icon: LucideIcons.store,
              title: l10n.onboarding_business_title,
              subtitle: l10n.onboarding_business_subtitle,
              isSelected: state.selectedUserType == 'business',
              onTap: () => context.read<OnboardingBloc>().add(
                const SelectUserType('business'),
              ),
            );
            if (constraints.maxWidth < 340) {
              return Column(
                children: [client, const SizedBox(height: 12), business],
              );
            }
            return IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: client),
                  const SizedBox(width: 12),
                  Expanded(child: business),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CountrySelection extends StatelessWidget {
  final OnboardingState state;
  const _CountrySelection({required this.state});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    final selected = state.selectedCountryCode == null
        ? null
        : SupportedCountry.fromCode(state.selectedCountryCode!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: l10n.onboarding_country_label),
        const SizedBox(height: 14),
        DropdownButtonFormField<SupportedCountry>(
          initialValue: selected,
          isExpanded: true,
          dropdownColor: colors.surface,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.labelSecondary),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surface.withValues(alpha: 0.94),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.surfaceElevated),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: barzGold, width: 1.5),
            ),
          ),
          hint: Row(
            children: [
              Icon(LucideIcons.globe, size: 17, color: colors.labelSecondary),
              const SizedBox(width: 10),
              Text(l10n.onboarding_country_hint),
            ],
          ),
          items: CountryHelper.allCountries
              .map(
                (country) => DropdownMenuItem(
                  value: country,
                  child: Text(
                    '${country.flag}  ${_localizedCountryName(l10n, country)}  ${country.phonePrefix}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (country) {
            if (country != null) {
              context.read<OnboardingBloc>().add(SelectCountry(country.code));
            }
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              LucideIcons.sparkles,
              size: 14,
              color: state.phoneNumber != null
                  ? barzGold
                  : colors.labelSecondary,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                state.phoneNumber != null
                    ? l10n.onboarding_country_auto_detected
                    : l10n.onboarding_country_manual,
                style: TextStyle(
                  fontSize: 12,
                  color: state.phoneNumber != null
                      ? (context.isDark ? barzGold : barzGoldDark)
                      : colors.labelSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final OnboardingState state;
  const _ContinueButton({required this.state});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  barzGold.withValues(alpha: state.canSubmit ? 1 : 0.45),
                  barzGoldDark.withValues(alpha: state.canSubmit ? 1 : 0.45),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: state.canSubmit
                  ? [
                      BoxShadow(
                        color: barzGold.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: TextButton.icon(
              onPressed: state.canSubmit
                  ? () => context.read<OnboardingBloc>().add(
                      const SubmitOnboarding(),
                    )
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: barzDark,
                disabledForegroundColor: barzDark.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              iconAlignment: IconAlignment.end,
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: barzDark,
                      ),
                    )
                  : const Icon(LucideIcons.arrow_right, size: 21),
              label: Text(
                state.isSubmitting
                    ? l10n.onboarding_submitting
                    : l10n.onboarding_continue.toUpperCase(),
                style: GoogleFonts.oswald(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
        if (!state.canSubmit && !state.isSubmitting) ...[
          const SizedBox(height: 12),
          Text(
            l10n.onboarding_choose_profile_country,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.dobarColors.labelSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.oswald(
      color: context.dobarColors.labelSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 2.4,
    ),
  );
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final border = isSelected ? barzGold : colors.surfaceElevated;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.surfaceElevated.withValues(alpha: 0.95)
                : colors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: isSelected ? 1.5 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: barzGold.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? barzGold.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(color: border),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isSelected ? barzGold : colors.labelSecondary,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isSelected ? 1 : 0,
                    child: const Icon(Icons.check, color: barzGold, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.oswald(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                  color: colors.labelPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: colors.labelSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _localizedCountryName(AppLocalizations l10n, SupportedCountry country) {
  return switch (country) {
    SupportedCountry.brazil => l10n.country_brazil,
    SupportedCountry.argentina => l10n.country_argentina,
    SupportedCountry.usa => l10n.country_united_states,
    SupportedCountry.mexico => l10n.country_mexico,
    SupportedCountry.chile => l10n.country_chile,
    SupportedCountry.colombia => l10n.country_colombia,
    SupportedCountry.peru => l10n.country_peru,
  };
}
