import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/pages/live_alert/widgets/live_alert_following_picker.dart';
import 'package:pili_plus/services/live_alert_controller.dart';

class LiveAlertRuleEditorSheet extends StatelessWidget {
  const LiveAlertRuleEditorSheet({
    super.key,
    required this.controller,
  });

  final LiveAlertController controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.isEditing ? '编辑提醒规则' : '添加提醒规则',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text('从关注列表选择', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                LiveAlertFollowingPicker(controller: controller),
                const SizedBox(height: 20),
                Text(
                  '或手动输入 UID',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.manualMidController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'UP 主 UID',
                          hintText: '例如 12345678',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => FilledButton.tonal(
                        onPressed: controller.isResolvingMid.value
                            ? null
                            : () => _resolveMid(),
                        child: controller.isResolvingMid.value
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('校验'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Obx(
                  () => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: controller.selectedMid.value == null
                        ? const Text('请选择或校验一位已开通直播间的 UP 主')
                        : ListTile(
                            key: ValueKey(controller.selectedMid.value),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(controller.selectedUpName.value),
                            subtitle: Text(
                              'UID ${controller.selectedMid.value}',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.keywordController,
                  maxLength: 50,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '关键词',
                    hintText: '例如 演唱会、杂谈、游戏通关',
                    helperText: '按不区分大小写的包含关系匹配，空关键词不会触发。',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('匹配范围', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Obx(
                  () => SegmentedButton<MatchTarget>(
                    segments: const [
                      ButtonSegment(
                        value: MatchTarget.titleOnly,
                        label: Text('仅标题'),
                      ),
                      ButtonSegment(
                        value: MatchTarget.areaOnly,
                        label: Text('仅分区'),
                      ),
                      ButtonSegment(
                        value: MatchTarget.both,
                        label: Text('任一'),
                      ),
                    ],
                    selected: {controller.selectedMatchTarget.value},
                    onSelectionChanged: (selection) {
                      controller.setMatchTarget(selection.first);
                    },
                    showSelectedIcon: false,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用此规则'),
                    subtitle: const Text('暂停后会保留规则，但不参与轮询匹配。'),
                    value: controller.isRuleEnabled.value,
                    onChanged: controller.setEnabled,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: Obx(
                () => FilledButton.icon(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => _save(context),
                  icon: controller.isSaving.value
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(controller.isEditing ? '保存修改' : '添加规则'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveMid() async {
    final result = await controller.resolveManualMid();
    if (result != LiveAlertResolveResult.resolved) {
      SmartDialog.showToast(_resolveMessage(result));
    }
  }

  Future<void> _save(BuildContext context) async {
    final result = await controller.saveRule();
    if (result == LiveAlertSaveResult.saved) {
      if (context.mounted) Navigator.pop(context, true);
      return;
    }
    SmartDialog.showToast(_saveMessage(result));
  }

  static String _resolveMessage(LiveAlertResolveResult result) =>
      switch (result) {
        LiveAlertResolveResult.resolved => '校验成功',
        LiveAlertResolveResult.notLoggedIn => '请先登录账号',
        LiveAlertResolveResult.invalidMid => '请输入有效的数字 UID',
        LiveAlertResolveResult.upNotFound => '未找到该用户的直播间',
        LiveAlertResolveResult.accountChanged => '账号已切换，请重新选择',
      };

  static String _saveMessage(LiveAlertSaveResult result) => switch (result) {
    LiveAlertSaveResult.saved => '保存成功',
    LiveAlertSaveResult.notLoggedIn => '请先登录账号',
    LiveAlertSaveResult.invalidMid => '请输入有效的数字 UID',
    LiveAlertSaveResult.keywordRequired => '关键词不能为空',
    LiveAlertSaveResult.keywordTooLong => '关键词不能超过 50 个字符',
    LiveAlertSaveResult.upNotFound => '未找到该用户的直播间',
    LiveAlertSaveResult.duplicate => '相同 UP、关键词和匹配范围的规则已存在',
    LiveAlertSaveResult.accountChanged => '账号已切换，请重新编辑',
    LiveAlertSaveResult.failed => '保存失败，请重试',
  };
}
