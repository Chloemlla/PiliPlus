import 'dart:async';

import 'package:pili_plus/controllers/quality_recommendation_controller.dart';
import 'package:pili_plus/models/quality_mode.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> showQualityModeSelector(
  BuildContext context,
  QualityRecommendationController controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('选择画质模式'),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: Obx(
        () => RadioGroup<QualityMode>(
          groupValue: controller.currentMode.value,
          onChanged: (mode) {
            if (mode == null) return;
            unawaited(_selectQualityMode(dialogContext, controller, mode));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: QualityMode.values
                .map(
                  (mode) => RadioListTile<QualityMode>(
                    value: mode,
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                    isThreeLine: true,
                  ),
                )
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}

Future<void> _selectQualityMode(
  BuildContext dialogContext,
  QualityRecommendationController controller,
  QualityMode mode,
) async {
  try {
    await controller.setMode(mode);
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  } catch (_) {
    if (!dialogContext.mounted) return;
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      const SnackBar(content: Text('画质模式保存失败，请重试')),
    );
  }
}

/// Quality mode selector for settings surfaces.
class QualityModeSelector extends StatelessWidget {
  const QualityModeSelector({
    super.key,
    required this.controller,
  });

  final QualityRecommendationController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final currentMode = controller.currentMode.value;
    return ListTile(
      leading: const Icon(Icons.high_quality),
      title: const Text('画质模式'),
      subtitle: Text(currentMode.label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(showQualityModeSelector(context, controller)),
    );
  });
}

/// Three-second automatic recommendation overlay for the player.
class QualityChipOverlay extends StatelessWidget {
  const QualityChipOverlay({
    super.key,
    required this.controller,
  });

  final QualityRecommendationController controller;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 80,
    right: 16,
    child: IgnorePointer(
      child: Obx(
        () => AnimatedOpacity(
          opacity: controller.showQualityChip.value ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Semantics(
            liveRegion: true,
            label: controller.qualityChipMessage.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
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
                      controller.qualityChipMessage.value,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Compact mode status used inside the player's quality menu.
class QualityModeIndicator extends StatelessWidget {
  const QualityModeIndicator({
    super.key,
    required this.controller,
  });

  final QualityRecommendationController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final mode = controller.currentMode.value;
    final recommendation = controller.currentRecommendation.value;
    return Row(
      children: [
        Icon(_getModeIcon(mode), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text('模式：${mode.label}')),
        if (mode == QualityMode.auto && recommendation != null)
          Text(
            recommendation.qualityLabel,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
      ],
    );
  });

  IconData _getModeIcon(QualityMode mode) => switch (mode) {
    QualityMode.qualityFirst => Icons.high_quality,
    QualityMode.smoothFirst => Icons.speed,
    QualityMode.batterySaver => Icons.battery_saver,
    QualityMode.auto => Icons.auto_awesome,
  };
}
