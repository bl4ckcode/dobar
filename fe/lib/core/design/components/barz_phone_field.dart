import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:intl_phone_field/countries.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

class BarzPhoneField extends StatelessWidget {
  final String? label;
  final String hintText;
  final bool enabled;
  final String? errorText;
  final ValueChanged<PhoneNumber>? onChanged;
  final ValueChanged<Country>? onCountryChanged;
  final String initialCountryCode;
  final String? initialValue;
  final FocusNode? focusNode;
  final bool showDropdownIcon;
  final bool disableLengthCheck;
  final List<String>? countryFilter;
  final List<String>? favoriteCountries;

  const BarzPhoneField({
    super.key,
    this.label,
    this.hintText = '',
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onCountryChanged,
    this.initialCountryCode = 'BR',
    this.initialValue,
    this.focusNode,
    this.showDropdownIcon = true,
    this.disableLengthCheck = false,
    this.countryFilter,
    this.favoriteCountries = const ['BR', 'PT', 'US'],
  });

  List<Country>? _getFilteredCountries() {
    if (countryFilter == null) return null;
    return countries.where((c) => countryFilter!.contains(c.code)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        IntlPhoneField(
          initialValue: initialValue,
          initialCountryCode: initialCountryCode,
          enabled: enabled,
          focusNode: focusNode,
          showDropdownIcon: showDropdownIcon,
          disableLengthCheck: disableLengthCheck,
          countries: _getFilteredCountries(),
          flagsButtonPadding: const EdgeInsets.only(left: 12),
          dropdownIconPosition: IconPosition.trailing,
          dropdownIcon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? textSecondary : textTertiary,
          ),
          dropdownTextStyle: theme.textTheme.bodyLarge?.copyWith(
            color: enabled ? textPrimary : textTertiary,
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: enabled ? textPrimary : textTertiary,
          ),
          invalidNumberMessage: null,
          languageCode: 'pt',
          onChanged: onChanged,
          onCountryChanged: onCountryChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? barzGoldMuted : surfaceMuted,
            hintText: hintText,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: textTertiary,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: const BorderSide(color: errorRed, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: const BorderSide(color: errorRed, width: 2),
            ),
            errorText: errorText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

class PhoneNumberData {
  final String countryISOCode;
  final String countryCode;
  final String number;
  final String completeNumber;

  PhoneNumberData({
    required this.countryISOCode,
    required this.countryCode,
    required this.number,
    required this.completeNumber,
  });

  factory PhoneNumberData.fromPhoneNumber(PhoneNumber phoneNumber) {
    return PhoneNumberData(
      countryISOCode: phoneNumber.countryISOCode,
      countryCode: phoneNumber.countryCode,
      number: phoneNumber.number,
      completeNumber: phoneNumber.completeNumber,
    );
  }

  bool get isValid => countryCode.isNotEmpty && number.isNotEmpty;

  String toApiFormat() => completeNumber;

  @override
  String toString() => completeNumber;
}
