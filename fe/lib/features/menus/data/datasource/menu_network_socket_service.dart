import 'dart:convert';
import 'package:barz/core/network/socket_service.dart';
import 'package:barz/features/partners/domain/models/partner/product.dart';

class MenuSocketService extends BaseSocketService {
  MenuSocketService(int barId) : super("$barId/menus");

  Stream<List<Product>> get menuStream => messages.map<List<Product>>((event) {
    final decoded = jsonDecode(event as String);
    return (decoded as List).map((item) => Product.fromJson(item)).toList();
  });
}
