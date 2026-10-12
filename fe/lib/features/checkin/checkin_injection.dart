import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initialize check-in feature dependencies
Future<void> initCheckinInjection() async {
  // Register CheckinBloc (factory - new instance each time)
  getItInjector.registerFactory<CheckinBloc>(
    () => CheckinBloc(
      barUsecase: getItInjector(),
      prefs: getItInjector<SharedPreferences>(),
    ),
  );
}
