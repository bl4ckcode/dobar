import 'dart:math';

class IdempotencyKey {
  static final Random _random = Random.secure();

  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = List.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$timestamp-$randomPart';
  }

  static String forPayment(int orderId) {
    return 'pay-$orderId-${generate()}';
  }

  static String forOrder(int? orderId, String operation) {
    final id = orderId ?? 'new';
    return '$operation-$id-${generate()}';
  }
}
