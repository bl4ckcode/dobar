import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/notifications/data/data_sources/notification_network_datasource.dart';
import 'package:barz/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:barz/features/notifications/domain/repositories/abstract_notification_repository.dart';
import 'package:barz/features/notifications/presentation/bloc/notification_bloc.dart';

void initNotificationsFeatureInjection() {
  // Data Source
  getItInjector.registerLazySingleton<NotificationNetworkDataSource>(
    () => NotificationNetworkDataSource(dio: DioNetwork.appAPI),
  );

  // Repository
  getItInjector.registerLazySingleton<AbstractNotificationRepository>(
    () => NotificationRepositoryImpl(
      dataSource: getItInjector<NotificationNetworkDataSource>(),
    ),
  );

  // Bloc
  getItInjector.registerFactory<NotificationBloc>(
    () => NotificationBloc(
      repository: getItInjector<AbstractNotificationRepository>(),
    ),
  );
}
