import 'dart:ui';
import 'dart:math' as math;
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
            sigmaX: math.max(0.001, anim1.value * 12.0),
            sigmaY: math.max(0.001, anim1.value * 12.0),
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
  CampaignType _selectedType = CampaignType.featured;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
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
          final l10n = AppLocalizations.of(context)!;

          return Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: BoxDecoration(
              color: barzDarkLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: dobar.surfaceElevated, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dobar.surfaceElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
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
                          color: barzGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          color: barzGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.campaign_create_title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: dobar.labelPrimary,
                                fontFamily: 'SF Pro Display',
                              ),
                            ),
                            Text(
                              l10n.campaign_create_subtitle,
                              style: TextStyle(
                                fontSize: 14,
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

                Divider(color: dobar.surfaceElevated, height: 1),

                Expanded(
                  child: AbsorbPointer(
                    absorbing: isCreating,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          // Campaign Name
                          Text(
                            l10n.campaign_name_label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: dobar.labelPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: dobar.labelPrimary),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: barzDark,
                              hintText: l10n.campaign_name_hint,
                              hintStyle: TextStyle(
                                color: dobar.labelSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: barzGold,
                                  width: 1,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? l10n.campaign_name_required
                                : null,
                          ),

                          const SizedBox(height: 24),

                          // Campaign Type
                          Text(
                            l10n.campaign_type_label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: dobar.labelPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: CampaignType.values.map((type) {
                              if (type == CampaignType.banner) {
                                return const SizedBox.shrink(); // Hide unsupported
                              }
                              final isSelected = _selectedType == type;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedType = type),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? barzGold.withValues(alpha: 0.15)
                                        : barzDark,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? barzGold
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _typeLabel(type, l10n),
                                    style: TextStyle(
                                      color: isSelected
                                          ? barzGold
                                          : dobar.labelSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          // Budget
                          Text(
                            l10n.campaign_budget_label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: dobar.labelPrimary,
                            ),
                          ),
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              prefixText: r'$ ',
                              prefixStyle: const TextStyle(
                                color: barzGold,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: barzDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: barzGold,
                                  width: 1,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
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

                          // Dates
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.campaign_start_date_label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: dobar.labelPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _selectDate(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: barzDark,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat(
                                                'MMM d, yyyy',
                                              ).format(_startDate),
                                              style: TextStyle(
                                                color: dobar.labelPrimary,
                                              ),
                                            ),
                                            Icon(
                                              LucideIcons.calendar,
                                              size: 18,
                                              color: dobar.labelSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.campaign_end_date_label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: dobar.labelPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _selectDate(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: barzDark,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _endDate != null
                                                  ? DateFormat(
                                                      'MMM d, yyyy',
                                                    ).format(_endDate!)
                                                  : l10n.campaign_no_end_date,
                                              style: TextStyle(
                                                color: _endDate != null
                                                    ? dobar.labelPrimary
                                                    : dobar.labelSecondary,
                                              ),
                                            ),
                                            Icon(
                                              LucideIcons.calendar,
                                              size: 18,
                                              color: dobar.labelSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom CTA
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: barzDarkLight,
                    border: Border(
                      top: BorderSide(color: dobar.surfaceElevated, width: 1),
                    ),
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: InkWell(
                      onTap: isCreating ? null : _submit,
                      borderRadius: BorderRadius.circular(16),
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
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isCreating
                              ? null
                              : [
                                  BoxShadow(
                                    color: barzGold.withValues(alpha: 0.3),
                                    blurRadius: 16,
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
                              : Text(
                                  l10n.campaign_launch_button,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
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
}
