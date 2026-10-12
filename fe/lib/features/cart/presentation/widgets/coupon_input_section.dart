import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import '../../domain/models/cart_models.dart';

class CouponInputSection extends StatefulWidget {
  final Coupon? appliedCoupon;
  final bool Function(String code) onApplyCoupon;
  final VoidCallback onRemoveCoupon;

  const CouponInputSection({
    super.key,
    required this.appliedCoupon,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
  });

  @override
  State<CouponInputSection> createState() => _CouponInputSectionState();
}

class _CouponInputSectionState extends State<CouponInputSection> {
  final _controller = TextEditingController();
  String? _error;
  bool _isApplying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleApply() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isApplying = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    final success = widget.onApplyCoupon(code);

    setState(() {
      _isApplying = false;
      if (!success) {
        _error = 'Invalid coupon code';
      } else {
        _controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? barzDarkLight : surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: barzDark.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: barzGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Coupon Code',
                style: TextStyle(
                  color: isDark ? textOnDark : textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          widget.appliedCoupon != null
              ? _buildAppliedCoupon(isDark)
              : _buildCouponInput(isDark),
        ],
      ),
    );
  }

  Widget _buildAppliedCoupon(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: barzGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: barzGold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: barzDark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appliedCoupon!.code,
                  style: TextStyle(
                    color: isDark ? textOnDark : textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.appliedCoupon!.type == CouponType.percentage
                      ? '${widget.appliedCoupon!.discount.toInt()}% off'
                      : '\$${widget.appliedCoupon!.discount.toStringAsFixed(0)} off',
                  style: const TextStyle(color: barzGold, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onRemoveCoupon,
            child: Icon(
              Icons.close,
              size: 20,
              color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: isDark ? textOnDark : textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter code',
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF888888) : textTertiary,
                  ),
                  filled: true,
                  fillColor: isDark ? barzDarkMuted : surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: barzGold, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isApplying ? null : _handleApply,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: barzGold,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: barzGold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _isApplying ? '...' : 'Apply',
                  style: const TextStyle(
                    color: barzDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: errorRed, fontSize: 13)),
        ],
      ],
    );
  }
}
