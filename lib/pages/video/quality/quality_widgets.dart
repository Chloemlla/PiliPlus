import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/quality_mode.dart';
import 'package:pili_plus/controllers/quality_recommendation_controller.dart';
import 'package:pili_plus/pages/setting/widgets/select_dialog.dart';

/// Quality mode selector widget for settings
class QualityModeSelector extends StatelessWidget {
  final QualityRecommendationController controller;

  const QualityModeSelector({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final currentMode = controller.currentMode.value;

      return ListTile(
        leading: const Icon(Icons.high_quality),
        title: const Text('画质模式'),
        subtitle: Text(currentMode.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showModeSelector(context),
      );
    });
  }

  void _showModeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择画质模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: QualityMode.values.map((mode) {
            return RadioListTile<QualityMode>(
              value: mode,
              groupValue: controller.currentMode.value,
              onChanged: (value) {
                if (value != null) {
                  controller.setMode(value);
                  Navigator.pop(context);
                }
              },
              title: Text(mode.label),
              subtitle: Text(mode.description),
              isThreeLine: true,
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

/// Quality chip overlay for player
class QualityChipOverlay extends StatelessWidget {
  final QualityRecommendationController controller;

  const QualityChipOverlay({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.showQualityChip.value) {
        return const SizedBox.shrink();
      }

      final recommendation = controller.currentRecommendation.value;
      if (recommendation == null) {
        return const SizedBox.shrink();
      }

      return Positioned(
        top: 80,
        right: 16,
        child: AnimatedOpacity(
          opacity: controller.showQualityChip.value ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '自动: ${recommendation.qualityLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                if (recommendation.reason != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${recommendation.reason})',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Compact quality mode indicator
class QualityModeIndicator extends StatelessWidget {
  final QualityRecommendationController controller;
  final VoidCallback? onTap;

  const QualityModeIndicator({
    super.key,
    required this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.currentMode.value;
      final recommendation = controller.currentRecommendation.value;

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getModeIcon(mode),
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                recommendation?.qualityLabel ?? mode.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              if (mode == QualityMode.auto && recommendation?.reason != null) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.white54,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  IconData _getModeIcon(QualityMode mode) {
    switch (mode) {
      case QualityMode.qualityFirst:
        return Icons.high_quality;
      case QualityMode.smoothFirst:
        return Icons.speed;
      case QualityMode.batterySaver:
        return Icons.battery_saver;
      case QualityMode.auto:
        return Icons.auto_awesome;
    }
  }
}
