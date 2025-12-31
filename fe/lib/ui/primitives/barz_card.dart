import 'package:flutter/material.dart';
import '../../core/utils/constant/colors.dart';
import '../../core/utils/constant/styles.dart';

class BarzCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const BarzCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: BarzSpacing.sm),
      padding: padding ?? const EdgeInsets.all(BarzSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: barzBlack, width: 1),
      ),
      child: child,
    );
  }
}