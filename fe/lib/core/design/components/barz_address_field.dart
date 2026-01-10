import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

class PlaceDetails {
  final String description;
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

  factory PlaceDetails.fromPrediction(Prediction prediction) {
    return PlaceDetails(
      description: prediction.description ?? '',
      placeId: prediction.placeId,
      latitude: prediction.lat != null ? double.tryParse(prediction.lat!) : null,
      longitude: prediction.lng != null ? double.tryParse(prediction.lng!) : null,
    );
  }

  String get formattedAddress => description;
}

class BarzAddressField extends StatefulWidget {
  final String? label;
  final String hintText;
  final String googleApiKey;
  final bool enabled;
  final String? initialValue;
  final ValueChanged<PlaceDetails>? onPlaceSelected;
  final ValueChanged<String>? onChanged;
  final List<String>? countries;
  final FocusNode? focusNode;
  final int debounceTime;
  final bool isLatLngRequired;

  const BarzAddressField({
    super.key,
    this.label,
    this.hintText = '',
    required this.googleApiKey,
    this.enabled = true,
    this.initialValue,
    this.onPlaceSelected,
    this.onChanged,
    this.countries,
    this.focusNode,
    this.debounceTime = 600,
    this.isLatLngRequired = true,
  });

  @override
  State<BarzAddressField> createState() => _BarzAddressFieldState();
}

class _BarzAddressFieldState extends State<BarzAddressField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        GooglePlaceAutoCompleteTextField(
          textEditingController: _controller,
          googleAPIKey: widget.googleApiKey,
          debounceTime: widget.debounceTime,
          countries: widget.countries,
          isLatLngRequired: widget.isLatLngRequired,
          focusNode: widget.focusNode,
          isCrossBtnShown: true,
          inputDecoration: InputDecoration(
            filled: true,
            fillColor: widget.enabled ? barzGoldMuted : surfaceMuted,
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: textTertiary,
            ),
            prefixIcon: Icon(Icons.location_on_outlined, color: textSecondary),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
          textStyle: theme.textTheme.bodyLarge?.copyWith(
            color: widget.enabled ? textPrimary : textTertiary,
          ) ?? const TextStyle(),
          getPlaceDetailWithLatLng: (prediction) {
            final details = PlaceDetails.fromPrediction(prediction);
            widget.onPlaceSelected?.call(details);
          },
          itemClick: (prediction) {
            _controller.text = prediction.description ?? '';
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
            widget.onChanged?.call(_controller.text);
          },
          itemBuilder: (context, index, prediction) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: barzGold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      prediction.description ?? '',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
          seperatedBuilder: Divider(height: 1, color: surfaceDim),
        ),
      ],
    );
  }
}
