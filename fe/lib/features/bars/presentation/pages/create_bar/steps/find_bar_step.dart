import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';

class FindBarStep extends StatefulWidget {
  final CreateBarFormData formData;
  final VoidCallback onNext;

  const FindBarStep({
    super.key,
    required this.formData,
    required this.onNext,
  });

  @override
  State<FindBarStep> createState() => _FindBarStepState();
}

class _FindBarStepState extends State<FindBarStep> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BarzSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(l10n),
                const SizedBox(height: BarzSpacing.xl),
                _buildSearchSection(l10n),
                const SizedBox(height: BarzSpacing.lg),
                if (widget.formData.address.isNotEmpty) _buildSelectedPlace(l10n),
                const SizedBox(height: BarzSpacing.lg),
                _buildManualEntryToggle(l10n),
              ],
            ),
          ),
        ),
        _buildBottomButton(l10n),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: barzGoldSoft,
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: barzGold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.find_your_bar,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.find_bar_hint,
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.store_rounded, color: barzGold, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.search_bar_name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: BarzSpacing.sm),
        // BarzAddressField uses our secure backend proxy
        BarzAddressField(
          hintText: l10n.search_bar_hint,
          countries: ['br', 'pt', 'us', 'es', 'mx', 'ar'],
          onPlaceSelected: (details) {
            setState(() {
              widget.formData.name = _extractBarName(details.description);
              widget.formData.address = details.description;
              widget.formData.latitude = details.latitude;
              widget.formData.longitude = details.longitude;
              widget.formData.countryCode = details.countryCode ?? 'BR';
            });
          },
        ),
      ],
    );
  }

  String _extractBarName(String description) {
    final parts = description.split(',');
    return parts.isNotEmpty ? parts.first.trim() : '';
  }

  Widget _buildSelectedPlace(AppLocalizations l10n) {
    final config = CountryFormConfig.forCountry(widget.formData.countryCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: barzGold, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: barzGold, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.bar_found,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoTile(Icons.store, widget.formData.name.isEmpty ? '-' : widget.formData.name),
          _buildInfoTile(Icons.location_on, widget.formData.address),
          if (widget.formData.latitude != null && widget.formData.longitude != null)
            _buildInfoTile(
              Icons.pin_drop,
              '${widget.formData.latitude!.toStringAsFixed(4)}, ${widget.formData.longitude!.toStringAsFixed(4)}',
            ),
          _buildInfoTile(Icons.flag, '${config.name} (${config.currency})'),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryToggle(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: barzGoldMuted, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_rounded, color: barzDark.withValues(alpha: 0.5), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.cant_find_bar,
              style: TextStyle(color: barzDark.withValues(alpha: 0.6), fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                widget.formData.countryCode = 'BR';
              });
              widget.onNext();
            },
            style: TextButton.styleFrom(
              backgroundColor: barzGoldMuted,
              foregroundColor: barzDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              l10n.enter_manually,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(AppLocalizations l10n) {
    final isValid = widget.formData.address.isNotEmpty;

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
      child: FilledButton(
        onPressed: isValid ? widget.onNext : null,
        style: FilledButton.styleFrom(
          backgroundColor: barzGold,
          foregroundColor: barzDark,
          disabledBackgroundColor: surfaceDim,
          padding: const EdgeInsets.all(16),
          minimumSize: const Size(double.infinity, 56),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.continue_with_bar,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }
}
