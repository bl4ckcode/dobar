import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/advertising/domain/models/campaign_creation_models.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'campaign_step_indicator.dart';

/// Multi-step campaign creation page.
///
/// 5-step immersive workflow inspired by Lovable design:
/// Step 1: Passo 1 de 5 - Objetivo
/// Step 2: Passo 2 de 5 - Orçamento
/// Step 3: Passo 3 de 5 - Criativo
/// Step 4: Passo 4 de 5 - Segmentação
/// Step 5: Revisar e Lançar
class MultiStepCampaignSheet extends StatefulWidget {
  const MultiStepCampaignSheet({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<AdvertisingBloc>()),
            BlocProvider.value(value: context.read<SessionBloc>()),
          ],
          child: const MultiStepCampaignSheet(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<MultiStepCampaignSheet> createState() => _MultiStepCampaignSheetState();
}

class _MultiStepCampaignSheetState extends State<MultiStepCampaignSheet>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _slideController;

  int _currentStep = 0;
  bool _isLaunching = false;

  // Step 1: Goal
  CampaignGoal _selectedGoal = CampaignGoal.footTraffic;
  final _nameController = TextEditingController();
  String _barName = '';
  bool _barNameLoaded = false;

  // Step 2: Budget
  final _budgetController = TextEditingController(text: '500');
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  List<PlacementDistribution> _distribution = [];

  // Step 3: Creative
  final _taglineController = TextEditingController();
  String _selectedCta = 'visit_now';
  bool _promoteHappyHour = false;

  // Step 4: Targeting
  double _radiusKm = 5.0;
  double _ageMin = 18;
  double _ageMax = 65;
  bool _peakHoursOnly = false;
  bool _budgetOptimizerEnabled = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideController.value = 1.0;
    _initBarName();
    _applySmartDistribution();
  }

  void _initBarName() {
    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is SessionReady) {
      final bar = sessionState.session.activeBar;
      if (bar != null) {
        _barName = bar.barName;
        _barNameLoaded = true;
        _prefillName();
        return;
      }
    }
    // Fallback: try to get from the user session's active bar
    _barName = 'Meu Bar';
    _prefillName();
  }

  void _prefillName() {
    final dateStr = DateFormat('d/M').format(DateTime.now());
    final goalLabels = {
      CampaignGoal.discovery: 'Descoberta',
      CampaignGoal.footTraffic: 'Clientes',
      CampaignGoal.promotion: 'Promoção',
      CampaignGoal.fullPresence: 'Presença Total',
    };
    _nameController.text = '$_barName — ${goalLabels[_selectedGoal]} $dateStr';
  }

  void _applySmartDistribution() {
    _distribution = _selectedGoal.smartRecommendations(
      double.tryParse(_budgetController.text) ?? 500.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  double get _totalBudget => double.tryParse(_budgetController.text) ?? 0.0;

  int get _campaignDays {
    if (_endDate == null) return 7;
    return _endDate!.difference(_startDate).inDays.clamp(1, 90);
  }

  EstimatedPerformance get _estimatedPerformance {
    final days = _campaignDays;
    final dailyReach = (_totalBudget * 2.4).round().clamp(100, 50000);
    return EstimatedPerformance(
      dailyReach: dailyReach,
      estimatedClicks: (dailyReach * 0.07).round(),
      estimatedImpressions: dailyReach * days,
    );
  }

  void _goToStep(int step) {
    if (step < 0 || step > 4) return;
    if (step > _currentStep && !_validateCurrentStep()) return;

    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().length >= 3;
      case 1:
        final total = _distribution.fold<double>(
          0.0,
          (sum, d) => sum + d.percentage,
        );
        return _totalBudget >= 50 && (total - 100).abs() < 0.01;
      case 2:
        return _taglineController.text.length <= 60;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return true;
    }
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: barzDarkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2C2C2C)),
        ),
        title: const Text(
          'Descartar campanha?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja descartar esta campanha? As alterações não serão salvas.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: errorRed),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _startDate
          : (_endDate ?? _startDate.add(const Duration(days: 7))),
      firstDate: isStart ? now : _startDate,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: barzGold,
            onPrimary: Colors.black,
            surface: barzDarkLight,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _onDistributionChanged(int index, double percentage) {
    setState(() {
      percentage = percentage.clamp(0.0, 100.0);
      _distribution[index] = PlacementDistribution(
        placement: _distribution[index].placement,
        percentage: percentage,
        budget: _totalBudget * percentage / 100,
      );
    });
  }

  void _togglePlacement(int index) {
    setState(() {
      if (_distribution.length > index) {
        final list = [..._distribution];
        list.removeAt(index);
        _distribution = list;
      } else {
        final remaining = CampaignPlacement.values
            .where((p) => !_distribution.any((d) => d.placement == p))
            .toList();
        if (remaining.isNotEmpty) {
          final newP = remaining.first;
          final evenShare = 100.0 / (_distribution.length + 1);
          _distribution = _distribution
              .map((d) => PlacementDistribution(
                    placement: d.placement,
                    percentage: evenShare,
                    budget: _totalBudget * evenShare / 100,
                  ))
              .toList();
          _distribution.add(PlacementDistribution(
            placement: newP,
            percentage: evenShare,
            budget: _totalBudget * evenShare / 100,
          ));
        }
      }
    });
  }

  void _launchCampaign() {
    if (!_validateCurrentStep()) return;
    setState(() => _isLaunching = true);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _isLaunching = false);
      _showLaunchSuccess();
    });
  }

  void _showLaunchSuccess() {
    final ep = _estimatedPerformance;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => _LaunchSuccessDialog(
        name: _nameController.text,
        budget: _totalBudget,
        days: _campaignDays,
        estimatedPerformance: ep,
        onViewCampaign: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
        onCreateAnother: () {
          Navigator.of(ctx).pop();
          setState(() {
            _currentStep = 0;
            _selectedGoal = CampaignGoal.footTraffic;
            _budgetController.text = '500';
            _applySmartDistribution();
            _taglineController.clear();
            _prefillName();
          });
          _pageController.jumpToPage(0);
        },
        onClose: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Campanha salva como rascunho!'),
        backgroundColor: pixGreen,
      ),
    );
    Navigator.of(context).pop();
  }

  String get _stepHeaderTitle {
    return 'Passo ${_currentStep + 1} de 5 - $_stepShortLabel';
  }

  String get _stepShortLabel {
    return switch (_currentStep) {
      0 => 'Objetivo',
      1 => 'Orçamento',
      2 => 'Criativo',
      3 => 'Segmentação',
      4 => 'Revisão',
      _ => '',
    };
  }

  String get _continueLabel =>
      _currentStep == 4 ? 'Lançar Campanha' : 'Continuar';

  // Color palette for placement distribution - matches Lovable color scheme
  static const Color _placementGold = Color(0xFFFFDE59);
  static const Color _placementOrange = Color(0xFFFFB347);
  static const Color _placementRed = Color(0xFFFF6B6B);
  static const Color _placementGreen = Color(0xFF4ECDC4);
  static const Color _placementPurple = Color(0xFF9B59B6);

  Color _placementColor(CampaignPlacement p) {
    return switch (p) {
      CampaignPlacement.featured => _placementGold,
      CampaignPlacement.search => _placementOrange,
      CampaignPlacement.mapPin => _placementRed,
      CampaignPlacement.promo => _placementGreen,
      CampaignPlacement.banner => _placementPurple,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nova Campanha',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: dobarColors.labelSecondary,
              ),
            ),
            Text(
              _stepHeaderTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Space Grotesk',
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: _currentStep > 0
              ? () => _goToStep(_currentStep - 1)
              : _showCloseConfirmation,
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white70),
            onPressed: _showCloseConfirmation,
          ),
        ],
      ),
      body: Column(
        children: [
          CampaignStepIndicator(
            currentStep: _currentStep,
            onStepTapped: (step) {
              if (step < _currentStep) {
                setState(() => _currentStep = step);
                _pageController.animateToPage(
                  step,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              } else if (step > _currentStep && _validateCurrentStep()) {
                setState(() => _currentStep = step);
                _pageController.animateToPage(
                  step,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),

          const Divider(color: Color(0xFF2C2C2C), height: 1),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Goal(),
                _buildStep2Budget(),
                _buildStep3Creative(),
                _buildStep4Targeting(),
                _buildStep5Review(),
              ],
            ),
          ),

          _buildFooter(dobar),
        ],
      ),
    );
  }

  // STEP 1: CAMPAIGN GOAL & NAME - "Passo 1 de 5 - Objetivo"
  Widget _buildStep1Goal() {
    final goals = [
      _GoalCardData(
        goal: CampaignGoal.discovery,
        icon: LucideIcons.compass,
        title: 'Ser Descoberto',
        subtitle: 'Sou novo e quero que as pessoas conheçam meu bar',
      ),
      _GoalCardData(
        goal: CampaignGoal.footTraffic,
        icon: LucideIcons.users,
        title: 'Atrair Mais Clientes',
        subtitle: 'Quero aumentar o fluxo de clientes no meu bar',
      ),
      _GoalCardData(
        goal: CampaignGoal.promotion,
        icon: LucideIcons.tag,
        title: 'Promover Oferta Especial',
        subtitle: 'Estou com happy hour ou promoção especial',
      ),
      _GoalCardData(
        goal: CampaignGoal.fullPresence,
        icon: LucideIcons.sparkles,
        title: 'Presença Total',
        subtitle: 'Quero aparecer em todos os lugares!',
      ),
    ];

    return ResponsiveCenterContainer(
      maxWidthPercentage: 0.5,
      minWidth: 320,
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal selection grid - matching Lovable 2-column card layout
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: goals.map((g) {
                final isSelected = _selectedGoal == g.goal;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGoal = g.goal;
                      _prefillName();
                      _applySmartDistribution();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 312,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? barzGold.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? barzGold
                            : const Color(0xFF2C2C2C),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: barzGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            g.icon,
                            size: 24,
                            color: isSelected ? barzGold : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isSelected ? barzGold : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                g.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB0B0B0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Campaign name field
            Text(
              'Nome da Campanha',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: dobarColors.labelSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: _barNameLoaded ? 'Ex: $_barName — Promoção 1/1' : 'Ex: Meu Bar — Promoção 1/1',
                hintStyle: TextStyle(
                  color: dobarColors.labelSecondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: const Color(0xFF121212),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: barzGold, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  DobarColors get dobarColors => context.dobarColors;

  // STEP 2: BUDGET & DISTRIBUTION - "Passo 2 de 5 - Orçamento"
  Widget _buildStep2Budget() {
    final totalPct =
        _distribution.fold<double>(0.0, (sum, d) => sum + d.percentage);
    final isValid = (totalPct - 100).abs() < 0.01;

    return ResponsiveCenterContainer(
      maxWidthPercentage: 0.5,
      minWidth: 320,
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget input - matching Lovable
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orçamento Total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: dobarColors.labelSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Space Grotesk',
                    ),
                    decoration: InputDecoration(
                      prefixText: 'R\$ ',
                      prefixStyle: const TextStyle(
                        color: barzGold,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Space Grotesk',
                      ),
                      hintText: '500',
                      hintStyle: TextStyle(
                        color:
                            dobarColors.labelSecondary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0A0A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: barzGold, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _distribution = _distribution.map((d) {
                          return PlacementDistribution(
                            placement: d.placement,
                            percentage: d.percentage,
                            budget: _totalBudget * d.percentage / 100,
                          );
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'orçamento total da campanha',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          dobarColors.labelSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Date range - matching Lovable style
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Início',
                    date: _startDate,
                    onTap: () => _selectDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Término',
                    date: _endDate,
                    placeholder: 'Sem data fim',
                    onTap: () => _selectDate(false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Smart distribution button - matching Lovable
            Center(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: MaterialButton(
                  onPressed: () {
                    setState(() {
                      _applySmartDistribution();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Distribuição inteligente aplicada!'),
                        backgroundColor: barzGold,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.wand2,
                          size: 16,
                          color: barzGold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Distribuição Inteligente',
                        style: TextStyle(
                          color: barzGold,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Distribuição por Canal',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dobarColors.labelPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Placement channels with colored icons
            ...CampaignPlacement.values.asMap().entries.map((entry) {
              final placement = entry.value;
              final index =
                  _distribution.indexWhere((d) => d.placement == placement);
              final isEnabled = index >= 0;
              final dist = isEnabled ? _distribution[index] : null;
              final pct = dist?.percentage ?? 0.0;
              final color = _placementColor(placement);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEnabled
                        ? color.withValues(alpha: 0.3)
                        : const Color(0xFF2C2C2C),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _placementIcon(placement),
                            size: 18,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                placement.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                placement.description,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFB0B0B0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _togglePlacement(
                              index >= 0 ? index : _distribution.length),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color:
                                  isEnabled ? color : const Color(0xFF2C2C2C),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 200),
                              alignment: isEnabled
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _onDistributionChanged(index, pct - 5),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.minus,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: color,
                                inactiveTrackColor:
                                    const Color(0xFF2C2C2C),
                                thumbColor: color,
                                overlayColor:
                                    color.withValues(alpha: 0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: pct,
                                min: 0,
                                max: 100,
                                divisions: 20,
                                onChanged: (v) =>
                                    _onDistributionChanged(index, v),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _onDistributionChanged(index, pct + 5),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.plus,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${pct.round()}%',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'R\$ ${dist!.budget.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          Text(
                            '~${(pct * 50).round()} impressões/dia',
                            style: const TextStyle(
                              fontSize: 11,
                              color: pixGreen,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'R\$ ${(dist.budget / _campaignDays.clamp(1, 90)).toStringAsFixed(2)}/dia · ${placement.pricingModel}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFB0B0B0),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            // Distribution bar with colored segments
            if (_distribution.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF0A0A0A),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: _distribution.map((d) {
                    return Expanded(
                      flex: d.percentage.round().clamp(1, 100),
                      child: Container(
                        color: _placementColor(d.placement),
                        child: Center(
                          child: Text(
                            '${d.percentage.round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (!isValid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle,
                        size: 16, color: errorRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Distribuição inválida: ${(100 - totalPct).toStringAsFixed(0)}% restante. Ajuste os valores para totalizar 100%.',
                        style:
                            const TextStyle(fontSize: 11, color: errorRed),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final even = 100.0 / _distribution.length;
                        setState(() {
                          _distribution = _distribution.map((d) {
                            return PlacementDistribution(
                              placement: d.placement,
                              percentage: even,
                              budget: _totalBudget * even / 100,
                            );
                          }).toList();
                        });
                      },
                      child: const Text(
                        'Ajustar',
                        style:
                            TextStyle(color: barzGold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // STEP 3: CREATIVE & DETAILS - "Passo 3 de 5 - Criativo"
  Widget _buildStep3Creative() {
    final hasBanner =
        _distribution.any((d) => d.placement == CampaignPlacement.banner);

    return ResponsiveCenterContainer(
      maxWidthPercentage: 0.5,
      minWidth: 320,
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner card - matching Lovable design
            if (hasBanner) ...[
              Text(
                'Imagem do Banner',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: dobarColors.labelSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Upload de imagem (simulado)'),
                      backgroundColor: barzGold,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2C2C2C),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.image,
                          size: 28,
                          color: barzGold.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Adicionar imagem do banner',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB0B0B0),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recomendado: 1200x628px',
                        style: TextStyle(
                          fontSize: 11,
                          color: dobarColors.labelSecondary
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Tagline
            Text(
              'Chamada / Call-to-Action',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: dobarColors.labelSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _taglineController,
              maxLength: 60,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Crie uma chamada irresistível',
                hintStyle: TextStyle(
                  color:
                      dobarColors.labelSecondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: const Color(0xFF121212),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: barzGold, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                counterStyle: TextStyle(
                  color: _taglineController.text.length > 55
                      ? errorRed
                      : barzGold,
                  fontSize: 11,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // CTA options
            Text(
              'Botão de Ação',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: dobarColors.labelSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CtaOption.options.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cta = CtaOption.options[index];
                  final isSelected = _selectedCta == cta.value;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCta = cta.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? barzGold
                              : const Color(0xFF2C2C2C),
                          width: isSelected ? 1.5 : 1,
                        ),
                        color: isSelected
                            ? barzGold.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      child: Center(
                        child: Text(
                          cta.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? barzGold
                                : dobarColors.labelSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Preview card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.eye,
                          size: 14, color: barzGold),
                      const SizedBox(width: 6),
                      Text(
                        'Pré-visualização',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: dobarColors.labelSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFDF73),
                                    Color(0xFFFFC000),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                LucideIcons.beer,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _barName.isEmpty ? 'Meu Bar' : _barName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Patrocinado',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: dobarColors.labelSecondary
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _taglineController.text.isEmpty
                              ? 'Sua chamada aparecerá aqui'
                              : _taglineController.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: dobarColors.labelSecondary,
                            fontStyle: _taglineController.text.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFDF73),
                                  Color(0xFFFFC000),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              CtaOption.options
                                  .firstWhere(
                                      (o) => o.value == _selectedCta)
                                  .label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Happy hour toggle
            GestureDetector(
              onTap: () => setState(
                  () => _promoteHappyHour = !_promoteHappyHour),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _promoteHappyHour
                        ? barzGold.withValues(alpha: 0.3)
                        : const Color(0xFF2C2C2C),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 18,
                      color: _promoteHappyHour
                          ? barzGold
                          : dobarColors.labelSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Promover Happy Hour',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Destaque seu happy hour nos resultados',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB0B0B0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _promoteHappyHour
                          ? LucideIcons.checkCircle
                          : LucideIcons.circle,
                      size: 22,
                      color: _promoteHappyHour
                          ? pixGreen
                          : dobarColors.labelSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // STEP 4: TARGETING - "Passo 4 de 5 - Segmentação"
  Widget _buildStep4Targeting() {
    return ResponsiveCenterContainer(
      maxWidthPercentage: 0.5,
      minWidth: 320,
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 16, color: barzGold),
                const SizedBox(width: 8),
                Text(
                  'Alcance geográfico',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dobarColors.labelPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Raio de alcance',
                        style:
                            TextStyle(fontSize: 13, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_radiusKm.round()} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: barzGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: barzGold,
                      inactiveTrackColor: const Color(0xFF2C2C2C),
                      thumbColor: barzGold,
                      overlayColor:
                          barzGold.withValues(alpha: 0.2),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '${_radiusKm.round()} km',
                      onChanged: (v) =>
                          setState(() => _radiusKm = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1 km',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white38)),
                      const Text('50 km',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                const Icon(LucideIcons.users,
                    size: 16, color: barzGold),
                const SizedBox(width: 8),
                Text(
                  'Faixa etária',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dobarColors.labelPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_ageMin.round()} — ${_ageMax.round()} anos',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RangeSlider(
                    values: RangeValues(_ageMin, _ageMax),
                    min: 18,
                    max: 65,
                    divisions: 47,
                    activeColor: barzGold,
                    inactiveColor: const Color(0xFF2C2C2C),
                    labels: RangeLabels(
                      '${_ageMin.round()}',
                      '${_ageMax.round()}',
                    ),
                    onChanged: (values) => setState(() {
                      _ageMin = values.start;
                      _ageMax = values.end;
                    }),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('18',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white38)),
                      const Text('65+',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildToggleOption(
              icon: LucideIcons.clock,
              title: 'Apenas em horários de pico',
              subtitle:
                  'Exibir campanha apenas em horários de maior movimento (sextas e sábados à noite, happy hour)',
              value: _peakHoursOnly,
              onChanged: (v) =>
                  setState(() => _peakHoursOnly = v),
            ),
            if (_peakHoursOnly) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DaySchedule(day: 'Sex', hours: '18h-02h'),
                    _DaySchedule(day: 'Sáb', hours: '18h-03h'),
                    _DaySchedule(day: 'Dom', hours: '16h-22h'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _budgetOptimizerEnabled
                      ? barzGold.withValues(alpha: 0.3)
                      : const Color(0xFF2C2C2C),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.zap,
                            size: 16, color: barzGold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Otimizador de Orçamento',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Nosso sistema ajusta automaticamente os lances para maximizar resultados',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB0B0B0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() =>
                            _budgetOptimizerEnabled =
                                !_budgetOptimizerEnabled),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          width: 44,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(12),
                            color: _budgetOptimizerEnabled
                                ? pixGreen
                                : const Color(0xFF2C2C2C),
                          ),
                          child: AnimatedAlign(
                            duration:
                                const Duration(milliseconds: 200),
                            alignment: _budgetOptimizerEnabled
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_budgetOptimizerEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(LucideIcons.checkCircle,
                            size: 12, color: Color(0xFF00B37E)),
                        const SizedBox(width: 6),
                        const Text(
                          'Recomendado para melhores resultados',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00B37E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? barzGold.withValues(alpha: 0.3)
                : const Color(0xFF2C2C2C),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: value
                    ? barzGold
                    : dobarColors.labelSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFB0B0B0)),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value ? barzGold : const Color(0xFF2C2C2C),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 5: REVIEW & LAUNCH
  Widget _buildStep5Review() {
    final ep = _estimatedPerformance;

    return ResponsiveCenterContainer(
      maxWidthPercentage: 0.5,
      minWidth: 320,
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Campaign summary card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.2),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Rascunho',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFA78BFA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.receipt,
                          size: 20, color: barzGold),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2C2C2C)),
                  const SizedBox(height: 16),

                  _buildReviewRow(
                    icon: _goalIcon(_selectedGoal),
                    label: 'Objetivo',
                    value: _goalLabel(_selectedGoal),
                  ),
                  const SizedBox(height: 12),

                  _buildReviewRow(
                    icon: LucideIcons.calendar,
                    label: 'Duração',
                    value: _endDate != null
                        ? '${DateFormat('d MMM').format(_startDate)} a ${DateFormat('d MMM yyyy').format(_endDate!)} ($_campaignDays dias)'
                        : '${DateFormat('d MMM yyyy').format(_startDate)} (em aberto)',
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Investimento',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dobarColors.labelSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R\$ ${_totalBudget.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: barzGold,
                      fontFamily: 'Space Grotesk',
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._distribution.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            _placementIcon(d.placement),
                            size: 14,
                            color: _placementColor(d.placement),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.placement.label,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '${d.percentage.round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'R\$ ${d.budget.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: barzGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(color: Color(0xFF2C2C2C)),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Investimento Total',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'R\$ ${_totalBudget.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: barzGold,
                            fontFamily: 'Space Grotesk',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_taglineController.text.isNotEmpty) ...[
                    _buildReviewRow(
                      icon: LucideIcons.messageSquare,
                      label: 'Chamada',
                      value: _taglineController.text,
                    ),
                    const SizedBox(height: 8),
                  ],

                  _buildReviewRow(
                    icon: LucideIcons.mapPin,
                    label: 'Alcance',
                    value:
                        '${_radiusKm.round()} km · ${_ageMin.round()}-${_ageMax.round()} anos',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Performance card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.trendingUp,
                          size: 16, color: barzGold),
                      const SizedBox(width: 8),
                      Text(
                        'Performance Estimada',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dobarColors.labelPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricBox(
                          label: 'Alcance/dia',
                          value: '~${_formatCompact(ep.dailyReach)}',
                          isGold: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricBox(
                          label: 'Cliques',
                          value:
                              '~${_formatCompact(ep.estimatedClicks)}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricBox(
                          label: 'Impressões',
                          value:
                              '~${_formatCompact(ep.estimatedImpressions)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Estimativas baseadas em performance histórica. Resultados reais podem variar.',
                    style: TextStyle(
                      fontSize: 10,
                      color: dobarColors.labelSecondary
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: barzGold),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: dobarColors.labelSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    bool isGold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: dobarColors.labelSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isGold ? barzGold : Colors.white,
              fontFamily: 'Space Grotesk',
            ),
          ),
        ],
      ),
    );
  }

  // FOOTER
  Widget _buildFooter(DobarColors dobar) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: const Border(
          top: BorderSide(color: Color(0xFF2C2C2C), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep == 4)
              Expanded(
                child: TextButton(
                  onPressed: _isLaunching ? null : _saveDraft,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      side: const BorderSide(
                          color: Color(0xFF2C2C2C)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.save,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        'Salvar Rascunho',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: dobar.labelSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: TextButton(
                  onPressed: _currentStep > 0
                      ? () => _goToStep(_currentStep - 1)
                      : null,
                  child: Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _currentStep > 0
                          ? dobar.labelSecondary
                          : dobar.labelSecondary
                              .withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),

            if (_currentStep == 4) const SizedBox(width: 12),

            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _isLaunching
                    ? null
                    : () {
                        if (_currentStep == 4) {
                          _launchCampaign();
                        } else {
                          _goToStep(_currentStep + 1);
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(12),
                    gradient: _isLaunching
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFFFFDF73),
                              Color(0xFFFFC000),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: _isLaunching
                        ? dobar.surfaceElevated
                        : null,
                    boxShadow: _isLaunching
                        ? null
                        : [
                            BoxShadow(
                              color: barzGold
                                  .withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: -4,
                              offset:
                                  const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isLaunching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_currentStep == 4)
                                const Icon(
                                  LucideIcons.rocket,
                                  size: 18,
                                  color: Colors.black,
                                )
                              else
                                const Icon(
                                  LucideIcons.chevronRight,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              const SizedBox(
                                  width: 8),
                              Text(
                                _continueLabel,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                  fontFamily:
                                      'Space Grotesk',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HELPERS
  Widget _buildDateField({
    required String label,
    required DateTime? date,
    String placeholder = '',
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: dobarColors.labelSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    date != null
                        ? DateFormat('MMM d, yyyy')
                            .format(date)
                        : placeholder,
                    style: TextStyle(
                      color: date != null
                          ? Colors.white
                          : dobarColors.labelSecondary
                              .withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: date != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(LucideIcons.calendar,
                    size: 16, color: barzGold),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static IconData _placementIcon(CampaignPlacement p) {
    return switch (p) {
      CampaignPlacement.featured => LucideIcons.star,
      CampaignPlacement.search => LucideIcons.search,
      CampaignPlacement.mapPin => LucideIcons.mapPin,
      CampaignPlacement.promo => LucideIcons.flame,
      CampaignPlacement.banner => LucideIcons.image,
    };
  }

  static IconData _goalIcon(CampaignGoal g) {
    return switch (g) {
      CampaignGoal.discovery => LucideIcons.compass,
      CampaignGoal.footTraffic => LucideIcons.users,
      CampaignGoal.promotion => LucideIcons.tag,
      CampaignGoal.fullPresence => LucideIcons.sparkles,
    };
  }

  static String _goalLabel(CampaignGoal g) {
    return switch (g) {
      CampaignGoal.discovery => 'Ser Descoberto',
      CampaignGoal.footTraffic => 'Atrair Mais Clientes',
      CampaignGoal.promotion =>
        'Promover Oferta Especial',
      CampaignGoal.fullPresence => 'Presença Total',
    };
  }

  static String _formatCompact(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1)}k';
    }
    return number.toString();
  }
}

class _GoalCardData {
  final CampaignGoal goal;
  final IconData icon;
  final String title;
  final String subtitle;

  const _GoalCardData({
    required this.goal,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _DaySchedule extends StatelessWidget {
  final String day;
  final String hours;

  const _DaySchedule({required this.day, required this.hours});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          day,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          hours,
          style:
              const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
        ),
      ],
    );
  }
}

/// Launch success celebration dialog.
class _LaunchSuccessDialog extends StatefulWidget {
  final String name;
  final double budget;
  final int days;
  final EstimatedPerformance estimatedPerformance;
  final VoidCallback onViewCampaign;
  final VoidCallback onCreateAnother;
  final VoidCallback onClose;

  const _LaunchSuccessDialog({
    required this.name,
    required this.budget,
    required this.days,
    required this.estimatedPerformance,
    required this.onViewCampaign,
    required this.onCreateAnother,
    required this.onClose,
  });

  @override
  State<_LaunchSuccessDialog> createState() =>
      _LaunchSuccessDialogState();
}

class _LaunchSuccessDialogState extends State<_LaunchSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
    _scaleAnim = CurvedAnimation(
      parent: _confettiController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: barzDarkCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: barzGold.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: barzGold.withValues(alpha: 0.3),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFDF73),
                        Color(0xFFFFC000),
                      ],
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 40,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Campanha Lançada!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Space Grotesk',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFB0B0B0),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${widget.budget.toStringAsFixed(2)} · ${widget.days} dias',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: barzGold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onViewCampaign,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFDF73),
                                Color(0xFFFFC000),
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Ver Campanha',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onCreateAnother,
                  child: const Text(
                    'Criar Outra',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}