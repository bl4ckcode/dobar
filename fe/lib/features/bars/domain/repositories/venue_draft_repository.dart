import 'dart:typed_data';
import '../models/venue_draft.dart';

abstract class VenueDraftRepository {
  Future<List<VenueDraft>> list();
  Future<VenueDraft> create(String key);
  Future<VenueDraft> load(String id);
  Future<VenueDraft> save(
    String id,
    int version,
    Map<String, dynamic> payload,
    Map<String, String> steps, {
    bool bankChanged = false,
    Map<String, dynamic>? bank,
  });
  Future<VenueDraft> finalize(String id, int version, String key);
  Future<VenueDraft> upload(
    String id,
    String key,
    String slot,
    String filename,
    Uint8List bytes,
    void Function(double) progress,
  );
  Future<VenueDraft> removeAsset(String id, String assetId);
}
