import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: advertisingBloc,
          child: SubscriptionPlansSheet(barId: barId),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
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

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: dobar.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : surfaceDim),
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
                  // Header
                  _buildHeader(context),

                  // Plans Content wrapped in ResponsiveCenterContainer
                  Flexible(
                    child: ResponsiveCenterContainer(
                      maxWidthPercentage: 0.9,
                      maxWidth: 1400,
                      padding: EdgeInsets.zero,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            if (state.isLoadingPlans)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(48.0),
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
                  ),

                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final dobar = context.dobarColors;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPGRADE YOUR BUSINESS',
                style: TextStyle(
                  color: dobar.labelPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unlock premium features and reach more customers',
                style: TextStyle(
                  color: dobar.labelSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(LucideIcons.x, color: dobar.labelSecondary),
          ),
        ],
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
    final cardBg = isDark ? const Color(0xFF121212) : dobar.surfaceElevated;
    final textColor = isDark ? Colors.white70 : dobar.labelPrimary;
    final mutedColor = isDark ? Colors.white38 : dobar.labelSecondary;
    final borderColor = isVip
        ? barzGold.withValues(alpha: 0.3)
        : (isDark ? Colors.white10 : surfaceDim);
    final btnBg = isVip ? barzGold : (isDark ? Colors.white10 : dobar.navBackground);
    final btnFg = isVip ? Colors.black : (isDark ? Colors.white : dobar.labelPrimary);

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
