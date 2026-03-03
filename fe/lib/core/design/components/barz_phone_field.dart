import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

class BarzPhoneField extends StatefulWidget {
  final String? label;
  final String hintText;
  final bool enabled;
  final String? errorText;
  final ValueChanged<PhoneNumber?>? onChanged;
  final String initialCountryCode;
  final String? initialValue;
  final FocusNode? focusNode;
  final List<IsoCode>? favoriteCountries;
  final bool isRequired;
  final bool showFlag;
  final bool showDialCode;

  const BarzPhoneField({
    super.key,
    this.label,
    this.hintText = '',
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.initialCountryCode = 'BR',
    this.initialValue,
    this.focusNode,
    this.favoriteCountries = const [
      IsoCode.BR,
      IsoCode.PT,
      IsoCode.US,
      IsoCode.MX,
      IsoCode.AR,
    ],
    this.isRequired = false,
    this.showFlag = true,
    this.showDialCode = true,
  });

  @override
  State<BarzPhoneField> createState() => _BarzPhoneFieldState();
}

class _BarzPhoneFieldState extends State<BarzPhoneField> {
  late PhoneController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PhoneController(initialValue: _parseInitialValue());
    _controller.addListener(_onPhoneChanged);
  }

  PhoneNumber _parseInitialValue() {
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      try {
        return PhoneNumber.parse(widget.initialValue!);
      } catch (_) {
        return PhoneNumber(
          isoCode: _getIsoCode(widget.initialCountryCode),
          nsn: '',
        );
      }
    }
    return PhoneNumber(
      isoCode: _getIsoCode(widget.initialCountryCode),
      nsn: '',
    );
  }

  IsoCode _getIsoCode(String code) {
    try {
      return IsoCode.values.firstWhere(
        (iso) => iso.name.toUpperCase() == code.toUpperCase(),
        orElse: () => IsoCode.BR,
      );
    } catch (_) {
      return IsoCode.BR;
    }
  }

  void _onPhoneChanged() {
    widget.onChanged?.call(_controller.value);
  }

  PhoneNumberInputValidator? _getValidator(BuildContext context) {
    if (widget.isRequired) {
      return PhoneValidator.compose([
        PhoneValidator.required(context),
        PhoneValidator.valid(context),
      ]);
    }
    return PhoneValidator.valid(context);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPhoneChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: hasError ? errorRed : textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        PhoneFormField(
          controller: _controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          isCountryButtonPersistent: true,
          isCountrySelectionEnabled: true,
          countrySelectorNavigator: CountrySelectorNavigator.modalBottomSheet(
            favorites: widget.favoriteCountries ?? [],
          ),
          countryButtonStyle: CountryButtonStyle(
            showDialCode: widget.showDialCode,
            showIsoCode: false,
            showFlag: widget.showFlag,
            flagSize: 24,
            textStyle: theme.textTheme.bodyLarge?.copyWith(
              color: widget.enabled ? textPrimary : textTertiary,
            ),
            padding: const EdgeInsets.only(left: 12, right: 4),
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: widget.enabled ? textPrimary : textTertiary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.enabled ? barzGoldMuted : surfaceMuted,
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(color: textTertiary),
            errorText: widget.errorText,
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
            counterText: '',
          ),
          validator: _getValidator(context),
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
      countryISOCode: phoneNumber.isoCode.name,
      countryCode: '+${phoneNumber.countryCode}',
      number: phoneNumber.nsn,
      completeNumber: phoneNumber.international,
    );
  }

  bool get isValid => countryCode.isNotEmpty && number.isNotEmpty;

  String toApiFormat() => completeNumber;

  @override
  String toString() => completeNumber;
}
