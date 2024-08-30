import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUsecase loginUseCase;

  LoginBloc({required this.loginUseCase}) : super(const LoginState.initial()) {
    on<LoginEvent>((event, emit) async {
      if (event is LoginButtonPressed) {
        emit(const LoginState.loading());
        try {
          final params = LoginParams(
            phoneNumber: event.phoneNumber,
            email: event.email,
            password: event.password,
            googleId: event.googleId,
            appleId: event.appleId,
          );

          await loginUseCase.call(params);
          emit(const LoginState.success());
        } catch (e) {
          emit(LoginState.failure(error: e.toString()));
        }
      }
    });
  }
}
