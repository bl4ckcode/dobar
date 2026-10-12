enum CardBrand { visa, mastercard, elo, amex, nubank }

class SavedCard {
  final String id;
  final CardBrand brand;
  final String last4;
  final String expiry;

  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiry,
  });
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get total => price * quantity;
}

class OrderDiscount {
  final double amount;
  final String code;

  const OrderDiscount({required this.amount, required this.code});
}

enum PaymentMethodType { card, pix, nubank, applePay, googlePay }
