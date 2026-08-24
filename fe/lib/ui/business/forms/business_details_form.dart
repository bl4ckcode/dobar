import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/business_settings/presentation/bloc/business_settings_bloc.dart';
import 'package:barz/features/business_settings/presentation/bloc/business_settings_event.dart';
import 'package:barz/features/business_settings/presentation/bloc/business_settings_state.dart';
import 'package:barz/features/business_settings/domain/models/bar_details.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:barz/l10n/app_localizations.dart';

typedef DayKey = String;
const days = [
  ('mon', 'Monday'),
  ('tue', 'Tuesday'),
  ('wed', 'Wednesday'),
  ('thu', 'Thursday'),
  ('fri', 'Friday'),
  ('sat', 'Saturday'),
  ('sun', 'Sunday'),
];

class _DayHours {
  String open;
  String close;
  bool closed;

  _DayHours({required this.open, required this.close, this.closed = false});
}

class _FormData {
  String barName;
  String description;
  String category;
  String phone;
  String email;
  String address;
  String city;
  String state;
  String countryCode;
  double latitude;
  double longitude;
  String businessId;
  String businessIdType;
  String stateRegistration;
  String verification;
  List<String> photoUrls;
  bool sameHours;
  _DayHours generalHours;
  Map<String, _DayHours> hours;
  String locationMethod;
  List<String> spots;
  String? coverImageUrl;
  String? logoUrl;

  _FormData({
    required this.barName,
    required this.description,
    required this.category,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.businessId,
    required this.businessIdType,
    required this.stateRegistration,
    required this.verification,
    required this.photoUrls,
    required this.sameHours,
    required this.generalHours,
    required this.hours,
    required this.locationMethod,
    required this.spots,
    this.coverImageUrl,
    this.logoUrl,
  });
}

class BusinessDetailsForm extends StatelessWidget {
  const BusinessDetailsForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getItInjector<BusinessSettingsBloc>(),
      child: const _BusinessDetailsFormContent(),
    );
  }
}

class _BusinessDetailsFormContent extends StatefulWidget {
  const _BusinessDetailsFormContent();

  @override
  State<_BusinessDetailsFormContent> createState() => _BusinessDetailsFormState();
}

class _BusinessDetailsFormState extends State<_BusinessDetailsFormContent> {
  final _FormData _form = _FormData(
    barName: '',
    description: '',
    category: 'bar',
    phone: '',
    email: '',
    address: '',
    city: '',
    state: '',
    countryCode: 'BR',
    latitude: 0,
    longitude: 0,
    businessId: '',
    businessIdType: 'CNPJ',
    stateRegistration: '',
    verification: 'not_submitted',
    photoUrls: [],
    sameHours: false,
    generalHours: _DayHours(open: '18:00', close: '02:00'),
    hours: {for (final d in days) d.$1: _DayHours(open: '18:00', close: '02:00', closed: d.$1 == 'sun')},
    locationMethod: 'table_number',
    spots: ['VIP Area', 'Terrace', 'Counter'],
  );
  String _getDayName(AppLocalizations l10n, String key) {
    switch (key) {
      case 'mon': return l10n.monday;
      case 'tue': return l10n.tuesday;
      case 'wed': return l10n.wednesday;
      case 'thu': return l10n.thursday;
      case 'fri': return l10n.friday;
      case 'sat': return l10n.saturday;
      case 'sun': return l10n.sunday;
      default: return '';
    }
  }

  late _FormData _initial;
  bool _saving = false;
  bool _saved = false;
  String _newSpot = '';
  final Map<String, TextEditingController> _controllers = {};

  bool get _dirty => _form.barName != _initial.barName ||
      _form.description != _initial.description ||
      _form.category != _initial.category ||
      _form.phone != _initial.phone ||
      _form.email != _initial.email ||
      _form.address != _initial.address ||
      _form.city != _initial.city ||
      _form.state != _initial.state ||
      _form.businessId != _initial.businessId ||
      _form.stateRegistration != _initial.stateRegistration ||
      _form.sameHours != _initial.sameHours ||
      _form.locationMethod != _initial.locationMethod ||
      _form.generalHours.open != _initial.generalHours.open ||
      _form.generalHours.close != _initial.generalHours.close ||
      !_hoursEqual(_form.hours, _initial.hours) ||
      !_listEqual(_form.photoUrls, _initial.photoUrls) ||
      !_listEqual(_form.spots, _initial.spots) ||
      _form.coverImageUrl != _initial.coverImageUrl ||
      _form.logoUrl != _initial.logoUrl;

  bool _hoursEqual(Map<String, _DayHours> a, Map<String, _DayHours> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final aDay = a[key];
      final bDay = b[key];
      if (aDay == null || bDay == null) return false;
      if (aDay.open != bDay.open || aDay.close != bDay.close || aDay.closed != bDay.closed) return false;
    }
    return true;
  }

  bool _listEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  TextEditingController _ctrl(String key, String value) {
    return _controllers.putIfAbsent(key, () => TextEditingController(text: value));
  }

  @override
  void initState() {
    super.initState();
    _initial = _FormData(
      barName: _form.barName,
      description: _form.description,
      category: _form.category,
      phone: _form.phone,
      email: _form.email,
      address: _form.address,
      city: _form.city,
      state: _form.state,
      countryCode: _form.countryCode,
      latitude: _form.latitude,
      longitude: _form.longitude,
      businessId: _form.businessId,
      businessIdType: _form.businessIdType,
      stateRegistration: _form.stateRegistration,
      verification: _form.verification,
      photoUrls: List.from(_form.photoUrls),
      sameHours: _form.sameHours,
      generalHours: _DayHours(open: _form.generalHours.open, close: _form.generalHours.close, closed: _form.generalHours.closed),
      hours: {for (final e in _form.hours.entries) e.key: _DayHours(open: e.value.open, close: e.value.close, closed: e.value.closed)},
      locationMethod: _form.locationMethod,
      spots: List.from(_form.spots),
    );
    _loadBarDetails();
  }

  String? _getFormValueForField(String key) {
    return switch (key) {
      'barName' => _form.barName,
      'description' => _form.description,
      'phone' => _form.phone,
      'email' => _form.email,
      'address' => _form.address,
      'city' => _form.city,
      'state' => _form.state,
      'businessId' => _form.businessId,
      'stateRegistration' => _form.stateRegistration,
      'newSpot' => _newSpot,
      _ => null,
    };
  }

  void _loadBarDetails() {
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is SessionReady) {
      final barId = sessionState.session.activeBar?.barId;
      if (barId != null) {
        context.read<BusinessSettingsBloc>().add(LoadBarDetails(barId));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFromBarDetails(BarDetails details) {
    String parsedCity = _form.city;
    String parsedState = _form.state;
    if (details.address != null && details.address!.contains(',')) {
      final parts = details.address!.split(',');
      if (parts.length >= 2) {
        final locationPart = parts[parts.length - 2].trim();
        final stateMatch = RegExp(r'(.+?)\s*-\s*([A-Z]{2})$').firstMatch(locationPart);
        if (stateMatch != null) {
          parsedCity = stateMatch.group(1)!.trim();
          parsedState = stateMatch.group(2)!.trim();
        } else {
          parsedCity = locationPart;
        }
      }
    }

    setState(() {
      _form.barName = details.barName;
      _form.description = details.description ?? '';
      _form.category = details.category ?? 'bar';
      _form.email = '';
      _form.phone = '';
      _form.address = details.address ?? '';
      _form.city = parsedCity;
      _form.state = parsedState;
      _form.countryCode = details.country ?? 'BR';
      _form.latitude = details.latitude ?? 0;
      _form.longitude = details.longitude ?? 0;
      _form.businessId = details.businessId ?? '';
      _form.coverImageUrl = details.coverImageUrl;
      _form.logoUrl = details.logoUrl;
      // Sync controllers with new values from API
      for (final entry in _controllers.entries) {
        final formValue = _getFormValueForField(entry.key);
        if (formValue != null && entry.value.text != formValue) {
          entry.value.text = formValue;
          entry.value.selection = TextSelection.collapsed(offset: formValue.length);
        }
      }
      _initial = _FormData(
        barName: _form.barName,
        description: _form.description,
        category: _form.category,
        phone: _form.phone,
        email: _form.email,
        address: _form.address,
        city: _form.city,
        state: _form.state,
        countryCode: _form.countryCode,
        latitude: _form.latitude,
        longitude: _form.longitude,
         businessId: _form.businessId,
        businessIdType: _form.businessIdType,
        stateRegistration: _form.stateRegistration,
        verification: _form.verification,
        photoUrls: List.from(_form.photoUrls),
        sameHours: _form.sameHours,
        generalHours: _DayHours(open: _form.generalHours.open, close: _form.generalHours.close),
        hours: {for (final e in _form.hours.entries) e.key: _DayHours(open: e.value.open, close: e.value.close, closed: e.value.closed)},
        locationMethod: _form.locationMethod,
        spots: List.from(_form.spots),
        coverImageUrl: _form.coverImageUrl,
        logoUrl: _form.logoUrl,
      );
    });
  }

  void _handleBack() {
    if (_dirty) {
      _showUnsavedBottomSheet(context);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final bloc = context.read<BusinessSettingsBloc>();
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is SessionReady) {
      final barId = sessionState.session.activeBar?.barId;
      if (barId != null) {
        final data = <String, dynamic>{
          'bar_name': _form.barName,
          'description': _form.description,
          'category': _form.category,
          'address': _form.address,
          'city': _form.city,
          'state': _form.state,
          'country': _form.countryCode,
          'latitude': _form.latitude,
          'longitude': _form.longitude,
        };
        if (_form.businessId.isNotEmpty) {
          data['business_id'] = _form.businessId.replaceAll(RegExp(r'[^0-9]'), '');
        }
        if (_form.coverImageUrl != null) {
          data['cover_image_url'] = _form.coverImageUrl;
        }
        if (_form.logoUrl != null) {
          data['logo_url'] = _form.logoUrl;
        }
        bloc.add(UpdateBarDetails(barId, data));
      }
    }
  }

  Future<void> _pickAndUploadImage({required bool isCover}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (mounted) {
      final sessionState = context.read<SessionBloc>().state;
      if (sessionState is SessionReady) {
        final barId = sessionState.session.activeBar?.barId;
        if (barId == null) return;
        context.read<BusinessSettingsBloc>().add(
          UploadBarImage(barId, imageBytes: bytes, fileName: picked.name),
        );
        // Listen for the URL via a post-frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final bloc = context.read<BusinessSettingsBloc>();
          final sub = bloc.stream.listen((state) {
            if (state.uploadedImageUrl != null && mounted) {
              setState(() {
                if (isCover) {
                  _form.coverImageUrl = state.uploadedImageUrl;
                } else {
                  _form.logoUrl = state.uploadedImageUrl;
                }
              });
            }
          });
          // Cancel after 30s to avoid leaks
          Future.delayed(const Duration(seconds: 30), () => sub.cancel());
        });
      }
    }
  }

  String _flagEmoji(String cc) {
    final code = cc.toUpperCase();
    return String.fromCharCodes(
      code.runes.map((c) => 127397 + c),
    );
  }

  Widget _sectionHeader(String label) {
    final mutedColor = context.dobarColors.labelSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: mutedColor,
          fontFamily: 'Courier',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _fieldLabel(IconData icon, String label) {
    final mutedColor = context.dobarColors.labelSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: mutedColor),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: mutedColor,
              fontFamily: 'Courier',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required String value,
    required ValueChanged<String> onChanged,
    String? hint,
    bool large = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? fieldKey,
  }) {
    final dobar = context.dobarColors;
    final theme = Theme.of(context);
    final controller = _ctrl(fieldKey ?? 'unnamed', value);
    // Sync controller text when value changes externally (e.g. API load)
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.collapsed(offset: value.length);
    }
    return TextField(
      controller: controller,
      onChanged: (v) => setState(() => onChanged(v)),
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: TextStyle(
        color: dobar.labelPrimary,
        fontSize: large ? 20 : 14,
        fontWeight: large ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: dobar.labelSecondary),
        counterStyle: TextStyle(color: dobar.labelSecondary, fontSize: 11),
        filled: true,
        fillColor: dobar.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: barzGold, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final theme = Theme.of(context);
    final mutedColor = dobar.labelSecondary;
    final textColor = dobar.labelPrimary;
    final borderColor = theme.colorScheme.outline;

    final l10n = AppLocalizations.of(context)!;
    final verificationBadge = switch (_form.verification) {
      'verified' => (l10n.details_status_verified, successGreen, successGreen.withValues(alpha: 0.15)),
      'pending' => (l10n.details_status_pending, barzGold, barzGold.withValues(alpha: 0.15)),
      'rejected' => (l10n.details_status_rejected, errorRed, errorRed.withValues(alpha: 0.15)),
      _ => (l10n.details_status_not_submitted, mutedColor, borderColor),
    };

    return BlocListener<BusinessSettingsBloc, BusinessSettingsState>(
      listenWhen: (previous, current) =>
          current.barDetails != null && current.isLoading == false ||
          (previous.isProcessing && !current.isProcessing),
      listener: (context, state) {
        if (state.barDetails != null && !state.isLoading) {
          _populateFromBarDetails(state.barDetails!);
        }
        // Handle save completion
        if (state.isProcessing == false && _saving) {
          setState(() {
            _saving = false;
            if (state.error == null) {
              _saved = true;
            }
          });
          if (state.error == null) {
            // Update initial state to match current form so _dirty becomes false
            _initial = _FormData(
              barName: _form.barName,
              description: _form.description,
              category: _form.category,
              phone: _form.phone,
              email: _form.email,
              address: _form.address,
              city: _form.city,
              state: _form.state,
              countryCode: _form.countryCode,
              latitude: _form.latitude,
              longitude: _form.longitude,
              businessId: _form.businessId,
              businessIdType: _form.businessIdType,
              stateRegistration: _form.stateRegistration,
              verification: _form.verification,
              photoUrls: List.from(_form.photoUrls),
              sameHours: _form.sameHours,
              generalHours: _DayHours(open: _form.generalHours.open, close: _form.generalHours.close, closed: _form.generalHours.closed),
              hours: {for (final e in _form.hours.entries) e.key: _DayHours(open: e.value.open, close: e.value.close, closed: e.value.closed)},
              locationMethod: _form.locationMethod,
              spots: List.from(_form.spots),
            );
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _saved = false);
            });
          }
        }
      },
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _dirty) {
            _showUnsavedBottomSheet(context);
          }
        },
        child: Scaffold(
          backgroundColor: dobar.background,
          body: SafeArea(
            child: ResponsiveCenterContainer(
              maxWidthPercentage: 0.8,
              maxWidth: 1200,
              padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.md),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    height: 64,
                    decoration: BoxDecoration(
                      color: dobar.background,
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _handleBack,
                          child: Icon(LucideIcons.arrowLeft, color: textColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.details_title,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'Courier',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (_dirty) ...[
                          const SizedBox(width: 8),
                          Animate(
                            effects: [
                              ScaleEffect(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1, 1),
                                duration: 300.ms,
                                curve: Curves.easeOut,
                              ),
                            ],
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: barzGold,
                                    shape: BoxShape.circle,
                                  ),
                                ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                                  duration: 1000.ms,
                                  color: barzGold.withValues(alpha: 0.3),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'UNSAVED',
                                  style: TextStyle(
                                    color: barzGold,
                                    fontFamily: 'Courier',
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        GestureDetector(
                          onTap: _dirty && !_saving ? _handleSave : null,
                          child: AnimatedOpacity(
                            opacity: _dirty ? 1.0 : 0.4,
                            duration: 300.ms,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_saving)
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: barzGold,
                                    ),
                                  )
                                else if (_saved)
                                  const Icon(LucideIcons.checkCircle,
                                      color: successGreen, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _saving
                                      ? l10n.details_saving
                                      : (_saved ? l10n.details_saved : l10n.save),
                                  style: TextStyle(
                                    color: _dirty ? barzGold : mutedColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _pickAndUploadImage(isCover: true),
                                child: Container(
                                  height: 176,
                                  decoration: BoxDecoration(
                                    color: dobar.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: _form.coverImageUrl != null
                                      ? Center(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Image.network(_form.coverImageUrl!, fit: BoxFit.cover),
                                                Positioned(
                                                  bottom: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.5),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(LucideIcons.camera, size: 16, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(LucideIcons.camera, size: 36, color: mutedColor),
                                              const SizedBox(height: 4),
                                              Text('COVER PHOTO', style: TextStyle(color: mutedColor, fontFamily: 'Courier', fontSize: 10, letterSpacing: 1)),
                                            ],
                                          ),
                                        ),
                                ),
                              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                              Transform.translate(
                                offset: const Offset(24, -40),
                                child: GestureDetector(
                                  onTap: () => _pickAndUploadImage(isCover: false),
                                  child: Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: dobar.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: borderColor, width: 4),
                                    ),
                                    child: _form.logoUrl != null
                                        ? Center(
                                            child: ClipOval(
                                              child: Image.network(_form.logoUrl!, fit: BoxFit.cover),
                                            ),
                                          )
                                        : Center(
                                            child: Icon(LucideIcons.store, size: 28, color: mutedColor),
                                          ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: 200.ms).scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        _sectionHeader(l10n.basic_info),
                        _buildSection(
                          children: [
                            _fieldLabel(LucideIcons.store, l10n.bar_name),
                            _inputField(
                              value: _form.barName,
                              onChanged: (v) => _form.barName = v,
                              large: true,
                              fieldKey: 'barName',
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel(LucideIcons.fileText, l10n.details_description),
                            TextField(
                              controller: _ctrl('description', _form.description),
                              onChanged: (v) => setState(() => _form.description = v),
                              maxLength: 500,
                              maxLines: 4,
                              style: TextStyle(color: textColor, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: l10n.details_describe_atmosphere,
                                hintStyle: TextStyle(color: mutedColor),
                                filled: true,
                                fillColor: dobar.background,
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: barzGold, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDropdown(
                                    label: l10n.details_category,
                                    icon: LucideIcons.tag,
                                    value: _form.category,
                                    items: const [
                                      'bar', 'restaurant', 'club', 'lounge', 'pub', 'brewery'
                                    ],
                                    displayNames: {
                                      'bar': l10n.category_bar,
                                      'restaurant': l10n.category_restaurant,
                                      'club': l10n.category_club,
                                      'lounge': l10n.category_lounge,
                                      'pub': l10n.category_pub,
                                      'brewery': l10n.category_brewery,
                                    },
                                    onChanged: (v) => setState(() => _form.category = v),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                 Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _fieldLabel(LucideIcons.phone, l10n.phone),
                                      _inputField(
                                        value: _form.phone,
                                        onChanged: (v) => _form.phone = v,
                                        keyboardType: TextInputType.phone,
                                        fieldKey: 'phone',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel(LucideIcons.mail, l10n.email),
                            _inputField(
                              value: _form.email,
                              onChanged: (v) => _form.email = v,
                              keyboardType: TextInputType.emailAddress,
                              fieldKey: 'email',
                            ),
                          ],
                          delay: 50,
                        ),
                        _sectionHeader(l10n.location),
                        _buildSection(
                          children: [
                            _fieldLabel(LucideIcons.mapPin, l10n.address),
                            _inputField(
                              value: _form.address,
                              onChanged: (v) => _form.address = v,
                              fieldKey: 'address',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _fieldLabel(LucideIcons.mapPin, l10n.details_city),
                                      _inputField(
                                        value: _form.city,
                                        onChanged: (v) => _form.city = v,
                                        fieldKey: 'city',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _fieldLabel(LucideIcons.mapPin, l10n.details_state),
                                      _inputField(
                                        value: _form.state,
                                        onChanged: (v) => _form.state = v,
                                        fieldKey: 'state',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel(LucideIcons.globe, l10n.details_country),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: dobar.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _flagEmoji(_form.countryCode),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _form.countryCode,
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontFamily: 'Courier',
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: dobar.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'LAT ${_form.latitude.toStringAsFixed(4)}   LNG ${_form.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontFamily: 'Courier',
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _showMapDialog(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: barzGold.withValues(alpha: 0.1),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(LucideIcons.map,
                                              size: 14, color: barzGold),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.details_pin_on_map,
                                            style: TextStyle(
                                              color: barzGold,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          delay: 100,
                        ),
                        _sectionHeader(l10n.details_business_registration),
                        _buildSection(
                          children: [
                            _fieldLabel(LucideIcons.fileText, l10n.business_id),
                            Row(
                              children: [
                                Expanded(
                                  child: _inputField(
                                    value: _form.businessId,
                                    onChanged: (v) => _form.businessId = v,
                                    fieldKey: 'businessId',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: barzGold.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: barzGold.withValues(alpha: 0.3)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _form.businessIdType,
                                      style: const TextStyle(
                                        color: barzGold,
                                        fontFamily: 'Courier',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel(LucideIcons.scrollText, l10n.details_state_registration),
                            _inputField(
                              value: _form.stateRegistration,
                              onChanged: (v) => _form.stateRegistration = v,
                              fieldKey: 'stateRegistration',
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel(LucideIcons.checkCircle, l10n.details_verification_status),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: verificationBadge.$3,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: verificationBadge.$2.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                verificationBadge.$1,
                                style: TextStyle(
                                  color: verificationBadge.$2,
                                  fontFamily: 'Courier',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                          delay: 150,
                        ),
                        _sectionHeader(l10n.details_media_gallery),
                        _buildSection(
                          children: [
                            SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                itemCount: _form.photoUrls.length + 1,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  if (index < _form.photoUrls.length) {
                                    return _buildPhotoCard(index);
                                  }
                                  return _buildAddPhotoCard();
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(LucideIcons.image,
                                    size: 12, color: mutedColor),
                                const SizedBox(width: 4),
                                Text(
                                  '${_form.photoUrls.length}/6 photos',
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          delay: 200,
                        ),
                        _sectionHeader(l10n.operating_hours),
                        _buildSection(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 10, right: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.details_same_hours,
                                      style: TextStyle(color: textColor, fontSize: 14)),
                                  Switch.adaptive(
                                    value: _form.sameHours,
                                    onChanged: (v) =>
                                        setState(() => _form.sameHours = v),
                                    activeTrackColor: barzGold.withValues(alpha: 0.4),
                                    activeThumbColor: barzGold,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_form.sameHours)
                              _buildGeneralHoursRow()
                            else
                              ...days.map((d) => _buildDayRow(l10n, d.$1)),
                          ],
                          delay: 250,
                        ),
                        _sectionHeader(l10n.details_location_logic),
                        _buildSection(
                          children: [
                            _fieldLabel(LucideIcons.mapPin, l10n.details_location_method),
                            _buildDropdown(
                              label: '',
                              icon: LucideIcons.mapPin,
                              value: _form.locationMethod,
                              items: const [
                                'table_number',
                                'spot_list',
                                'free_text'
                              ],
                              displayNames: {
                                'table_number': l10n.details_method_table,
                                'spot_list': l10n.details_method_spot,
                                'free_text': l10n.details_method_free,
                              },
                              onChanged: (v) =>
                                  setState(() => _form.locationMethod = v),
                            ),
                            const SizedBox(height: 8),
                            if (_form.locationMethod == 'table_number')
                              Text(
                                l10n.details_table_desc,
                                style: TextStyle(color: mutedColor, fontSize: 12),
                              ),
                            if (_form.locationMethod == 'free_text')
                              Text(
                                l10n.details_free_desc,
                                style: TextStyle(color: mutedColor, fontSize: 12),
                              ),
                            if (_form.locationMethod == 'spot_list') ...[
                              ..._form.spots.asMap().entries.map((entry) {
                                final i = entry.key;
                                final spot = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.only(left: 16),
                                  decoration: BoxDecoration(
                                    color: dobar.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(spot,
                                            style: TextStyle(
                                                color: textColor, fontSize: 14)),
                                      ),
                                      IconButton(
                                        icon: Icon(LucideIcons.x,
                                            color: errorRed, size: 16),
                                        onPressed: () => setState(
                                            () => _form.spots.removeAt(i)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: _inputField(
                                        value: _newSpot,
                                        onChanged: (v) => _newSpot = v,
                                        hint: l10n.details_new_spot_hint,
                                        fieldKey: 'newSpot',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      if (_newSpot.trim().isNotEmpty) {
                                        setState(() {
                                          _form.spots.add(_newSpot.trim());
                                          _newSpot = '';
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: barzGold,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(LucideIcons.plus,
                                          color: barzDark, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          delay: 300,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUnsavedBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dobar = context.dobarColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: dobar.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dobar.labelSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.details_discard_title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: dobar.labelPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have unsaved changes that will be lost.',
                style: TextStyle(
                  fontSize: 14,
                  color: dobar.labelSecondary,
                ),
              ),
              const SizedBox(height: 24),
              // Leave & Save
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _handleSave();
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: barzGold,
                    foregroundColor: barzDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Leave & Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Leave & Discard
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: errorRed,
                    side: const BorderSide(color: errorRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Leave & Discard',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Cancel
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(
                      color: dobar.labelSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMapDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dobarColors.surface,
        title: Row(
          children: [
            Icon(LucideIcons.map, size: 18, color: barzGold),
            const SizedBox(width: 8),
            Text(l10n.details_map_title),
          ],
        ),
        content: SizedBox(
          height: 256,
          child: Center(
            child: Text(l10n.details_map_coming_soon,
                style: TextStyle(color: context.dobarColors.labelSecondary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required List<Widget> children,
    required int delay,
  }) {
    final dobar = context.dobarColors;
    final borderColor = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dobar.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    Map<String, String>? displayNames,
    required ValueChanged<String> onChanged,
  }) {
    final dobar = context.dobarColors;
    final borderColor = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) _fieldLabel(icon, label),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: dobar.surface,
          decoration: InputDecoration(
            filled: true,
            fillColor: dobar.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: barzGold, width: 2),
            ),
          ),
          style: TextStyle(
            color: dobar.labelPrimary,
            fontSize: 14,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                displayNames?[item] ?? item,
                style: TextStyle(
                  color: dobar.labelPrimary,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _buildPhotoCard(int index) {
    final dobar = context.dobarColors;
    final borderColor = Theme.of(context).colorScheme.outline;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: dobar.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: const Center(
              child: Icon(LucideIcons.image, size: 32),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _form.photoUrls.removeAt(index)),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: dobar.background.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.x, size: 14, color: errorRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoCard() {
    final l10n = AppLocalizations.of(context)!;
    final borderColor = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: () {
        if (_form.photoUrls.length < 6) {
          setState(() =>
              _form.photoUrls.add('https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/240'));
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 2, strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, size: 20, color: borderColor),
            const SizedBox(height: 4),
            Text(
              l10n.details_add_photo,
              style: TextStyle(
                color: borderColor,
                fontFamily: 'Courier',
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralHoursRow() {
    final l10n = AppLocalizations.of(context)!;
    final dobar = context.dobarColors;
    final borderColor = Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dobar.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.clock, size: 14, color: barzGold),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.general_hours,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          _buildTimePicker(
            _form.generalHours.open,
            (v) => setState(() => _form.generalHours.open = v),
          ),
          const SizedBox(width: 8),
          _buildTimePicker(
            _form.generalHours.close,
            (v) => setState(() => _form.generalHours.close = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(AppLocalizations l10n, String key) {
    final dobar = context.dobarColors;
    final borderColor = Theme.of(context).colorScheme.outline;
    final day = _form.hours[key]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dobar.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Opacity(
        opacity: day.closed ? 0.5 : 1.0,
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(_getDayName(l10n, key),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Expanded(
              child: _buildTimePicker(
                day.open,
                (v) => setState(() {
                  _form.hours[key]!.open = v;
                }),
                enabled: !day.closed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTimePicker(
                day.close,
                (v) => setState(() {
                  _form.hours[key]!.close = v;
                }),
                enabled: !day.closed,
              ),
            ),
            const SizedBox(width: 8),
            if (day.closed)
              Text(l10n.closed.toUpperCase(),
                  style: TextStyle(
                    color: errorRed,
                    fontFamily: 'Courier',
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  )),
            Switch.adaptive(
              value: day.closed,
              onChanged: (v) => setState(() {
                _form.hours[key]!.closed = v;
              }),
              activeTrackColor: errorRed.withValues(alpha: 0.4),
              activeThumbColor: errorRed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String time, ValueChanged<String> onChanged,
      {bool enabled = true}) {
    final dobar = context.dobarColors;
    final borderColor = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: enabled
          ? () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.tryParse(time.split(':')[0]) ?? 18,
                  minute: int.tryParse(time.split(':')[1]) ?? 0,
                ),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: barzGold,
                        onPrimary: barzDark,
                        surface: dobar.surface,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                onChanged(
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
              }
            }
          : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: dobar.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clock, size: 12, color: barzGold),
            const SizedBox(width: 6),
            Text(
              time,
              style: TextStyle(
                color: dobar.labelPrimary,
                fontFamily: 'Courier',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}