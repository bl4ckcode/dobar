import 'package:flutter/material.dart';
import '../../core/utils/constant/colors.dart';
import '../../core/utils/constant/styles.dart';

class BarzButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool filled;
  const BarzButton({super.key, required this.text, this.onPressed, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? barzYellow : Colors.transparent,
          foregroundColor: filled ? barzBlack : barzYellow,
          side: filled ? null : const BorderSide(color: barzYellow, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
        ),
        child: Text(text, style: BarzTextStyles.button.copyWith(color: filled ? barzBlack : barzYellow)),
      ),
    );
  }
}