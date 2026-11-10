import 'package:dio/dio.dart';
import '../../domain/services/card_tokenizer.dart';

class PagarmeCardTokenizer implements CardTokenizer {
  final Dio _dio;
  final String publicKey;

  PagarmeCardTokenizer({Dio? dio, String? publicKey})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      publicKey =
          publicKey ?? const String.fromEnvironment('PAGARME_PUBLIC_KEY');

  @override
  Future<String> tokenize({
    required String number,
    required String holderName,
    required int expMonth,
    required int expYear,
    required String cvv,
  }) async {
    if (!publicKey.startsWith('pk_')) {
      throw const CardTokenizationException(unavailable: true);
    }
    final now = DateTime.now();
    if (expMonth < 1 ||
        expMonth > 12 ||
        expYear < now.year ||
        (expYear == now.year && expMonth < now.month)) {
      throw const CardTokenizationException();
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.pagar.me/core/v5/tokens',
        queryParameters: {'appId': publicKey},
        options: Options(contentType: Headers.jsonContentType),
        data: {
          'type': 'card',
          'card': {
            'number': number.replaceAll(RegExp(r'\D'), ''),
            'holder_name': holderName.trim(),
            'exp_month': expMonth,
            'exp_year': expYear,
            'cvv': cvv,
          },
        },
      );
      final token = response.data?['id'];
      if (token is! String || !token.startsWith('token_')) {
        throw const CardTokenizationException();
      }
      return token;
    } on DioException {
      throw const CardTokenizationException();
    }
  }
}
