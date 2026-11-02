import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:barz/core/api/api_endpoints.dart';
import '../../domain/models/venue_draft.dart';
import '../../domain/repositories/venue_draft_repository.dart';

class VenueDraftRepositoryImpl implements VenueDraftRepository {
  final Dio dio;
  VenueDraftRepositoryImpl(this.dio);
  String get _base => '${ApiEndpoints.baseUrl}/bars/onboarding-drafts';

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final data = e.response?.data;
      throw VenueDraftException(
        e.response?.statusCode,
        data is Map && data['details'] is Map
            ? Map<String, dynamic>.from(data['details'] as Map)
            : const {},
      );
    }
  }

  VenueDraft _draft(Response<dynamic> r) =>
      VenueDraft.fromJson(Map<String, dynamic>.from(r.data as Map));
  @override
  Future<List<VenueDraft>> list() => _request(
    () async => ((await dio.get(_base)).data as List)
        .map((d) => VenueDraft.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList(),
  );
  @override
  Future<VenueDraft> create(String key) => _request(
    () async => _draft(await dio.post(_base, data: {'creation_key': key})),
  );
  @override
  Future<VenueDraft> load(String id) =>
      _request(() async => _draft(await dio.get('$_base/$id')));
  @override
  Future<VenueDraft> save(
    String id,
    int version,
    Map<String, dynamic> payload,
    Map<String, String> steps, {
    bool bankChanged = false,
    Map<String, dynamic>? bank,
  }) => _request(
    () async => _draft(
      await dio.patch(
        '$_base/$id',
        data: {
          'version': version,
          'payload': payload,
          'steps': steps,
          if (bankChanged) 'bank_account': bank,
        },
      ),
    ),
  );
  @override
  Future<VenueDraft> finalize(String id, int version, String key) => _request(
    () async => _draft(
      await dio.post(
        '$_base/$id/finalize',
        data: {'version': version, 'operation_key': key},
      ),
    ),
  );
  @override
  Future<VenueDraft> upload(
    String id,
    String key,
    String slot,
    String filename,
    Uint8List bytes,
    void Function(double) progress,
  ) => _request(() async {
    final mime = bytes.length > 3 && bytes[0] == 0x89
        ? 'image/png'
        : bytes.length > 3 && bytes[0] == 0xff
        ? 'image/jpeg'
        : 'image/webp';
    return _draft(
      await dio.post(
        '$_base/$id/assets',
        data: FormData.fromMap({
          'client_key': key,
          'slot': slot,
          'image': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType.parse(mime),
          ),
        }),
        onSendProgress: (n, total) => progress(total > 0 ? n / total : 0),
      ),
    );
  });
  @override
  Future<VenueDraft> removeAsset(String id, String assetId) => _request(
    () async => _draft(await dio.delete('$_base/$id/assets/$assetId')),
  );
}
