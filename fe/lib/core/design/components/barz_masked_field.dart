import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

enum BarzMaskType { cnpj, cpf, phone, cep, custom }

class BarzMaskedField extends StatefulWidget {
  final String? label;
  final String hintText;
  final BarzMaskType maskType;
  final String? customMask;
  final bool enabled;
  final String? initialValue;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onUnmaskedChanged;
  final FocusNode? focusNode;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const BarzMaskedField({
    super.key,
    this.label,
    this.hintText = '',
    this.maskType = BarzMaskType.custom,
    this.customMask,
    this.enabled = true,
    this.initialValue,
    this.errorText,
    this.onChanged,
    this.onUnmaskedChanged,
    this.focusNode,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  State<BarzMaskedField> createState() => _BarzMaskedFieldState();
}

class _BarzMaskedFieldState extends State<BarzMaskedField> {
  late TextEditingController _controller;
  late MaskTextInputFormatter _formatter;

  String _getMask() {
    switch (widget.maskType) {
      case BarzMaskType.cnpj:
        return '##.###.###/####-##';
      case BarzMaskType.cpf:
        return '###.###.###-##';
      case BarzMaskType.phone:
        return '(##) #####-####';
      case BarzMaskType.cep:
        return '#####-###';
      case BarzMaskType.custom:
        return widget.customMask ?? '';
    }
  }

  TextInputType _getKeyboardType() {
    if (widget.keyboardType != null) return widget.keyboardType!;
    switch (widget.maskType) {
      case BarzMaskType.cnpj:
      case BarzMaskType.cpf:
      case BarzMaskType.phone:
      case BarzMaskType.cep:
        return TextInputType.number;
      case BarzMaskType.custom:
        return TextInputType.text;
    }
  }

  @override
  void initState() {
    super.initState();
    _formatter = MaskTextInputFormatter(
      mask: _getMask(),
      filter: {'#': RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );
    _controller = TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = _formatter.maskText(widget.initialValue!);
    }
  }

  @override
  void dispose() {
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
        TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          keyboardType: _getKeyboardType(),
          inputFormatters: [_formatter],
          onChanged: (value) {
            widget.onChanged?.call(value);
            widget.onUnmaskedChanged?.call(_formatter.getUnmaskedText());
          },
          style: theme.textTheme.bodyLarge?.copyWith(
            color: widget.enabled ? textPrimary : textTertiary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _getFillColor(hasError),
            hintText: widget.hintText.isEmpty
                ? _getMask().replaceAll('#', '_')
                : widget.hintText,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(color: textTertiary),
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: const BorderSide(color: errorRed, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: const BorderSide(color: errorRed, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Color _getFillColor(bool hasError) {
    if (!widget.enabled) return surfaceMuted;
    if (hasError) return errorRedLight;
    return barzGoldMuted;
  }
}

class BrazilMasks {
  static const String cnpj = '##.###.###/####-##';
  static const String cpf = '###.###.###-##';
  static const String phone = '(##) #####-####';
  static const String landline = '(##) ####-####';
  static const String cep = '#####-###';

  static bool isValidCNPJ(String cnpj) {
    final numbers = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    if (numbers.length != 14) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(numbers)) return false;

    int sum = 0;
    const weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    for (var i = 0; i < 12; i++) {
      sum += int.parse(numbers[i]) * weights1[i];
    }
    var digit1 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    if (int.parse(numbers[12]) != digit1) return false;

    sum = 0;
    const weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    for (var i = 0; i < 13; i++) {
      sum += int.parse(numbers[i]) * weights2[i];
    }
    var digit2 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    return int.parse(numbers[13]) == digit2;
  }

  static bool isValidCPF(String cpf) {
    final numbers = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (numbers.length != 11) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(numbers)) return false;

    int sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(numbers[i]) * (10 - i);
    }
    var digit1 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    if (int.parse(numbers[9]) != digit1) return false;

    sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += int.parse(numbers[i]) * (11 - i);
    }
    var digit2 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    return int.parse(numbers[10]) == digit2;
  }
}
