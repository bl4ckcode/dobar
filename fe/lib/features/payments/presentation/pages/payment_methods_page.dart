import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/payments/presentation/bloc/payment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/l10n/app_localizations.dart';

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  static Widget withBloc() {
    return BlocProvider(
      create: (_) =>
          getItInjector<PaymentBloc>()
            ..add(const PaymentEvent.loadSavedCards()),
      child: const PaymentMethodsPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: dobar.background,
      appBar: AppBar(
        backgroundColor: dobar.background,
        foregroundColor: dobar.labelPrimary,
        title: Text(
          l10n.payment_methods_title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dobar.labelPrimary,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: barzGold),
            onPressed: () => _showAddCardSheet(context),
          ),
        ],
      ),
      body: BlocConsumer<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red.shade800,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: barzGold),
            );
          }

          if (state.savedCards.isEmpty) {
            return _EmptyCardsView(onAdd: () => _showAddCardSheet(context));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: state.savedCards.length,
            itemBuilder: (context, i) {
              return _CreditCardTile(
                card: state.savedCards[i],
                onDelete: () => _confirmDelete(context, state.savedCards[i]),
              );
            },
          );
        },
      ),
      floatingActionButton: BlocBuilder<PaymentBloc, PaymentState>(
        builder: (context, state) {
          return FloatingActionButton.extended(
            onPressed: () => _showAddCardSheet(context),
            backgroundColor: barzGold,
            foregroundColor: Colors.black,
            icon: const Icon(LucideIcons.creditCard),
            label: Text(
              l10n.payment_add_card,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  void _showAddCardSheet(BuildContext context) {
    final bloc = context.read<PaymentBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BlocProvider.value(value: bloc, child: const _AddCardSheet()),
    );
  }

  void _confirmDelete(BuildContext context, PaymentMethod card) {
    final bloc = context.read<PaymentBloc>();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: barzDarkCard,
        title: Text(l10n.payment_remove_card_title, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.payment_remove_card_confirm(
            '${card.brand ?? l10n.payment_card_generic} •••• ${card.lastFourDigits}',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (card.id != null) {
                bloc.add(PaymentEvent.deleteSavedCard(card.id!));
              }
            },
            child: Text(
              l10n.remove,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCardsView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCardsView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.creditCard,
              size: 48,
              color: barzGold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.payment_no_cards,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: dobar.labelPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.payment_no_cards_subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: dobar.labelSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: barzGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(LucideIcons.plus),
            label: Text(
              l10n.payment_add_credit_card,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  final PaymentMethod card;
  final VoidCallback onDelete;

  const _CreditCardTile({required this.card, required this.onDelete});

  IconData _brandIcon(String? brand) {
    switch (brand?.toLowerCase()) {
      case 'visa':
        return LucideIcons.creditCard;
      case 'mastercard':
        return LucideIcons.creditCard;
      default:
        return LucideIcons.creditCard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [barzDarkCard, barzDarkLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: card.isDefault
              ? barzGold.withValues(alpha: 0.6)
              : dobar.surfaceElevated,
          width: card.isDefault ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_brandIcon(card.brand), color: barzGold, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      card.brand ?? l10n.payment_card_generic,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: dobar.labelPrimary,
                      ),
                    ),
                    if (card.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: barzGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          l10n.payment_default_badge,
                          style: const TextStyle(
                            color: barzGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.trash2,
                    color: dobar.labelSecondary,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '•••• •••• •••• ${card.lastFourDigits ?? '****'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.payment_expires_label(
                '${card.expiryMonth?.toString().padLeft(2, '0') ?? '--'}/${card.expiryYear ?? '----'}',
              ),
              style: TextStyle(fontSize: 13, color: dobar.labelSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet();

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isDefault = false;

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

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    final expParts = _expiryController.text.split('/');
    final expMonth = int.tryParse(expParts.first.trim()) ?? 1;
    final expYear = int.tryParse(expParts.last.trim()) ?? DateTime.now().year;
    final lastFour = _numberController.text.replaceAll(' ', '').substring(12);
    final brand = _detectBrand(_numberController.text, l10n);

    context.read<PaymentBloc>().add(
      PaymentEvent.addSavedCard(
        cardToken:
            'tok_${DateTime.now().millisecondsSinceEpoch}', // Real impl: tokenize via gateway SDK
        lastFour: lastFour,
        brand: brand,
        expMonth: expMonth,
        expYear: expYear,
        isDefault: _isDefault,
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: barzDarkLight,
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
                const Icon(LucideIcons.creditCard, color: barzGold),
                const SizedBox(width: 12),
                Text(
                  l10n.payment_add_credit_card,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: dobar.labelPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                      if (val == null || val.length < 5) return l10n.field_required;
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
                      if (val == null || val.length < 3) return l10n.field_required;
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
                  onChanged: (v) => setState(() => _isDefault = v),
                  activeThumbColor: barzGold,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.payment_set_default_label,
                  style: TextStyle(color: dobar.labelPrimary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [barzGoldGradientStart, barzGoldGradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: barzGold.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    l10n.payment_save_card_button,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
            fillColor: barzDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: barzGold, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
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
