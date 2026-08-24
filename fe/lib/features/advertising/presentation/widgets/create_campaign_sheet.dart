import 'dart:ui';
import 'dart:math' as math;
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_bloc.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_event.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_state.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

class CreateCampaignSheet extends StatefulWidget {
  const CreateCampaignSheet({super.key});

  static void show(BuildContext context) {
    final advertisingBloc = context.read<AdvertisingBloc>();
    final sessionBloc = context.read<SessionBloc>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: advertisingBloc),
            BlocProvider.value(value: sessionBloc),
          ],
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: const CreateCampaignSheet(),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: math.max(0.001, anim1.value * 8.0),
            sigmaY: math.max(0.001, anim1.value * 8.0),
          ),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
                .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CreateCampaignSheet> createState() => _CreateCampaignSheetState();
}

class _CreateCampaignSheetState extends State<CreateCampaignSheet> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _budgetController = TextEditingController(text: '100');
  final _taglineController = TextEditingController();
  CampaignType _selectedType = CampaignType.featured;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _startDate
          : (_endDate ?? _startDate.add(const Duration(days: 7))),
      firstDate: isStart ? DateTime.now() : _startDate,
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: barzGold,
              onPrimary: Colors.black,
              surface: barzDarkLight,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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

  String _typeLabel(CampaignType type, AppLocalizations l10n) {
    return switch (type) {
      CampaignType.featured => l10n.campaign_type_featured,
      CampaignType.search => l10n.campaign_type_search,
      CampaignType.map => l10n.campaign_type_map,
      CampaignType.promoBoost => l10n.campaign_type_promo_boost,
      _ => type.name.toUpperCase(),
    };
  }

  String _typeEmoji(CampaignType type) {
    return switch (type) {
      CampaignType.featured => '⭐',
      CampaignType.search => '🔍',
      CampaignType.map => '📍',
      CampaignType.promoBoost => '🚀',
      _ => '📢',
    };
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final sessionState = context.read<SessionBloc>().state;
      if (sessionState is! SessionReady) return;

      final barId = sessionState.session.activeBar?.barId;
      if (barId == null) return;

      final request = CreateCampaignRequest(
        barId: barId,
        name: _nameController.text,
        campaignType: _selectedType,
        budgetType: BudgetType.cash,
        budgetAmount: double.tryParse(_budgetController.text) ?? 0.0,
        startDate: _startDate,
        endDate: _endDate,
      );

      context.read<AdvertisingBloc>().add(
        AdvertisingEvent.createCampaign(request: request),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdvertisingBloc, AdvertisingState>(
      listener: (context, state) {
        if (state.successMessage == 'Campaign created successfully!') {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.campaign_created_success),
              backgroundColor: barzGold,
            ),
          );
          Navigator.of(context).pop();
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: BlocBuilder<AdvertisingBloc, AdvertisingState>(
        builder: (context, state) {
          final isCreating = state.isLoadingCampaign;
          final dobar = context.dobarColors;
          final isDark = context.isDark;
          final l10n = AppLocalizations.of(context)!;

          return Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: BoxDecoration(
              color: dobar.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark ? dobar.surfaceElevated : surfaceDim,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.8 : 0.1),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? dobar.surfaceElevated
                          : surfaceDim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header - Matching Lovable's dialog header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [barzGoldGradientStart, barzGoldGradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.megaphone,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  l10n.campaign_create_title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: dobar.labelPrimary,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  LucideIcons.sparkles,
                                  size: 16,
                                  color: barzGold,
                                ),
                              ],
                            ),
                            Text(
                              l10n.campaign_create_subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: dobar.labelSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: dobar.labelSecondary),
                        onPressed: isCreating
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: isDark ? dobar.surfaceElevated : surfaceDim,
                  height: 1,
                ),

                // Scrollable Form
                Expanded(
                  child: AbsorbPointer(
                    absorbing: isCreating,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          // Campaign Name
                          _buildFieldLabel(l10n.campaign_name_label, dobar),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(
                              color: dobar.labelPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              hint: l10n.campaign_name_hint,
                              dobar: dobar,
                              isDark: isDark,
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? l10n.campaign_name_required
                                : null,
                          ),

                          const SizedBox(height: 24),

                          // Campaign Type - 2-column grid with emoji
                          _buildFieldLabel(l10n.campaign_type_label, dobar),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: CampaignType.values.map((type) {
                              if (type == CampaignType.banner) {
                                return const SizedBox.shrink();
                              }
                              final isSelected = _selectedType == type;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedType = type),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark
                                            ? barzGold.withValues(alpha: 0.15)
                                            : barzGold.withValues(alpha: 0.1))
                                        : (isDark
                                            ? barzDark
                                            : surfaceMuted),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? barzGold
                                          : (isDark
                                              ? Colors.transparent
                                              : surfaceDim),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _typeEmoji(type),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _typeLabel(type, l10n),
                                        style: TextStyle(
                                          color: isSelected
                                              ? (isDark
                                                  ? barzGold
                                                  : barzDark)
                                              : dobar.labelSecondary,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          // Budget
                          _buildFieldLabel(l10n.campaign_budget_label, dobar),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _budgetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                            ],
                            style: TextStyle(
                              color: dobar.labelPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Space Grotesk',
                            ),
                            decoration: InputDecoration(
                              prefixText: '\$ ',
                              prefixStyle: TextStyle(
                                color: barzGold,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Space Grotesk',
                              ),
                              filled: true,
                              fillColor: isDark ? barzDark : surfaceMuted,
                              hintText: '500',
                              hintStyle: TextStyle(
                                color: dobar.labelSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: barzGold,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return l10n.campaign_budget_required;
                              }
                              final num = double.tryParse(val);
                              if (num == null || num <= 0) {
                                return l10n.campaign_budget_invalid;
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          // Dates Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: l10n.campaign_start_date_label,
                                  date: _startDate,
                                  onTap: () => _selectDate(context, true),
                                  dobar: dobar,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDateField(
                                  label: l10n.campaign_end_date_label,
                                  date: _endDate,
                                  isEndDate: true,
                                  placeholder: l10n.campaign_no_end_date,
                                  onTap: () => _selectDate(context, false),
                                  dobar: dobar,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Creative Tagline (matching Lovable's optional textarea)
                          Row(
                            children: [
                              _buildFieldLabel(
                                l10n.campaign_tagline_label,
                                dobar,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(optional)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dobar.labelSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _taglineController,
                            maxLines: 3,
                            style: TextStyle(
                              color: dobar.labelPrimary,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              hint: l10n.campaign_tagline_hint,
                              dobar: dobar,
                              isDark: isDark,
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom CTA - Matching Lovable's Launch Campaign button
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: dobar.surface,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? dobar.surfaceElevated : surfaceDim,
                        width: 1,
                      ),
                    ),
                  ),
                  child: InkWell(
                    onTap: isCreating ? null : _submit,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isCreating
                            ? null
                            : const LinearGradient(
                                colors: [
                                  barzGoldGradientStart,
                                  barzGoldGradientEnd,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: isCreating ? dobar.surfaceElevated : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isCreating
                            ? null
                            : [
                                BoxShadow(
                                  color: barzGold.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: -4,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Center(
                        child: isCreating
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: dobar.labelPrimary,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.rocket,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.campaign_launch_button,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Space Grotesk',
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
          );
        },
      ),
    );
  }

  Widget _buildFieldLabel(String label, DobarColors dobar) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: dobar.labelSecondary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required DobarColors dobar,
    required bool isDark,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? barzDark : surfaceMuted,
      hintText: hint,
      hintStyle: TextStyle(
        color: dobar.labelSecondary.withValues(alpha: 0.5),
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: barzGold,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool isEndDate = false,
    String placeholder = '',
    required DobarColors dobar,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, dobar),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: isDark ? barzDark : surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    date != null
                        ? DateFormat('MMM d, yyyy').format(date)
                        : placeholder,
                    style: TextStyle(
                      color: date != null
                          ? dobar.labelPrimary
                          : dobar.labelSecondary.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: barzGold,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}