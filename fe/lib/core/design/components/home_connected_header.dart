import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../design_system.dart';

class HomeConnectedHeader extends StatelessWidget {
  final VoidCallback? onNotificationTap;
  final VoidCallback? onBarTap;
  final String? nearbyBarName;
  final int unreadNotifications;
  final bool isProMember;

  const HomeConnectedHeader({
    super.key,
    this.onNotificationTap,
    this.onBarTap,
    this.nearbyBarName,
    this.unreadNotifications = 0,
    this.isProMember = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    if (nearbyBarName == null && unreadNotifications <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildAppBarRow(context, colors)],
    );
  }

  Widget _buildAppBarRow(BuildContext context, DobarColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (nearbyBarName != null)
            Expanded(
              child:
                  GestureDetector(
                        onTap: onBarTap,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.buttonPrimary,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place,
                                color: colors.buttonPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: colors.labelPrimary,
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Are you here: '),
                                      TextSpan(
                                        text: nearbyBarName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '? Make a check-in!',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: colors.labelSecondary,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                        duration: 1500.ms,
                        curve: Curves.easeInOut,
                      ),
            )
          else
            const SizedBox.shrink(),
          if (onNotificationTap != null && unreadNotifications > 0)
            GestureDetector(
              onTap: onNotificationTap,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  color: colors.buttonPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      LucideIcons.bell,
                      color: colors.buttonOnPrimary,
                      size: 20,
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.buttonPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
