import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/shared/presentation/widget/theme_toggle_button.dart';

/// Type 1: Reusable toolbar for business pages with specific actions.
/// Used in Staff Management and Menu Management.
class BusinessActionToolbar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget>? actions;
  final bool isNarrow;

  const BusinessActionToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions,
    this.isNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final textColor = dobar.labelPrimary;
    final mutedTextColor = dobar.labelSecondary;

    final titleBlock = Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: dobar.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: BarzSpacing.md),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isNarrow ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: 'Space Grotesk',
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(color: mutedTextColor, fontSize: 13),
              ),
          ],
        ),
      ],
    );

    if (isNarrow) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: BarzSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: BarzSpacing.md),
              Wrap(
                spacing: BarzSpacing.sm,
                runSpacing: BarzSpacing.sm,
                children: actions!,
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: BarzSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: titleBlock),
          if (actions != null && actions!.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!.expand((w) => [w, const SizedBox(width: BarzSpacing.sm)]).toList()..removeLast(),
            ),
        ],
      ),
    );
  }
}

/// Type 2: Reusable toolbar for high-level business pages.
/// Used in Dashboard, Cashier, and Campaigns.
class BusinessStatusToolbar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool? isOpen;
  final VoidCallback? onToggleOpen;
  final bool showClientModeToggle;
  final bool showSearch;
  final bool showNotifications;
  final bool showStatusToggle;
  final bool showAvatar;
  final List<Widget>? actions;

  const BusinessStatusToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.isOpen,
    this.onToggleOpen,
    this.showClientModeToggle = true,
    this.showSearch = true,
    this.showNotifications = true,
    this.showStatusToggle = true,
    this.showAvatar = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF0A0A0A) : dobar.surfaceElevated;
    final borderColor = isDark ? const Color(0xFF1A1A1A) : theme.colorScheme.outline;
    final textColor = dobar.labelPrimary;
    final mutedTextColor = dobar.labelSecondary;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: mutedTextColor, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              if (actions != null) ...[
                ...actions!,
                const SizedBox(width: 12),
              ],
              // Open/Closed Toggle
              if (showStatusToggle && isOpen != null && onToggleOpen != null) ...[
                BusinessStatusToggle(
                  isOpen: isOpen!,
                  onTap: onToggleOpen!,
                ),
                const SizedBox(width: 12),
              ],
              // Search
              if (showSearch) ...[
                _ToolbarIcon(icon: LucideIcons.search, borderColor: borderColor, color: mutedTextColor),
                const SizedBox(width: 12),
              ],
              // Notifications
              if (showNotifications) ...[
                Stack(
                  children: [
                    _ToolbarIcon(icon: LucideIcons.bell, borderColor: borderColor, color: mutedTextColor),
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: barzGold,
                          shape: BoxShape.circle,
                          border: Border.all(color: headerBg, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              // Theme Toggle
              const ThemeToggleButton(),
              const SizedBox(width: 12),
              // Switch to client
              if (showClientModeToggle) ...[
                _ClientModeButton(borderColor: borderColor, textColor: mutedTextColor),
                const SizedBox(width: 12),
              ],
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: barzGold.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    'JD',
                    style: TextStyle(
                      color: barzGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final Color borderColor;
  final Color color;

  const _ToolbarIcon({required this.icon, required this.borderColor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _ClientModeButton extends StatelessWidget {
  final Color borderColor;
  final Color textColor;

  const _ClientModeButton({required this.borderColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(LucideIcons.user, size: 18),
      label: const Text('Client Mode'),
      style: TextButton.styleFrom(
        foregroundColor: textColor,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: borderColor),
        ),
      ),
      onPressed: () {
        context.read<SessionBloc>().add(
          const SessionEvent.switchToClientMode(),
        );
      },
    );
  }
}

class BusinessStatusToggle extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;
  final bool compact;

  const BusinessStatusToggle({
    super.key,
    required this.isOpen,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isOpen
              ? successGreen.withValues(alpha: 0.15)
              : errorRed.withValues(alpha: 0.15),
          border: Border.all(
            color: isOpen
                ? successGreen.withValues(alpha: 0.3)
                : errorRed.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isOpen ? successGreen : errorRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOpen ? 'Open' : 'Closed',
              style: TextStyle(
                color: isOpen ? successGreen : errorRed,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
