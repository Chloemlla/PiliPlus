import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/common/widgets/pendant_avatar.dart';
import 'package:pili_plus/services/live_alert_controller.dart';

class LiveAlertFollowingPicker extends StatelessWidget {
  const LiveAlertFollowingPicker({
    super.key,
    required this.controller,
  });

  final LiveAlertController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingFollowings.value &&
          controller.followings.isEmpty) {
        return const SizedBox(
          height: 104,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.followings.isEmpty) {
        return _EmptyFollowings(
          error: controller.followingsError.value,
          onRetry: controller.loadFollowings,
        );
      }

      final canLoadMore = controller.hasMoreFollowings.value;
      return SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: controller.followings.length + (canLoadMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == controller.followings.length) {
              return SizedBox(
                width: 80,
                child: OutlinedButton(
                  onPressed: controller.isLoadingFollowings.value
                      ? null
                      : controller.loadMoreFollowings,
                  child: controller.isLoadingFollowings.value
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('更多'),
                ),
              );
            }

            final following = controller.followings[index];
            final isSelected = controller.selectedMid.value == following.mid;
            final colorScheme = Theme.of(context).colorScheme;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 88,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.secondaryContainer
                    : colorScheme.surfaceContainerLow,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => controller.selectFollowing(following),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      PendantAvatar(following.face, size: 54),
                      const SizedBox(height: 6),
                      Text(
                        following.uname ?? 'UID ${following.mid}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _EmptyFollowings extends StatelessWidget {
  const _EmptyFollowings({required this.error, required this.onRetry});

  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            error?.isNotEmpty == true ? '关注列表加载失败' : '关注列表为空，可手动输入 UID',
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}
