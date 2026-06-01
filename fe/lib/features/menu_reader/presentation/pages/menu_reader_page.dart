import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/design/tokens/spacing.dart';
import 'package:barz/core/design/tokens/radii.dart';
import 'package:barz/core/design/components/responsive_center_container.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_event.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_state.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_extraction_results_page.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:barz/l10n/app_localizations.dart';

class MenuReaderPage extends StatefulWidget {
  final int barId;
  final int menuId;

  const MenuReaderPage({super.key, required this.barId, required this.menuId});

  @override
  State<MenuReaderPage> createState() => _MenuReaderPageState();
}

class _MenuReaderPageState extends State<MenuReaderPage>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _urlController = TextEditingController();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _showUrlInput = false;

  // Animation controllers
  late final AnimationController _rotateController;
  late final AnimationController _entryController;
  late final Animation<double> _rotation;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _rotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _rotateController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final isDark = context.isDark;

    return BlocConsumer<MenuReaderBloc, MenuReaderState>(
      listener: (context, state) async {
        final l10n = AppLocalizations.of(context)!;
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
              content: Text(
                state.errorMessage ?? l10n.menu_reader_error_extract,
              ),
              backgroundColor: errorRed,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: colors.background,
          body: Stack(
            children: [
              // Ambient gold glow
              _buildAmbientGlow(isDark),
              // Main content
              SafeArea(
                child: Column(
                  children: [
                    ResponsiveCenterContainer(
                      maxWidthPercentage: 0.8,
                      maxWidth: 1200,
                      padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.md),
                      child: _buildToolbar(context, colors, isDark),
                    ),
                    Expanded(
                      child: state.status == MenuReaderStatus.extracting
                          ? _buildLoadingState(colors, isDark)
                          : _buildInitialState(context, colors, isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmbientGlow(bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 420,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.1),
              radius: 0.8,
              colors: [
                barzGold.withValues(alpha: isDark ? 0.18 : 0.12),
                barzGold.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    DobarColors colors,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BarzSpacing.lg,
        vertical: BarzSpacing.sm,
      ),
      child: Row(
        children: [
          // Back button (glass pill)
          _GlassPillButton(
            onTap: () => context.go(AppRoute.businessMenu.path),
            isDark: isDark,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: colors.labelPrimary,
                ),
                const SizedBox(width: BarzSpacing.xs),
                Text(
                  l10n.menu_reader_title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.labelPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // AI Vision badge
          _GlassPillButton(
            onTap: () {},
            isDark: isDark,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: barzGold,
                ),
                const SizedBox(width: 4),
                Text(
                  'AI VISION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: barzGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(DobarColors colors, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return FadeTransition(
      opacity: _fadeIn,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(BarzSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rotating scan icon
              _buildScanIcon(size: 100, iconSize: 48),
              const SizedBox(height: BarzSpacing.xl),
              LoadingAnimationWidget.staggeredDotsWave(
                color: barzGold,
                size: 40,
              ),
              const SizedBox(height: BarzSpacing.lg),
              Text(
                l10n.menu_reader_analyzing,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.labelPrimary,
                ),
              ),
              const SizedBox(height: BarzSpacing.sm),
              Text(
                l10n.menu_reader_take_seconds,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.labelSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState(
    BuildContext context,
    DobarColors colors,
    bool isDark,
  ) {
    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideUp,
        child: SingleChildScrollView(
          child: ResponsiveCenterContainer(
            maxWidthPercentage: 0.8,
            maxWidth: 1200,
            padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: BarzSpacing.lg),
                _buildHeader(colors, isDark),
                const SizedBox(height: BarzSpacing.xxl),
                if (_selectedImageBytes != null) ...[
                  _buildImagePreview(isDark),
                  const SizedBox(height: BarzSpacing.lg),
                  _buildAnalyzeButton(context),
                  const SizedBox(height: BarzSpacing.md),
                  _buildRetakeButton(isDark),
                ] else if (_showUrlInput) ...[
                  _buildUrlInput(context, colors, isDark),
                  const SizedBox(height: BarzSpacing.md),
                  _buildBackToOptionsButton(isDark),
                ] else ...[
                  _buildOptionsGrid(context, colors, isDark),
                ],
                const SizedBox(height: BarzSpacing.xl),
                _buildTips(colors, isDark),
                const SizedBox(height: BarzSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DobarColors colors, bool isDark) {
    return Column(
      children: [
        // Title with gold accent
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Scan your menu and digitalize it with ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.labelPrimary,
                  height: 1.3,
                ),
              ),
              TextSpan(
                text: 'AI speed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: barzGold,
                  height: 1.3,
                ),
              ),
              TextSpan(
                text: ' {1 click}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.labelSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BarzSpacing.xl),
        // Eye icon with rotating dashed circle
        _buildScanIcon(size: 80, iconSize: 36),
        const SizedBox(height: BarzSpacing.xl),
        Text(
          'How would you like to digitize your menu?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: colors.labelSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildScanIcon({required double size, required double iconSize}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating dashed circle
          AnimatedBuilder(
            animation: _rotation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotation.value,
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _DashedCirclePainter(),
                ),
              );
            },
          ),
          // Inner golden circle with eye icon
          Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [barzGold, barzGoldDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: barzGold.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.visibility_rounded,
              size: iconSize,
              color: barzDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(
    BuildContext context,
    DobarColors colors,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;

    final options = [
      _OptionData(
        icon: Icons.camera_alt_rounded,
        title: l10n.menu_reader_opt_take_photo,
        subtitle: 'Use your camera to capture\nthe menu in real time.',
        onTap: () => _pickImage(ImageSource.camera),
      ),
      _OptionData(
        icon: Icons.photo_library_rounded,
        title: l10n.menu_reader_opt_gallery,
        subtitle: 'Choose an existing photo\nfrom your device.',
        onTap: () => _pickImage(ImageSource.gallery),
      ),
      _OptionData(
        icon: Icons.link_rounded,
        title: 'Import From URL',
        subtitle: 'Paste a link to a PDF,\nInstagram or website menu.',
        onTap: () => setState(() => _showUrlInput = true),
      ),
    ];

    return Row(
      children: options.map((option) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildOptionCard(
              icon: option.icon,
              title: option.title,
              subtitle: option.subtitle,
              onTap: option.onTap,
              colors: colors,
              isDark: isDark,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required DobarColors colors,
    required bool isDark,
  }) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BarzRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BarzRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(BarzSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BarzRadii.lg),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(BarzRadii.md),
                ),
                child: Icon(icon, color: barzGold, size: 22),
              ),
              const SizedBox(height: BarzSpacing.md),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.labelPrimary,
                ),
              ),
              const SizedBox(height: BarzSpacing.xs),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.labelSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BarzRadii.lg),
      child: Stack(
        children: [
          Image.memory(
            _selectedImageBytes!,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
          // AI badge overlay
          Positioned(
            top: BarzSpacing.md,
            right: BarzSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: barzGold,
                borderRadius: BorderRadius.circular(BarzRadii.full),
                boxShadow: [
                  BoxShadow(
                    color: barzGold.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: barzDark),
                  SizedBox(width: 4),
                  Text(
                    'AI READY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: barzDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Retake overlay button
          Positioned(
            bottom: BarzSpacing.md,
            left: BarzSpacing.md,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedImageBytes = null;
                _selectedImageName = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(BarzRadii.full),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Change photo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
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
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: Text(
          l10n.menu_reader_btn_analyze,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: barzGold,
          foregroundColor: barzDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarzRadii.lg),
          ),
        ),
      ),
    );
  }

  Widget _buildRetakeButton(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => setState(() {
          _selectedImageBytes = null;
          _selectedImageName = null;
        }),
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: Text(
          l10n.menu_reader_btn_choose_different,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : textSecondary,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarzRadii.lg),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlInput(
    BuildContext context,
    DobarColors colors,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(BarzSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BarzRadii.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
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
                  size: 22,
                ),
              ),
              const SizedBox(width: BarzSpacing.md),
              Text(
                l10n.menu_reader_url_label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.labelPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: BarzSpacing.md),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: l10n.menu_reader_url_hint,
              hintStyle: TextStyle(color: colors.labelSecondary),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : barzGoldMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.lg),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.lg),
                borderSide: const BorderSide(color: barzGold, width: 2),
              ),
              prefixIcon: Icon(
                Icons.public_rounded,
                color: colors.labelSecondary,
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: TextStyle(color: colors.labelPrimary),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: BarzSpacing.sm),
          Text(
            l10n.menu_reader_url_supports,
            style: TextStyle(fontSize: 12, color: colors.labelSecondary),
          ),
          const SizedBox(height: BarzSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _urlController.text.trim().isEmpty
                  ? null
                  : () => _extractFromUrl(context),
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: Text(
                l10n.menu_reader_btn_analyze,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: barzGold,
                foregroundColor: barzDark,
                disabledBackgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                disabledForegroundColor: colors.labelSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BarzRadii.lg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackToOptionsButton(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => setState(() {
          _showUrlInput = false;
          _urlController.clear();
        }),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        label: Text(
          l10n.menu_reader_btn_back_options,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : textSecondary,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarzRadii.lg),
          ),
        ),
      ),
    );
  }

  void _extractFromUrl(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.menu_reader_error_invalid_url),
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

  Widget _buildTips(DobarColors colors, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(BarzSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BarzRadii.lg),
        border: Border.all(
          color: barzGold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_rounded,
                color: barzGold,
                size: 20,
              ),
              const SizedBox(width: BarzSpacing.sm),
              Text(
                l10n.menu_reader_tips_title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: barzGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: BarzSpacing.md),
          // Horizontal tips row
          Row(
            children: [
              _buildTipItem(l10n.menu_reader_tip_lighting, colors),
              const SizedBox(width: BarzSpacing.xl),
              _buildTipItem(l10n.menu_reader_tip_flat, colors),
              const SizedBox(width: BarzSpacing.xl),
              _buildTipItem(l10n.menu_reader_tip_glare, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text, DobarColors colors) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: barzGold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: colors.labelSecondary,
                height: 1.4,
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
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.menu_reader_error_pick_image(e.toString())),
            backgroundColor: errorRed,
          ),
        );
      }
    }
  }
}

// =============================================================================
// Glass pill button for toolbar
// =============================================================================

class _GlassPillButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final Widget child;

  const _GlassPillButton({
    required this.onTap,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BarzRadii.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(BarzRadii.full),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// =============================================================================
// Dashed circle painter for scan icon animation
// =============================================================================

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barzGold.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const dashCount = 24;
    const dashAngle = 2 * math.pi / dashCount;
    const gapAngle = dashAngle * 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle - gapAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}

// =============================================================================
// Option data model
// =============================================================================

class _OptionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}