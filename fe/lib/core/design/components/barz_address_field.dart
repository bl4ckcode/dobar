import 'package:flutter/material.dart';
import 'package:google_places_api_flutter/google_places_api_flutter.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

/// Place details returned after selection
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

  String get formattedAddress => description;

  /// Create PlaceDetails from the package's types
  factory PlaceDetails.fromGooglePlace(Prediction prediction, PlaceDetailsModel? details) {
    String? streetNumber;
    String? route;
    String? city;
    String? state;
    String? postalCode;
    String? country;
    String? countryCode;
    double? lat;
    double? lng;

    if (details != null) {
      final result = details.result;

      // Parse geometry
      if (result.geometry != null) {
        lat = result.geometry!.location.lat;
        lng = result.geometry!.location.lng;
      }

      // Parse address components
      final components = result.address_components;
      if (components != null) {
        for (final component in components) {
          final types = component.types ?? [];

          if (types.contains('street_number')) {
            streetNumber = component.long_name;
          } else if (types.contains('route')) {
            route = component.long_name;
          } else if (types.contains('locality')) {
            city = component.long_name;
          } else if (types.contains('administrative_area_level_1')) {
            state = component.short_name;
          } else if (types.contains('postal_code')) {
            postalCode = component.long_name;
          } else if (types.contains('country')) {
            country = component.long_name;
            countryCode = component.short_name;
          }
        }
      }
    }

    return PlaceDetails(
      description: details?.result.formatted_address ?? prediction.description,
      placeId: prediction.place_id,
      latitude: lat,
      longitude: lng,
      streetNumber: streetNumber,
      route: route,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      countryCode: countryCode,
    );
  }
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
        PlaceSearchField(
          apiKey: widget.googleApiKey,
          controller: _controller,
          isLatLongRequired: widget.isLatLngRequired,
          onPlaceSelected: (prediction, details) {
            widget.onPlaceSelected?.call(
              PlaceDetails.fromGooglePlace(prediction, details),
            );
          },
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: widget.enabled ? textPrimary : textTertiary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.enabled ? barzGoldMuted : surfaceMuted,
                hintText: widget.hintText,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: textTertiary,
                ),
                prefixIcon:
                    const Icon(Icons.location_on_outlined, color: textSecondary),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: textSecondary),
                        onPressed: () {
                          controller.clear();
                        },
                      )
                    : null,
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
            );
          },
          decorationBuilder: (context, child) {
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(BarzRadii.md),
              color: surfaceWhite,
              child: child,
            );
          },
          itemBuilder: (context, prediction) => Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: barzGold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prediction.description,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
