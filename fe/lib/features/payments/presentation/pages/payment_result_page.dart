import 'package:barz/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum PaymentResultType { success, failure, pending }

class PaymentResultPage extends StatelessWidget {
  final PaymentResultType result;
  final String? orderId;
  final double? amount;
  final String? errorMessage;
  final VoidCallback? onContinue;
  final VoidCallback? onRetry;

  const PaymentResultPage({
    super.key,
    required this.result,
    this.orderId,
    this.amount,
    this.errorMessage,
    this.onContinue,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    return Scaffold(
      backgroundColor: dobar.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              _ResultIcon(result: result),
              const SizedBox(height: 32),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: dobar.labelPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _subtitle(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: dobar.labelSecondary,
                  height: 1.5,
                ),
              ),
              if (amount != null && result == PaymentResultType.success) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: barzGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: barzGold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Amount Paid',
                        style: TextStyle(
                          color: dobar.labelSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'R\$ ${amount!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: barzGold,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (orderId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Order #$orderId',
                          style: TextStyle(
                            color: dobar.labelSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (errorMessage != null &&
                  result == PaymentResultType.failure) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _PrimaryButton(
                result: result,
                onContinue: onContinue,
                onRetry: onRetry,
              ),
              const SizedBox(height: 16),
              if (result != PaymentResultType.success)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Text(
                    'Return to Menu',
                    style: TextStyle(color: dobar.labelSecondary, fontSize: 16),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    return switch (result) {
      PaymentResultType.success => '🎉 Payment Confirmed!',
      PaymentResultType.failure => 'Payment Failed',
      PaymentResultType.pending => 'Payment Pending',
    };
  }

  String _subtitle(BuildContext context) {
    return switch (result) {
      PaymentResultType.success =>
        'Your order has been placed.\nEnjoy your night! 🥂',
      PaymentResultType.failure =>
        'Something went wrong processing your payment. Please try again.',
      PaymentResultType.pending =>
        'Your payment is being processed. We\'ll notify you once it\'s confirmed.',
    };
  }
}

class _ResultIcon extends StatefulWidget {
  final PaymentResultType result;

  const _ResultIcon({required this.result});

  @override
  State<_ResultIcon> createState() => _ResultIconState();
}

class _ResultIconState extends State<_ResultIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.result) {
    PaymentResultType.success => pixGreen,
    PaymentResultType.failure => errorRed,
    PaymentResultType.pending => barzGold,
  };

  IconData get _icon => switch (widget.result) {
    PaymentResultType.success => LucideIcons.checkCircle2,
    PaymentResultType.failure => LucideIcons.xCircle,
    PaymentResultType.pending => LucideIcons.clock,
  };

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color.withValues(alpha: 0.12),
          border: Border.all(color: _color.withValues(alpha: 0.4), width: 2),
        ),
        child: Icon(_icon, size: 56, color: _color),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final PaymentResultType result;
  final VoidCallback? onContinue;
  final VoidCallback? onRetry;

  const _PrimaryButton({required this.result, this.onContinue, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (result == PaymentResultType.success) {
      return GestureDetector(
        onTap:
            onContinue ??
            () => Navigator.of(context).popUntil((r) => r.isFirst),
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
          child: const Center(
            child: Text(
              'Back to Home',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onRetry ?? () => Navigator.of(context).pop(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: barzDarkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        child: const Center(
          child: Text(
            'Try Again',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
