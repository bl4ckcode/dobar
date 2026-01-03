import 'package:equatable/equatable.dart';
import 'package:barz/features/checkin/domain/models/checkin_model.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';

/// Check-in flow steps
enum CheckinStep {
  initial,
  scanning,
  nearbyBars,
  confirmCheckin,
  checkedIn,
}

/// Check-in state
class CheckinState extends Equatable {
  final CheckinStep step;
  final bool isLoading;
  final String? error;
  
  // Current active check-in
  final CheckinModel? activeCheckin;
  
  // Bar being checked into
  final BarModel? selectedBar;
  final String? tableNumber;
  
  // Nearby bars for geo-based check-in
  final List<BarModel> nearbyBars;
  
  // QR scan result
  final QrScanResult? scanResult;

  const CheckinState({
    this.step = CheckinStep.initial,
    this.isLoading = false,
    this.error,
    this.activeCheckin,
    this.selectedBar,
    this.tableNumber,
    this.nearbyBars = const [],
    this.scanResult,
  });

  CheckinState copyWith({
    CheckinStep? step,
    bool? isLoading,
    String? error,
    CheckinModel? activeCheckin,
    BarModel? selectedBar,
    String? tableNumber,
    List<BarModel>? nearbyBars,
    QrScanResult? scanResult,
    bool clearError = false,
    bool clearActiveCheckin = false,
    bool clearScanResult = false,
  }) {
    return CheckinState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeCheckin: clearActiveCheckin ? null : (activeCheckin ?? this.activeCheckin),
      selectedBar: selectedBar ?? this.selectedBar,
      tableNumber: tableNumber ?? this.tableNumber,
      nearbyBars: nearbyBars ?? this.nearbyBars,
      scanResult: clearScanResult ? null : (scanResult ?? this.scanResult),
    );
  }

  /// Whether user is currently checked in somewhere
  bool get isCheckedIn => activeCheckin?.isActive == true;

  /// Current bar name if checked in
  String? get currentBarName => activeCheckin?.barName;

  @override
  List<Object?> get props => [
        step,
        isLoading,
        error,
        activeCheckin,
        selectedBar,
        tableNumber,
        nearbyBars,
        scanResult,
      ];
}
