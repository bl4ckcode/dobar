import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';
import '../widgets/wizard_footer.dart';

class HoursStep extends StatefulWidget {
  final CreateBarFormData formData;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const HoursStep({
    super.key,
    required this.formData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<HoursStep> createState() => _HoursStepState();
}

class _HoursStepState extends State<HoursStep> {
  final _weekDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  TimeOfDay _generalOpenTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _generalCloseTime = const TimeOfDay(hour: 2, minute: 0);

  @override
  void initState() {
    super.initState();
    for (final day in _weekDays) {
      widget.formData.operatingHours.putIfAbsent(
        day,
        () => OperatingHours(
          isOpen: day != 'sunday',
          openTime: const TimeOfDay(hour: 18, minute: 0),
          closeTime: const TimeOfDay(hour: 2, minute: 0),
        ),
      );
    }
  }

  void _applyToAllDays() {
    setState(() {
      for (final day in _weekDays) {
        final currentHours = widget.formData.operatingHours[day]!;
        widget.formData.operatingHours[day] = OperatingHours(
          isOpen: currentHours.isOpen,
          openTime: _generalOpenTime,
          closeTime: _generalCloseTime,
        );
      }
    });
  }

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
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: barzGold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.operating_hours,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.operating_hours_hint,
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: BarzSpacing.lg),
                  _buildGeneralHoursCard(context, l10n),
                  const SizedBox(height: BarzSpacing.lg),
                  Text(
                    l10n.or_customize,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: BarzSpacing.md),
                  ..._weekDays.map((day) => _buildDayRow(context, day, l10n)),
                ],
              ),
            ),
          ),
        ),
        WizardFooter(onBack: widget.onBack, onNext: widget.onNext),
      ],
    );
  }

  Widget _buildGeneralHoursCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: barzGoldSoft,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: barzGold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled, color: barzGold, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.general_hours,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.general_hours_hint,
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeButton(context, l10n.opens, _generalOpenTime, (
                  time,
                ) {
                  setState(() => _generalOpenTime = time);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeButton(
                  context,
                  l10n.closes,
                  _generalCloseTime,
                  (time) {
                    setState(() => _generalCloseTime = time);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _applyToAllDays,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(l10n.apply_to_all_days),
              style: FilledButton.styleFrom(
                backgroundColor: barzGold,
                foregroundColor: barzDark,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, String day, AppLocalizations l10n) {
    final hours = widget.formData.operatingHours[day]!;
    final dayLabels = {
      'monday': l10n.monday,
      'tuesday': l10n.tuesday,
      'wednesday': l10n.wednesday,
      'thursday': l10n.thursday,
      'friday': l10n.friday,
      'saturday': l10n.saturday,
      'sunday': l10n.sunday,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: hours.isOpen ? barzGold : surfaceDim),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayLabels[day] ?? day,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: hours.isOpen ? textPrimary : textSecondary,
                  ),
                ),
              ),
              Switch(
                value: hours.isOpen,
                activeTrackColor: barzGold.withValues(alpha: 0.5),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return barzGold;
                  return surfaceDim;
                }),
                onChanged: (value) {
                  setState(() {
                    widget.formData.operatingHours[day] = OperatingHours(
                      isOpen: value,
                      openTime: hours.openTime,
                      closeTime: hours.closeTime,
                    );
                  });
                },
              ),
            ],
          ),
          if (hours.isOpen) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _buildTimeButton(
                    context,
                    l10n.opens,
                    hours.openTime ?? const TimeOfDay(hour: 18, minute: 0),
                    (time) {
                      setState(() {
                        widget.formData.operatingHours[day] = OperatingHours(
                          isOpen: true,
                          openTime: time,
                          closeTime: hours.closeTime,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeButton(
                    context,
                    l10n.closes,
                    hours.closeTime ?? const TimeOfDay(hour: 2, minute: 0),
                    (time) {
                      setState(() {
                        widget.formData.operatingHours[day] = OperatingHours(
                          isOpen: true,
                          openTime: hours.openTime,
                          closeTime: time,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeButton(
    BuildContext context,
    String label,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: barzDark,
                  secondary: barzGold,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(BarzRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceMuted,
          borderRadius: BorderRadius.circular(BarzRadii.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
            Text(
              time.format(context),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
