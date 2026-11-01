import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/l10n/app_localizations.dart';

/// Complete Registration Page
///
/// Shown after initial authentication (SMS or social) to collect
/// additional required user information before accessing the app.
class CompleteRegistrationPage extends StatefulWidget {
  /// Optional user data pre-filled from social auth
  final String? prefilledEmail;
  final String? prefilledName;
  final String? prefilledPhone;
  final bool initialTermsAccepted;
  final bool initialPrivacyAccepted;
  final bool returnToCheckout;

  const CompleteRegistrationPage({
    super.key,
    this.prefilledEmail,
    this.prefilledName,
    this.prefilledPhone,
    this.initialTermsAccepted = false,
    this.initialPrivacyAccepted = false,
    this.returnToCheckout = false,
  });

  @override
  State<CompleteRegistrationPage> createState() =>
      _CompleteRegistrationPageState();
}

class _CompleteRegistrationPageState extends State<CompleteRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.prefilledName ?? '';
    _emailController.text = widget.prefilledEmail ?? '';
    _termsAccepted = widget.initialTermsAccepted;
    _privacyAccepted = widget.initialPrivacyAccepted;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _termsAccepted &&
        _privacyAccepted;
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final l10n = AppLocalizations.of(context)!;
      final userRepository = getItInjector<UserRepository>();

      // Update user profile with collected data
      final result = await userRepository.updateProfile(
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );

      // Handle result
      await result.fold(
        (failure) async {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.registration_error(failure.errorMessage)),
              ),
            );
          }
        },
        (user) async {
          // Accept terms and privacy
          if (_termsAccepted) {
            await userRepository.acceptTerms();
          }
          if (_privacyAccepted) {
            await userRepository.acceptPrivacy();
          }

          if (mounted) {
            if (widget.returnToCheckout) {
              context.pop(true);
            } else {
              AppRoute.home.go(context);
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.registration_error(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: barzGoldSoft,
      appBar: AppBar(
        backgroundColor: barzGoldSoft,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BarzSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  l10n.registration_title,
                  style: barzTextTheme.headlineMedium?.copyWith(
                    color: barzDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: BarzSpacing.sm),
                Text(
                  l10n.registration_subtitle,
                  style: barzTextTheme.bodyLarge?.copyWith(
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: BarzSpacing.xxl),

                // Name Field
                BarzTextField(
                  controller: _nameController,
                  label: l10n.registration_full_name,
                  hintText: l10n.registration_full_name_hint,
                  prefixIcon: const Icon(Icons.person_outline),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: BarzSpacing.lg),

                // Email Field
                BarzTextField(
                  controller: _emailController,
                  label: l10n.registration_email,
                  hintText: l10n.registration_email_hint,
                  prefixIcon: const Icon(Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: BarzSpacing.xxl),

                // Terms and Privacy
                _buildCheckbox(
                  value: _termsAccepted,
                  onChanged: (value) =>
                      setState(() => _termsAccepted = value ?? false),
                  text: l10n.registration_agree_prefix,
                  linkText: l10n.login_terms,
                  onLinkTap: () {
                    AppRoute.termsOfService.push(context);
                  },
                ),
                const SizedBox(height: BarzSpacing.md),
                _buildCheckbox(
                  value: _privacyAccepted,
                  onChanged: (value) =>
                      setState(() => _privacyAccepted = value ?? false),
                  text: l10n.registration_agree_prefix,
                  linkText: l10n.login_privacy,
                  onLinkTap: () {
                    AppRoute.privacyPolicy.push(context);
                  },
                ),
                const SizedBox(height: BarzSpacing.xxl),

                // Submit Button
                BarzButton.primary(
                  onPressed: _isFormValid ? _completeRegistration : null,
                  label: l10n.registration_get_started,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: BarzSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
    required String linkText,
    required VoidCallback onLinkTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: barzGold,
            checkColor: barzDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BarzRadii.xs),
            ),
            side: const BorderSide(color: barzDark, width: 2),
          ),
        ),
        const SizedBox(width: BarzSpacing.sm),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: RichText(
              text: TextSpan(
                text: text,
                style: barzTextTheme.bodyMedium?.copyWith(color: textSecondary),
                children: [
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText,
                        style: barzTextTheme.bodyMedium?.copyWith(
                          color: barzDark,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
