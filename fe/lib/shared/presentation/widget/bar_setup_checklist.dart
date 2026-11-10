import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _SetupStatus {
  final bool hasMenu;
  final bool hasBankAccount;
  final bool isReady;

  const _SetupStatus({
    required this.hasMenu,
    required this.hasBankAccount,
    required this.isReady,
  });

  factory _SetupStatus.fromJson(Map<String, dynamic> json) => _SetupStatus(
    hasMenu: json['has_menu'] as bool? ?? false,
    hasBankAccount: json['has_bank_account'] as bool? ?? false,
    isReady: json['is_ready'] as bool? ?? false,
  );
}

/// Floating bottom-right setup checklist balloon for bar owners.
/// Shows only when the bar hasn't completed basic setup (menu + bank account).
class BarSetupChecklist extends StatefulWidget {
  final int barId;

  const BarSetupChecklist({super.key, required this.barId});

  @override
  State<BarSetupChecklist> createState() => _BarSetupChecklistState();
}

class _BarSetupChecklistState extends State<BarSetupChecklist> {
  _SetupStatus? _status;
  bool _loading = true;
  bool _expanded = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final dio = getItInjector<Dio>();
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.barSetupStatus(widget.barId)}',
      );
      if (!mounted) return;
      setState(() {
        _status = _SetupStatus.fromJson(response.data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed || _status == null || _status!.isReady) {
      return const SizedBox.shrink();
    }

    final colors = context.dobarColors;
    final completedSteps = [
      _status!.hasMenu,
      _status!.hasBankAccount,
    ].where((v) => v).length;
    final totalSteps = 2;

    return Positioned(
      bottom: 24,
      right: 16,
      child:
          AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.buttonPrimary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.buttonPrimary.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(colors, completedSteps, totalSteps),
                        if (_expanded) _buildSteps(colors, context),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .slideY(
                begin: 0.3,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOut,
              )
              .fadeIn(duration: 300.ms),
    );
  }

  Widget _buildHeader(DobarColors colors, int completed, int total) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.buttonPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.clipboard_list,
                size: 16,
                color: colors.buttonPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Go live checklist',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.labelPrimary,
                    ),
                  ),
                  Text(
                    '$completed/$total completed',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: colors.labelSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: colors.labelSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _expanded ? LucideIcons.chevron_down : LucideIcons.chevron_up,
              size: 16,
              color: colors.labelSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteps(DobarColors colors, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: colors.surface.withValues(alpha: 0.2)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepTile(
                done: _status!.hasMenu,
                label: 'Scan or create a menu',
                colors: colors,
                onTap: () => context.push(AppRoute.businessMenuReader.path),
              ),
              const SizedBox(height: 10),
              _StepTile(
                done: _status!.hasBankAccount,
                label: 'Add bank / payment details',
                colors: colors,
                onTap: () => context.push(AppRoute.businessSettings.path),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value:
                    [
                      _status!.hasMenu,
                      _status!.hasBankAccount,
                    ].where((v) => v).length /
                    2,
                backgroundColor: colors.surface.withValues(alpha: 0.3),
                color: colors.buttonPrimary,
                borderRadius: BorderRadius.circular(4),
                minHeight: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final bool done;
  final String label;
  final DobarColors colors;
  final VoidCallback? onTap;

  const _StepTile({
    required this.done,
    required this.label,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: done ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? colors.buttonPrimary
                  : colors.surface.withValues(alpha: 0.3),
              border: done
                  ? null
                  : Border.all(
                      color: colors.labelSecondary.withValues(alpha: 0.4),
                    ),
            ),
            child: done
                ? Icon(
                    LucideIcons.check,
                    size: 12,
                    color: colors.buttonOnPrimary,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: done ? colors.labelSecondary : colors.labelPrimary,
                decoration: done ? TextDecoration.lineThrough : null,
                fontWeight: done ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          if (!done)
            Icon(
              LucideIcons.chevron_right,
              size: 14,
              color: colors.labelSecondary,
            ),
        ],
      ),
    );
  }
}
