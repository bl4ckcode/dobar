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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';

class CheckinPage extends StatelessWidget {
  final BarModel? initialBar;

  const CheckinPage({super.key, this.initialBar});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getItInjector<CheckinBloc>();
        if (initialBar != null) {
          bloc.add(SelectBar(initialBar!));
        } else {
          bloc.add(const LoadActiveCheckin());
        }
        return bloc;
      },
      child: const _CheckinPageContent(),
    );
  }
}

class _CheckinPageContent extends StatelessWidget {
  const _CheckinPageContent();

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
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.error!,
                  style: GoogleFonts.spaceGrotesk(color: Colors.white),
                ),
                backgroundColor: Colors.redAccent,
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
            return Center(
              child: CircularProgressIndicator(color: colors.buttonPrimary),
            );
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
                              LucideIcons.qrCode,
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
                      label: l10n.checkin_initial_scan_qr,
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
                      icon: LucideIcons.mapPin,
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
      await locationCubit.getCurrentLocation();
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
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.redAccent,
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

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;

    return Container(
      color: colors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Scanning Frame
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: colors.surfaceElevated, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      children: [
                        // Scanning Beam
                        Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      colors.buttonPrimary.withValues(
                                        alpha: 0.3,
                                      ),
                                      colors.buttonPrimary.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .moveY(
                              begin: -100,
                              end: 280,
                              duration: 2.seconds,
                              curve: Curves.easeInOut,
                            ),

                        const Center(
                          child: Opacity(
                            opacity: 0.5,
                            child: Icon(
                              LucideIcons.camera,
                              size: 48,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Corner Brackets
                ..._buildCorners(colors.buttonPrimary),
              ],
            ),
          ),

          const SizedBox(height: 48),

          Text(
            l10n.checkin_scanning_instruction,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colors.labelPrimary,
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          Text(
            l10n.cart_scan_qr_hint,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: colors.labelSecondary,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 64),

          // Demo/Cancel buttons
          _GhostButton(
            onPressed: () {
              context.read<CheckinBloc>().add(
                const QrCodeScanned('barz://bar/1?table=5'),
              );
            },
            label: l10n.checkin_demo_scan,
          ),
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

  List<Widget> _buildCorners(Color color) {
    const size = 30.0;
    const thickness = 4.0;
    return [
      // Top Left
      Positioned(
        top: -2,
        left: -2,
        child: _CornerPart(
          size: size,
          thickness: thickness,
          color: color,
          isTop: true,
          isLeft: true,
        ),
      ),
      // Top Right
      Positioned(
        top: -2,
        right: -2,
        child: _CornerPart(
          size: size,
          thickness: thickness,
          color: color,
          isTop: true,
          isLeft: false,
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: -2,
        left: -2,
        child: _CornerPart(
          size: size,
          thickness: thickness,
          color: color,
          isTop: false,
          isLeft: true,
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: -2,
        right: -2,
        child: _CornerPart(
          size: size,
          thickness: thickness,
          color: color,
          isTop: false,
          isLeft: false,
        ),
      ),
    ];
  }
}

class _CornerPart extends StatelessWidget {
  final double size;
  final double thickness;
  final Color color;
  final bool isTop;
  final bool isLeft;

  const _CornerPart({
    required this.size,
    required this.thickness,
    required this.color,
    required this.isTop,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
        ),
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
              LucideIcons.mapPinOff,
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
              label: l10n.checkin_nearby_empty_scan_instead,
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
                    LucideIcons.arrowLeft,
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
            BarImageAvatar(barId: bar.id, imageUrl: bar.imageUrl, radius: 30),
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
                '200m', // Hardcoded for now as bar model might not have distance
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

                TextField(
                  controller: _tableController,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.labelPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.cart_table_number,
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
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
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
                          begin: const BoxShadow(
                            color: Colors.green,
                            blurRadius: 0,
                          ),
                          end: const BoxShadow(
                            color: Colors.green,
                            blurRadius: 10,
                          ),
                        ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.checkin_active_badge.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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
                icon: LucideIcons.utensilsCrossed,
                label: l10n.checkin_active_browse_menu,
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              _SecondaryButton(
                onPressed: () => AppRoute.cart.push(context),
                icon: LucideIcons.shoppingCart,
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
          color: Colors.redAccent.withValues(alpha: 0.1),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
        ),
      ),
    );
  }
}
