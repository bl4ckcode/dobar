import 'package:flutter/material.dart';
import '../design_system.dart';

class DobarHomeHeader extends StatelessWidget {
  final VoidCallback? onNotificationTap;

  const DobarHomeHeader({super.key, this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildAppBarRow(context, colors)],
      ),
    );
  }

  Widget _buildAppBarRow(BuildContext context, DobarColors colors) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Image.asset(
            'assets/icons/dobar-logo-animated-transparent.gif',
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          right: 0,
          child: onNotificationTap != null
              ? GestureDetector(
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
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
