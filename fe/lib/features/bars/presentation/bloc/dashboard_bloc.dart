import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/bars/domain/models/dashboard_models.dart';
import 'package:barz/features/bars/data/data_sources/bar_network_datasource.dart';
import 'package:barz/core/network/exceptions.dart';

sealed class DashboardEvent {}

class LoadDashboard extends DashboardEvent {
  final int barId;
  final String period;
  LoadDashboard({required this.barId, this.period = 'today'});
}

class RefreshDashboard extends DashboardEvent {
  final int barId;
  RefreshDashboard({required this.barId});
}

class ToggleBarOpen extends DashboardEvent {
  final int barId;
  final bool isOpen;
  final String? reason;
  ToggleBarOpen({required this.barId, required this.isOpen, this.reason});
}

sealed class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final BarStatus status;
  final RecentOrdersResponse recentOrders;

  DashboardLoaded({
    required this.stats,
    required this.status,
    required this.recentOrders,
  });

  DashboardLoaded copyWith({
    DashboardStats? stats,
    BarStatus? status,
    RecentOrdersResponse? recentOrders,
  }) {
    return DashboardLoaded(
      stats: stats ?? this.stats,
      status: status ?? this.status,
      recentOrders: recentOrders ?? this.recentOrders,
    );
  }
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError({required this.message});
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final BarNetworkDataSource dataSource;

  DashboardBloc({required this.dataSource}) : super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<RefreshDashboard>(_onRefreshDashboard);
    on<ToggleBarOpen>(_onToggleBarOpen);
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final results = await Future.wait([
        dataSource.getDashboardStats(event.barId, period: event.period),
        dataSource.getBarStatus(event.barId),
        dataSource.getBarOrders(event.barId, limit: 5),
      ]);

      emit(
        DashboardLoaded(
          stats: results[0] as DashboardStats,
          status: results[1] as BarStatus,
          recentOrders: results[2] as RecentOrdersResponse,
        ),
      );
    } on ServerException catch (e) {
      emit(DashboardError(message: e.message));
    } catch (e) {
      emit(DashboardError(message: 'Failed to load dashboard'));
    }
  }

  Future<void> _onRefreshDashboard(
    RefreshDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    final currentState = state;
    try {
      final results = await Future.wait([
        dataSource.getDashboardStats(event.barId),
        dataSource.getBarStatus(event.barId),
        dataSource.getBarOrders(event.barId, limit: 5),
      ]);

      emit(
        DashboardLoaded(
          stats: results[0] as DashboardStats,
          status: results[1] as BarStatus,
          recentOrders: results[2] as RecentOrdersResponse,
        ),
      );
    } catch (e) {
      if (currentState is DashboardLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onToggleBarOpen(
    ToggleBarOpen event,
    Emitter<DashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! DashboardLoaded) return;

    try {
      final newStatus = await dataSource.toggleBarStatus(
        event.barId,
        event.isOpen,
        reason: event.reason,
      );
      emit(currentState.copyWith(status: newStatus));
    } on ServerException catch (e) {
      emit(DashboardError(message: e.message));
      emit(currentState);
    }
  }
}
