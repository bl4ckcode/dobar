import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/spacing.dart';
import 'package:barz/core/design/tokens/radii.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_event.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_state.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_extraction_results_page.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class MenuReaderPage extends StatefulWidget {
  final int barId;
  final int menuId;

  const MenuReaderPage({super.key, required this.barId, required this.menuId});

  @override
  State<MenuReaderPage> createState() => _MenuReaderPageState();
}

class _MenuReaderPageState extends State<MenuReaderPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _urlController = TextEditingController();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _showUrlInput = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MenuReaderBloc, MenuReaderState>(
      listener: (context, state) async {
        if (state.status == MenuReaderStatus.extracted) {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<MenuReaderBloc>(),
                child: MenuExtractionResultsPage(barId: widget.barId),
              ),
            ),
          );
          if (saved == true && context.mounted) {
            Navigator.of(context).pop(true);
          }
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
        return Container(
          color: barzGoldSoft,
          child: Column(
            children: [
              _buildToolbar(context),
              Expanded(
                child: state.status == MenuReaderStatus.extracting
                    ? _buildLoadingState()
                    : _buildInitialState(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      color: barzGoldSoft,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoute.businessMenu.path),
          ),
          const Expanded(
            child: Text(
              'Menu Reader AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(color: barzGold, size: 60),
          const SizedBox(height: BarzSpacing.lg),
          Text(
            'Analyzing your menu...',
            style: theme.textTheme.titleMedium?.copyWith(color: textSecondary),
          ),
          const SizedBox(height: BarzSpacing.sm),
          Text(
            'This may take a few seconds',
            style: theme.textTheme.bodyMedium?.copyWith(color: textTertiary),
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
          if (_selectedImageBytes != null) ...[
            _buildImagePreview(),
            const SizedBox(height: BarzSpacing.lg),
            _buildAnalyzeButton(context),
            const SizedBox(height: BarzSpacing.md),
            _buildRetakeButton(),
          ] else if (_showUrlInput) ...[
            _buildUrlInput(context),
            const SizedBox(height: BarzSpacing.md),
            _buildBackToOptionsButton(),
          ] else ...[
            _buildCameraOption(context),
            const SizedBox(height: BarzSpacing.md),
            _buildGalleryOption(context),
            const SizedBox(height: BarzSpacing.md),
            _buildUrlOption(context),
          ],
          const SizedBox(height: BarzSpacing.xl),
          _buildTips(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
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
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: BarzSpacing.sm),
        Text(
          'Take a photo of your physical menu and our AI will extract all items automatically',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BarzRadii.lg),
      child: Image.memory(
        _selectedImageBytes!,
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
            imageBytes: _selectedImageBytes!,
            fileName:
                _selectedImageName ??
                'menu_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
      onPressed: () => setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
      }),
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

  Widget _buildUrlOption(BuildContext context) {
    return _buildOptionCard(
      icon: Icons.link_rounded,
      title: 'Paste Menu URL',
      subtitle: 'Have an online menu? Paste the link',
      onTap: () => setState(() => _showUrlInput = true),
    );
  }

  Widget _buildUrlInput(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BarzSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(BarzSpacing.sm),
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(BarzRadii.sm),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: barzGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: BarzSpacing.md),
              Text(
                'Menu URL',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: BarzSpacing.md),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://yourmenu.com/menu.pdf',
              filled: true,
              fillColor: barzGoldSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: const BorderSide(color: barzGold, width: 2),
              ),
              prefixIcon: const Icon(Icons.public, color: textTertiary),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: BarzSpacing.sm),
          Text(
            'Supports: PDF menus, images (JPG, PNG), and web pages',
            style: theme.textTheme.bodySmall?.copyWith(color: textTertiary),
          ),
          const SizedBox(height: BarzSpacing.lg),
          ElevatedButton.icon(
            onPressed: _urlController.text.trim().isEmpty
                ? null
                : () => _extractFromUrl(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Analyze Menu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: barzGold,
              foregroundColor: barzDark,
              disabledBackgroundColor: textTertiary.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackToOptionsButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() {
        _showUrlInput = false;
        _urlController.clear();
      }),
      icon: const Icon(Icons.arrow_back),
      label: const Text('Back to Options'),
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

  void _extractFromUrl(BuildContext context) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL'),
          backgroundColor: errorRed,
        ),
      );
      return;
    }

    context.read<MenuReaderBloc>().add(
      ExtractMenuFromUrl(
        menuUrl: url,
        barId: widget.barId,
        languageHint: 'pt-BR',
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(color: textSecondary),
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
    final theme = Theme.of(context);
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
                style: theme.textTheme.titleSmall?.copyWith(
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: infoBlue)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: textSecondary),
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
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
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
