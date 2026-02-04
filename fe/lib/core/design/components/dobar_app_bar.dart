import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system.dart';

class DobarHomeHeader extends StatelessWidget {
  final VoidCallback? onNotificationTap;

  const DobarHomeHeader({super.key, this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAppBarRow(context, colors),
        const SizedBox(height: 16),
        _buildWelcomeCard(colors),
      ],
    );
  }

  Widget _buildAppBarRow(BuildContext context, DobarColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'dobar',
          style: GoogleFonts.poppins(
            color: colors.buttonPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        if (onNotificationTap != null)
          GestureDetector(
            onTap: onNotificationTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.buttonPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: colors.buttonOnPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWelcomeCard(DobarColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: colors.surfaceElevated, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.buttonPrimary,
              borderRadius: BorderRadius.circular(BarzRadii.sm),
            ),
            child: Icon(Icons.waving_hand, color: colors.buttonOnPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: colors.labelPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to order?',
                  style: TextStyle(color: colors.labelSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
