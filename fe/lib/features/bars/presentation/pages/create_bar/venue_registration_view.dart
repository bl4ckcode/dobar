import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/services/places_service.dart';
import 'package:barz/features/bars/domain/repositories/venue_draft_repository.dart';
import 'package:barz/features/bars/domain/models/venue_draft.dart';
import 'package:barz/features/bars/presentation/bloc/venue_draft_cubit.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/l10n/app_localizations.dart';

class VenueRegistrationView extends StatefulWidget {
  final bool fromOnboarding;
  final VenueDraftRepository? repository;
  const VenueRegistrationView({
    super.key,
    this.fromOnboarding = false,
    this.repository,
  });
  @override
  State<VenueRegistrationView> createState() => _VenueRegistrationViewState();
}

class _VenueRegistrationViewState extends State<VenueRegistrationView> {
  late final VenueDraftCubit cubit;
  final _form = GlobalKey<FormState>();
  final _fieldNodes = <String, FocusNode>{};
  String? _firstInvalidField;
  final _headingFocus = FocusNode();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  List<PlacePrediction> _results = [];
  bool _searching = false, _searched = false, _lookupFailed = false;
  bool _entering = false, _accessFailed = false;
  bool _allowPop = false;
  int _locationRevision = 0;
  int _lookupRevision = 0;
  AppLocalizations get t => AppLocalizations.of(context)!;
  Map<String, dynamic> get p => cubit.payload;

  @override
  void initState() {
    super.initState();
    cubit = VenueDraftCubit(
      widget.repository ?? getItInjector<VenueDraftRepository>(),
    )..list();
  }

  @override
  void dispose() {
    for (final node in _fieldNodes.values) {
      node.dispose();
    }
    cubit.close();
    _headingFocus.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  String _stepLabel(int index) => [
    t.b02_find,
    t.b02_details,
    t.b02_receiving,
    t.b02_photos,
    t.b02_hours,
    t.b02_review,
  ][index];
  String _status(String? s) => switch (s) {
    'complete' => t.b02_complete,
    'skipped' => t.b02_later,
    'in_progress' => t.b02_inProgress,
    _ => t.b02_unvisited,
  };
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();
  void _go(int step) {
    _unfocus();
    cubit.goStep(step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _headingFocus.requestFocus();
    });
  }

  Future<void> _next({bool skip = false}) async {
    _unfocus();
    _firstInvalidField = null;
    if (!skip && !(_form.currentState?.validate() ?? true)) {
      final invalid = _form.currentState?.validateGranularly();
      if (invalid != null && invalid.isNotEmpty) {
        await Scrollable.ensureVisible(
          invalid.first.context,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        );
        if (mounted) _fieldNodes[_firstInvalidField]?.requestFocus();
      }
      return;
    }
    if (cubit.state.step == 3 && cubit.hasPendingUpload) return;
    if (skip && cubit.state.step == 3) {
      final failed = cubit.state.draft!.assets
          .where((a) => a['status'] != 'saved')
          .toList();
      for (final asset in failed) {
        await cubit.removeAsset(asset['id'] as String);
      }
      if (cubit.state.draft!.assets.any((a) => a['status'] != 'saved')) return;
    }
    if (await cubit.next(skip: skip)) _go(cubit.state.step);
  }

  Future<void> _saveExit() async {
    _unfocus();
    if (await cubit.save() &&
        cubit.state.saveStatus == DraftSaveStatus.saved &&
        mounted) {
      _leave();
    }
  }

  void _leave() {
    setState(() => _allowPop = true);
    if (widget.fromOnboarding) {
      AppRoute.onboarding.go(context);
    } else if (context.canPop()) {
      context.pop();
    } else {
      AppRoute.home.go(context);
    }
  }

  Future<void> _close() async {
    _unfocus();
    if (cubit.state.busy || cubit.state.phase == VenuePhase.submitting) return;
    if (cubit.state.phase != VenuePhase.editing ||
        cubit.state.saveStatus == DraftSaveStatus.saved) {
      _leave();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(t.b02_exitTitle)),
            _themeButton(),
          ],
        ),
        content: Text(t.b02_exitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.b02_keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(t.b02_exitUnsaved),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(t.b02_saveExit),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _saveExit();
    } else if (action == 'discard') {
      _leave();
    }
  }

  Widget _themeButton() => IconButton(
    tooltip: context.isDark ? t.b02_themeLight : t.b02_themeDark,
    onPressed: () {
      _unfocus();
      getItInjector<ThemeCubit>().toggleTheme();
    },
    icon: Icon(context.isDark ? LucideIcons.sun : LucideIcons.moon),
  );
  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: context.dobarColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget _button(
    String label,
    VoidCallback? onPressed, {
    bool primary = false,
    IconData? icon,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return primary
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: context.dobarColors.buttonPrimary,
              foregroundColor: context.dobarColors.buttonOnPrimary,
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(
                inherit: false,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.dobarColors.labelPrimary,
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(
                inherit: false,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: child,
          );
  }

  Widget _notice(String message, {bool error = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(
          color: error
              ? Theme.of(context).colorScheme.error
              : context.dobarColors.labelSecondary,
        ),
      ),
    ),
  );
  Widget _field(
    String key,
    String label, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? initial,
    bool bank = false,
  }) {
    final serverError = cubit.state.fieldErrors.containsKey(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        key: ValueKey(
          '${cubit.state.draft?.id}-${cubit.state.step}-${cubit.state.step == 0 ? _locationRevision : 0}-$key',
        ),
        initialValue: initial ?? (p[key]?.toString() ?? ''),
        style: TextStyle(color: context.dobarColors.labelPrimary, fontSize: 16),
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        onTapOutside: (_) => _unfocus(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.dobarColors.labelPrimary),
          hintStyle: TextStyle(color: context.dobarColors.labelSecondary),
          filled: true,
          fillColor: context.dobarColors.surfaceElevated,
          errorText: serverError ? t.b02_invalid : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        focusNode: _fieldNodes.putIfAbsent(key, FocusNode.new),
        validator: (value) {
          final error = validator?.call(value);
          if (error != null) _firstInvalidField ??= key;
          return error;
        },
        onChanged: onChanged ?? (v) => cubit.edit({key: v}),
        autofillHints: bank
            ? null
            : key == 'email'
            ? const [AutofillHints.email]
            : key == 'phone_number'
            ? const [AutofillHints.telephoneNumber]
            : null,
      ),
    );
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? t.b02_required : null;
  Future<void> _lookup() async {
    if (_search.text.trim().isEmpty) return;
    final revision = ++_lookupRevision;
    setState(() {
      _searching = true;
      _lookupFailed = false;
    });
    try {
      final response = await DioNetwork.appAPI.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.placesAutocomplete}',
        queryParameters: {'input': _search.text, 'countries': 'BR'},
      );
      if (!mounted || revision != _lookupRevision) return;
      final body = response.data as Map;
      setState(() {
        _results = (body['predictions'] as List? ?? [])
            .map(
              (d) =>
                  PlacePrediction.fromJson(Map<String, dynamic>.from(d as Map)),
            )
            .toList();
        _searched = true;
        _searching = false;
      });
    } catch (_) {
      if (mounted && revision == _lookupRevision) {
        setState(() {
          _lookupFailed = true;
          _searching = false;
        });
      }
    }
  }

  Future<void> _choose(PlacePrediction place) async {
    setState(() => _searching = true);
    final details = await PlacesService.getDetails(place.placeId);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _lookupFailed = details == null;
    });
    if (details == null) return;
    cubit.edit({
      'name': (p['name'] as String? ?? '').isEmpty ? details.name : p['name'],
      'address': details.address,
      'latitude': details.latitude,
      'longitude': details.longitude,
      'location_confirmed': false,
    });
    setState(() {
      _results = [];
      _searched = false;
      _locationRevision++;
    });
  }

  Widget _find() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _search,
        onTapOutside: (_) => _unfocus(),
        onSubmitted: (_) => _lookup(),
        decoration: InputDecoration(
          labelText: t.b02_search,
          prefixIcon: const Icon(LucideIcons.search),
        ),
        style: TextStyle(color: context.dobarColors.labelPrimary, fontSize: 16),
      ),
      const SizedBox(height: 12),
      _button(
        t.b02_lookup,
        _searching
            ? null
            : () {
                _unfocus();
                _lookup();
              },
      ),
      if (_searching) const LinearProgressIndicator(),
      if (_lookupFailed) _notice(t.b02_lookupFailed, error: true),
      if (_searched && _results.isEmpty) _notice(t.b02_noResults),
      ..._results.map(
        (r) => ListTile(
          title: Text(r.mainText),
          subtitle: Text(r.description),
          onTap: () => _choose(r),
        ),
      ),
      const SizedBox(height: 24),
      _field(
        'address',
        t.b02_address,
        validator: _required,
        onChanged: (v) =>
            cubit.edit({'address': v, 'location_confirmed': false}),
      ),
      _field(
        'latitude',
        t.b02_latitude,
        keyboard: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onChanged: (v) => cubit.edit({
          'latitude': double.tryParse(v.replaceAll(',', '.')),
          'location_confirmed': false,
        }),
        validator: (_) {
          final n = p['latitude'] as num?;
          return n == null || n < -90 || n > 90 ? t.b02_invalid : null;
        },
      ),
      _field(
        'longitude',
        t.b02_longitude,
        keyboard: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onChanged: (v) => cubit.edit({
          'longitude': double.tryParse(v.replaceAll(',', '.')),
          'location_confirmed': false,
        }),
        validator: (_) {
          final n = p['longitude'] as num?;
          return n == null || n < -180 || n > 180 ? t.b02_invalid : null;
        },
      ),
      FormField<bool>(
        validator: (_) =>
            p['location_confirmed'] == true ? null : t.b02_invalid,
        builder: (f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: p['location_confirmed'] == true,
              title: Text(t.b02_confirmLocation),
              onChanged: (v) {
                _unfocus();
                cubit.edit({'location_confirmed': v});
                f.didChange(v);
              },
            ),
            if (f.hasError) _notice(f.errorText!, error: true),
          ],
        ),
      ),
    ],
  );
  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _notice(t.b02_country),
      _field('name', t.b02_name, validator: _required),
      _field('business_id', t.b02_cnpj, keyboard: TextInputType.number),
      Text(t.b02_contact, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 18),
      _field(
        'phone_number',
        t.b02_phone,
        keyboard: TextInputType.phone,
        validator: (v) =>
            (v ?? '').isNotEmpty &&
                !RegExp(
                  r'^(?:55)?[1-9]\d(?:9\d{8}|[2-8]\d{7})$',
                ).hasMatch(v!.replaceAll(RegExp(r'\D'), ''))
            ? t.b02_invalid
            : null,
      ),
      _field(
        'email',
        t.b02_email,
        keyboard: TextInputType.emailAddress,
        validator: (v) =>
            (v ?? '').isNotEmpty &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v!)
            ? t.b02_invalid
            : null,
      ),
    ],
  );
  Map<String, dynamic> get _bank => cubit.bank ?? {};
  void _bankEdit(String key, String value) => cubit.editBank({
    ..._bank,
    key: value,
    'method': _bank['method'] ?? 'pix',
    'pix_key_type': key == 'pix_key_type'
        ? value
        : (_bank['pix_key_type'] ?? 'cnpj'),
    'account_type': key == 'account_type'
        ? value
        : (_bank['account_type'] ?? 'checking'),
  });
  Widget _receiving() {
    final summary = cubit.bankChanged ? null : cubit.state.draft?.bankSummary;
    if (summary != null && cubit.bank == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary['masked'] as String? ?? '',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _notice(
            summary['complete'] == true
                ? t.b02_pendingVerification
                : t.b02_partialBank,
          ),
          _button(t.b02_replace, () {
            cubit.editBank({'method': summary['method']});
          }),
          const SizedBox(height: 8),
          _button(t.b02_remove, () => cubit.editBank(null)),
        ],
      );
    }
    final method = _bank['method'] as String? ?? 'pix';
    Widget bankField(String key, String label, {TextInputType? keyboard}) =>
        _field(
          key,
          label,
          bank: true,
          keyboard: keyboard,
          initial: _bank[key] as String? ?? '',
          onChanged: (v) => _bankEdit(key, v),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _notice(t.b02_optional),
        Wrap(
          spacing: 8,
          children: ['pix', 'bank']
              .map(
                (m) => ChoiceChip(
                  label: Text(m == 'pix' ? t.b02_pix : t.b02_bank),
                  selected: method == m,
                  onSelected: (_) {
                    _unfocus();
                    cubit.editBank({'method': m});
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        if (method == 'pix') ...[
          DropdownButtonFormField<String>(
            initialValue: _bank['pix_key_type'] as String? ?? 'cnpj',
            decoration: InputDecoration(labelText: t.b02_pixType),
            items: ['cpf', 'cnpj', 'email', 'phone', 'random']
                .map(
                  (k) => DropdownMenuItem(
                    value: k,
                    child: Text(switch (k) {
                      'email' => t.b02_email,
                      'phone' => t.b02_phone,
                      'random' => t.b02_random,
                      _ => k.toUpperCase(),
                    }),
                  ),
                )
                .toList(),
            onChanged: (v) => _bankEdit('pix_key_type', v!),
          ),
          const SizedBox(height: 18),
          bankField('pix_key', t.b02_pixKey),
        ] else ...[
          bankField(
            'bank_code',
            t.b02_bankCode,
            keyboard: TextInputType.number,
          ),
          bankField(
            'branch_code',
            t.b02_branch,
            keyboard: TextInputType.number,
          ),
          bankField(
            'account_number',
            t.b02_account,
            keyboard: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            initialValue: _bank['account_type'] as String? ?? 'checking',
            decoration: InputDecoration(labelText: t.b02_accountType),
            items: [
              DropdownMenuItem(value: 'checking', child: Text(t.b02_checking)),
              DropdownMenuItem(value: 'savings', child: Text(t.b02_savings)),
            ],
            onChanged: (v) => _bankEdit('account_type', v!),
          ),
          const SizedBox(height: 18),
          bankField('account_holder_name', t.b02_holder),
          bankField(
            'holder_document',
            t.b02_document,
            keyboard: TextInputType.number,
          ),
        ],
        _button(t.b02_remove, () => cubit.editBank(null)),
      ],
    );
  }

  Future<void> _pick(String slot) async {
    _unfocus();
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await cubit.upload(slot, file.name, bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.b02_uploadFailed)));
      }
    }
  }

  Widget _photos(VenueDraftState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _notice(t.b02_photoLimits),
      if (state.uploadProgress != null) ...[
        _notice(t.b02_uploading),
        LinearProgressIndicator(value: state.uploadProgress),
      ],
      if (cubit.hasPendingUpload && !state.busy) ...[
        _notice(t.b02_uploadFailed, error: true),
        _button(t.b02_retryUpload, () => cubit.retryUpload()),
        _button(t.b02_remove, () => cubit.discardUpload()),
      ],
      for (final slot in ['logo', 'cover', 'gallery'])
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (slot) {
                'logo' => t.b02_logo,
                'cover' => t.b02_cover,
                _ => t.b02_gallery,
              }, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final a in state.draft!.assets.where(
                (a) => a['slot'] == slot,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: a['preview_url'] == null
                      ? const Icon(LucideIcons.image)
                      : Image.network(
                          a['preview_url'] as String,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(LucideIcons.image),
                        ),
                  title: Text(a['filename'] as String),
                  subtitle: Text(
                    a['status'] == 'saved' ? t.b02_saved : t.b02_uploadFailed,
                  ),
                  trailing: IconButton(
                    tooltip: t.b02_remove,
                    onPressed: state.busy
                        ? null
                        : () => cubit.removeAsset(a['id'] as String),
                    icon: const Icon(LucideIcons.trash),
                  ),
                ),
              _button(
                t.b02_addImage,
                state.busy || cubit.hasPendingUpload ? null : () => _pick(slot),
                icon: LucideIcons.image_plus,
              ),
            ],
          ),
        ),
    ],
  );
  Map<String, dynamic> _defaultHours() => {
    for (final day in venueDays)
      day: {'is_closed': day == 'monday', 'open': '18:00', 'close': '02:00'},
  };
  void _dayEdit(String day, Map<String, dynamic> change) {
    final hours = Map<String, dynamic>.from(p['operating_hours'] as Map);
    hours[day] = {
      ...Map<String, dynamic>.from(hours[day] as Map? ?? {}),
      ...change,
    };
    cubit.edit({'operating_hours': hours});
  }

  String _dayLabel(int index) => DateFormat.EEEE(
    Localizations.localeOf(context).toString(),
  ).format(DateTime(2026, 10, 26 + index));
  Future<void> _time(String day, String key, String label) async {
    _unfocus();
    final value =
        ((p['operating_hours'] as Map)[day] as Map)[key] as String? ?? '18:00';
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(value.split(':')[0]),
        minute: int.parse(value.split(':')[1]),
      ),
      helpText: label,
    );
    if (time != null) {
      _dayEdit(day, {
        key:
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      });
    }
  }

  Widget _hours() {
    final hours = p['operating_hours'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _notice(t.b02_timezone),
        if (hours == null) ...[
          _notice(t.b02_later),
          _button(
            t.b02_configureHours,
            () => cubit.edit({'operating_hours': _defaultHours()}),
          ),
        ] else ...[
          for (var i = 0; i < venueDays.length; i++)
            _card(
              Builder(
                builder: (_) {
                  final day = venueDays[i];
                  final h = hours[day] as Map? ?? {};
                  final open = h['is_closed'] != true;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _dayLabel(i),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(open ? t.b02_open : t.b02_closed),
                        value: open,
                        onChanged: (v) => _dayEdit(day, {'is_closed': !v}),
                      ),
                      if (open) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _button(
                              '${t.b02_opens} ${h['open'] ?? ''}',
                              () => _time(day, 'open', t.b02_opens),
                            ),
                            _button(
                              '${t.b02_closes} ${h['close'] ?? ''}',
                              () => _time(day, 'close', t.b02_closes),
                            ),
                          ],
                        ),
                        if ((h['close'] as String? ?? '').compareTo(
                              h['open'] as String? ?? '',
                            ) <
                            0)
                          _notice(t.b02_overnight),
                        if (h['close'] == h['open'])
                          _notice(t.b02_invalid, error: true),
                      ],
                      TextButton(
                        onPressed: () => cubit.edit({
                          'operating_hours': {
                            for (final key in venueDays) key: Map.of(h),
                          },
                        }),
                        child: Text(t.b02_copyHours),
                      ),
                    ],
                  );
                },
              ),
            ),
          _button(
            t.b02_clearHours,
            () => cubit.edit({'operating_hours': null}),
          ),
        ],
      ],
    );
  }

  Widget _review(VenueDraftState state) {
    Widget section(int step, String text) => _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _stepLabel(step),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: () => _go(step), child: Text(t.b02_edit)),
            ],
          ),
          Text(text),
        ],
      ),
    );
    final summary = state.draft!.bankSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          1,
          '${p['name'] ?? t.b02_unnamed}\n${p['address'] ?? ''}\n${p['phone_number'] ?? ''}\n${p['email'] ?? ''}',
        ),
        section(
          2,
          summary == null
              ? t.b02_later
              : '${summary['masked']}\n${summary['complete'] == true ? t.b02_pendingVerification : t.b02_partialBank}',
        ),
        section(
          3,
          state.draft!.assets.isEmpty
              ? t.b02_later
              : state.draft!.assets.map((a) => a['filename']).join('\n'),
        ),
        section(
          4,
          p['operating_hours'] == null
              ? t.b02_later
              : [
                  for (var i = 0; i < venueDays.length; i++)
                    '${_dayLabel(i)}: ${((p['operating_hours'] as Map)[venueDays[i]] as Map?)?['is_closed'] == true ? t.b02_closed : '${((p['operating_hours'] as Map)[venueDays[i]] as Map?)?['open'] ?? ''}–${((p['operating_hours'] as Map)[venueDays[i]] as Map?)?['close'] ?? ''}'}',
                ].join('\n'),
        ),
        _card(
          Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.b02_import),
                value: p['menu_import_intent'] == true,
                onChanged: (v) => cubit.edit({'menu_import_intent': v}),
              ),
              Text(t.b02_importHint),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _enter() async {
    if (_entering || cubit.state.draft?.barId == null) return;
    setState(() {
      _entering = true;
      _accessFailed = false;
    });
    final ok = await getItInjector<SessionBloc>().refreshAndSelectVenue(
      cubit.state.draft!.barId!,
    );
    if (!mounted) return;
    setState(() {
      _entering = false;
      _accessFailed = !ok;
    });
    if (ok) {
      setState(() => _allowPop = true);
      if (p['menu_import_intent'] == true) {
        AppRoute.businessMenuReader.go(
          context,
          extra: {'barId': cubit.state.draft!.barId},
        );
      } else {
        AppRoute.businessDashboard.go(context);
      }
    }
  }

  Widget _content(VenueDraftState state) {
    switch (state.phase) {
      case VenuePhase.loading:
        return const Center(child: CircularProgressIndicator());
      case VenuePhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _notice(
              state.errorStatus == 401
                  ? t.b02_session
                  : state.errorStatus == 404 || state.errorStatus == 403
                  ? t.b02_unavailable
                  : t.b02_error,
              error: true,
            ),
            _button(t.b02_retry, () => cubit.list()),
            if (state.errorStatus == 401)
              _button(t.b02_signIn, () => AppRoute.login.go(context)),
          ],
        );
      case VenuePhase.list:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.b02_drafts,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _notice(t.b02_intro),
            for (final d in state.drafts)
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      d.payload['name'] as String? ?? t.b02_unnamed,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d.barId == null
                          ? '${t.b02_draft} · ${_stepLabel(venueSteps.indexOf(d.nextStep))}'
                          : t.b02_created,
                    ),
                    if (d.updatedAt != null)
                      Text(
                        DateFormat.yMd(
                          Localizations.localeOf(context).toString(),
                        ).add_Hm().format(
                          DateTime.parse(d.updatedAt!).toLocal(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _button(
                      d.barId == null ? t.b02_resume : t.b02_enter,
                      state.busy ? null : () => cubit.resume(d.id),
                    ),
                  ],
                ),
              ),
            _button(
              t.b02_start,
              state.busy ? null : () => cubit.start(),
              primary: true,
            ),
            const SizedBox(height: 20),
            _notice(t.b02_exitBody),
          ],
        );
      case VenuePhase.submitting:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(t.b02_submitting),
          ],
        );
      case VenuePhase.unknown:
        return Column(
          children: [
            _notice(t.b02_unknown),
            _button(
              t.b02_checkResult,
              state.busy ? null : () => cubit.reconcile(),
              primary: true,
            ),
          ],
        );
      case VenuePhase.created:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(LucideIcons.circle_check, size: 48),
            const SizedBox(height: 16),
            Text(
              t.b02_created,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (_accessFailed) _notice(t.b02_accessFailed, error: true),
            if (_entering) const LinearProgressIndicator(),
            _button(
              p['menu_import_intent'] == true ? t.b02_import : t.b02_enter,
              _entering ? null : _enter,
              primary: true,
            ),
          ],
        );
      case VenuePhase.editing:
        return Form(
          key: _form,
          child: _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Focus(
                    focusNode: _headingFocus,
                    child: Text(
                      _stepLabel(state.step),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                switch (state.step) {
                  0 => _find(),
                  1 => _details(),
                  2 => _receiving(),
                  3 => _photos(state),
                  4 => _hours(),
                  _ => _review(state),
                },
              ],
            ),
          ),
        );
    }
  }

  Widget _progress(VenueDraftState state) => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth < 600) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(t.b02_step(state.step + 1, _stepLabel(state.step))),
            children: [
              for (var i = 0; i < 6; i++)
                ListTile(
                  title: Text(_stepLabel(i)),
                  subtitle: Text(_status(state.draft!.steps[venueSteps[i]])),
                  selected: state.step == i,
                  onTap: () => _go(i),
                ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: Semantics(
                  selected: i == state.step,
                  label:
                      '${_stepLabel(i)}, ${_status(state.draft!.steps[venueSteps[i]])}',
                  child: InkWell(
                    onTap: () => _go(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                i == state.step ||
                                    state.draft!.steps[venueSteps[i]] ==
                                        'complete'
                                ? context.dobarColors.buttonPrimary
                                : context.dobarColors.surfaceElevated,
                            foregroundColor:
                                i == state.step ||
                                    state.draft!.steps[venueSteps[i]] ==
                                        'complete'
                                ? context.dobarColors.buttonOnPrimary
                                : context.dobarColors.labelPrimary,
                            child:
                                state.draft!.steps[venueSteps[i]] == 'complete'
                                ? const Icon(LucideIcons.check, size: 18)
                                : Text('${i + 1}'),
                          ),
                          const SizedBox(height: 8),
                          Text(_stepLabel(i), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
  Widget _saveStatus(VenueDraftState state) {
    final text = switch (state.saveStatus) {
      DraftSaveStatus.saved =>
        state.draft?.updatedAt == null
            ? t.b02_saved
            : t.b02_savedAt(
                DateFormat.Hm().format(
                  DateTime.parse(state.draft!.updatedAt!).toLocal(),
                ),
              ),
      DraftSaveStatus.dirty => t.b02_dirty,
      DraftSaveStatus.saving => t.b02_saving,
      DraftSaveStatus.failed => t.b02_saveFailed,
      DraftSaveStatus.conflict => t.b02_conflict,
      DraftSaveStatus.sessionExpired => t.b02_session,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _notice(
          text,
          error:
              state.saveStatus == DraftSaveStatus.failed ||
              state.saveStatus == DraftSaveStatus.conflict,
        ),
        if (state.saveStatus == DraftSaveStatus.failed)
          _button(t.b02_retry, () => cubit.save()),
        if (state.saveStatus == DraftSaveStatus.conflict)
          _button(t.b02_reload, () => cubit.resume(state.draft!.id)),
        if (state.saveStatus == DraftSaveStatus.sessionExpired)
          _button(t.b02_signIn, () => AppRoute.login.go(context)),
        for (final field in state.fieldErrors.keys)
          TextButton(
            onPressed: () => _go(
              field == 'bank_account'
                  ? 2
                  : field == 'operating_hours'
                  ? 4
                  : field == 'assets'
                  ? 3
                  : field == 'location_confirmed' || field == 'address'
                  ? 0
                  : 1,
            ),
            child: Text(
              '${t.b02_edit}: ${_stepLabel(field == 'bank_account'
                  ? 2
                  : field == 'operating_hours'
                  ? 4
                  : field == 'assets'
                  ? 3
                  : field == 'location_confirmed' || field == 'address'
                  ? 0
                  : 1)}',
            ),
          ),
        if (state.fieldErrors.isNotEmpty || state.errorStatus != null)
          _notice(
            state.fieldErrors.isEmpty ? t.b02_error : t.b02_reviewErrors,
            error: true,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<VenueDraftCubit, VenueDraftState>(
        bloc: cubit,
        listenWhen: (previous, current) =>
            previous.phase != VenuePhase.created &&
            current.phase == VenuePhase.created,
        listener: (_, state) {
          _enter();
        },
        builder: (context, state) {
          final editing = state.phase == VenuePhase.editing;
          final colors = context.dobarColors;
          return PopScope(
            canPop: _allowPop || (!editing && !state.busy),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _close();
            },
            child: Scaffold(
              backgroundColor: colors.background,
              appBar: AppBar(
                backgroundColor: colors.background,
                foregroundColor: colors.labelPrimary,
                leading: IconButton(
                  tooltip: t.b02_exitTitle,
                  onPressed: _close,
                  icon: const Icon(LucideIcons.x),
                ),
                title: Text(
                  t.b02_title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                actions: [_themeButton(), const SizedBox(width: 8)],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (editing) ...[
                                _progress(state),
                                _saveStatus(state),
                              ],
                              _content(state),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (editing)
                    Container(
                      decoration: BoxDecoration(
                        color: colors.background,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _button(
                                    t.b02_saveExit,
                                    state.busy ? null : _saveExit,
                                    icon: LucideIcons.save,
                                  ),
                                  if (state.step > 0)
                                    _button(
                                      t.b02_back,
                                      state.busy
                                          ? null
                                          : () => _go(state.step - 1),
                                    ),
                                  if (state.step >= 2 && state.step <= 4)
                                    _button(
                                      t.b02_skip,
                                      state.busy || cubit.hasPendingUpload
                                          ? null
                                          : () => _next(skip: true),
                                    ),
                                  _button(
                                    state.step == 5 ? t.b02_create : t.b02_next,
                                    state.busy || cubit.hasPendingUpload
                                        ? null
                                        : () {
                                            _unfocus();
                                            if (state.step == 5) {
                                              cubit.finalize();
                                            } else {
                                              _next();
                                            }
                                          },
                                    primary: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}
