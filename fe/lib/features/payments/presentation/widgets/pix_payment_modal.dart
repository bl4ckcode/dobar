import 'dart:async';
import 'dart:ui';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Result of the Pix payment flow
enum PixPaymentResult {
  approved,
  cancelled,
  timeout,
}

class PixPaymentModal extends StatefulWidget {
  final PixPaymentResponse pixPayment;

  const PixPaymentModal({super.key, required this.pixPayment});

  /// Shows the Pix payment modal and waits for the result.
  /// Returns PixPaymentResult.approved on successful payment,
  /// PixPaymentResult.cancelled if user dismisses,
  /// PixPaymentResult.timeout if polling times out.
  static Future<PixPaymentResult> show(
    BuildContext context,
    PixPaymentResponse pixPayment,
  ) {
    return showGeneralDialog<PixPaymentResult>(
      context: context,
      barrierDismissible: false, // User must complete or explicitly cancel
      barrierLabel: 'Pix Payment',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: PixPaymentModal(pixPayment: pixPayment),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: anim1.value * 10,
            sigmaY: anim1.value * 10,
          ),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
                .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        );
      },
    ).then((result) => result ?? PixPaymentResult.cancelled);
  }

  @override
  State<PixPaymentModal> createState() => _PixPaymentModalState();
}

class _PixPaymentModalState extends State<PixPaymentModal> {
  late Duration _remainingTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.pixPayment.expiresAt.difference(DateTime.now());
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingTime = widget.pixPayment.expiresAt.difference(DateTime.now());
          if (_remainingTime.isNegative) {
            _timer?.cancel();
            _timer = null;
          }
        });
      }
    });
  }

  void _copyBrCode(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: widget.pixPayment.copyPaste));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(l10n.payment_pix_copied),
          ],
        ),
        backgroundColor: barzDarkCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    final minutesLeft = _remainingTime.isNegative
        ? 0
        : _remainingTime.inMinutes.clamp(0, 60);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: barzDarkLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: dobar.surfaceElevated, width: 1)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dobar.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pixGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.qrCode,
                    color: pixGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.payment_pix_title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: dobar.labelPrimary,
                      ),
                    ),
                    Text(
                      l10n.payment_pix_expires(minutesLeft),
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.x, color: dobar.labelSecondary),
                  onPressed: () => Navigator.of(context).pop(PixPaymentResult.cancelled),
                ),
              ],
            ),
          ),

          Divider(color: dobar.surfaceElevated, height: 24),

          // Amount
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: barzDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    l10n.payment_pix_amount,
                    style: TextStyle(color: dobar.labelSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'R\$ ${widget.pixPayment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: barzGold,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // QR Code
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(
                      data: widget.pixPayment.qrCode,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.payment_pix_copy_hint,
                    style: TextStyle(color: dobar.labelSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: barzDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: dobar.surfaceElevated),
                    ),
                    child: Text(
                      widget.pixPayment.copyPaste,
                      style: TextStyle(
                        color: dobar.labelSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: () => _copyBrCode(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [pixGreen, pixGreenDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: pixGreen.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.copy, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      l10n.payment_pix_copy_button,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}