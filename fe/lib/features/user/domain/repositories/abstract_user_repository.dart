import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/models/user_document.dart';

abstract class UserRepository {
  Future<Either<Failure, UserModel>> getCurrentUser();
  Future<Either<Failure, UserModel>> getUserById(int id);
  Future<Either<Failure, UserModel>> updateProfile({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profilePictureUrl,
  });
  Future<Either<Failure, UserModel>> updatePreferences(
    UserPreferences preferences,
  );
  Future<Either<Failure, UserModel>> addDocument(UserDocument document);
  Future<Either<Failure, UserModel>> removeDocument(int documentId);
  Future<Either<Failure, UserModel>> acceptTerms();
  Future<Either<Failure, UserModel>> acceptPrivacy();
  Future<Either<Failure, bool>> deleteAccount();
  Future<Either<Failure, double>> getWalletBalance();
  Future<Either<Failure, List<CashbackTransaction>>> getCashbackHistory();
}

class CashbackTransaction {
  final int id;
  final double amount;
  final String type;
  final String description;
  final int? orderId;
  final int? partnerId;
  final DateTime createdAt;

  CashbackTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.orderId,
    this.partnerId,
    required this.createdAt,
  });

  factory CashbackTransaction.fromJson(Map<String, dynamic> json) {
    return CashbackTransaction(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      description: json['description'],
      orderId: json['order_id'],
      partnerId: json['partner_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'description': description,
      'order_id': orderId,
      'partner_id': partnerId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
