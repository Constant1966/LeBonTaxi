import 'package:flutter/material.dart';
import 'package:users_app/theme/app_colors.dart';

/// Timeline visuelle du statut de la course
class StatusTimeline extends StatelessWidget {
  final String currentStatus;

  const StatusTimeline({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep('Recherche', 'searching', Icons.search),
      _TimelineStep('Accepté', 'accepted', Icons.check_circle),
      _TimelineStep('En route', 'arrived', Icons.directions_car),
      _TimelineStep('En course', 'ontrip', Icons.navigation),
      _TimelineStep('Terminé', 'ended', Icons.flag),
    ];

    final currentIndex = steps.indexWhere((s) => s.key == currentStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Ligne entre les étapes
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentIndex;
            return Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final step = steps[stepIndex];
          final isCompleted = stepIndex < currentIndex;
          final isCurrent = stepIndex == currentIndex;

          return _buildStep(step, isCompleted, isCurrent);
        }),
      ),
    );
  }

  Widget _buildStep(_TimelineStep step, bool isCompleted, bool isCurrent) {
    Color color;
    if (isCompleted) {
      color = AppColors.success;
    } else if (isCurrent) {
      color = AppColors.primary;
    } else {
      color = Colors.grey.shade400;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 36 : 28,
          height: isCurrent ? 36 : 28,
          decoration: BoxDecoration(
            color: isCurrent
                ? color
                : (isCompleted ? color : Colors.grey.shade200),
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: color.withOpacity(0.3), width: 3)
                : null,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : step.icon,
            color: (isCompleted || isCurrent) ? Colors.white : Colors.grey.shade400,
            size: isCurrent ? 18 : 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent
                ? AppColors.textPrimary
                : (isCompleted ? AppColors.success : Colors.grey.shade500),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TimelineStep {
  final String label;
  final String key;
  final IconData icon;

  _TimelineStep(this.label, this.key, this.icon);
}
