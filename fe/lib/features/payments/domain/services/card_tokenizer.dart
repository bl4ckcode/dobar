abstract class CardTokenizer {
  Future<String> tokenize({
    required String number,
    required String holderName,
    required int expMonth,
    required int expYear,
    required String cvv,
  });
}

class CardTokenizationException implements Exception {
  final bool unavailable;
  const CardTokenizationException({this.unavailable = false});
}
