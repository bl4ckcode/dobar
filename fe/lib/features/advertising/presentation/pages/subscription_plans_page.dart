import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/models.dart';
import '../bloc/advertising_bloc.dart';
import '../bloc/advertising_event.dart';
import '../bloc/advertising_state.dart';
import '../bloc/subscription_trial_cubit.dart';

class SubscriptionPlansPage extends StatelessWidget {
  const SubscriptionPlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getItInjector<AdvertisingBloc>()..add(const LoadPlans()),
        ),
        BlocProvider(create: (_) => getItInjector<SubscriptionTrialCubit>()),
      ],
      child: const _SubscriptionPlansContent(),
    );
  }
}

class _SubscriptionPlansContent extends StatefulWidget {
  const _SubscriptionPlansContent();

  @override
  State<_SubscriptionPlansContent> createState() =>
      _SubscriptionPlansContentState();
}

class _SubscriptionPlansContentState extends State<_SubscriptionPlansContent> {
  final TextEditingController _paymentMethodController = TextEditingController(
    text: 'pm_card_visa',
  );
  bool _hasRequestedSubscription = false;

  @override
  void dispose() {
    _paymentMethodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionState = context.watch<SessionBloc>().state;
    final activeBar = sessionState is SessionReady
        ? sessionState.session.activeBar
        : null;

    if (!_hasRequestedSubscription && activeBar != null) {
      _hasRequestedSubscription = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdvertisingBloc>().add(
          LoadSubscription(barId: activeBar.barId),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscription_plans),
        backgroundColor: barzDark,
        foregroundColor: Colors.white,
        actions: [
          if (activeBar != null)
            TextButton(
              onPressed: () => _openTrialDialog(context),
              child: Text(
                l10n.pro_trial_cta,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Container(
        color: barzGoldSoft,
        child: MultiBlocListener(
          listeners: [
            BlocListener<AdvertisingBloc, AdvertisingState>(
              listener: (context, state) {
                if (state.error != null && state.error!.isNotEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.error!)));
                } else if (state.successMessage != null &&
                    state.successMessage!.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.successMessage!)),
                  );
                }
              },
            ),
            BlocListener<SubscriptionTrialCubit, SubscriptionTrialState>(
              listener: (context, state) {
                if (state.error != null && state.error!.isNotEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.error!)));
                } else if (state.successMessage != null &&
                    state.successMessage!.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.successMessage!)),
                  );
                }
              },
            ),
          ],
          child: BlocBuilder<AdvertisingBloc, AdvertisingState>(
            builder: (context, state) {
              final trialState = context.watch<SubscriptionTrialCubit>().state;
              if (state.isLoadingPlans) {
                return const Center(
                  child: CircularProgressIndicator(color: barzGold),
                );
              }
              if (state.error != null) {
                return _errorState(context, state.error!, l10n);
              }
              if (state.plans == null) {
                return _emptyState(l10n);
              }
              return _content(
                context,
                plans: state.plans!,
                currentSubscription: state.subscription,
                trialSetup: trialState.result,
                l10n: l10n,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _errorState(
    BuildContext context,
    String error,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: errorRed),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<AdvertisingBloc>().add(const LoadPlans()),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_membership,
            size: 80,
            color: barzGold.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 24),
          Text(l10n.no_plans_available, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required PlansResponse plans,
    required AdSubscription? currentSubscription,
    required SubscriptionTrialSetupResult? trialSetup,
    required AppLocalizations l10n,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trialSetup != null) ...[
            _TrialStatusCard(trialSetup: trialSetup, l10n: l10n),
            const SizedBox(height: 16),
          ],
          if (currentSubscription != null) ...[
            _CurrentSubscriptionCard(
              subscription: currentSubscription,
              l10n: l10n,
            ),
            const SizedBox(height: 24),
          ],
          Text(
            l10n.choose_your_plan,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.boost_your_bar_visibility,
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 24),
          ...plans.plans.map(
            (plan) => _PlanCard(
              plan: plan,
              currency: plans.currency,
              isCurrentPlan: currentSubscription?.tier == plan.tier,
              onSelect: () => _selectPlan(context, plan, l10n),
            ),
          ),
        ],
      ),
    );
  }

  void _openTrialDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is! SessionReady ||
        sessionState.session.activeBar == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.select_bar_first)));
      return;
    }

    final plans =
        context.read<AdvertisingBloc>().state.plans?.plans ?? const [];
    SubscriptionTier selectedTier = plans.isNotEmpty
        ? plans.first.tier
        : SubscriptionTier.vip;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(l10n.pro_trial_cta),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<SubscriptionTier>(
                initialValue: selectedTier,
                items: plans.isNotEmpty
                    ? plans
                          .map(
                            (plan) => DropdownMenuItem(
                              value: plan.tier,
                              child: Text(plan.name),
                            ),
                          )
                          .toList()
                    : SubscriptionTier.values
                          .where((tier) => tier != SubscriptionTier.regular)
                          .map(
                            (tier) => DropdownMenuItem(
                              value: tier,
                              child: Text(tier.name),
                            ),
                          )
                          .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setModalState(() => selectedTier = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paymentMethodController,
                decoration: const InputDecoration(
                  labelText: 'Payment method id',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final user = sessionState.session.user;
                final paymentMethodId = _paymentMethodController.text.trim();
                if (paymentMethodId.isEmpty || user.id == null) {
                  return;
                }
                await context.read<SubscriptionTrialCubit>().setupTrial(
                  barId: sessionState.session.activeBar!.barId,
                  ownerId: user.id!,
                  plan: selectedTier.name.toUpperCase(),
                  paymentMethodId: paymentMethodId,
                  customerEmail: user.email ?? '',
                  customerName: user.displayName ?? '',
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPlan(
    BuildContext context,
    SubscriptionPlan plan,
    AppLocalizations l10n,
  ) {
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is! SessionReady ||
        sessionState.session.activeBar == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.select_bar_first)));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.subscribe_to} ${plan.name}'),
        content: Text('${l10n.confirm_subscription_message} ${plan.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              context.read<AdvertisingBloc>().add(
                CreateSubscription(
                  barId: sessionState.session.activeBar!.barId,
                  tier: plan.tier,
                  regionCode: 'BR',
                ),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.subscription_created)),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: barzGold,
              foregroundColor: barzDark,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class _TrialStatusCard extends StatelessWidget {
  final SubscriptionTrialSetupResult trialSetup;
  final AppLocalizations l10n;

  const _TrialStatusCard({required this.trialSetup, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: barzDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pro_trial_cta,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.valid_until}: ${_formatDate(trialSetup.trialEndsAt)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  final AdSubscription subscription;
  final AppLocalizations l10n;

  const _CurrentSubscriptionCard({
    required this.subscription,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: barzDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: successGreen),
                const SizedBox(width: 8),
                Text(
                  l10n.current_plan,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: barzGold,
                    borderRadius: BorderRadius.circular(BarzRadii.full),
                  ),
                  child: Text(
                    subscription.tier.name.toUpperCase(),
                    style: const TextStyle(
                      color: barzDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.valid_until}: ${_formatDate(subscription.currentPeriodEnd)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final String currency;
  final bool isCurrentPlan;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.currency,
    required this.isCurrentPlan,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isVip = plan.tier == SubscriptionTier.vip;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        side: isVip
            ? const BorderSide(color: barzGold, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          if (isVip)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: barzGold,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(BarzRadii.md - 2),
                  topRight: Radius.circular(BarzRadii.md - 2),
                ),
              ),
              child: Text(
                l10n.most_popular,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: barzDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$currency ${plan.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('/mo', style: TextStyle(color: textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.commission}: ${(plan.commissionRate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: textSecondary),
                ),
                const SizedBox(height: 16),
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: successGreen, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(feature)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: isCurrentPlan
                      ? OutlinedButton(
                          onPressed: null,
                          child: Text(l10n.current_plan),
                        )
                      : FilledButton(
                          onPressed: onSelect,
                          style: FilledButton.styleFrom(
                            backgroundColor: isVip ? barzGold : barzDark,
                            foregroundColor: isVip ? barzDark : Colors.white,
                            padding: const EdgeInsets.all(14),
                          ),
                          child: Text(l10n.choose_plan),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
