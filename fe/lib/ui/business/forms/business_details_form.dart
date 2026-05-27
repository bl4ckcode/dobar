import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  _DayHours({this.open = '18:00', this.close = '02:00', this.closed = false});
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

  _FormData({
    this.barName = 'The Iron Draught',
    this.description =
        'An industrial-modern speakeasy with a curated craft beer selection.',
    this.category = 'bar',
    this.phone = '+55 11 99999-0000',
    this.email = 'contact@irondraught.com',
    this.address = 'Av. Paulista, 1500',
    this.city = 'São Paulo',
    this.state = 'SP',
    this.countryCode = 'BR',
    this.latitude = -23.561,
    this.longitude = -46.656,
    this.businessId = '12.345.678/0001-90',
    this.businessIdType = 'CNPJ',
    this.stateRegistration = '123.456.789.000',
    this.verification = 'verified',
    this.photoUrls = const [],
    this.sameHours = false,
    _DayHours? generalHours,
    Map<String, _DayHours>? hours,
    this.locationMethod = 'table_number',
    List<String>? spots,
  })  : generalHours = generalHours ?? _DayHours(),
        hours = hours ??
            {
              for (final d in days)
                d.$1: _DayHours(closed: d.$1 == 'sun'),
            },
        spots = spots ?? ['VIP Area', 'Terrace', 'Counter'];
}

class BusinessDetailsForm extends StatefulWidget {
  const BusinessDetailsForm({super.key});

  @override
  State<BusinessDetailsForm> createState() => _BusinessDetailsFormState();
}

class _BusinessDetailsFormState extends State<BusinessDetailsForm> {
  late _FormData _form;
  late _FormData _initial;
  bool _saving = false;
  bool _saved = false;
  String _newSpot = '';

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
      _form.locationMethod != _initial.locationMethod;

  @override
  void initState() {
    super.initState();
    _form = _FormData();
    _initial = _FormData();
  }

  void _handleBack() {
    if (_dirty) {
      _showDiscardDialog(context);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Business details updated successfully!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: successGreen,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _saved = false);
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
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 12),
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
  }) {
    final dobar = context.dobarColors;
    final theme = Theme.of(context);
    return TextField(
      controller: TextEditingController(text: value),
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

    final verificationBadge = switch (_form.verification) {
      'verified' => ('Verified', successGreen, successGreen.withValues(alpha: 0.15)),
      'pending' => ('Pending Review', barzGold, barzGold.withValues(alpha: 0.15)),
      'rejected' => ('Rejected', errorRed, errorRed.withValues(alpha: 0.15)),
      _ => ('Not Submitted', mutedColor, borderColor),
    };

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dirty) {
          _showDiscardDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: dobar.background,
        body: SafeArea(
          child: Column(
            children: [
              // HEADER
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
                      'BUSINESS DETAILS',
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
                                  ? 'Saving'
                                  : (_saved ? 'Saved' : 'Save'),
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

              // BODY
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    // HERO IMAGES
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 176,
                            decoration: BoxDecoration(
                              color: dobar.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Center(
                              child: Icon(LucideIcons.camera,
                                  size: 36, color: mutedColor),
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                          Transform.translate(
                            offset: const Offset(24, -40),
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: dobar.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: 4),
                              ),
                              child: Center(
                                child: Icon(LucideIcons.store,
                                    size: 28, color: mutedColor),
                              ),
                            ),
                          ).animate().fadeIn(delay: 200.ms).scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),

                    // BASIC INFORMATION
                    _sectionHeader('Basic Information'),
                    _buildSection(
                      children: [
                        _fieldLabel(LucideIcons.store, 'Bar Name'),
                        _inputField(
                          value: _form.barName,
                          onChanged: (v) => _form.barName = v,
                          large: true,
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel(LucideIcons.fileText, 'Description'),
                        TextField(
                          controller: TextEditingController(text: _form.description),
                          onChanged: (v) => setState(() => _form.description = v),
                          maxLength: 500,
                          maxLines: 4,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Describe your bar's atmosphere...",
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
                                label: 'Category',
                                icon: LucideIcons.tag,
                                value: _form.category,
                                items: const [
                                  'bar', 'restaurant', 'club', 'lounge', 'pub', 'brewery'
                                ],
                                onChanged: (v) => setState(() => _form.category = v),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel(LucideIcons.phone, 'Phone'),
                                  _inputField(
                                    value: _form.phone,
                                    onChanged: (v) => _form.phone = v,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel(LucideIcons.mail, 'Email'),
                        _inputField(
                          value: _form.email,
                          onChanged: (v) => _form.email = v,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                      delay: 50,
                    ),

                    // LOCATION
                    _sectionHeader('Location'),
                    _buildSection(
                      children: [
                        _fieldLabel(LucideIcons.mapPin, 'Address'),
                        _inputField(
                          value: _form.address,
                          onChanged: (v) => _form.address = v,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel(LucideIcons.mapPin, 'City'),
                                  _inputField(
                                    value: _form.city,
                                    onChanged: (v) => _form.city = v,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel(LucideIcons.mapPin, 'State'),
                                  _inputField(
                                    value: _form.state,
                                    onChanged: (v) => _form.state = v,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel(LucideIcons.globe, 'Country'),
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
                                        'PIN ON MAP',
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

                    // BUSINESS REGISTRATION
                    _sectionHeader('Business Registration'),
                    _buildSection(
                      children: [
                        _fieldLabel(LucideIcons.fileText, 'Business ID'),
                        Row(
                          children: [
                            Expanded(
                              child: _inputField(
                                value: _form.businessId,
                                onChanged: (v) => _form.businessId = v,
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
                        _fieldLabel(LucideIcons.scrollText, 'State Registration'),
                        _inputField(
                          value: _form.stateRegistration,
                          onChanged: (v) => _form.stateRegistration = v,
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel(LucideIcons.checkCircle, 'Verification Status'),
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

                    // MEDIA GALLERY
                    _sectionHeader('Media Gallery'),
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

                    // OPERATING HOURS
                    _sectionHeader('Operating Hours'),
                    _buildSection(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Same hours every day',
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
                        const SizedBox(height: 12),
                        if (_form.sameHours)
                          _buildGeneralHoursRow()
                        else
                          ...days.map((d) => _buildDayRow(d.$1, d.$2)),
                      ],
                      delay: 250,
                    ),

                    // PLACE LOCATION LOGIC
                    _sectionHeader('Place Location Logic'),
                    _buildSection(
                      children: [
                        _fieldLabel(LucideIcons.mapPin, 'Location Method'),
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
                            'table_number': 'Table Number',
                            'spot_list': 'Spot List',
                            'free_text': 'Free Text',
                          },
                          onChanged: (v) =>
                              setState(() => _form.locationMethod = v),
                        ),
                        const SizedBox(height: 8),
                        if (_form.locationMethod == 'table_number')
                          Text(
                            'Customers enter their table number manually.',
                            style: TextStyle(color: mutedColor, fontSize: 12),
                          ),
                        if (_form.locationMethod == 'free_text')
                          Text(
                            'Customers describe where they are sitting.',
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
                                    hint: 'New spot name',
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
    );
  }

  void _showDiscardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dobarColors.surface,
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: context.dobarColors.labelSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: errorRed),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _showMapDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dobarColors.surface,
        title: Row(
          children: [
            Icon(LucideIcons.map, size: 18, color: barzGold),
            const SizedBox(width: 8),
            const Text('Pin on Map'),
          ],
        ),
        content: SizedBox(
          height: 256,
          child: Center(
            child: Text('Map integration coming soon',
                style: TextStyle(color: context.dobarColors.labelSecondary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
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
          value: value,
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
              'ADD PHOTO',
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
          const Expanded(child: Text('General Hours',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
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

  Widget _buildDayRow(String key, String label) {
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
              child: Text(label,
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
              Text('CLOSED',
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