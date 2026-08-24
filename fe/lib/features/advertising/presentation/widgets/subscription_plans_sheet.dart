import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../../domain/models/ad_subscription.dart';

class SubscriptionPlansSheet extends StatefulWidget {
  final int barId;

  const SubscriptionPlansSheet({super.key, required this.barId});

  static Future<void> show(BuildContext parentContext, int barId) {
    final advertisingBloc = parentContext.read<AdvertisingBloc>();
    return showGeneralDialog(
      context: parentContext,
      barrierDismissible: true,
      barrierLabel: 'Subscription Plans',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: BlocProvider.value(
              value: advertisingBloc,
              child: SubscriptionPlansSheet(barId: barId),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: math.max(0.001, animation.value * 8.0),
            sigmaY: math.max(0.001, animation.value * 8.0),
          ),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SubscriptionPlansSheet> createState() => _SubscriptionPlansSheetState();
}

class _SubscriptionPlansSheetState extends State<SubscriptionPlansSheet> {
  @override
  void initState() {
    super.initState();
    context.read<AdvertisingBloc>().add(const AdvertisingEvent.loadPlans());
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final isDark = context.isDark;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: dobar.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: isDark ? dobar.surfaceElevated : surfaceDim,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 32,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: BlocConsumer<AdvertisingBloc, AdvertisingState>(
          listener: (context, state) {
            if (state.successMessage ==
                'Subscription created successfully!') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Upgrade successful! Welcome to the premium club.',
                  ),
                  backgroundColor: barzGold,
                ),
              );
              Navigator.of(context).pop();
              context.read<AdvertisingBloc>().add(
                AdvertisingEvent.loadSubscription(barId: widget.barId),
              );
            }
          },
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? dobar.surfaceElevated : surfaceDim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        barzGoldGradientStart,
                                        barzGoldGradientEnd,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    LucideIcons.crown,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'UPGRADE YOUR BUSINESS',
                                  style: TextStyle(
                                    color: dobar.labelPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Unlock premium features and reach more customers',
                              style: TextStyle(
                                color: dobar.labelSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          LucideIcons.x,
                          color: dobar.labelSecondary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              isDark ? dobar.navBackground : surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: isDark ? dobar.surfaceElevated : surfaceDim,
                  height: 1,
                ),

                // Plans Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        if (state.isLoadingPlans)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48.0),
                              child: CircularProgressIndicator(
                                color: barzGold,
                              ),
                            ),
                          )
                        else if (state.error != null && state.plans == null)
                          _buildErrorState(state.error!)
                        else if (state.plans != null)
                          ...state.plans!.plans.map(
                            (plan) => _PlanCard(
                              plan: plan,
                              currency: state.plans!.currency,
                              isLoading: state.isLoadingSubscription,
                              onSelect: () => _onSelectPlan(
                                plan,
                                state.plans!.regionCode,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final dobar = context.dobarColors;
    return Center(
      child: Column(
        children: [
          Icon(LucideIcons.alertTriangle, color: errorRed, size: 48),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: dobar.labelSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<AdvertisingBloc>().add(
              const AdvertisingEvent.loadPlans(),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _onSelectPlan(SubscriptionPlan plan, String regionCode) {
    context.read<AdvertisingBloc>().add(
      AdvertisingEvent.createSubscription(
        barId: widget.barId,
        tier: plan.tier,
        regionCode: regionCode,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final String currency;
  final bool isLoading;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.currency,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isVip = plan.tier == SubscriptionTier.vip;
    final isMaster = plan.tier == SubscriptionTier.master;
    final dobar = context.dobarColors;
    final isDark = context.isDark;
    final accentColor = isVip
        ? barzGold
        : (isMaster ? dobar.labelPrimary : dobar.labelSecondary);
    final cardBg = dobar.background;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;
    final borderColor = isVip
        ? barzGold.withValues(alpha: 0.3)
        : (isDark ? dobar.surfaceElevated : surfaceDim);
    final btnBg = isVip
        ? barzGold
        : (isDark ? dobar.navBackground : dobar.surfaceElevated);
    final btnFg = isVip
        ? Colors.black
        : dobar.labelPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isVip ? 2 : 1,
        ),
        boxShadow: isVip
            ? [
                BoxShadow(
                  color: barzGold.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (isVip)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: barzGold,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Text(
                'MOST POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isVip
                                ? LucideIcons.crown
                                : (isMaster
                                      ? LucideIcons.zap
                                      : LucideIcons.info),
                            color: accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            plan.name.toUpperCase(),
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...plan.features.map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.check,
                                color: isDark ? Colors.greenAccent : successGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency,
                          style: TextStyle(
                            color: dobar.labelPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          plan.price.toStringAsFixed(0),
                          style: TextStyle(
                            color: dobar.labelPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '/month',
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnBg,
                        foregroundColor: btnFg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: btnFg,
                              ),
                            )
                          : Text(
                              'Select Plan',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}