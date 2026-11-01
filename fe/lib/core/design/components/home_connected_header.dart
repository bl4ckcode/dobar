import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final countLabel = unreadNotifications > 99
        ? '99+'
        : unreadNotifications.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (nearbyBarName != null)
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.home_nearby_checkin_prompt(nearbyBarName!),
                child: InkWell(
                  onTap: onBarTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colors.surfaceElevated,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: barzGold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.map_pin,
                            color: barzDark,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.home_nearby_prefix,
                                style: TextStyle(
                                  color: colors.labelSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                nearbyBarName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.labelPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          LucideIcons.chevron_right,
                          color: colors.labelSecondary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          if (onNotificationTap != null && unreadNotifications > 0)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Semantics(
                button: true,
                label: l10n.home_notifications(countLabel),
                child: InkWell(
                  onTap: onNotificationTap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.surfaceElevated,
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          LucideIcons.bell,
                          color: colors.labelPrimary,
                          size: 20,
                        ),
                        Positioned(
                          right: -2,
                          top: -3,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: colors.background,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              countLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
