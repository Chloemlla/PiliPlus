import 'package:flutter/material.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';

enum _RuleAction { edit, delete }

class LiveAlertRuleTile extends StatelessWidget {
  const LiveAlertRuleTile({
    super.key,
    required this.rule,
    required this.matchTargetLabel,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final LiveKeywordRule rule;
  final String matchTargetLabel;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: const Icon(Icons.live_tv_outlined),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rule.upName.isEmpty ? 'UID ${rule.mid}' : rule.upName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              rule.enabled ? '启用' : '暂停',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: rule.enabled ? colorScheme.primary : colorScheme.outline,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('关键词：${rule.keyword}'),
            Text(
              '$matchTargetLabel · UID ${rule.mid}',
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: rule.enabled, onChanged: (_) => onToggle()),
            PopupMenuButton<_RuleAction>(
              tooltip: '更多操作',
              onSelected: (action) {
                switch (action) {
                  case _RuleAction.edit:
                    onEdit();
                    break;
                  case _RuleAction.delete:
                    onDelete();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _RuleAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('编辑'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _RuleAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('删除'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
