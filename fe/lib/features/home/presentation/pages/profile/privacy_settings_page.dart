import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/user/domain/models/privacy_settings.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _locationSharing = true;
  bool _dataSharing = true;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final result = await getItInjector<UserRepository>().getPrivacySettings();
    if (mounted) {
      result.fold(
        (_) {
          setState(() => _loading = false);
        },
        (settings) {
          setState(() {
            _locationSharing = settings.locationEnabled;
            _dataSharing = settings.dataSharingEnabled;
            _loading = false;
          });
        },
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await getItInjector<UserRepository>()
          .updatePrivacySettings(
            PrivacySettings(
              locationEnabled: _locationSharing,
              dataSharingEnabled: _dataSharing,
            ),
          );
      if (mounted) {
        result.fold(
          (failure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.errorMessage)));
          },
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy settings saved')),
            );
          },
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _handleDeleteData() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account & Data', style: TextStyle(color: errorRed)),
        content: const Text(
          'Are you sure you want to permanently delete your account and data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: errorRed,
              backgroundColor: errorRed.withValues(alpha: 0.1),
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await getItInjector<UserRepository>().deleteAccount();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete data: ${failure.errorMessage}'),
            ),
          );
        },
        (_) async {
          await DioNetwork.clearTokens();
          if (mounted) {
            AppRoute.login.go(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your data and account have been deleted.')),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Privacy'),
        backgroundColor: colors.surface,
        foregroundColor: colors.labelPrimary,
        elevation: 0,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: TextStyle(color: barzGold, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(BarzSpacing.lg),
              children: [
                _buildSectionTitle('Location', colors),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location Sharing',
                  subtitle: 'Allow nearby bar discovery',
                  value: _locationSharing,
                  onChanged: (v) => setState(() => _locationSharing = v),
                  colors: colors,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Data', colors),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  icon: Icons.data_usage_outlined,
                  title: 'Data Sharing',
                  subtitle: 'Help improve the app by sharing usage data',
                  value: _dataSharing,
                  onChanged: (v) => setState(() => _dataSharing = v),
                  colors: colors,
                ),
                _buildInfoTile(
                  icon: Icons.shield_outlined,
                  title: 'Data Protection',
                  subtitle:
                      'Your data is protected under LGPD/GDPR regulations',
                  colors: colors,
                ),
                _buildInfoTile(
                  icon: Icons.download_outlined,
                  title: 'Export My Data',
                  subtitle: 'Request a copy of your data',
                  colors: colors,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data export requested')),
                    );
                  },
                ),
                _buildInfoTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete My Data',
                  subtitle: 'Permanently remove all your data',
                  colors: colors,
                  isDestructive: true,
                  onTap: _handleDeleteData,
                ),
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

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required DobarColors colors,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                color: isDestructive ? errorRed.withValues(alpha: 0.1) : barzGoldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDestructive ? errorRed : barzGold, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? errorRed : colors.labelPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.labelSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: colors.labelSecondary),
          ],
        ),
      ),
    );
  }
}
