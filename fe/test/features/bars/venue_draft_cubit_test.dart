import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:barz/features/bars/domain/models/venue_draft.dart';
import 'package:barz/features/bars/domain/repositories/venue_draft_repository.dart';
import 'package:barz/features/bars/presentation/bloc/venue_draft_cubit.dart';

class DraftFake implements VenueDraftRepository {
  VenueDraft value = const VenueDraft(
    id: 'draft-1',
    version: 1,
    payload: {},
    steps: {},
    nextStep: 'details',
  );
  Completer<void>? saveGate;
  int? saveError;
  bool loseFinalizeResponse = false;
  int finalizeCount = 0;
  final List<String> finalizeKeys = [];
  final List<String> uploadKeys = [];
  bool uploadFails = false;
  bool createFails = false;
  final List<String> createKeys = [];
  VenueDraft copy({
    Map<String, dynamic>? payload,
    Map<String, String>? steps,
    int? barId,
    List<Map<String, dynamic>>? assets,
  }) => VenueDraft(
    id: value.id,
    version: value.version + 1,
    payload: payload ?? value.payload,
    steps: steps ?? value.steps,
    nextStep: 'review',
    bankSummary: value.bankSummary,
    assets: assets ?? value.assets,
    barId: barId ?? value.barId,
  );
  @override
  Future<List<VenueDraft>> list() async => [value];
  @override
  Future<VenueDraft> create(String key) async {
    createKeys.add(key);
    if (createFails) throw const VenueDraftException(null);
    return value;
  }

  @override
  Future<VenueDraft> load(String id) async => value;
  @override
  Future<VenueDraft> save(
    String id,
    int version,
    Map<String, dynamic> payload,
    Map<String, String> steps, {
    bool bankChanged = false,
    Map<String, dynamic>? bank,
  }) async {
    await saveGate?.future;
    if (saveError != null) throw VenueDraftException(saveError);
    if (version != value.version) throw const VenueDraftException(409);
    value = copy(payload: payload, steps: steps);
    return value;
  }

  @override
  Future<VenueDraft> finalize(String id, int version, String key) async {
    finalizeCount++;
    finalizeKeys.add(key);
    value = copy(barId: 42);
    if (loseFinalizeResponse) throw const VenueDraftException(null);
    return value;
  }

  @override
  Future<VenueDraft> upload(
    String id,
    String key,
    String slot,
    String filename,
    Uint8List bytes,
    void Function(double) progress,
  ) async {
    uploadKeys.add(key);
    if (uploadFails) {
      value = copy(
        assets: [
          {'id': 'asset-1', 'client_key': key, 'status': 'failed'},
        ],
      );
      throw const VenueDraftException(500);
    }
    value = copy(
      assets: [
        {'id': 'asset-1', 'client_key': key, 'status': 'saved'},
      ],
    );
    return value;
  }

  @override
  Future<VenueDraft> removeAsset(String id, String assetId) async {
    value = copy(assets: []);
    return value;
  }
}

class _ResolvedDraftFake extends DraftFake {
  final sent = <Map<String, dynamic>>[];
  @override
  Future<VenueDraft> save(
    String id,
    int version,
    Map<String, dynamic> payload,
    Map<String, String> steps, {
    bool bankChanged = false,
    Map<String, dynamic>? bank,
  }) async {
    sent.add(Map.of(payload));
    final saved = await super.save(
      id,
      version,
      payload,
      steps,
      bankChanged: bankChanged,
      bank: bank,
    );
    value = VenueDraft(
      id: saved.id,
      version: saved.version,
      payload: {
        ...saved.payload,
        'latitude': -19.92,
        'longitude': -43.94,
        'location_confirmed': true,
      },
      steps: saved.steps,
      nextStep: saved.nextStep,
    );
    return value;
  }
}

void main() {
  test(
    'acknowledged address coordinates survive the next draft edit',
    () async {
      final repo = _ResolvedDraftFake();
      final cubit = VenueDraftCubit(repo);
      addTearDown(cubit.close);
      await cubit.start();
      cubit.edit({
        'address': 'Rua Teste, 241',
        'latitude': null,
        'longitude': null,
      });
      await cubit.save();
      expect(cubit.payload['latitude'], -19.92);
      expect(cubit.payload['longitude'], -43.94);
      cubit.edit({'name': 'Baxo Bar'});
      await cubit.save();
      expect(repo.sent.last['latitude'], -19.92);
      expect(repo.sent.last['longitude'], -43.94);
      expect(repo.sent.last['name'], 'Baxo Bar');
    },
  );
  test('late save acknowledgement does not erase newer edits', () async {
    final repo = DraftFake();
    final c = VenueDraftCubit(repo);
    addTearDown(c.close);
    await c.start();
    c.edit({'name': 'First'});
    repo.saveGate = Completer();
    final pending = c.save();
    c.edit({'name': 'Second'});
    repo.saveGate!.complete();
    await pending;
    expect(c.state.saveStatus, DraftSaveStatus.dirty);
    expect(c.payload['name'], 'Second');
    expect(c.state.draft!.payload['name'], 'First');
    repo.saveGate = null;
    await c.save();
    expect(repo.value.payload['name'], 'Second');
    expect(c.state.saveStatus, DraftSaveStatus.saved);
  });
  test('a stale save keeps edits and requires explicit reload', () async {
    final repo = DraftFake()..saveError = 409;
    final c = VenueDraftCubit(repo);
    addTearDown(c.close);
    await c.start();
    c.edit({'name': 'Local'});
    expect(await c.save(), false);
    c.edit({'name': 'Still local'});
    expect(c.state.saveStatus, DraftSaveStatus.conflict);
    expect(await c.save(), false);
    expect(c.payload['name'], 'Still local');
    await c.resume('draft-1');
    expect(c.state.saveStatus, DraftSaveStatus.saved);
  });
  test(
    'lost finalize response reconciles the existing venue without creating twice',
    () async {
      final repo = DraftFake()..loseFinalizeResponse = true;
      final c = VenueDraftCubit(repo);
      addTearDown(c.close);
      await c.start();
      await c.finalize();
      expect(c.state.phase, VenuePhase.unknown);
      await c.reconcile();
      expect(c.state.phase, VenuePhase.created);
      expect(c.state.draft!.barId, 42);
      expect(repo.finalizeCount, 1);
    },
  );
  test('failed creation retries the same draft creation key', () async {
    final repo = DraftFake()..createFails = true;
    final c = VenueDraftCubit(repo);
    addTearDown(c.close);
    await c.start();
    repo.createFails = false;
    await c.start();
    expect(repo.createKeys.length, 2);
    expect(repo.createKeys.toSet().length, 1);
  });
  test(
    'bank values remain editable in memory after autosave and clear after leaving',
    () async {
      final repo = DraftFake();
      final c = VenueDraftCubit(repo);
      addTearDown(c.close);
      await c.start();
      c.goStep(2);
      c.editBank({'method': 'pix', 'pix_key': 'unfinished'});
      await c.save();
      expect(c.bank!['pix_key'], 'unfinished');
      await c.next(skip: true);
      expect(c.bank, null);
      expect(c.steps['receiving'], 'skipped');
    },
  );
  test(
    'upload retry retains its operation key and failed upload can be removed',
    () async {
      final repo = DraftFake()..uploadFails = true;
      final c = VenueDraftCubit(repo);
      addTearDown(c.close);
      await c.start();
      await c.upload('logo', 'logo.png', Uint8List(12));
      expect(c.hasPendingUpload, true);
      expect(c.state.draft!.version, repo.value.version);
      repo.uploadFails = false;
      await c.retryUpload();
      expect(repo.uploadKeys.toSet().length, 1);
      expect(c.hasPendingUpload, false);
      repo.uploadFails = true;
      await c.upload('gallery', 'photo.png', Uint8List(12));
      await c.discardUpload();
      expect(c.state.draft!.assets, isEmpty);
      expect(c.hasPendingUpload, false);
    },
  );
}
