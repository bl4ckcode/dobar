import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/services/websocket/order_tracking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StageStep {
  final OrderStatus status;
  final String label;
  final String sub;
  final IconData icon;

  const StageStep({
    required this.status,
    required this.label,
    required this.sub,
    required this.icon,
  });
}

const List<StageStep> _stages = [
  StageStep(
    status: OrderStatus.confirmed,
    label: 'Ordered',
    sub: 'Confirmed',
    icon: LucideIcons.clipboardCheck,
  ),
  StageStep(
    status: OrderStatus.preparing,
    label: 'Preparing',
    sub: 'Crafting your drinks',
    icon: LucideIcons.glassWater,
  ),
  StageStep(
    status: OrderStatus.ready,
    label: 'Ready',
    sub: 'At the counter',
    icon: LucideIcons.packageCheck,
  ),
  StageStep(
    status: OrderStatus.completed,
    label: 'Served',
    sub: 'Enjoy!',
    icon: LucideIcons.sparkles,
  ),
];

class DobarProgressTracker extends StatelessWidget {
  final OrderStatus currentStatus;

  const DobarProgressTracker({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final dobarColors = context.dobarColors;
    
    // Map internal status to index
    int currentIndex = _stages.indexWhere((s) => s.status == currentStatus);
    // If pending, it's before confirmed (0)
    if (currentIndex == -1) {
      if (currentStatus == OrderStatus.pending) {
        currentIndex = -1; // Not yet at first stage
      } else {
        // Cancelled or similar, maybe show as served if we want to finish
        currentIndex = _stages.length - 1; 
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildHorizontal(context, dobarColors, currentIndex);
        }
        return _buildVertical(context, dobarColors, currentIndex);
      },
    );
  }

  Widget _buildHorizontal(BuildContext context, DobarColors colors, int currentIndex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth - 80; // 40 left + 40 right padding
        final maxWidth = trackWidth > 0 ? trackWidth : 400; // Fallback for edge cases

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Stack(
                children: [
                  // Background track
                  Positioned(
                    top: 24,
                    left: 40,
                    right: 40,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.labelPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Filled track - using Container with explicit width instead of FractionallySizedBox
                  Positioned(
                    top: 24,
                    left: 40,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0.0,
                        end: currentIndex == -1 ? 0.0 : (currentIndex / (_stages.length - 1)),
                      ),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final progressWidth = value * maxWidth * 0.8;
                        final safeWidth = progressWidth.isNaN || progressWidth.isInfinite
                            ? 0.0
                            : (progressWidth < 0 ? 0.0 : progressWidth);

                        return Container(
                          width: safeWidth,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [barzGold, barzGold.withValues(alpha: 0.7)],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: barzGold.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ).animate().shimmer(duration: const Duration(seconds: 2), color: barzGold.withValues(alpha: 0.2)),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_stages.length, (i) {
                      final completed = i < currentIndex;
                      final active = i == currentIndex;
                      final stage = _stages[i];

                      return Expanded(
                        child: Column(
                          children: [
                            _StageDot(
                              colors: colors,
                              completed: completed,
                              active: active,
                              icon: stage.icon,
                              isReady: currentStatus == OrderStatus.ready ||
                                  currentStatus == OrderStatus.completed,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              stage.label,
                              style: TextStyle(
                                color: active || completed
                                    ? null
                                    : colors.labelPrimary.withValues(alpha: 0.6),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              active ? 'NOW' : stage.sub,
                              style: TextStyle(
                                color: active
                                    ? barzGold
                                    : colors.labelPrimary.withValues(alpha: 0.4),
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVertical(BuildContext context, DobarColors colors, int currentIndex) {
    return Column(
      children: List.generate(_stages.length, (i) {
        final completed = i < currentIndex;
        final active = i == currentIndex;
        final stage = _stages[i];
        final isLast = i == _stages.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _StageDot(
                    colors: colors,
                    completed: completed,
                    active: active,
                    icon: stage.icon,
                    isReady: currentStatus == OrderStatus.ready ||
                        currentStatus == OrderStatus.completed,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: colors.labelPrimary.withValues(alpha: 0.1),
                        child: active
                            ? null
                            : (completed ? Container(color: barzGold) : null),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            stage.label,
                            style: TextStyle(
                              color: active || completed
                                  ? null
                                  : colors.labelPrimary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (active)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (currentStatus == OrderStatus.ready
                                        ? Colors.green
                                        : barzGold)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'NOW',
                                style: TextStyle(
                                  color: currentStatus == OrderStatus.ready
                                      ? pixGreen
                                      : barzGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        stage.sub,
                        style: TextStyle(
                          color: active
                              ? colors.labelPrimary.withValues(alpha: 0.8)
                              : colors.labelPrimary.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).animate(interval: const Duration(milliseconds: 80)).fadeIn(duration: const Duration(milliseconds: 500)).slideX(begin: -0.1),
    );
  }
}

class _StageDot extends StatelessWidget {
  final DobarColors colors;
  final bool completed;
  final bool active;
  final IconData icon;
  final bool isReady;

  const _StageDot({
    required this.colors,
    required this.completed,
    required this.active,
    required this.icon,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (active)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isReady ? pixGreen : barzGold,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.6, 1.6),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
              )
              .fadeOut(
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
              ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed || active
                ? (active && isReady ? pixGreen : barzGold)
                : colors.labelPrimary.withValues(alpha: 0.05),
            border: Border.all(
              color: completed || active
                  ? Colors.transparent
                  : colors.labelPrimary.withValues(alpha: 0.2),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: (isReady ? pixGreen : barzGold)
                          .withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ]
                : completed
                    ? [
                        BoxShadow(
                          color: barzGold.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
          ),
          child: Center(
            child: Icon(
              completed ? Icons.check : icon,
              size: 20,
              color: completed || active
                  ? barzDark
                  : colors.labelPrimary.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}