import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';

class ReviewStep extends StatelessWidget {
  final CreateBarFormData formData;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool isLoading;

  const ReviewStep({
    super.key,
    required this.formData,
    required this.onBack,
    required this.onSubmit,
    this.isLoading = false,
  });

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
                const SizedBox(height: BarzSpacing.lg),
                _buildSection(
                  icon: Icons.store_rounded,
                  title: l10n.basic_info,
                  children: [
                    _buildInfoRow(l10n.bar_name, formData.name),
                    _buildInfoRow(l10n.address, formData.address),
                    _buildInfoRow(l10n.phone, formData.phone),
                    _buildInfoRow(l10n.email, formData.email),
                  ],
                ),
                const SizedBox(height: BarzSpacing.md),
                _buildSection(
                  icon: Icons.location_on_rounded,
                  title: l10n.location,
                  children: [
                    if (formData.latitude != null && formData.longitude != null)
                      _buildInfoRow(
                        l10n.coordinates,
                        '${formData.latitude!.toStringAsFixed(4)}, ${formData.longitude!.toStringAsFixed(4)}',
                      )
                    else
                      _buildWarning(l10n.location_not_set),
                  ],
                ),
                const SizedBox(height: BarzSpacing.md),
                _buildSection(
                  icon: Icons.photo_library_rounded,
                  title: l10n.photos,
                  children: [
                    _buildPhotoStatus(l10n.bar_logo, formData.logoPath != null),
                    _buildPhotoStatus(l10n.cover_photo, formData.coverPath != null),
                    _buildPhotoStatus(
                      l10n.gallery_photos,
                      formData.photoPaths.isNotEmpty,
                      count: formData.photoPaths.length,
                    ),
                  ],
                ),
                const SizedBox(height: BarzSpacing.md),
                _buildSection(
                  icon: Icons.schedule_rounded,
                  title: l10n.operating_hours,
                  children: _buildHoursList(context, l10n),
                ),
              ],
            ),
          ),
        ),
        _buildBottomButtons(context, l10n),
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
          Icon(Icons.check_circle_rounded, color: barzGold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.review_info,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.review_info_hint,
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: surfaceDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: barzDark, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? '-' : value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isEmpty ? textSecondary : textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BarzRadii.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: errorRed, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStatus(String label, bool hasPhoto, {int count = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            hasPhoto ? Icons.check_circle : Icons.cancel,
            color: hasPhoto ? barzGold : textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            count > 0 ? '$label ($count)' : label,
            style: TextStyle(
              color: hasPhoto ? textPrimary : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHoursList(BuildContext context, AppLocalizations l10n) {
    final dayLabels = {
      'monday': l10n.monday,
      'tuesday': l10n.tuesday,
      'wednesday': l10n.wednesday,
      'thursday': l10n.thursday,
      'friday': l10n.friday,
      'saturday': l10n.saturday,
      'sunday': l10n.sunday,
    };

    return formData.operatingHours.entries.map((entry) {
      final hours = entry.value;
      final dayName = dayLabels[entry.key] ?? entry.key;
      
      if (!hours.isOpen) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(width: 100, child: Text(dayName, style: TextStyle(color: textSecondary))),
              Text(l10n.closed, style: TextStyle(color: textSecondary)),
            ],
          ),
        );
      }

      final open = hours.openTime?.format(context) ?? '--:--';
      final close = hours.closeTime?.format(context) ?? '--:--';

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(dayName)),
            Text('$open - $close', style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildBottomButtons(BuildContext context, AppLocalizations l10n) {
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
              onPressed: isLoading ? null : onBack,
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
            flex: 2,
            child: FilledButton(
              onPressed: isLoading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: barzGold,
                foregroundColor: barzDark,
                padding: const EdgeInsets.all(16),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.create_bar),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
