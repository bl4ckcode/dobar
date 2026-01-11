import 'dart:async';
import 'package:flutter/material.dart';
import 'package:barz/core/services/places_service.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

class PlaceDetails {
  final String description;
  final String? name;
  final String? placeId;
  final double? latitude;
  final double? longitude;
  final String? streetNumber;
  final String? route;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? countryCode;

  PlaceDetails({
    required this.description,
    this.name,
    this.placeId,
    this.latitude,
    this.longitude,
    this.streetNumber,
    this.route,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.countryCode,
  });

  String get formattedAddress => description;

  /// Returns the place name if available, otherwise extracts from description
  String get displayName => name ?? description.split(',').first.trim();

  factory PlaceDetails.fromParsed(ParsedPlaceDetails parsed) {
    return PlaceDetails(
      description: parsed.address,
      name: parsed.name.isNotEmpty ? parsed.name : null,
      placeId: parsed.placeId,
      latitude: parsed.latitude,
      longitude: parsed.longitude,
      city: parsed.city,
      state: parsed.state,
      postalCode: parsed.postalCode,
      countryCode: parsed.countryCode,
    );
  }
}

class BarzAddressField extends StatefulWidget {
  final String? label;
  final String hintText;
  final bool enabled;
  final String? initialValue;
  final ValueChanged<PlaceDetails>? onPlaceSelected;
  final ValueChanged<String>? onChanged;
  final List<String>? countries;
  final FocusNode? focusNode;
  final int debounceTime;

  const BarzAddressField({
    super.key,
    this.label,
    this.hintText = '',
    this.enabled = true,
    this.initialValue,
    this.onPlaceSelected,
    this.onChanged,
    this.countries,
    this.focusNode,
    this.debounceTime = 600,
  });

  @override
  State<BarzAddressField> createState() => _BarzAddressFieldState();
}

class _BarzAddressFieldState extends State<BarzAddressField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<PlacePrediction> _predictions = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isSelecting) _removeOverlay();
      });
    }
  }

  void _onTextChanged() {
    if (_isSelecting) return;
    widget.onChanged?.call(_controller.text);
    _debounce?.cancel();
    if (_controller.text.length < 3) {
      _removeOverlay();
      return;
    }
    _debounce = Timer(Duration(milliseconds: widget.debounceTime), _search);
  }

  Future<void> _search() async {
    final query = _controller.text;
    if (query.length < 3) return;

    setState(() => _isLoading = true);
    final results = await PlacesService.autocomplete(
      query,
      countries: widget.countries,
    );
    
    if (mounted && _controller.text == query) {
      setState(() {
        _predictions = results;
        _isLoading = false;
      });
      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (context) => _buildOverlay());
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay() {
    final renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 300;
    
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 60),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(BarzRadii.md),
          color: surfaceWhite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return InkWell(
                  onTap: () => _selectPlace(prediction),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: barzGold, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.mainText,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (prediction.secondaryText.isNotEmpty)
                                Text(
                                  prediction.secondaryText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    _isSelecting = true;
    _removeOverlay();
    _controller.text = prediction.description;
    
    final details = await PlacesService.getDetails(prediction.placeId);
    if (details != null && widget.onPlaceSelected != null) {
      widget.onPlaceSelected!(PlaceDetails.fromParsed(details));
    }
    _isSelecting = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            key: _textFieldKey,
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: widget.enabled ? textPrimary : textTertiary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: widget.enabled ? barzGoldMuted : surfaceMuted,
              hintText: widget.hintText,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(color: textTertiary),
              prefixIcon: const Icon(Icons.location_on_outlined, color: textSecondary),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: barzGold),
                      ),
                    )
                  : _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: textSecondary),
                          onPressed: () {
                            _controller.clear();
                            _removeOverlay();
                          },
                        )
                      : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: const BorderSide(color: barzGold, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
