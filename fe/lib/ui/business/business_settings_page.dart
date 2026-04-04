import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/core/rbac/rbac.dart';
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

        return Scaffold(
          backgroundColor: barzDark,
          body: SafeArea(
            bottom: false,
            child: ListView(
              children: [
                _SettingsHeader(
                  barName: activeBar.barName,
                  role: activeBar.role.displayName,
                ),

                const _SectionHeader(label: 'General Settings'),

                const _SettingItem(
                  icon: LucideIcons.palette,
                  label: 'App Appearance',
                  value: 'Dark Mode',
                ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),

                const _SettingItem(
                  icon: LucideIcons.globe,
                  label: 'Language',
                  value: 'English',
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                const _SettingItem(
                  icon: LucideIcons.store,
                  label: 'Business Details',
                  value: 'Edit',
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),

                const _SettingItem(
                  icon: LucideIcons.settings,
                  label: 'Contact Settings',
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                const _SectionHeader(label: 'Legal & Compliance'),

                const _SettingItem(
                  icon: LucideIcons.fileText,
                  label: 'Terms of Service',
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),

                const _SettingItem(
                  icon: LucideIcons.shieldCheck,
                  label: 'Privacy Policy',
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                const _SettingItem(
                  icon: LucideIcons.scale,
                  label: 'Operational Rules',
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                const _DangerZone(),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'V2.4.1 // SESSION ACTIVE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontFamily: 'Courier',
                        letterSpacing: 2,
                        color: textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String barName;
  final String role;

  const _SettingsHeader({required this.barName, required this.role});

  @override
  Widget build(BuildContext context) {
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'SYSTEM_SETTINGS // BUSINESS_CONTROL',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.store,
                  color: textTertiary,
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
              const Text('|', style: TextStyle(color: Color(0xFF333333))),
              const SizedBox(width: 16),
              _HeaderAction(
                label: 'View Public Profile',
                icon: LucideIcons.chevronRight,
                onTap: () {},
                color: textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: Color(0xFF222222)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: textTertiary,
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
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  const _SettingItem({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? errorRed : textPrimary;
    final iconColor = destructive ? errorRed : textSecondary;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          color: barzDark,
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
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
            if (value != null)
              Text(
                value!,
                style: const TextStyle(color: textTertiary, fontSize: 13),
              ),
            const SizedBox(width: 12),
            Icon(
              LucideIcons.chevronRight,
              color: destructive
                  ? errorRed.withValues(alpha: 0.4)
                  : const Color(0xFF333333),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF121212), errorRed.withValues(alpha: 0.05)],
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
            value: 'Permanent',
            destructive: true,
            onTap: () {},
          ),
          _SettingItem(
            icon: LucideIcons.alertTriangle,
            label: 'Deactivate Account',
            value: 'Temporary',
            destructive: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
