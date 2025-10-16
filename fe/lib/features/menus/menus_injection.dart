import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/menus/domain/repositories/abstract_menus_repository.dart';
import 'package:barz/features/menus/domain/usecases/menus_usecase.dart';

import 'data/repositories/menus_repo.dart' show MenusRepositoryImpl;
import 'presentation/bloc/menus_bloc.dart';

Future<void> initPartnersInjection() async {
  // Register MenusRepository
  getItInjector.registerLazySingleton<AbstractMenusRepository>(
        () => MenusRepositoryImpl(),
  );
  // Register MenusUseCase
  getItInjector.registerLazySingleton<MenusUseCase>(
    () => MenusUseCase(
      repository: getItInjector<AbstractMenusRepository>(),
    ),
  );

  // Register MenusBloc
  getItInjector.registerLazySingleton<MenusBloc>(
    () => MenusBloc(
      menusUseCase: getItInjector<MenusUseCase>(),
    ),
  );
}
