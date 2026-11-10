import '../models/checkin_model.dart';
import 'package:barz/features/location/domain/models/location_model.dart';

abstract class CheckinRepository {
  Future<CheckinModel?> getActive();
  Future<CheckinModel> confirm({
    required int barId,
    required LocationModel location,
    String? tableNumber,
  });
  Future<void> end();
}

class CheckinException implements Exception {
  final String code;
  const CheckinException(this.code);
}
