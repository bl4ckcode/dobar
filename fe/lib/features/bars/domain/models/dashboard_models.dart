class DashboardStats {
  final String period;
  final OrderStats orders;
  final RevenueStats revenue;
  final AverageTicketStats averageTicket;
  final List<TopItem> topItems;

  DashboardStats({
    required this.period,
    required this.orders,
    required this.revenue,
    required this.averageTicket,
    required this.topItems,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      period: json['period'] ?? 'today',
      orders: OrderStats.fromJson(json['orders'] ?? {}),
      revenue: RevenueStats.fromJson(json['revenue'] ?? {}),
      averageTicket: AverageTicketStats.fromJson(json['average_ticket'] ?? {}),
      topItems: (json['top_items'] as List<dynamic>?)
              ?.map((e) => TopItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  factory DashboardStats.empty() {
    return DashboardStats(
      period: 'today',
      orders: OrderStats.empty(),
      revenue: RevenueStats.empty(),
      averageTicket: AverageTicketStats.empty(),
      topItems: [],
    );
  }
}

class OrderStats {
  final int total;
  final int pending;
  final int completed;
  final int cancelled;
  final double trendPercent;

  OrderStats({
    required this.total,
    required this.pending,
    required this.completed,
    required this.cancelled,
    required this.trendPercent,
  });

  factory OrderStats.fromJson(Map<String, dynamic> json) {
    return OrderStats(
      total: json['total'] ?? 0,
      pending: json['pending'] ?? 0,
      completed: json['completed'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      trendPercent: (json['trend_percent'] ?? 0).toDouble(),
    );
  }

  factory OrderStats.empty() {
    return OrderStats(total: 0, pending: 0, completed: 0, cancelled: 0, trendPercent: 0);
  }
}

class RevenueStats {
  final double total;
  final String currency;
  final double trendPercent;

  RevenueStats({
    required this.total,
    required this.currency,
    required this.trendPercent,
  });

  factory RevenueStats.fromJson(Map<String, dynamic> json) {
    return RevenueStats(
      total: (json['total'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'BRL',
      trendPercent: (json['trend_percent'] ?? 0).toDouble(),
    );
  }

  factory RevenueStats.empty() {
    return RevenueStats(total: 0, currency: 'BRL', trendPercent: 0);
  }

  String get formattedTotal {
    if (currency == 'BRL') {
      return 'R\$ ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    }
    return '\$ ${total.toStringAsFixed(2)}';
  }
}

class AverageTicketStats {
  final double value;
  final String currency;
  final double trendPercent;

  AverageTicketStats({
    required this.value,
    required this.currency,
    required this.trendPercent,
  });

  factory AverageTicketStats.fromJson(Map<String, dynamic> json) {
    return AverageTicketStats(
      value: (json['value'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'BRL',
      trendPercent: (json['trend_percent'] ?? 0).toDouble(),
    );
  }

  factory AverageTicketStats.empty() {
    return AverageTicketStats(value: 0, currency: 'BRL', trendPercent: 0);
  }

  String get formattedValue {
    if (currency == 'BRL') {
      return 'R\$ ${value.toStringAsFixed(0)}';
    }
    return '\$ ${value.toStringAsFixed(2)}';
  }
}

class TopItem {
  final String name;
  final int quantity;
  final double revenue;

  TopItem({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) {
    return TopItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
    );
  }
}

class BarStatus {
  final int barId;
  final bool isOpen;
  final ScheduleInfo? currentSchedule;
  final String? nextOpen;
  final int activeOrdersCount;
  final int activeTablesCount;

  BarStatus({
    required this.barId,
    required this.isOpen,
    this.currentSchedule,
    this.nextOpen,
    required this.activeOrdersCount,
    required this.activeTablesCount,
  });

  factory BarStatus.fromJson(Map<String, dynamic> json) {
    return BarStatus(
      barId: json['bar_id'] ?? 0,
      isOpen: json['is_open'] ?? false,
      currentSchedule: json['current_schedule'] != null
          ? ScheduleInfo.fromJson(json['current_schedule'])
          : null,
      nextOpen: json['next_open'],
      activeOrdersCount: json['active_orders_count'] ?? 0,
      activeTablesCount: json['active_tables_count'] ?? 0,
    );
  }

  factory BarStatus.empty(int barId) {
    return BarStatus(
      barId: barId,
      isOpen: false,
      activeOrdersCount: 0,
      activeTablesCount: 0,
    );
  }
}

class ScheduleInfo {
  final String day;
  final String open;
  final String close;

  ScheduleInfo({
    required this.day,
    required this.open,
    required this.close,
  });

  factory ScheduleInfo.fromJson(Map<String, dynamic> json) {
    return ScheduleInfo(
      day: json['day'] ?? '',
      open: json['open'] ?? '',
      close: json['close'] ?? '',
    );
  }
}

class RecentOrder {
  final int id;
  final String orderNumber;
  final String status;
  final double total;
  final String currency;
  final int itemsCount;
  final String? tableNumber;
  final String? customerName;
  final DateTime createdAt;
  final DateTime? estimatedReadyAt;

  RecentOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.currency,
    required this.itemsCount,
    this.tableNumber,
    this.customerName,
    required this.createdAt,
    this.estimatedReadyAt,
  });

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    return RecentOrder(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'pending',
      total: (json['total'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'BRL',
      itemsCount: json['items_count'] ?? 0,
      tableNumber: json['table_number'],
      customerName: json['customer_name'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      estimatedReadyAt: json['estimated_ready_at'] != null
          ? DateTime.tryParse(json['estimated_ready_at'])
          : null,
    );
  }

  String get formattedTotal {
    if (currency == 'BRL') {
      return 'R\$ ${total.toStringAsFixed(2)}';
    }
    return '\$ ${total.toStringAsFixed(2)}';
  }
}

class RecentOrdersResponse {
  final List<RecentOrder> orders;
  final int total;
  final int page;
  final int perPage;
  final bool hasMore;

  RecentOrdersResponse({
    required this.orders,
    required this.total,
    required this.page,
    required this.perPage,
    required this.hasMore,
  });

  factory RecentOrdersResponse.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] ?? {};
    return RecentOrdersResponse(
      orders: (json['orders'] as List<dynamic>?)
              ?.map((e) => RecentOrder.fromJson(e))
              .toList() ??
          [],
      total: pagination['total'] ?? 0,
      page: pagination['page'] ?? 1,
      perPage: pagination['per_page'] ?? 10,
      hasMore: pagination['has_more'] ?? false,
    );
  }

  factory RecentOrdersResponse.empty() {
    return RecentOrdersResponse(
      orders: [],
      total: 0,
      page: 1,
      perPage: 10,
      hasMore: false,
    );
  }
}
