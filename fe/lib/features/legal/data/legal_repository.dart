import 'package:dio/dio.dart';
import 'package:barz/core/api/api_endpoints.dart';
import '../domain/models/legal_document.dart';

class LegalRepository {
  final Dio dio;

  LegalRepository({required this.dio});

  Future<LegalDocument> getLegalDocument(
    LegalDocumentType type,
    LegalDocumentLanguage language,
  ) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.legalDocument(type.apiValue, language.apiValue)}',
        options: Options(responseType: ResponseType.plain),
      );

      return LegalDocument(
        type: type,
        language: language,
        content: response.data as String,
      );
    } catch (e) {
      throw Exception('Failed to load legal document: $e');
    }
  }

  Future<LegalDocument> getTermsOfService(LegalDocumentLanguage language) {
    return getLegalDocument(LegalDocumentType.termsOfService, language);
  }

  Future<LegalDocument> getPrivacyPolicy(LegalDocumentLanguage language) {
    return getLegalDocument(LegalDocumentType.privacyPolicy, language);
  }
}
