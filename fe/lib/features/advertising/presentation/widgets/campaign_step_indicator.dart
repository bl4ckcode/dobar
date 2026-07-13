import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';

/// Step data for the campaign creation indicator.
class CampaignStep {
  final String label;
  final IconData icon;

  const CampaignStep({required this.label, required this.icon});

  static const List<CampaignStep> steps = [
    CampaignStep(label: 'Goal', icon: LucideIcons.goal),
    CampaignStep(label: 'Budget', icon: LucideIcons.wallet),
    CampaignStep(label: 'Creative', icon: LucideIcons.image),
    CampaignStep(label: 'Targeting', icon: LucideIcons.target),
    CampaignStep(label: 'Review', icon: LucideIcons.checkSquare),
  ];
}

/// Horizontal 5-step progress indicator for the campaign creation flow.
///
/// Matches the design spec:
/// - Current step: filled gold circle with white number
/// - Completed steps: green checkmark circle
/// - Future steps: dark gray circle (#2C2C2C)
/// - Connecting lines: gold for completed, dark gray for future
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step circles with connecting lines
          SizedBox(
            height: 32,
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
                        color: isCompleted
                            ? barzGold
                            : const Color(0xFF2C2C2C),
                      ),
                    );
                  }
                  // Step circle
                  final stepIndex = index ~/ 2;
                  final step = CampaignStep.steps[stepIndex];
                  final isCompleted = stepIndex < currentStep;
                  final isCurrent = stepIndex == currentStep;

                  return GestureDetector(
                    onTap: isCompleted || isCurrent
                        ? () => onStepTapped?.call(stepIndex)
                        : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? barzGold
                            : isCompleted
                                ? pixGreen
                                : const Color(0xFF2C2C2C),
                        border: isCurrent
                            ? Border.all(color: barzGold, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                LucideIcons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                '${stepIndex + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? Colors.black
                                      : Colors.white38,
                                  fontFamily: 'Space Grotesk',
                                ),
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
                    fontWeight: isCurrent
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isCompleted
                        ? barzGold.withValues(alpha: 0.7)
                        : isCurrent
                            ? barzGold
                            : Colors.white38,
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