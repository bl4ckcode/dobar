import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/venue_draft.dart';
import '../../domain/repositories/venue_draft_repository.dart';

String venueOperationKey() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

enum VenuePhase { loading, list, editing, submitting, unknown, created, error }

enum DraftSaveStatus { saved, dirty, saving, failed, conflict, sessionExpired }

class VenueDraftState {
  final VenuePhase phase;
  final DraftSaveStatus saveStatus;
  final VenueDraft? draft;
  final List<VenueDraft> drafts;
  final int step;
  final bool busy;
  final int? errorStatus;
  final Map<String, dynamic> fieldErrors;
  final double? uploadProgress;
  const VenueDraftState({
    this.phase = VenuePhase.loading,
    this.saveStatus = DraftSaveStatus.saved,
    this.draft,
    this.drafts = const [],
    this.step = 0,
    this.busy = false,
    this.errorStatus,
    this.fieldErrors = const {},
    this.uploadProgress,
  });
}

class VenueDraftCubit extends Cubit<VenueDraftState> {
  final VenueDraftRepository repository;
  VenueDraftCubit(this.repository) : super(const VenueDraftState());
  Map<String, dynamic> payload = {};
  Map<String, String> steps = {};
  Map<String, dynamic>? bank;
  bool _bankChanged = false;
  int _revision = 0;
  Timer? _debounce;
  String? _createKey;
  String? _finalizeKey;
  int? _finalizeVersion;
  Future<bool>? _saving;
  ({String key, String slot, String filename, Uint8List bytes})? _upload;

  void _emit({
    VenuePhase? phase,
    DraftSaveStatus? save,
    VenueDraft? draft,
    List<VenueDraft>? drafts,
    int? step,
    bool? busy,
    int? error,
    Map<String, dynamic>? fields,
    double? progress,
  }) {
    if (isClosed) return;
    emit(
      VenueDraftState(
        phase: phase ?? state.phase,
        saveStatus: save ?? state.saveStatus,
        draft: draft ?? state.draft,
        drafts: drafts ?? state.drafts,
        step: step ?? state.step,
        busy: busy ?? state.busy,
        errorStatus: error,
        fieldErrors: fields ?? const {},
        uploadProgress: progress,
      ),
    );
  }

  Future<void> list() async {
    _debounce?.cancel();
    _emit(phase: VenuePhase.loading);
    try {
      _emit(phase: VenuePhase.list, drafts: await repository.list());
    } on VenueDraftException catch (e) {
      _emit(phase: VenuePhase.error, error: e.status);
    }
  }

  Future<void> start() async {
    if (state.busy) return;
    _emit(busy: true);
    _createKey ??= venueOperationKey();
    try {
      _accept(await repository.create(_createKey!));
      _createKey = null;
    } on VenueDraftException catch (e) {
      _emit(phase: VenuePhase.error, error: e.status, busy: false);
    }
  }

  Future<void> resume(String id) async {
    if (state.busy) return;
    _debounce?.cancel();
    _emit(busy: true);
    try {
      _accept(await repository.load(id));
    } on VenueDraftException catch (e) {
      _emit(phase: VenuePhase.error, error: e.status, busy: false);
    }
  }

  void _accept(VenueDraft draft) {
    payload = Map.of(draft.payload);
    steps = Map.of(draft.steps);
    bank = null;
    _bankChanged = false;
    _revision = 0;
    _finalizeKey = null;
    _finalizeVersion = null;
    _upload = null;
    _emit(
      phase: draft.barId != null ? VenuePhase.created : VenuePhase.editing,
      draft: draft,
      save: DraftSaveStatus.saved,
      step: venueSteps.indexOf(draft.nextStep),
      busy: false,
    );
  }

  void edit(Map<String, dynamic> changes) {
    if (state.phase != VenuePhase.editing || state.busy) return;
    payload = {...payload, ...changes};
    _changed();
  }

  void editBank(Map<String, dynamic>? value) {
    if (state.phase != VenuePhase.editing || state.busy) return;
    bank = value == null ? null : Map.of(value);
    _bankChanged = true;
    _changed();
  }

  bool get bankChanged => _bankChanged;
  bool get hasPendingUpload => _upload != null;
  void _changed() {
    _revision++;
    final blocked =
        state.saveStatus == DraftSaveStatus.conflict ||
        state.saveStatus == DraftSaveStatus.sessionExpired;
    _emit(save: blocked ? state.saveStatus : DraftSaveStatus.dirty);
    _debounce?.cancel();
    if (!blocked) {
      _debounce = Timer(const Duration(milliseconds: 800), () => save());
    }
  }

  Future<bool> save() async {
    _debounce?.cancel();
    if (state.draft == null ||
        state.phase != VenuePhase.editing ||
        state.saveStatus == DraftSaveStatus.conflict) {
      return false;
    }
    if (_saving != null) {
      if (!await _saving!) return false;
      return state.saveStatus == DraftSaveStatus.saved ? true : save();
    }
    if (state.saveStatus == DraftSaveStatus.saved) return true;
    final pending = _saveOnce();
    _saving = pending;
    try {
      return await pending;
    } finally {
      _saving = null;
    }
  }

  Future<bool> _saveOnce() async {
    final draft = state.draft!;
    final revision = _revision;
    final sentBankChanged = _bankChanged;
    final sentBank = bank == null ? null : Map<String, dynamic>.of(bank!);
    _emit(save: DraftSaveStatus.saving);
    try {
      final saved = await repository.save(
        draft.id,
        draft.version,
        Map.of(payload),
        Map.of(steps),
        bankChanged: sentBankChanged,
        bank: sentBank,
      );
      if (revision == _revision) {
        _bankChanged = false;
      }
      _emit(
        draft: saved,
        save: revision == _revision
            ? DraftSaveStatus.saved
            : DraftSaveStatus.dirty,
      );
      if (revision != _revision) {
        _debounce = Timer(const Duration(milliseconds: 800), () => save());
      }
      return true;
    } on VenueDraftException catch (e) {
      _emit(
        save: e.status == 409
            ? DraftSaveStatus.conflict
            : e.status == 401
            ? DraftSaveStatus.sessionExpired
            : DraftSaveStatus.failed,
        error: e.status,
        fields: e.details,
      );
      return false;
    }
  }

  void goStep(int index) {
    if (state.busy || state.phase != VenuePhase.editing) return;
    _emit(step: index);
  }

  Future<bool> next({bool skip = false}) async {
    if (state.busy || state.phase != VenuePhase.editing) return false;
    final key = venueSteps[state.step];
    if (skip && state.step >= 2 && state.step <= 4) {
      if (key == 'receiving') {
        bank = null;
        _bankChanged = true;
      }
      if (key == 'hours') payload = {...payload, 'operating_hours': null};
    }
    steps = {...steps, key: skip ? 'skipped' : 'complete'};
    _changed();
    if (!await save()) return false;
    if (key == 'receiving') bank = null;
    _emit(step: min(state.step + 1, 5));
    return true;
  }

  Future<void> finalize() async {
    if (state.busy || state.phase != VenuePhase.editing || hasPendingUpload) {
      return;
    }
    if (!await save() || state.saveStatus != DraftSaveStatus.saved) return;
    _finalizeKey ??= venueOperationKey();
    _finalizeVersion ??= state.draft!.version;
    _emit(phase: VenuePhase.submitting, busy: true);
    try {
      final created = await repository.finalize(
        state.draft!.id,
        _finalizeVersion!,
        _finalizeKey!,
      );
      _emit(phase: VenuePhase.created, draft: created, busy: false);
    } on VenueDraftException catch (e) {
      if (e.status == 422 || e.status == 409) {
        _finalizeKey = null;
        _finalizeVersion = null;
        _emit(
          phase: VenuePhase.editing,
          busy: false,
          error: e.status,
          fields: e.details,
        );
      } else {
        _emit(phase: VenuePhase.unknown, busy: false, error: e.status);
      }
    }
  }

  Future<void> reconcile() async {
    if (state.busy) return;
    _emit(busy: true);
    try {
      final result = await repository.load(state.draft!.id);
      if (result.barId != null) {
        _emit(phase: VenuePhase.created, draft: result, busy: false);
      } else if (result.version != _finalizeVersion) {
        _accept(result);
        _emit(save: DraftSaveStatus.conflict);
      } else {
        _emit(phase: VenuePhase.editing, draft: result, busy: false);
        await finalize();
      }
    } on VenueDraftException catch (e) {
      _emit(phase: VenuePhase.unknown, busy: false, error: e.status);
    }
  }

  Future<void> upload(String slot, String filename, Uint8List bytes) async {
    if (state.busy || !await save()) return;
    _upload = (
      key: venueOperationKey(),
      slot: slot,
      filename: filename,
      bytes: bytes,
    );
    await retryUpload();
  }

  Future<void> retryUpload() async {
    if (state.busy || _upload == null) return;
    final upload = _upload!;
    _emit(busy: true, progress: 0);
    try {
      final updated = await repository.upload(
        state.draft!.id,
        upload.key,
        upload.slot,
        upload.filename,
        upload.bytes,
        (p) => _emit(busy: true, progress: p),
      );
      _upload = null;
      _emit(draft: updated, busy: false);
    } on VenueDraftException catch (e) {
      VenueDraft? current;
      try {
        current = await repository.load(state.draft!.id);
      } on VenueDraftException {
        /* Keep the pending operation for reconciliation. */
      }
      _emit(draft: current, busy: false, error: e.status);
    }
  }

  Future<void> discardUpload() async {
    if (state.busy || _upload == null) return;
    _emit(busy: true);
    try {
      var current = await repository.load(state.draft!.id);
      final matches = current.assets.where(
        (a) => a['client_key'] == _upload!.key,
      );
      if (matches.isNotEmpty) {
        current = await repository.removeAsset(
          current.id,
          matches.first['id'] as String,
        );
      }
      _upload = null;
      _emit(draft: current, busy: false);
    } on VenueDraftException catch (e) {
      _emit(busy: false, error: e.status);
    }
  }

  Future<void> removeAsset(String id) async {
    if (state.busy || !await save()) return;
    _emit(busy: true);
    try {
      _emit(
        draft: await repository.removeAsset(state.draft!.id, id),
        busy: false,
      );
    } on VenueDraftException catch (e) {
      _emit(busy: false, error: e.status);
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
