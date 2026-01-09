import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class EmailPromptModal extends StatefulWidget {
  final Future<void> Function(String email) onSubmit;
  final VoidCallback onDismiss;

  const EmailPromptModal({
    super.key,
    required this.onSubmit,
    required this.onDismiss,
  });

  @override
  State<EmailPromptModal> createState() => _EmailPromptModalState();

  static Future<bool?> show(
    BuildContext context, {
    required Future<void> Function(String email) onSubmit,
    required VoidCallback onDismiss,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmailPromptModal(
        onSubmit: onSubmit,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _EmailPromptModalState extends State<EmailPromptModal> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return AppLocalizations.of(context)!.email_invalid;
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_controller.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().contains('409')
            ? AppLocalizations.of(context)!.email_already_in_use
            : AppLocalizations.of(context)!.email_update_failed;
      });
    }
  }

  void _handleDismiss() {
    widget.onDismiss();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.lg),
      ),
      title: Row(
        children: [
          const Text('📧', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.email_prompt_title)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.email_prompt_benefits,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _BenefitRow(icon: Icons.receipt_long, text: l10n.email_benefit_receipts),
            _BenefitRow(icon: Icons.history, text: l10n.email_benefit_history),
            _BenefitRow(icon: Icons.lock_reset, text: l10n.email_benefit_recovery),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'email@example.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _error,
              ),
              validator: _validateEmail,
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _handleDismiss,
          child: Text(l10n.email_prompt_skip),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: barzGold,
            foregroundColor: barzDark,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.email_prompt_add),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
