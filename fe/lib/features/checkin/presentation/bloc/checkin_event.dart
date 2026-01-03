import 'package:equatable/equatable.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';

abstract class CheckinEvent extends Equatable {
  const CheckinEvent();

  @override
  List<Object?> get props => [];
}

/// Load active check-in on app start
class LoadActiveCheckin extends CheckinEvent {
  const LoadActiveCheckin();
}

/// Start QR code scanner
class StartQrScan extends CheckinEvent {
  const StartQrScan();
}

/// QR code scanned successfully
class QrCodeScanned extends CheckinEvent {
  final String qrCode;
  const QrCodeScanned(this.qrCode);

  @override
  List<Object?> get props => [qrCode];
}

/// Find nearby bars using geolocation
class FindNearbyBars extends CheckinEvent {
  final double latitude;
  final double longitude;
  const FindNearbyBars({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

/// Select a bar for check-in
class SelectBar extends CheckinEvent {
  final BarModel bar;
  const SelectBar(this.bar);

  @override
  List<Object?> get props => [bar];
}

/// Set table number
class SetTableNumber extends CheckinEvent {
  final String tableNumber;
  const SetTableNumber(this.tableNumber);

  @override
  List<Object?> get props => [tableNumber];
}

/// Confirm check-in
class ConfirmCheckin extends CheckinEvent {
  const ConfirmCheckin();
}

/// Check out from current bar
class Checkout extends CheckinEvent {
  const Checkout();
}

/// Clear error
class ClearCheckinError extends CheckinEvent {
  const ClearCheckinError();
}

/// Reset to initial state
class ResetCheckin extends CheckinEvent {
  const ResetCheckin();
}
