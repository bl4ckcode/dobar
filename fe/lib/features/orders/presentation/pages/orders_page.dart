import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getItInjector<OrderBloc>()..add(const LoadMyOrders()),
    child: const _OrdersView(),
  );
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        final bloc = context.read<OrderBloc>();
        final orders = state is OrdersLoaded
            ? [...state.paginatedOrders.orders]
            : <OrderModel>[];
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ProfileFrame(
          title: l10n.profile_orders,
          actions: [
            IconButton(
              tooltip: l10n.retry,
              icon: const Icon(LucideIcons.refresh_cw),
              onPressed: state is OrderLoading
                  ? null
                  : () => bloc.add(const LoadMyOrders()),
            ),
          ],
          children: [
            if (state is OrderLoading) const BarzLoadingWidget(),
            if (state is OrderError) ...[
              Semantics(
                liveRegion: true,
                child: Text(l10n.profile_load_failed),
              ),
              ProfilePrimaryButton(
                label: l10n.retry,
                onPressed: () => bloc.add(const LoadMyOrders()),
              ),
            ],
            if (state is OrdersLoaded) ...[
              if (orders.isEmpty) ...[
                Text(l10n.orders_empty),
                Text(l10n.orders_empty_subtitle),
              ],
              for (final order in orders) _OrderCard(order: order),
              if (!state.hasReachedMax)
                ProfilePrimaryButton(
                  label: l10n.profile_load_more,
                  busy: state.isFetchingMore,
                  onPressed: () => bloc.add(const LoadMoreOrders()),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.dobarColors;
    final status = switch (order.status.toLowerCase()) {
      'pending' || 'confirmed' => l10n.profile_status_pending,
      'preparing' => l10n.profile_status_preparing,
      'ready' => l10n.profile_status_ready,
      'done' || 'delivered' || 'completed' => l10n.profile_status_completed,
      'cancelled' || 'canceled' => l10n.order_status_cancelled,
      _ => l10n.profile_status_unknown,
    };
    return ProfileGroup(
      children: [
        ProfileRow(
          icon: LucideIcons.receipt,
          title: '${l10n.order_number_prefix}${order.id}',
          subtitle: status,
          onTap: () => AppRoute.pushOrder(context, order.id),
        ),
        Padding(
          padding: const EdgeInsets.all(BarzSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.barName != null && order.barName!.isNotEmpty)
                Text(
                  order.barName!,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              Text(
                DateFormat.yMMMd(
                  locale,
                ).add_Hm().format(order.createdAt.toLocal()),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.labelSecondary),
              ),
              for (final item in order.items)
                Text('${item.quantity} × ${item.menuItemName}'),
              const SizedBox(height: BarzSpacing.sm),
              Text(
                NumberFormat.currency(
                  locale: locale,
                  name: 'BRL',
                  symbol: 'R\$',
                ).format(order.totalPrice),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
