import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/user/domain/models/notification_preferences.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _pushNotifications = true;
  bool _orderUpdates = true;
  bool _promotions = true;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final result = await getItInjector<UserRepository>()
        .getNotificationPreferences();
    if (mounted) {
      result.fold(
        (_) {
          setState(() => _loading = false);
        },
        (prefs) {
          setState(() {
            _pushNotifications = prefs.pushNotificationsEnabled;
            _orderUpdates = prefs.orderUpdatesEnabled;
            _promotions = prefs.promotionsEnabled;
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
          .updateNotificationPreferences(
            NotificationPreferences(
              pushNotificationsEnabled: _pushNotifications,
              orderUpdatesEnabled: _orderUpdates,
              promotionsEnabled: _promotions,
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Preferences saved')));
          },
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
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
              onPressed: _loading ? null : _save,
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
                _buildSectionTitle('Order Updates', colors),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  icon: Icons.notifications_active,
                  title: 'Push Notifications',
                  subtitle: 'Get notified about order status changes',
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                  colors: colors,
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
}
