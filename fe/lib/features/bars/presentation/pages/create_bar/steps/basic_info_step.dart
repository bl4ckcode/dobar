import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';

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

  @override
  void initState() {
    super.initState();
    _countryConfig = widget.formData.countryConfig;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FormBuilder(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
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
                  ),
                  const SizedBox(height: BarzSpacing.xl),
                  _buildSectionHeader(l10n.address, Icons.location_on_rounded),
                  const SizedBox(height: BarzSpacing.sm),
                  FormBuilderTextField(
                    name: 'address',
                    initialValue: widget.formData.address,
                    decoration: _inputDecoration(l10n.address_hint),
                    validator: FormBuilderValidators.required(),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: BarzSpacing.xl),
                  _buildSectionHeader(l10n.contact_info, Icons.phone_rounded),
                  const SizedBox(height: BarzSpacing.sm),
                  BarzPhoneField(
                    hintText: l10n.phone_hint,
                    initialCountryCode: widget.formData.countryCode,
                    initialValue: widget.formData.phone,
                    onChanged: (phone) {
                      widget.formData.phone = phone.completeNumber;
                    },
                  ),
                  const SizedBox(height: BarzSpacing.md),
                  FormBuilderTextField(
                    name: 'email',
                    initialValue: widget.formData.email,
                    decoration: _inputDecoration(l10n.email_hint, prefixIcon: Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.email(),
                    ]),
                  ),
                  if (_countryConfig.requiresBusinessId) ...[
                    const SizedBox(height: BarzSpacing.xl),
                    _buildSectionHeader(_countryConfig.businessIdLabel ?? l10n.business_id, Icons.badge_rounded),
                    const SizedBox(height: BarzSpacing.sm),
                    BarzMaskedField(
                      hintText: _countryConfig.businessIdHint ?? '',
                      customMask: _countryConfig.businessIdMask,
                      maskType: BarzMaskType.custom,
                      initialValue: widget.formData.businessId,
                      onUnmaskedChanged: (value) {
                        widget.formData.businessId = value;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomButtons(l10n),
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

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: barzGoldMuted,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: textSecondary) : null,
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

  Widget _buildBottomButtons(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: const BorderSide(color: barzDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.back),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: widget.onBack != null ? 1 : 2,
            child: FilledButton(
              onPressed: _onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: barzDark,
                padding: const EdgeInsets.all(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.next),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
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
