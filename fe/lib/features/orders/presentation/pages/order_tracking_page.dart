import 'dart:async';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/services/email_prompt_service.dart';
import 'package:barz/core/services/websocket/order_tracking_service.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_state.dart';
import 'package:barz/features/orders/presentation/widgets/order_summary_card.dart';
import 'package:barz/features/orders/presentation/widgets/progress_tracker.dart';
import 'package:barz/features/orders/presentation/widgets/venue_table_info.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/shared/presentation/widget/email_prompt_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:confetti/confetti.dart';

class OrderTrackingPage extends StatefulWidget {
  final int orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage>
    with TickerProviderStateMixin {
  Timer? _pollingTimer;
  late ConfettiController _confettiController;
  late AnimationController _pulseController;

  OrderStatus _currentStatus = OrderStatus.pending;
  bool _firedReady = false;
  bool _hasShownEmailPrompt = false;
  final DateTime _startTime = DateTime.now();
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _startTimer();
    _startPolling();
  }

  void _startPolling() {
    // Initial fetch handled by BlocProvider
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        context.read<OrderBloc>().add(
          LoadOrderTimeline(orderId: widget.orderId),
        );
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timer?.cancel();
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleStatusChange(OrderStatus newStatus) {
    if (newStatus == _currentStatus) return;

    setState(() {
      _currentStatus = newStatus;
    });

    _showStatusNotification(newStatus);

    if (newStatus == OrderStatus.ready && !_firedReady) {
      _firedReady = true;
      _confettiController.play();
    }
  }

  void _showStatusNotification(OrderStatus status) {
    final l10n = AppLocalizations.of(context)!;
    String message;

    switch (status) {
      case OrderStatus.confirmed:
        message = l10n.notification_order_confirmed;
        break;
      case OrderStatus.preparing:
        message = l10n.notification_order_preparing;
        break;
      case OrderStatus.ready:
        message = l10n.notification_order_ready;
        break;
      case OrderStatus.completed:
        message = l10n.order_status_completed;
        _maybeShowEmailPrompt();
        break;
      default:
        message = _getLocalizedStatusText(status, l10n);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(status.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.dobarColors.labelPrimary.withValues(
          alpha: 0.9,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dobarColors = context.dobarColors;
    final isReady =
        _currentStatus == OrderStatus.ready ||
        _currentStatus == OrderStatus.completed;

    return BlocProvider(
      create: (_) =>
          getItInjector<OrderBloc>()
            ..add(LoadOrderTimeline(orderId: widget.orderId)),
      child: BlocListener<OrderBloc, OrderState>(
        listener: (context, state) {
          if (state is OrderTimelineLoaded) {
            _handleStatusChange(OrderStatus.fromString(state.order.status));
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              // Ambient gold glow
              Positioned(
                top: -100,
                left: 0,
                right: 0,
                child: Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.5),
                      radius: 1.2,
                      colors: [
                        barzGold.withValues(alpha: isReady ? 0.15 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Top Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _IconButton(
                              icon: LucideIcons.arrowLeft,
                              onPressed: () => context.pop(),
                              colors: dobarColors,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: dobarColors.labelPrimary.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.clock,
                                    size: 14,
                                    color: barzGold,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildConnectionIndicator(dobarColors),
                          ],
                        ),
                      ),
                    ),

                    // Hero Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 32),
                        child: Column(
                          children: [
                            Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.glassWater,
                                      size: 14,
                                      color: barzGold,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n
                                          .order_number(widget.orderId)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 3,
                                        fontWeight: FontWeight.bold,
                                        color: dobarColors.labelPrimary
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                )
                                .animate()
                                .fadeIn(
                                  duration: const Duration(milliseconds: 500),
                                )
                                .slideY(begin: 0.1),
                            const SizedBox(height: 12),
                            const Text(
                                  'Lapa Lounge Bar',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                )
                                .animate()
                                .fadeIn(
                                  duration: const Duration(milliseconds: 600),
                                  delay: const Duration(milliseconds: 100),
                                )
                                .scale(begin: const Offset(0.95, 0.95)),
                            const SizedBox(height: 20),
                            _StatusBadge(
                                  isReady: isReady,
                                  colors: dobarColors,
                                  statusText: _getLocalizedStatusText(
                                    _currentStatus,
                                    l10n,
                                  ),
                                  pulseController: _pulseController,
                                )
                                .animate()
                                .fadeIn(
                                  duration: const Duration(milliseconds: 500),
                                  delay: const Duration(milliseconds: 200),
                                )
                                .scale(begin: const Offset(0.9, 0.9)),
                          ],
                        ),
                      ),
                    ),

                    // Tracking Content
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Progress Tracker Card
                          _GlassCard(
                                colors: dobarColors,
                                child: DobarProgressTracker(
                                  currentStatus: _currentStatus,
                                ),
                              )
                              .animate()
                              .fadeIn(
                                duration: const Duration(milliseconds: 600),
                                delay: const Duration(milliseconds: 300),
                              )
                              .slideY(begin: 0.05),

                          const SizedBox(height: 24),

                          // Order Summary Card
                          BlocBuilder<OrderBloc, OrderState>(
                            builder: (context, state) {
                              if (state is OrderTimelineLoaded) {
                                return OrderSummaryCard(order: state.order)
                                    .animate()
                                    .fadeIn(
                                      duration: const Duration(
                                        milliseconds: 600,
                                      ),
                                      delay: const Duration(milliseconds: 400),
                                    )
                                    .slideY(begin: 0.05);
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          const SizedBox(height: 24),

                          // Venue & Table Info
                          BlocBuilder<SessionBloc, SessionState>(
                            builder: (context, state) {
                              final tableNumber =
                                  context
                                      .watch<CheckinBloc>()
                                      .state
                                      .tableNumber ??
                                  '—';
                              return VenueTableInfo(
                                    tableNumber: tableNumber,
                                    onCallWaiter: () => _showTopSnackBar(
                                      context,
                                      l10n.support_on_the_way,
                                      LucideIcons.bellRing,
                                      context.dobarColors,
                                    ),
                                    onDirections: () => _showTopSnackBar(
                                      context,
                                      l10n.directions_opening,
                                      LucideIcons.mapPin,
                                      context.dobarColors,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(
                                    duration: const Duration(milliseconds: 600),
                                    delay: const Duration(milliseconds: 500),
                                  )
                                  .slideY(begin: 0.05);
                            },
                          ),

                          const SizedBox(height: 40),

                          // Footer Actions
                          _FooterActions(
                            colors: dobarColors,
                            onBack: () => context.pop(),
                            l10n: l10n,
                          ),
                          const SizedBox(height: 60),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),

              // Confetti
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [barzGold, Colors.yellow, Colors.orange],
                  gravity: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _maybeShowEmailPrompt() async {
    if (_hasShownEmailPrompt) return;

    final sessionState = context.read<SessionBloc>().state;
    final user = sessionState.currentSession?.user;
    if (user == null) return;

    final emailPromptService = getItInjector<EmailPromptService>();
    final hasEmail = user.email != null && user.email!.isNotEmpty;

    if (!emailPromptService.shouldShowPrompt(hasEmail: hasEmail)) return;

    _hasShownEmailPrompt = true;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final userUsecase = getItInjector<UserUsecase>();

    await EmailPromptModal.show(
      context,
      onSubmit: (email) async {
        final result = await userUsecase.updateProfile(email: email);
        result.fold(
          (failure) => throw Exception(failure.errorMessage),
          (_) async => await emailPromptService.clearDismissed(),
        );
      },
      onDismiss: () async {
        await emailPromptService.markDismissed();
      },
    );
  }

  Widget _buildConnectionIndicator(DobarColors colors) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.labelPrimary.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  String _getLocalizedStatusText(OrderStatus status, AppLocalizations l10n) {
    switch (status) {
      case OrderStatus.ready:
        return l10n.notification_order_ready;
      case OrderStatus.completed:
        return l10n.order_status_completed;
      case OrderStatus.preparing:
        return l10n.notification_order_preparing;
      case OrderStatus.confirmed:
        return l10n.notification_order_confirmed;
      default:
        return l10n.order_status_pending;
    }
  }

  void _showTopSnackBar(
    BuildContext context,
    String title,
    IconData icon,
    DobarColors colors,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        backgroundColor: barzDark,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 20,
          right: 20,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final DobarColors colors;

  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.labelPrimary.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(icon, size: 18)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isReady;
  final DobarColors colors;
  final String statusText;
  final AnimationController pulseController;

  const _StatusBadge({
    required this.isReady,
    required this.colors,
    required this.statusText,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isReady ? Colors.green : barzGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.labelPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.labelPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(
                    alpha: 0.4 + (pulseController.value * 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.2),
                      blurRadius: 4 + (pulseController.value * 8),
                      spreadRadius: pulseController.value * 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final DobarColors colors;

  const _GlassCard({required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.labelPrimary.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.labelPrimary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FooterActions extends StatelessWidget {
  final DobarColors colors;
  final VoidCallback onBack;
  final AppLocalizations l10n;

  const _FooterActions({
    required this.colors,
    required this.onBack,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(LucideIcons.arrowLeft, size: 16),
          label: Text(l10n.back),
          style: TextButton.styleFrom(
            foregroundColor: colors.labelPrimary.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(LucideIcons.helpCircle, size: 16),
          label: Text(l10n.help),
          style: TextButton.styleFrom(
            foregroundColor: colors.labelPrimary.withValues(alpha: 0.3),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
