import 'package:cached_network_image_ce/cached_network_image_ce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/services/live_alert_controller.dart';
import 'package:pili_plus/models_new/follow/data.dart';

class LiveAlertSettingsPage extends StatelessWidget {
  const LiveAlertSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LiveAlertController>(
      init: LiveAlertController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('直播提醒设置'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  controller.loadRules();
                  controller.loadFollowings();
                },
              ),
            ],
          ),
          body: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
                // Rules list
                if (controller.rules.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildRulesList(controller),
                  )
                else
                  const SliverToBoxAdapter(
                    child: _EmptyState(),
                  ),
                // Add rule button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddRuleDialog(context, controller),
                      icon: const Icon(Icons.add),
                      label: const Text('添加提醒规则'),
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  Widget _buildRulesList(LiveAlertController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '已设置 ${controller.rules.length} 条规则',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...controller.rules.map((rule) => _buildRuleItem(rule, controller)),
      ],
    );
  }

  Widget _buildRuleItem(LiveKeywordRule rule, LiveAlertController controller) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(rule.upName.isNotEmpty ? rule.upName[0] : '?'),
        ),
        title: Text(rule.upName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('关键词: ${rule.keyword}'),
            Text(
              '匹配: ${controller.getMatchTargetLabel(rule.matchTarget)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.enabled,
              onChanged: (_) => controller.toggleRule(rule.id),
            ),
            PopupMenuButton(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => controller.deleteRule(rule.id),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, LiveAlertController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddRuleSheet(controller: controller),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无提醒规则',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加 UP 主开播提醒',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRuleSheet extends StatelessWidget {
  final LiveAlertController controller;

  const _AddRuleSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '添加提醒规则',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // UP selector
              const Text(
                '选择 UP 主',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Obx(() {
                if (controller.isLoadingFollowings.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.followings.isEmpty) {
                  return const Text('暂无关注列表，请先关注 UP 主');
                }

                return SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.followings.length,
                    itemBuilder: (context, index) {
                      final following = controller.followings[index];
                      final isSelected =
                          controller.selectedMid.value == following.mid;

                      return GestureDetector(
                        onTap: () => controller.selectUp(
                          following.mid,
                          following.uname ?? '',
                        ),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: following.face != null
                                    ? CachedNetworkImageProvider(following.face!)
                                    : null,
                                child: following.face == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                following.uname ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Keyword input
              const Text(
                '关键词',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.keywordController,
                decoration: const InputDecoration(
                  hintText: '输入直播标题关键词',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Match target
              const Text(
                '匹配范围',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Obx(() => SegmentedButton<MatchTarget>(
                segments: [
                  ButtonSegment(
                    value: MatchTarget.titleOnly,
                    label: const Text('仅标题'),
                  ),
                  ButtonSegment(
                    value: MatchTarget.areaOnly,
                    label: const Text('仅分区'),
                  ),
                  ButtonSegment(
                    value: MatchTarget.both,
                    label: const Text('两者'),
                  ),
                ],
                selected: {controller.selectedMatchTarget.value},
                onSelectionChanged: (selected) {
                  controller.setMatchTarget(selected.first);
                },
              )),
              const SizedBox(height: 16),

              // Enabled switch
              Obx(() => SwitchListTile(
                title: const Text('启用此规则'),
                value: controller.isRuleEnabled.value,
                onChanged: controller.setEnabled,
                contentPadding: EdgeInsets.zero,
              )),
              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.selectedMid.value == null) {
                      SmartDialog.showToast('请选择 UP 主');
                      return;
                    }
                    if (controller.keywordController.text.isEmpty) {
                      SmartDialog.showToast('请输入关键词');
                      return;
                    }

                    SmartDialog.showLoading(msg: '添加中');
                    final success = await controller.addRule();
                    SmartDialog.dismiss();

                    if (success) {
                      Navigator.pop(context);
                      SmartDialog.showToast('添加成功');
                    } else {
                      SmartDialog.showToast('添加失败');
                    }
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
