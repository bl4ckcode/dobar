import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/services/biometry_service.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final BiometryService _biometryService = getItInjector<BiometryService>();
  late bool _biometryEnabled;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _biometryEnabled = _biometryService.isEnabled;
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    _selectedLanguage = locale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final themeCubit = context.read<ThemeCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: colors.surface,
        foregroundColor: colors.labelPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        children: [
          _buildSectionTitle('Appearance', colors),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: isDark ? Icons.dark_mode : Icons.light_mode,
            title: 'Dark Mode',
            subtitle: isDark ? 'Currently dark' : 'Currently light',
            value: isDark,
            onChanged: (_) => themeCubit.toggleTheme(),
            colors: colors,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Security', colors),
          const SizedBox(height: 12),
          FutureBuilder<bool>(
            future: _biometryService.isAvailable,
            builder: (context, snapshot) {
              final available = snapshot.data ?? false;
              if (!available) return const SizedBox.shrink();
              return _buildSwitchTile(
                icon: Icons.fingerprint,
                title: 'Biometric Login',
                subtitle: 'Use Face ID or fingerprint',
                value: _biometryEnabled,
                onChanged: (val) async {
                  if (val) {
                    final ok = await _biometryService.authenticate(
                      'Confirm to enable biometric login',
                    );
                    if (ok) {
                      await _biometryService.enable();
                      setState(() => _biometryEnabled = true);
                    }
                  } else {
                    await _biometryService.clear();
                    setState(() => _biometryEnabled = false);
                  }
                },
                colors: colors,
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Language', colors),
          const SizedBox(height: 12),
          _buildLanguageTile('English', 'en', colors),
          _buildLanguageTile('Português', 'pt', colors),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, DobarColors colors) {
    return Text(
      title,
      style: TextStyle(
        color: colors.labelPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required DobarColors colors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: barzGoldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: barzGold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.labelPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.labelSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: barzGold,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(String label, String code, DobarColors colors) {
    final isSelected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: barzGold, width: 2) : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.labelPrimary,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: barzGold, size: 24),
          ],
        ),
      ),
    );
  }
}
