import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/shared/presentation/widget/bar_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/location/presentation/location_permission_explainer.dart';

class CheckinPage extends StatefulWidget {
  final BarModel? initialBar;
  final bool returnOnCheckin;

  const CheckinPage({super.key, this.initialBar, this.returnOnCheckin = false});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  late final CheckinBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = getItInjector<CheckinBloc>();
    if (widget.initialBar != null) {
      bloc.add(SelectBar(widget.initialBar!));
    } else {
      bloc.add(const LoadActiveCheckin());
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: bloc,
    child: _CheckinPageContent(
      returnOnCheckin: widget.returnOnCheckin,
      barId: widget.initialBar?.id,
    ),
  );
}

class _CheckinPageContent extends StatelessWidget {
  final bool returnOnCheckin;
  final int? barId;
  const _CheckinPageContent({this.returnOnCheckin = false, this.barId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          l10n.checkin_title,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.navBackground,
        elevation: 0,
      ),
      body: BlocConsumer<CheckinBloc, CheckinState>(
        listenWhen: (previous, current) =>
            previous.error != current.error ||
            previous.activeCheckin != current.activeCheckin,
        listener: (context, state) {
          if (!context.mounted) return;
          if (returnOnCheckin &&
              state.isCheckedIn &&
              state.activeCheckin?.barId == barId) {
            context.pop(true);
            return;
          }
          if (state.error != null) {
            final bloc = context.read<CheckinBloc>();
            bloc.add(const ClearCheckinError());
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 4),
                showCloseIcon: true,
                closeIconColor: Theme.of(context).colorScheme.onError,
                content: Text(
                  switch (state.error) {
                    'CHECKIN_INVALID_QR' => l10n.checkin_invalid_qr,
                    'CHECKIN_TOO_FAR' ||
                    'CHECKIN_DISTANCE_REQUIRED' => l10n.checkin_too_far,
                    'CHECKIN_LOCATION_REQUIRED' ||
                    'CHECKIN_LOCATION_STALE' ||
                    'CHECKIN_STALE_LOCATION' => l10n.checkin_location_required,
                    'CHECKIN_INVALID_LOCATION' ||
                    'VALIDATION_ERROR' => l10n.checkin_invalid_location,
                    _ => l10n.checkin_retry_message,
                  },
                  style: GoogleFonts.spaceGrotesk(
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const BarzLoadingWidget();
          }

          if (state.isCheckedIn) {
            return _ActiveCheckinView(state: state);
          }

          return Animate(
            key: ValueKey(state.step),
            effects: const [FadeEffect(duration: Duration(milliseconds: 400))],
            child: _buildStep(state),
          );
        },
      ),
    );
  }

  Widget _buildStep(CheckinState state) {
    switch (state.step) {
      case CheckinStep.scanning:
        return const _ScanningView();
      case CheckinStep.nearbyBars:
        return _NearbyBarsView(state: state);
      case CheckinStep.confirmCheckin:
        return _ConfirmCheckinView(state: state);
      case CheckinStep.initial:
      default:
        return const _InitialView();
    }
  }
}

class _InitialView extends StatefulWidget {
  const _InitialView();

  @override
  State<_InitialView> createState() => _InitialViewState();
}

class _InitialViewState extends State<_InitialView> {
  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final locationState = context.read<LocationCubit>().state;
    if (locationState.hasPermission && locationState.currentLocation != null) {
      _findNearbyBars(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;

    return Stack(
      children: [
        // Background Glow
        Positioned(
          top: -100,
          left: -100,
          child:
              Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.buttonPrimary.withValues(alpha: 0.1),
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .blur(
                    begin: const Offset(100, 100),
                    end: const Offset(120, 120),
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                    duration: 4.seconds,
                  ),
        ),
        _buildContent(context, l10n, colors),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    DobarColors colors,
  ) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 100,
        ),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                // Animated QR Icon
                Center(
                  child:
                      Container(
                            width:
                                120, // Reduced from 160 to make room for list
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surfaceElevated,
                              border: Border.all(
                                color: colors.buttonPrimary.withValues(
                                  alpha: 0.2,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.qr_code,
                              size: 60,
                              color: colors.buttonPrimary,
                            ),
                          )
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.05, 1.05),
                            duration: 2.seconds,
                          )
                          .boxShadow(
                            begin: BoxShadow(
                              color: colors.buttonPrimary.withValues(alpha: 0),
                              blurRadius: 0,
                            ),
                            end: BoxShadow(
                              color: colors.buttonPrimary.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 40,
                            ),
                          ),
                ),

                const SizedBox(height: 32),

                Text(
                  l10n.checkin_initial_heading,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.labelPrimary,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 12),

                Text(
                      l10n.checkin_initial_subtitle,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        color: colors.labelSecondary,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 32),

                // Action Buttons (Stacked vertically one after another)
                Column(
                      children: [
                        _PrimaryButton(
                          onPressed: () => context.read<CheckinBloc>().add(
                            const StartQrScan(),
                          ),
                          icon: LucideIcons.scan,
                          label: l10n.checkin_qr_input,
                        ),
                        const SizedBox(height: 16),
                        _SecondaryButton(
                          onPressed: () {
                            // Switch straight to nearby bars view
                            context.read<CheckinBloc>().add(
                              const ResetCheckin(),
                            );
                            // Trigger finding bars immediately
                            _findNearbyBars(context);
                          },
                          icon: LucideIcons.map_pin,
                          label: l10n.checkin_initial_find_nearby,
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 48),
                _RadarPing(color: colors.buttonPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _findNearbyBars(BuildContext context) async {
    final locationCubit = context.read<LocationCubit>();

    try {
      if (!await LocationPermissionExplainer.ensure(context)) return;
      if (!context.mounted) return;
      final locationData = locationCubit.state.currentLocation;

      if (locationData != null && context.mounted) {
        context.read<CheckinBloc>().add(
          FindNearbyBars(
            latitude: locationData.latitude,
            longitude: locationData.longitude,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.checkin_location_required,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _RadarPing extends StatelessWidget {
  final Color color;
  const _RadarPing({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(20, 20),
          duration: 2.seconds,
        )
        .fadeOut(duration: 2.seconds);
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _PrimaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: LinearGradient(
            colors: [
              colors.buttonPrimary,
              colors.buttonPrimary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.buttonPrimary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.buttonOnPrimary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.buttonOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _SecondaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: colors.surfaceElevated, width: 2),
          color: colors.background,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.labelPrimary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.labelPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanningView extends StatefulWidget {
  const _ScanningView();
  @override
  State<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<_ScanningView> {
  final controller = TextEditingController();
  void _submit() {
    if (controller.text.trim().isNotEmpty) {
      context.read<CheckinBloc>().add(QrCodeScanned(controller.text.trim()));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(LucideIcons.link, size: 48, color: colors.buttonPrimary),
          const SizedBox(height: 24),
          Text(
            l10n.checkin_qr_input,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.checkin_qr_manual_hint,
            style: TextStyle(color: colors.labelSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.checkin_qr_input),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: Text(l10n.next)),
          const SizedBox(height: 12),
          _GhostButton(
            onPressed: () =>
                context.read<CheckinBloc>().add(const ResetCheckin()),
            label: l10n.cancel,
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _GhostButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.dobarColors.labelSecondary,
        ),
      ),
    );
  }
}

class _NearbyBarsView extends StatelessWidget {
  final CheckinState state;

  const _NearbyBarsView({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;

    if (state.nearbyBars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.map_pin_off,
              size: 64,
              color: colors.labelSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.checkin_nearby_empty_heading,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.labelPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _GhostButton(
              onPressed: () =>
                  context.read<CheckinBloc>().add(const StartQrScan()),
              label: l10n.checkin_qr_input,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    context.read<CheckinBloc>().add(const ResetCheckin()),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.arrow_left,
                    color: colors.labelPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.checkin_nearby_heading,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.labelPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.nearbyBars.length,
            itemBuilder: (context, index) {
              final bar = state.nearbyBars[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _BarCard(bar: bar)
                    .animate()
                    .fadeIn(delay: (index * 100).ms)
                    .slideX(begin: 0.1, end: 0),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BarCard extends StatelessWidget {
  final BarModel bar;

  const _BarCard({required this.bar});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return GestureDetector(
      onTap: () => context.read<CheckinBloc>().add(SelectBar(bar)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.surface.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            BarImageAvatar(
              barId: bar.id,
              imageUrl: bar.imageUrl,
              imageUrlExpiration: bar.imageUrlExpiration,
              radius: 30,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bar.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.labelPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bar.address,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: colors.labelSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.buttonPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bar.approximateLocation != null
                    ? '${bar.approximateLocation!.round()} m'
                    : '—',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.labelPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final colors = context.dobarColors;
    final bar = widget.state.selectedBar;

    if (bar == null) {
      return Center(
        child: Text(
          l10n.error_generic,
          style: GoogleFonts.spaceGrotesk(color: colors.labelPrimary),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Image with Gradient
          Stack(
            children: [
              BarImage(
                imageUrl: bar.imageUrl,
                imageUrlExpiration: bar.imageUrlExpiration,
                barId: bar.id,
                width: double.infinity,
                height: 300,
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.background.withValues(alpha: 0),
                        colors.background.withValues(alpha: 0.5),
                        colors.background,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 800.ms),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  bar.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colors.labelPrimary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().slideY(begin: 0.2, end: 0, duration: 600.ms),

                const SizedBox(height: 8),

                Text(
                  bar.address,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: colors.labelSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().slideY(begin: 0.2, end: 0, delay: 100.ms),

                const SizedBox(height: 48),

                if (widget.state.locationConfig?.method ==
                    LocationMethod.spotList)
                  DropdownButtonFormField<String>(
                    initialValue:
                        widget.state.locationConfig!.spots.any(
                          (spot) => spot.id == widget.state.tableNumber,
                        )
                        ? widget.state.tableNumber
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.cart_location_label,
                    ),
                    items: widget.state.locationConfig!.spots
                        .map(
                          (spot) => DropdownMenuItem(
                            value: spot.id,
                            child: Text(spot.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        context.read<CheckinBloc>().add(SetTableNumber(value));
                      }
                    },
                  )
                else
                  TextField(
                    controller: _tableController,
                    style: GoogleFonts.spaceGrotesk(
                      color: colors.labelPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    keyboardType:
                        widget.state.locationConfig?.method ==
                            LocationMethod.freeText
                        ? TextInputType.text
                        : TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          widget.state.locationConfig?.method ==
                              LocationMethod.freeText
                          ? l10n.cart_location_label
                          : l10n.cart_table_number,
                      labelStyle: GoogleFonts.spaceGrotesk(
                        color: colors.labelSecondary,
                      ),
                      hintText: "00",
                      hintStyle: GoogleFonts.spaceGrotesk(
                        color: colors.labelSecondary.withValues(alpha: 0.3),
                      ),
                      prefixIcon: Icon(
                        LucideIcons.hash,
                        color: colors.buttonPrimary,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.surfaceElevated),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.buttonPrimary),
                      ),
                      filled: true,
                      fillColor: colors.surfaceElevated.withValues(alpha: 0.5),
                    ),
                    onChanged: (value) {
                      context.read<CheckinBloc>().add(SetTableNumber(value));
                    },
                  ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 40),

                _PrimaryButton(
                  onPressed: () =>
                      context.read<CheckinBloc>().add(const ConfirmCheckin()),
                  icon: LucideIcons.check,
                  label: l10n.checkin_confirm_cta,
                ).animate().fadeIn(delay: 400.ms).scale(),

                const SizedBox(height: 16),

                _GhostButton(
                  onPressed: () =>
                      context.read<CheckinBloc>().add(const ResetCheckin()),
                  label: l10n.cancel,
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCheckinView extends StatelessWidget {
  final CheckinState state;

  const _ActiveCheckinView({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    final checkin = state.activeCheckin!;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Pulsing Success Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.buttonPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.buttonPrimary,
                          ),
                        )
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.5, 1.5),
                        )
                        .boxShadow(
                          begin: BoxShadow(
                            color: colors.buttonPrimary,
                            blurRadius: 0,
                          ),
                          end: BoxShadow(
                            color: colors.buttonPrimary,
                            blurRadius: 10,
                          ),
                        ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.checkin_active_badge.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.buttonPrimary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),

              const SizedBox(height: 32),

              Text(
                checkin.barName,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: colors.labelPrimary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.hash,
                      size: 16,
                      color: colors.labelSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.checkin_active_table(checkin.tableNumber ?? "??"),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.labelPrimary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 56),

              // Monospace Timer
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, _) {
                  final duration = checkin.duration;
                  final h = duration.inHours.toString().padLeft(2, '0');
                  final m = (duration.inMinutes % 60).toString().padLeft(
                    2,
                    '0',
                  );
                  final s = (duration.inSeconds % 60).toString().padLeft(
                    2,
                    '0',
                  );

                  return Text(
                    '$h:$m:$s',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                      color: colors.labelPrimary,
                    ),
                  );
                },
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 64),

              // Primary Actions
              _PrimaryButton(
                onPressed: () => AppRoute.pushBar(context, checkin.barId),
                icon: LucideIcons.utensils_crossed,
                label: l10n.checkin_active_browse_menu,
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              _SecondaryButton(
                onPressed: () => AppRoute.cart.push(context),
                icon: LucideIcons.shopping_cart,
                label: l10n.checkin_active_view_cart,
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 48),

              // Checkout Link
              _GhostButton(
                onPressed: () =>
                    _showCheckoutSheet(context, l10n, checkin.barName),
                label: l10n.checkin_active_checkout,
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ],
    );
  }

  void _showCheckoutSheet(
    BuildContext context,
    AppLocalizations l10n,
    String barName,
  ) {
    final colors = context.dobarColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
              l10n.checkin_checkout_title(barName),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.labelPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.checkin_checkout_subtitle,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: colors.labelSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _PrimaryDestructiveButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<CheckinBloc>().add(const Checkout());
              },
              label: l10n.checkin_checkout_confirm,
            ),
            const SizedBox(height: 12),
            _GhostButton(
              onPressed: () => Navigator.pop(ctx),
              label: l10n.checkin_checkout_cancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryDestructiveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _PrimaryDestructiveButton({
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}
