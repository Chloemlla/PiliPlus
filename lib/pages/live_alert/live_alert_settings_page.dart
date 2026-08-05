import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/pages/live_alert/widgets/live_alert_rule_editor_sheet.dart';
import 'package:pili_plus/pages/live_alert/widgets/live_alert_rule_tile.dart';
import 'package:pili_plus/services/live_alert_controller.dart';

class LiveAlertSettingsPage extends StatelessWidget {
  const LiveAlertSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LiveAlertController>(
      init: LiveAlertController(),
      builder: (controller) => Scaffold(
        appBar: AppBar(
          title: const Text('直播提醒设置'),
          actions: [
            Obx(
              () => IconButton(
                tooltip: '刷新',
                onPressed: controller.isLoading.value
                    ? null
                    : controller.refreshCurrentAccount,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        body: Obx(() => _buildBody(context, controller)),
        floatingActionButton: Obx(
          () => controller.isLoggedIn.value
              ? FloatingActionButton.extended(
                  onPressed: () => _openEditor(context, controller),
                  icon: const Icon(Icons.add_alert_outlined),
                  label: const Text('添加规则'),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LiveAlertController controller,
  ) {
    if (!controller.isLoggedIn.value) {
      return const _LoginRequiredState();
    }
    if (controller.isLoading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refreshCurrentAccount,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.battery_saver_outlined),
              title: Text('仅在应用前台检查'),
              subtitle: Text('进入前台时立即检查，之后每 15 分钟轮询；退到后台会停止。'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              '当前账号 · ${controller.rules.length} 条规则',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (controller.rules.isEmpty)
            const _EmptyState()
          else
            for (final rule in controller.rules)
              LiveAlertRuleTile(
                rule: rule,
                matchTargetLabel: controller.getMatchTargetLabel(
                  rule.matchTarget,
                ),
                onToggle: () => controller.toggleRule(rule.id),
                onEdit: () => _openEditor(context, controller, rule: rule),
                onDelete: () => _confirmDelete(context, controller, rule),
              ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    LiveAlertController controller, {
    LiveKeywordRule? rule,
  }) async {
    if (rule == null) {
      controller.beginCreate();
    } else {
      controller.beginEdit(rule);
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LiveAlertRuleEditorSheet(controller: controller),
    );
    controller.clearForm();
    if (saved == true) {
      SmartDialog.showToast(rule == null ? '提醒规则已添加' : '提醒规则已更新');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LiveAlertController controller,
    LiveKeywordRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除提醒规则？'),
        content: Text('将删除 ${rule.upName} 的关键词「${rule.keyword}」。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await controller.deleteRule(rule.id);
    SmartDialog.showToast(deleted ? '已删除' : '删除失败，请重试');
  }
}

class _LoginRequiredState extends StatelessWidget {
  const _LoginRequiredState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('请先登录账号', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('直播提醒规则按账号独立保存，登录后即可管理当前账号的规则。'),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('暂无提醒规则', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('可从关注列表选择 UP 主，也可以手动输入 UID。'),
          ],
        ),
      ),
    );
  }
}
