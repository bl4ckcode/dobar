import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/shared/presentation/widget/bar_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:location/location.dart';

/// Main check-in page with QR scan and geo-location options
class CheckinPage extends StatelessWidget {
  const CheckinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getItInjector<CheckinBloc>()..add(const LoadActiveCheckin()),
      child: const _CheckinPageContent(),
    );
  }
}

class _CheckinPageContent extends StatelessWidget {
  const _CheckinPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkin_title)),
      body: BlocConsumer<CheckinBloc, CheckinState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: l10n.close,
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<CheckinBloc>().add(const ClearCheckinError());
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Currently checked in - show active check-in
          if (state.isCheckedIn) {
            return _ActiveCheckinView(state: state);
          }

          // Show check-in options based on current step
          switch (state.step) {
            case CheckinStep.scanning:
              return _ScanningView();
            case CheckinStep.nearbyBars:
              return _NearbyBarsView(state: state);
            case CheckinStep.confirmCheckin:
              return _ConfirmCheckinView(state: state);
            case CheckinStep.initial:
            default:
              return _InitialView();
          }
        },
      ),
    );
  }
}

/// Initial view with check-in options
class _InitialView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 120,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.checkin_title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.checkin_scan_hint,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // QR Scan Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                context.read<CheckinBloc>().add(const StartQrScan());
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.checkin_scan_qr),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            ),
          ),
          const SizedBox(height: 16),

          // Nearby Bars Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _findNearbyBars(context),
              icon: const Icon(Icons.location_on),
              label: const Text('Find bars nearby'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _findNearbyBars(BuildContext context) async {
    final location = Location();

    // Check permissions
    var serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    // Get location
    final locationData = await location.getLocation();
    if (locationData.latitude != null && locationData.longitude != null) {
      if (context.mounted) {
        context.read<CheckinBloc>().add(
          FindNearbyBars(
            latitude: locationData.latitude!,
            longitude: locationData.longitude!,
          ),
        );
      }
    }
  }
}

/// QR Scanning view (placeholder - would integrate camera)
class _ScanningView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera would appear here',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.checkin_scan_hint,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Demo: Simulate scan
          OutlinedButton(
            onPressed: () {
              // Simulate scanning a bar QR code
              context.read<CheckinBloc>().add(
                const QrCodeScanned('barz://bar/1?table=5'),
              );
            },
            child: const Text('Demo: Simulate QR Scan'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              context.read<CheckinBloc>().add(const ResetCheckin());
            },
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

/// Nearby bars list
class _NearbyBarsView extends StatelessWidget {
  final CheckinState state;

  const _NearbyBarsView({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (state.nearbyBars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No bars found nearby', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Try scanning a QR code instead',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                context.read<CheckinBloc>().add(const StartQrScan());
              },
              child: Text(l10n.checkin_scan_qr),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Bars near you', style: theme.textTheme.titleLarge),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.nearbyBars.length,
            itemBuilder: (context, index) {
              final bar = state.nearbyBars[index];
              return ListTile(
                leading: BarImageAvatar(
                  barId: bar.id,
                  imageUrl: bar.imageUrl,
                  radius: 28,
                ),
                title: Text(bar.name),
                subtitle: Text(bar.address),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.read<CheckinBloc>().add(SelectBar(bar));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Confirm check-in view
class _ConfirmCheckinView extends StatefulWidget {
  final CheckinState state;

  const _ConfirmCheckinView({required this.state});

  @override
  State<_ConfirmCheckinView> createState() => _ConfirmCheckinViewState();
}

class _ConfirmCheckinViewState extends State<_ConfirmCheckinView> {
  final _tableController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tableController.text = widget.state.tableNumber ?? '';
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bar = widget.state.selectedBar;

    if (bar == null) {
      return const Center(child: Text('No bar selected'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Bar Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BarImage(
              imageUrl: bar.imageUrl,
              barId: bar.id,
              width: double.infinity,
              height: 200,
            ),
          ),
          const SizedBox(height: 24),

          // Bar Name
          Text(
            bar.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bar.address,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Table Number Input
          TextField(
            controller: _tableController,
            decoration: InputDecoration(
              labelText: l10n.cart_table_number,
              hintText: 'e.g., 5, A1, Terrace',
              prefixIcon: const Icon(Icons.table_bar),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              context.read<CheckinBloc>().add(SetTableNumber(value));
            },
          ),
          const SizedBox(height: 32),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                context.read<CheckinBloc>().add(const ConfirmCheckin());
              },
              icon: const Icon(Icons.check),
              label: Text(l10n.checkin_confirm),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              context.read<CheckinBloc>().add(const ResetCheckin());
            },
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

/// Active check-in view
class _ActiveCheckinView extends StatelessWidget {
  final CheckinState state;

  const _ActiveCheckinView({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final checkin = state.activeCheckin!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Success Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),

          // Bar Name
          Text(
            l10n.checkin_at_bar(checkin.barName),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkin_success,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.green),
          ),

          if (checkin.tableNumber != null) ...[
            const SizedBox(height: 16),
            Chip(
              avatar: const Icon(Icons.table_bar, size: 18),
              label: Text('Table ${checkin.tableNumber}'),
            ),
          ],

          const SizedBox(height: 32),

          // Duration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder: (context, _) {
                      final duration = checkin.duration;
                      final hours = duration.inHours;
                      final minutes = duration.inMinutes % 60;
                      final seconds = duration.inSeconds % 60;
                      return Text(
                        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Browse Menu Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                AppRoute.pushBar(context, checkin.barId);
              },
              icon: const Icon(Icons.restaurant_menu),
              label: Text(l10n.checkin_browse_menu),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            ),
          ),
          const SizedBox(height: 16),

          // View Cart Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                AppRoute.cart.push(context);
              },
              icon: const Icon(Icons.shopping_cart),
              label: Text(l10n.cart_title),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Checkout Button
          TextButton.icon(
            onPressed: () {
              _showCheckoutDialog(context);
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Check out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check out?'),
        content: const Text(
          'Are you sure you want to check out from this bar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CheckinBloc>().add(const Checkout());
            },
            child: const Text('Check out'),
          ),
        ],
      ),
    );
  }
}
