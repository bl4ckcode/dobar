enum ConflictType {
  statusChanged,
  orderModified,
  orderDeleted,
  concurrentUpdate,
}

enum Resolution {
  useServer,
  useClient,
  merge,
}

class SyncOperation {
  final String clientId;
  final int orderId;
  final String operation;
  final Map<String, dynamic> data;
  final DateTime clientTimestamp;

  SyncOperation({
    required this.clientId,
    required this.orderId,
    required this.operation,
    required this.data,
    required this.clientTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'order_id': orderId,
    'operation': operation,
    'data': data,
    'client_timestamp': clientTimestamp.toIso8601String(),
  };
}

class SyncConflict {
  final int orderId;
  final ConflictType conflictType;
  final Map<String, dynamic> serverState;
  final Map<String, dynamic> clientState;
  final Resolution suggestedResolution;

  SyncConflict({
    required this.orderId,
    required this.conflictType,
    required this.serverState,
    required this.clientState,
    required this.suggestedResolution,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      orderId: json['order_id'],
      conflictType: ConflictType.values.firstWhere(
        (e) => e.name == _snakeToCamel(json['conflict_type']),
        orElse: () => ConflictType.concurrentUpdate,
      ),
      serverState: json['server_state'] ?? {},
      clientState: json['client_state'] ?? {},
      suggestedResolution: Resolution.values.firstWhere(
        (e) => e.name == _snakeToCamel(json['suggested_resolution']),
        orElse: () => Resolution.useServer,
      ),
    );
  }
}

class SyncResponse {
  final List<int> syncedOrderIds;
  final List<SyncConflict> conflicts;

  SyncResponse({
    required this.syncedOrderIds,
    required this.conflicts,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      syncedOrderIds: List<int>.from(json['synced_order_ids'] ?? []),
      conflicts: (json['conflicts'] as List?)
          ?.map((c) => SyncConflict.fromJson(c))
          .toList() ?? [],
    );
  }

  bool get hasConflicts => conflicts.isNotEmpty;
}

String _snakeToCamel(String snake) {
  final parts = snake.split('_');
  return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
