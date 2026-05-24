import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/locale/locale_cubit.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BusinessSettingsPage extends StatelessWidget {
  const BusinessSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is! SessionReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeBar = state.session.activeBar;
        if (activeBar == null) return const SizedBox.shrink();

        final dobar = context.dobarColors;
        final mutedColor = dobar.labelSecondary;
        final bgColor = dobar.background;

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            bottom: false,
            child: ResponsiveCenterContainer(
              maxWidthPercentage: 0.9,
              maxWidth: 1400,
              padding: EdgeInsets.zero,
              child: ListView(
                children: [
                  _SettingsHeader(
                    barName: activeBar.barName,
                    role: activeBar.role.displayName,
                  ),

                  const _SectionHeader(label: 'General Settings'),

                  // App Appearance with functional theme toggle and Lucide icons
                  BlocBuilder<ThemeCubit, ThemeMode>(
                    builder: (context, themeMode) {
                      final isDark = themeMode == ThemeMode.dark;
                      return _SettingItem(
                        icon: isDark ? LucideIcons.moon : LucideIcons.sun,
                        label: 'App Appearance',
                        onTap: () {
                          context.read<ThemeCubit>().toggleTheme();
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isDark ? 'Dark Mode' : 'Light Mode',
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 24,
                              child: Switch.adaptive(
                                value: isDark,
                                onChanged: (_) {
                                  context.read<ThemeCubit>().toggleTheme();
                                },
                                activeTrackColor: barzGold.withValues(alpha: 0.4),
                                activeThumbColor: barzGold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),

                  // Language selector (dynamically shows current locale)
                  BlocBuilder<LocaleCubit, Locale>(
                    builder: (context, locale) {
                      final languageName = _languageDisplayName(locale.languageCode);
                      return _SettingItem(
                        icon: LucideIcons.globe,
                        label: 'Language',
                        trailing: Text(
                          languageName,
                          style: TextStyle(color: mutedColor, fontSize: 13),
                        ),
                        onTap: () => _showLanguageSelector(context),
                      );
                    },
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                  // Business Details
                  _SettingItem(
                    icon: LucideIcons.store,
                    label: 'Business Details',
                    trailing: Text(
                      'Edit',
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                    onTap: () {
                      _showComingSoon(context, 'Business Details');
                    },
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),

                  // Contact Settings
                  _SettingItem(
                    icon: LucideIcons.settings,
                    label: 'Contact Settings',
                    onTap: () {
                      _showComingSoon(context, 'Contact Settings');
                    },
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                  const _SectionHeader(label: 'Legal & Compliance'),

                  // Terms of Service
                  _SettingItem(
                    icon: LucideIcons.fileText,
                    label: 'Terms of Service',
                    onTap: () {
                      AppRoute.termsOfService.push(context);
                    },
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),

                  // Privacy Policy
                  _SettingItem(
                    icon: LucideIcons.shieldCheck,
                    label: 'Privacy Policy',
                    onTap: () {
                      AppRoute.privacyPolicy.push(context);
                    },
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                  // Operational Rules
                  _SettingItem(
                    icon: LucideIcons.scale,
                    label: 'Operational Rules',
                    onTap: () {
                      _showComingSoon(context, 'Operational Rules');
                    },
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                  const _DangerZone(),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'V2.4.1 // SESSION ACTIVE',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          letterSpacing: 2,
                          color: mutedColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _languageDisplayName(String code) {
    switch (code) {
      case 'pt':
        return 'Português';
      case 'es':
        return 'Español';
      default:
        return 'English';
    }
  }

  void _showLanguageSelector(BuildContext context) {
    final currentLocale = context.read<LocaleCubit>().state;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.dobarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colors = context.dobarColors;
        final localeCubit = context.read<LocaleCubit>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.labelSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.labelPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _LanguageOption(
                  label: 'English',
                  subtitle: 'English (US)',
                  isSelected: currentLocale.languageCode == 'en',
                  onTap: () {
                    localeCubit.setLanguageCode('en');
                    Navigator.pop(context);
                  },
                ),
                _LanguageOption(
                  label: 'Português',
                  subtitle: 'Brazilian Portuguese',
                  isSelected: currentLocale.languageCode == 'pt',
                  onTap: () {
                    localeCubit.setLanguageCode('pt');
                    Navigator.pop(context);
                  },
                ),
                _LanguageOption(
                  label: 'Español',
                  subtitle: 'Latin American Spanish',
                  isSelected: currentLocale.languageCode == 'es',
                  onTap: () {
                    localeCubit.setLanguageCode('es');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return ListTile(
      leading: Icon(
        isSelected ? LucideIcons.checkCircle : LucideIcons.languages,
        color: isSelected ? barzGold : colors.labelSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? barzGold : colors.labelPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.labelSecondary, fontSize: 12),
      ),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: barzGold, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String barName;
  final String role;

  const _SettingsHeader({required this.barName, required this.role});

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: barzGold),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: barzGold,
                          fontFamily: 'Courier',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      barName.toUpperCase(),
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'Courier',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SYSTEM_SETTINGS // BUSINESS_CONTROL',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.store,
                  color: mutedColor,
                  size: 20,
                ),
                onPressed: () {},
              ).animate().fadeIn().scale(),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _HeaderAction(
                label: 'Switch Bar',
                icon: LucideIcons.chevronRight,
                onTap: () {},
                color: barzGold,
              ),
              const SizedBox(width: 16),
              Text(
                '|',
                style: TextStyle(color: dobar.surfaceElevated),
              ),
              const SizedBox(width: 16),
              _HeaderAction(
                label: 'View Public Profile',
                icon: LucideIcons.chevronRight,
                onTap: () {},
                color: mutedColor,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Divider(color: dobar.surfaceElevated),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: color, size: 14),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final mutedColor = context.dobarColors.labelSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: mutedColor,
          fontFamily: 'Courier',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const _SettingItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final theme = Theme.of(context);
    final color = destructive ? errorRed : dobar.labelPrimary;
    final iconColor = destructive ? errorRed : dobar.labelSecondary;
    final bgColor = dobar.background;
    final dividerColor = theme.colorScheme.outline;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
              Icon(
                LucideIcons.chevronRight,
                color: destructive
                    ? errorRed.withValues(alpha: 0.4)
                    : dividerColor,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone();

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.dobarColors.surface,
            title: Text(
              title,
              style: TextStyle(
                color: errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              message,
              style: TextStyle(color: context.dobarColors.labelPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: context.dobarColors.labelSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: errorRed),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [dobar.surface, errorRed.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: errorRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              '⚠ DANGER ZONE',
              style: TextStyle(
                color: errorRed,
                fontFamily: 'Courier',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          _SettingItem(
            icon: LucideIcons.trash2,
            label: 'Delete Business Data',
            destructive: true,
            onTap: () async {
              final confirmed = await _confirmAction(
                context,
                title: 'Delete Business Data',
                message:
                    'This action is irreversible. All campaign history, menu data, and order records will be permanently deleted. Continue?',
                confirmLabel: 'Delete Everything',
              );
              if (confirmed && context.mounted) {
                _showComingSoon(context, 'Delete Business Data API');
              }
            },
          ),
          _SettingItem(
            icon: LucideIcons.alertTriangle,
            label: 'Deactivate Account',
            destructive: true,
            onTap: () async {
              final confirmed = await _confirmAction(
                context,
                title: 'Deactivate Account',
                message:
                    'Your business profile and all associated data will be temporarily disabled. You can reactivate at any time. Continue?',
                confirmLabel: 'Deactivate',
              );
              if (confirmed && context.mounted) {
                _showComingSoon(context, 'Deactivate Account API');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}