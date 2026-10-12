import 'package:barz/core/utils/constant/colors.dart';
import 'package:flutter/material.dart';

class BarzBlackElevatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isEnabled;

  const BarzBlackElevatedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isEnabled ? backgroundLightSMS : Colors.blueGrey,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (isEnabled)
            BoxShadow(
              color: mainColor.withValues(alpha: 0.8),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: mainColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: Text(text),
      ),
    );
  }
}
