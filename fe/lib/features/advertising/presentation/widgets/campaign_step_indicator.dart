import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';

/// Step data for the campaign creation indicator.
class CampaignStep {
  final String label;
  final IconData icon;

  const CampaignStep({required this.label, required this.icon});

  static const List<CampaignStep> steps = [
    CampaignStep(label: 'Objetivo', icon: LucideIcons.goal),
    CampaignStep(label: 'Orçamento', icon: LucideIcons.wallet),
    CampaignStep(label: 'Criativo', icon: LucideIcons.image),
    CampaignStep(label: 'Segmentação', icon: LucideIcons.target),
    CampaignStep(label: 'Revisão', icon: LucideIcons.checkSquare),
  ];
}

/// Horizontal 5-step progress indicator for the campaign creation flow.
///
/// Matches the Lovable design spec exactly:
/// - Current step: filled gold circle with step icon, gold label text, glow ring
/// - Completed steps: green circle with check icon, gray label text
/// - Future steps: dark gray circle (#1A1A1A) with gray icon, muted gray label
/// - Connecting lines: green for completed, dark gray for future
class CampaignStepIndicator extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int>? onStepTapped;

  const CampaignStepIndicator({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step circles with connecting lines
          SizedBox(
            height: 36,
            child: Row(
              children: List.generate(
                CampaignStep.steps.length * 2 - 1,
                (index) {
                  if (index.isOdd) {
                    // Connecting line
                    final stepIndex = index ~/ 2;
                    final isCompleted = stepIndex < currentStep;
                    return Expanded(
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          color: isCompleted
                              ? pixGreen  // Green for completed segments
                              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE7E5DE)),
                        ),
                      ),
                    );
                  }
                  // Step circle
                  final stepIndex = index ~/ 2;
                  final isCompleted = stepIndex < currentStep;
                  final isCurrent = stepIndex == currentStep;
                  final step = CampaignStep.steps[stepIndex];

                  return GestureDetector(
                    onTap: (isCompleted || isCurrent)
                        ? () => onStepTapped?.call(stepIndex)
                        : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? barzGold  // Gold for current
                            : isCompleted
                                ? pixGreen  // Green for completed
                                : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0EFEA)),  // Dark for future
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: barzGold.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                LucideIcons.check,
                                size: 18,
                                color: Colors.black,
                                // Lovable uses black icon on green/gold backgrounds
                              )
                            : Icon(
                                step.icon,
                                size: 16,
                                color: isCurrent
                                    ? Colors.black  // Black icon on gold
                                    : (isDark ? const Color(0xFFB0B0B0) : const Color(0xFF9C9C9C)),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Step labels
          Row(
            children: List.generate(CampaignStep.steps.length, (index) {
              final step = CampaignStep.steps[index];
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? barzGold  // Gold for current label
                        : isCompleted
                            ? (isDark ? const Color(0xFFB0B0B0) : const Color(0xFF6B6B6B))  // Muted for completed
                            : (isDark ? const Color(0xFF666666) : const Color(0xFF9C9C9C)),  // Light gray for future
                    fontFamily: 'Space Grotesk',
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}