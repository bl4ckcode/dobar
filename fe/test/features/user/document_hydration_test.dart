import 'package:barz/features/user/data/data_sources/user_network_datasource.dart';
import 'package:barz/features/user/domain/models/user_document.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../payments/checkout_recovery_test.dart'
    show ScriptedAdapter, jsonResponse;

void main() {
  test(
    'saving CPF reloads profile and document list instead of replacing user with document',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = ScriptedAdapter((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return jsonResponse({
              'id': 99,
              'type': 'cpf',
              'number': '12345678909',
            });
          }
          if (request.path.endsWith('/documents')) {
            return jsonResponse([
              {'id': 99, 'type': 'cpf', 'number': '12345678909'},
            ]);
          }
          return jsonResponse({
            'id': 7,
            'email': 'customer@example.com',
            'display_name': 'Cliente',
          });
        });
      final user = await UserNetworkDatasource(dio: dio).addDocument(
        UserDocument(type: DocumentType.cpf, number: '12345678909'),
      );
      expect(user.id, 7);
      expect(user.email, 'customer@example.com');
      expect(user.displayName, 'Cliente');
      expect(user.documents.single.id, 99);
      expect(user.documents.single.type, DocumentType.cpf);
      expect(requests.map((request) => request.method), ['POST', 'GET', 'GET']);
    },
  );
}
