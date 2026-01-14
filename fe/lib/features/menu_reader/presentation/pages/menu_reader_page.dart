import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/spacing.dart';
import 'package:barz/core/design/tokens/radii.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_event.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_state.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_extraction_results_page.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class MenuReaderPage extends StatefulWidget {
  final int barId;
  final int menuId;

  const MenuReaderPage({
    super.key,
    required this.barId,
    required this.menuId,
  });

  @override
  State<MenuReaderPage> createState() => _MenuReaderPageState();
}

class _MenuReaderPageState extends State<MenuReaderPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MenuReaderBloc, MenuReaderState>(
      listener: (context, state) {
        if (state.status == MenuReaderStatus.extracted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<MenuReaderBloc>(),
                child: MenuExtractionResultsPage(menuId: widget.menuId),
              ),
            ),
          );
        } else if (state.status == MenuReaderStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Failed to extract menu'),
              backgroundColor: errorRed,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: barzGoldSoft,
          appBar: AppBar(
            title: const Text('Menu Reader AI'),
            backgroundColor: barzGoldSoft,
            elevation: 0,
          ),
          body: state.status == MenuReaderStatus.extracting
              ? _buildLoadingState()
              : _buildInitialState(context),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(
            color: barzGold,
            size: 60,
          ),
          const SizedBox(height: BarzSpacing.lg),
          Text(
            'Analyzing your menu...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: textSecondary,
            ),
          ),
          const SizedBox(height: BarzSpacing.sm),
          Text(
            'This may take a few seconds',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BarzSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: BarzSpacing.xl),
          if (_selectedImage != null) ...[
            _buildImagePreview(),
            const SizedBox(height: BarzSpacing.lg),
            _buildAnalyzeButton(context),
            const SizedBox(height: BarzSpacing.md),
            _buildRetakeButton(),
          ] else ...[
            _buildCameraOption(context),
            const SizedBox(height: BarzSpacing.md),
            _buildGalleryOption(context),
          ],
          const SizedBox(height: BarzSpacing.xl),
          _buildTips(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(BarzSpacing.lg),
          decoration: BoxDecoration(
            color: barzGold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.document_scanner_rounded,
            size: 64,
            color: barzGold,
          ),
        ),
        const SizedBox(height: BarzSpacing.lg),
        Text(
          'Scan Your Menu',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: BarzSpacing.sm),
        Text(
          'Take a photo of your physical menu and our AI will extract all items automatically',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BarzRadii.lg),
      child: Image.file(
        _selectedImage!,
        height: 300,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildAnalyzeButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        context.read<MenuReaderBloc>().add(
          ExtractMenuFromImage(
            imageFile: _selectedImage!,
            barId: widget.barId,
            languageHint: 'pt-BR',
          ),
        );
      },
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Analyze Menu'),
      style: ElevatedButton.styleFrom(
        backgroundColor: barzGold,
        foregroundColor: barzDark,
        padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BarzRadii.md),
        ),
      ),
    );
  }

  Widget _buildRetakeButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _selectedImage = null),
      icon: const Icon(Icons.refresh),
      label: const Text('Choose Different Photo'),
      style: OutlinedButton.styleFrom(
        foregroundColor: textSecondary,
        side: const BorderSide(color: textTertiary),
        padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BarzRadii.md),
        ),
      ),
    );
  }

  Widget _buildCameraOption(BuildContext context) {
    return _buildOptionCard(
      icon: Icons.camera_alt_rounded,
      title: 'Take Photo',
      subtitle: 'Use your camera to capture the menu',
      onTap: () => _pickImage(ImageSource.camera),
    );
  }

  Widget _buildGalleryOption(BuildContext context) {
    return _buildOptionCard(
      icon: Icons.photo_library_rounded,
      title: 'Choose from Gallery',
      subtitle: 'Select an existing photo of your menu',
      onTap: () => _pickImage(ImageSource.gallery),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: surfaceWhite,
      borderRadius: BorderRadius.circular(BarzRadii.lg),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BarzRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(BarzSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(BarzSpacing.md),
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(BarzRadii.md),
                ),
                child: Icon(icon, color: barzGold, size: 32),
              ),
              const SizedBox(width: BarzSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(BarzSpacing.md),
      decoration: BoxDecoration(
        color: infoBlueLight,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: infoBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: infoBlue, size: 20),
              const SizedBox(width: BarzSpacing.sm),
              Text(
                'Tips for best results',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: infoBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: BarzSpacing.sm),
          _buildTipItem('Good lighting - avoid shadows'),
          _buildTipItem('Keep the menu flat and in focus'),
          _buildTipItem('Capture the entire menu in frame'),
          _buildTipItem('Avoid glare from laminated menus'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: infoBlue)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: errorRed,
          ),
        );
      }
    }
  }
}
