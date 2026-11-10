import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Explains (in the user's language) why check-in and ordering need location,
/// then requests permission. Browsing never calls this. Server-side check-in
/// enforcement is unchanged; this only prepares the permission/fix.
class LocationPermissionExplainer {
  /// Returns true when a location fix is available afterwards.
  static Future<bool> ensure(BuildContext context) async {
    final cubit = context.read<LocationCubit>();
    if (cubit.state.hasPermission && cubit.state.currentLocation != null) {
      return true;
    }

    // Already granted at OS level: no explanation needed, just fetch.
    if (await cubit.hasPermissionNow()) {
      await cubit.getCurrentLocation();
      return cubit.state.currentLocation != null;
    }
    if (!context.mounted) return false;

    final permanentlyDenied = await cubit.isPermanentlyDenied();
    if (!context.mounted) return false;
    if (permanentlyDenied) return _showSettingsRecovery(context, cubit);

    final proceed = await _showExplanation(context);
    if (proceed != true) return false;

    await cubit.getCurrentLocation();
    if (cubit.state.currentLocation != null) return true;
    if (!context.mounted) return false;
    if (cubit.state.hasPermission == false) {
      await _showSettingsRecovery(context, cubit);
    }
    return false;
  }

  static Future<bool?> _showExplanation(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.location_explain_title),
        content: Text(l10n.location_explain_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.location_explain_cancel),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.location_explain_continue),
          ),
        ],
      ),
    );
  }

  static Future<bool> _showSettingsRecovery(
    BuildContext context,
    LocationCubit cubit,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.location_denied_title),
        content: Text(l10n.location_denied_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.location_explain_cancel),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.location_open_settings),
          ),
        ],
      ),
    );
    if (open == true) await cubit.openSettings();
    return false;
  }
}
