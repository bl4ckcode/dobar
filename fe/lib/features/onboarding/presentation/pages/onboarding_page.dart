import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/country_helper.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Onboarding page shown to new users after authentication
/// 
/// Flow:
/// 1. Select role (client/business)
/// 2. Confirm/select country (auto-detected from phone)
/// 3. Submit → navigate to main app
class OnboardingPage extends StatelessWidget {
  /// Phone number used for country detection
  final String? phoneNumber;

  const OnboardingPage({super.key, this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getItInjector<OnboardingBloc>();
        // Auto-detect country from phone if available
        if (phoneNumber != null && phoneNumber!.isNotEmpty) {
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
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state.isComplete) {
          // Navigate to home after successful onboarding
          context.go('/');
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: barzGoldSoft,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  _buildHeader().animate().fadeIn().slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 48),
                  _buildRoleSelection(context, state)
                      .animate(delay: 200.ms)
                      .fadeIn()
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 32),
                  _buildCountrySelection(context, state)
                      .animate(delay: 400.ms)
                      .fadeIn()
                      .slideY(begin: 0.2, end: 0),
                  const Spacer(),
                  _buildContinueButton(context, state)
                      .animate(delay: 600.ms)
                      .fadeIn()
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: barzDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.local_bar,
            size: 40,
            color: barzGold,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to Dobar! 🍻',
          style: barzTextTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: barzDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Let\'s get you set up',
          style: barzTextTheme.bodyLarge?.copyWith(
            color: textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoleSelection(BuildContext context, OnboardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am a...',
          style: barzTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: barzDark,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _RoleCard(
                icon: Icons.local_drink,
                title: 'Customer',
                subtitle: 'Browse bars & order drinks',
                isSelected: state.selectedUserType == 'client',
                onTap: () => context.read<OnboardingBloc>().add(
                      const SelectUserType('client'),
                    ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _RoleCard(
                icon: Icons.store,
                title: 'Business',
                subtitle: 'Manage my bar',
                isSelected: state.selectedUserType == 'business',
                onTap: () => context.read<OnboardingBloc>().add(
                      const SelectUserType('business'),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountrySelection(BuildContext context, OnboardingState state) {
    final countries = CountryHelper.allCountries;
    final selectedCountry = state.selectedCountryCode != null
        ? SupportedCountry.fromCode(state.selectedCountryCode!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My country',
          style: barzTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: barzDark,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: barzDark.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<SupportedCountry>(
            value: selectedCountry,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              prefixIcon: selectedCountry != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        selectedCountry.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                    )
                  : const Icon(Icons.public, color: barzDark),
            ),
            hint: const Text('Select your country'),
            items: countries.map((country) {
              return DropdownMenuItem(
                value: country,
                // Only show name here since flag is already shown as prefix
                child: Text('${country.flag} ${country.name}'),
              );
            }).toList(),
            selectedItemBuilder: (context) {
              // When selected, only show name since flag is shown in prefixIcon
              return countries.map((country) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(country.name),
                );
              }).toList();
            },
            onChanged: (country) {
              if (country != null) {
                context.read<OnboardingBloc>().add(
                      SelectCountry(country.code),
                    );
              }
            },
          ),
        ),
        if (state.phoneNumber != null) ...[
          const SizedBox(height: 8),
          Text(
            'Auto-detected from your phone number',
            style: barzTextTheme.bodySmall?.copyWith(
              color: textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContinueButton(BuildContext context, OnboardingState state) {
    return BarzButton.primary(
      onPressed: state.canSubmit
          ? () => context.read<OnboardingBloc>().add(const SubmitOnboarding())
          : null,
      label: state.isSubmitting ? 'Setting up...' : 'Continue',
      isLoading: state.isSubmitting,
    );
  }
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? barzDark : surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? barzGold : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: barzDark.withValues(alpha: isSelected ? 0.2 : 0.1),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? barzGold : barzDark,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: barzTextTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? barzGold : barzDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: barzTextTheme.bodySmall?.copyWith(
                color: isSelected ? Colors.white70 : textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
