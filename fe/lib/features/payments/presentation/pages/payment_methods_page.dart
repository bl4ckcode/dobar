import 'package:barz/features/payments/domain/services/card_tokenizer.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/features/user/domain/models/user_document.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/payments/presentation/bloc/payment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/l10n/app_localizations.dart';

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  static Widget withBloc() => BlocProvider(
    create: (_) => getItInjector<PaymentBloc>()..add(const LoadSavedCards()),
    child: const PaymentMethodsPage(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<PaymentBloc, PaymentState>(
      builder: (context, state) {
        final bloc = context.read<PaymentBloc>();
        return ProfileFrame(
          title: l10n.profile_payments,
          children: [
            if (state.isLoading)
              const BarzLoadingWidget()
            else ...[
              if (state.error != null)
                Semantics(
                  liveRegion: true,
                  child: Column(
                    children: [
                      Text(
                        state.error == 'saved_card_replacement_remove_failed'
                            ? l10n.profile_replace_partial
                            : l10n.profile_action_failed,
                      ),
                      TextButton(
                        onPressed: () => bloc.add(const LoadSavedCards()),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              if (state.savedCards.isEmpty) Text(l10n.payment_no_cards),
              for (final card in state.savedCards)
                ProfileGroup(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(BarzSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${card.brand ?? l10n.payment_card_generic} •••• ${card.lastFourDigits ?? '••••'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (card.isDefault) Text(l10n.payment_default_badge),
                          Text(
                            l10n.payment_expires_label(
                              '${card.expiryMonth?.toString().padLeft(2, '0') ?? '--'}/${card.expiryYear ?? '----'}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    ProfileRow(
                      icon: LucideIcons.credit_card,
                      title: l10n.profile_replace_card,
                      onTap: state.isProcessing
                          ? null
                          : () => _showAddCardSheet(context, replacement: card),
                    ),
                    ProfileRow(
                      icon: LucideIcons.trash,
                      title: l10n.remove,
                      destructive: true,
                      onTap: state.isProcessing || card.id == null
                          ? null
                          : () async {
                              if (await confirmProfileAction(
                                    context,
                                    l10n.payment_remove_card_title,
                                    l10n.payment_remove_card_confirm(
                                      '${card.brand ?? l10n.payment_card_generic} •••• ${card.lastFourDigits}',
                                    ),
                                  ) &&
                                  context.mounted) {
                                bloc.add(DeleteSavedCard(card.id!));
                              }
                            },
                    ),
                  ],
                ),
              if (state.isProcessing) const BarzLoadingWidget(),
              ProfilePrimaryButton(
                label: l10n.payment_add_card,
                busy: state.isProcessing,
                onPressed: () => _showAddCardSheet(context),
              ),
              // OS alone cannot prove merchant/provider configuration. C10 owns capability
              // verification; never advertise a working wallet from a platform check.
              ProfileGroup(
                title: l10n.profile_device_wallet,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(BarzSpacing.lg),
                    child: Text(l10n.profile_wallet_unavailable),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showAddCardSheet(
    BuildContext context, {
    PaymentMethod? replacement,
  }) async {
    final user = (await getItInjector<UserUsecase>().getCurrentUser()).fold(
      (_) => null,
      (value) => value,
    );
    if (!context.mounted) return;
    if (user == null ||
        !user.hasCompletedRegistration ||
        !user.documents.any(
          (document) =>
              document.type == DocumentType.cpf &&
              document.number.trim().isNotEmpty,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.payment_card_profile_required,
          ),
        ),
      );
      return;
    }
    final bloc = context.read<PaymentBloc>();
    if (bloc.state.isProcessing) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _AddCardSheet(replacement: replacement),
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet({this.replacement});
  final PaymentMethod? replacement;

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _holderController = TextEditingController();
  bool _tokenizing = false;
  String? _tokenError;
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _isDefault = widget.replacement?.isDefault ?? false;
  }

  String _detectBrand(String number, AppLocalizations l10n) {
    final stripped = number.replaceAll(' ', '');
    if (stripped.startsWith('4')) return 'Visa';
    if (stripped.startsWith('5') || stripped.startsWith('2')) {
      return 'Mastercard';
    }
    if (stripped.startsWith('3')) return 'Amex';
    return l10n.payment_brand_unknown;
  }

  bool _luhnCheck(String number) {
    final digits = number.replaceAll(' ', '').split('').map(int.parse).toList();
    var sum = 0;
    var isOdd = true;
    for (final d in digits.reversed) {
      if (isOdd) {
        sum += d;
      } else {
        final doubled = d * 2;
        sum += doubled > 9 ? doubled - 9 : doubled;
      }
      isOdd = !isOdd;
    }
    return sum % 10 == 0;
  }

  Future<void> _submit() async {
    if (_tokenizing || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final expParts = _expiryController.text.split('/');
    final expMonth = int.tryParse(expParts.first.trim()) ?? 0;
    final enteredYear = int.tryParse(expParts.last.trim()) ?? 0;
    final expYear = enteredYear < 100 ? enteredYear + 2000 : enteredYear;
    final clean = _numberController.text.replaceAll(RegExp(r'\D'), '');
    final lastFour = clean.substring(clean.length - 4);
    final brand = _detectBrand(clean, l10n);
    setState(() {
      _tokenizing = true;
      _tokenError = null;
    });
    try {
      final token = await getItInjector<CardTokenizer>().tokenize(
        number: clean,
        holderName: _holderController.text,
        expMonth: expMonth,
        expYear: expYear,
        cvv: _cvvController.text,
      );
      if (!mounted) return;
      context.read<PaymentBloc>().add(
        PaymentEvent.addSavedCard(
          cardToken: token,
          lastFour: lastFour,
          brand: brand,
          expMonth: expMonth,
          expYear: expYear,
          isDefault: _isDefault,
          replacementCardId: widget.replacement?.id,
        ),
      );
      _numberController.clear();
      _cvvController.clear();
      Navigator.pop(context);
    } on CardTokenizationException catch (error) {
      if (mounted) {
        setState(
          () => _tokenError = error.unavailable
              ? l10n.payment_card_unavailable
              : l10n.payment_card_token_failed,
        );
      }
    } finally {
      if (mounted) setState(() => _tokenizing = false);
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _holderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: dobar.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dobar.surfaceElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(LucideIcons.credit_card, color: dobar.labelSelected),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.replacement == null
                          ? l10n.payment_add_credit_card
                          : l10n.profile_replace_card,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: dobar.labelPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildField(
                controller: _holderController,
                label: l10n.payment_card_holder_label,
                hint: l10n.payment_card_holder_hint,
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? l10n.field_required
                    : null,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _numberController,
                label: l10n.payment_card_number_label,
                hint: l10n.payment_card_number_hint,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardNumberFormatter(),
                ],
                validator: (val) {
                  if (val == null || val.isEmpty) return l10n.field_required;
                  if (val.replaceAll(' ', '').length < 16) {
                    return l10n.payment_error_invalid_number;
                  }
                  if (!_luhnCheck(val)) return l10n.payment_error_luhn_failed;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _expiryController,
                      label: l10n.payment_expiry_label,
                      hint: l10n.payment_expiry_hint,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ExpiryFormatter(),
                      ],
                      validator: (val) {
                        if (val == null || val.length < 5) {
                          return l10n.field_required;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildField(
                      controller: _cvvController,
                      label: l10n.payment_cvv_label,
                      hint: l10n.payment_cvv_hint,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (val) {
                        if (val == null || val.length < 3) {
                          return l10n.field_required;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Switch(
                    value: _isDefault,
                    onChanged: _tokenizing
                        ? null
                        : (v) => setState(() => _isDefault = v),
                    activeThumbColor: dobar.buttonPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.payment_set_default_label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: dobar.labelPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_tokenError != null)
                Text(
                  _tokenError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ProfilePrimaryButton(
                label: l10n.payment_save_card_button,
                busy: _tokenizing,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final dobar = context.dobarColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: dobar.labelSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: !_tokenizing,
          keyboardType: keyboardType,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(color: dobar.labelPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: dobar.labelSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: dobar.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dobar.labelSelected, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    final text = value.text.replaceAll(' ', '');
    if (text.length > 16) return old;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final newText = buffer.toString();
    return value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    final text = value.text.replaceAll('/', '');
    if (text.length > 4) return old;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    final newText = buffer.toString();
    return value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
