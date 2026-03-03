import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';
import '../widgets/wizard_footer.dart';

class PhotosStep extends StatefulWidget {
  final CreateBarFormData formData;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PhotosStep({
    super.key,
    required this.formData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends State<PhotosStep> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Expanded(
          child: ResponsiveCenterContainer(
            maxWidth: 720,
            minWidth: 320,
            maxWidthPercentage: 0.6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BarzSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhotoSection(
                    title: l10n.bar_logo,
                    subtitle: l10n.bar_logo_hint,
                    icon: Icons.storefront_rounded,
                    imagePath: widget.formData.logoPath,
                    onTap: () => _pickImage(ImageType.logo),
                    aspectRatio: 1,
                  ),
                  const SizedBox(height: BarzSpacing.xl),
                  _buildPhotoSection(
                    title: l10n.cover_photo,
                    subtitle: l10n.cover_photo_hint,
                    icon: Icons.panorama_rounded,
                    imagePath: widget.formData.coverPath,
                    onTap: () => _pickImage(ImageType.cover),
                    aspectRatio: 16 / 9,
                  ),
                  const SizedBox(height: BarzSpacing.xl),
                  _buildSectionHeader(
                    l10n.gallery_photos,
                    Icons.photo_library_rounded,
                  ),
                  const SizedBox(height: BarzSpacing.sm),
                  Text(
                    l10n.gallery_photos_hint,
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: BarzSpacing.md),
                  _buildGalleryGrid(),
                ],
              ),
            ),
          ),
        ),
        WizardFooter(
          onBack: widget.onBack,
          onNext: widget.onNext,
          topWidget: Text(
            l10n.photos_optional,
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: barzGold, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? imagePath,
    required VoidCallback onTap,
    required double aspectRatio,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, icon),
        const SizedBox(height: BarzSpacing.xs),
        Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 14)),
        const SizedBox(height: BarzSpacing.md),
        GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: surfaceMuted,
                borderRadius: BorderRadius.circular(BarzRadii.md),
                border: Border.all(
                  color: surfaceDim,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(BarzRadii.md - 2),
                      child: Image.asset(imagePath, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_rounded,
                          size: 48,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add',
                          style: TextStyle(color: textSecondary),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryGrid() {
    final photos = widget.formData.photoPaths;
    final itemCount = photos.length + 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount > 6 ? 6 : itemCount,
      itemBuilder: (context, index) {
        if (index == photos.length) {
          return GestureDetector(
            onTap: () => _pickImage(ImageType.gallery),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceMuted,
                borderRadius: BorderRadius.circular(BarzRadii.sm),
                border: Border.all(color: surfaceDim),
              ),
              child: Icon(Icons.add, size: 32, color: textSecondary),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: surfaceMuted,
            borderRadius: BorderRadius.circular(BarzRadii.sm),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(BarzRadii.sm),
                child: Image.asset(photos[index], fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removePhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: errorRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickImage(ImageType type) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Image picker coming soon')));
  }

  void _removePhoto(int index) {
    setState(() => widget.formData.photoPaths.removeAt(index));
  }
}

enum ImageType { logo, cover, gallery }
