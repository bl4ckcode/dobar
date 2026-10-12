import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';
import '../widgets/wizard_footer.dart';

class BasicInfoStep extends StatefulWidget {
  final CreateBarFormData formData;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const BasicInfoStep({
    super.key,
    required this.formData,
    required this.onNext,
    this.onBack,
  });

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  final _formKey = GlobalKey<FormBuilderState>();
  late CountryFormConfig _countryConfig;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _countryConfig = widget.formData.countryConfig;
    _checkFormValidity();
  }

  void _checkFormValidity() {
    final hasName = widget.formData.name.isNotEmpty;
    final hasAddress = widget.formData.address.isNotEmpty;
    final hasPhone = widget.formData.phone.isNotEmpty;
    final hasValidEmail = _isValidEmail(widget.formData.email);
    setState(() {
      _isFormValid = hasName && hasAddress && hasPhone && hasValidEmail;
    });
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FormBuilder(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ResponsiveCenterContainer(
              maxWidth: 720,
              minWidth: 320,
              maxWidthPercentage: 0.6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BarzSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCountryBanner(),
                    const SizedBox(height: BarzSpacing.lg),
                    _buildSectionHeader(l10n.bar_name, Icons.store_rounded),
                    const SizedBox(height: BarzSpacing.sm),
                    FormBuilderTextField(
                      name: 'name',
                      initialValue: widget.formData.name,
                      decoration: _inputDecoration(l10n.bar_name_hint),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.minLength(3),
                      ]),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (value) {
                        widget.formData.name = value ?? '';
                        _checkFormValidity();
                      },
                    ),
                    const SizedBox(height: BarzSpacing.xl),
                    _buildSectionHeader(
                      l10n.address,
                      Icons.location_on_rounded,
                    ),
                    const SizedBox(height: BarzSpacing.sm),
                    FormBuilderTextField(
                      name: 'address',
                      initialValue: widget.formData.address,
                      decoration: _inputDecoration(l10n.address_hint),
                      validator: FormBuilderValidators.required(),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) {
                        widget.formData.address = value ?? '';
                        _checkFormValidity();
                      },
                    ),
                    const SizedBox(height: BarzSpacing.xl),
                    _buildSectionHeader(l10n.contact_info, Icons.phone_rounded),
                    const SizedBox(height: BarzSpacing.sm),
                    BarzPhoneField(
                      hintText: l10n.phone_hint,
                      initialCountryCode: widget.formData.countryCode,
                      initialValue: widget.formData.phone,
                      isRequired: true,
                      onChanged: (phone) {
                        if (phone != null) {
                          widget.formData.phone = phone.international;
                        }
                        _checkFormValidity();
                      },
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    FormBuilderTextField(
                      name: 'email',
                      initialValue: widget.formData.email,
                      decoration: _inputDecoration(
                        l10n.email_hint,
                        prefixIcon: Icons.email_rounded,
                        iconSize: 28,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.email(),
                      ]),
                      onChanged: (value) {
                        widget.formData.email = value ?? '';
                        _checkFormValidity();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          WizardFooter(
            onBack: widget.onBack,
            onNext: _onSubmit,
            isNextEnabled: _isFormValid,
          ),
        ],
      ),
    );
  }

  Widget _buildCountryBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: surfaceDim),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: barzGold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_countryConfig.name} • ${_countryConfig.currency}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (widget.formData.latitude != null)
            Icon(Icons.check_circle, color: successGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: barzGold, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    IconData? prefixIcon,
    double iconSize = 24,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: barzGoldMuted,
      prefixIcon: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(prefixIcon, color: textSecondary, size: iconSize),
            )
          : null,
      prefixIconConstraints: prefixIcon != null
          ? const BoxConstraints(minWidth: 48, minHeight: 48)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: barzGold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: errorRed),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      widget.formData.name = values['name'] ?? '';
      widget.formData.address = values['address'] ?? '';
      widget.formData.email = values['email'] ?? '';
      widget.onNext();
    }
  }
}
