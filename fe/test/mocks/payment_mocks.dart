import 'package:barz/features/payments/data/data_sources/payment_network_datasource.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/features/payments/domain/repositories/abstract_payment_repository.dart';
import 'package:barz/features/payments/domain/usecases/payment_usecase.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockPaymentDatasource extends Mock implements PaymentDatasource {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockPaymentUsecase extends Mock implements PaymentUsecase {}

class FakePaymentRequest extends Fake implements PaymentRequest {}

class FakeUri extends Fake implements Uri {}
