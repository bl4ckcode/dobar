import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/location_handler.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';

class LocationStep extends StatefulWidget {
  final CreateBarFormData formData;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const LocationStep({
    super.key,
    required this.formData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (widget.formData.latitude != null && widget.formData.longitude != null) {
      setState(() {
        _selectedLocation = LatLng(
          widget.formData.latitude!,
          widget.formData.longitude!,
        );
        _isLoading = false;
      });
      return;
    }

    try {
      if (await requestLocationPermission()) {
        final location = await Location().getLocation();
        if (mounted) {
          setState(() {
            _selectedLocation = LatLng(
              location.latitude ?? -23.5505,
              location.longitude ?? -46.6333,
            );
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _selectedLocation = const LatLng(-23.5505, -46.6333);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _selectedLocation = const LatLng(-23.5505, -46.6333);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: barzGold))
              else
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation!,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: _onMapTap,
                  markers: _selectedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('bar_location'),
                            position: _selectedLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueYellow,
                            ),
                          ),
                        }
                      : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(BarzRadii.md),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: barzGold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.tap_to_select_location,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedLocation != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: barzDark,
                      borderRadius: BorderRadius.circular(BarzRadii.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: barzGold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildBottomButtons(l10n),
      ],
    );
  }

  Widget _buildBottomButtons(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: const BorderSide(color: barzDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.back),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _selectedLocation != null ? _onNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: barzDark,
                padding: const EdgeInsets.all(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.next),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng position) {
    setState(() => _selectedLocation = position);
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _onNext() {
    if (_selectedLocation != null) {
      widget.formData.latitude = _selectedLocation!.latitude;
      widget.formData.longitude = _selectedLocation!.longitude;
      widget.onNext();
    }
  }
}
