import 'package:barz/features/partners/domain/models/partner/product.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/network/error/failures.dart';

abstract class AbstractMenusRepository {
  Stream<Either<Failure, List<Product>>> subscribeToMenuUpdates(int barId);
}
