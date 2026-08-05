import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/danmaku/danmaku_highlight_rule.dart';
import 'package:pili_plus/services/danmaku_highlight_service.dart';

/// Page for managing danmaku highlight rules.
class DanmakuHighlightPage extends StatelessWidget {
  const DanmakuHighlightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<DanmakuHighlightService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('弹幕高亮'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuickRulesChips(service: service),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              final rules = service.rules;
              if (rules.isEmpty) {
                return _EmptyView();
              }
              return _RulesList(service: service, rules: rules);
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRuleEditor(context, service, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showRuleEditor(
    BuildContext context,
    DanmakuHighlightService service,
    DanmakuHighlightRule? existingRule,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RuleEditorSheet(
        service: service,
        existingRule: existingRule,
      ),
    );
  }
}

class _QuickRulesChips extends StatelessWidget {
  const _QuickRulesChips({required this.service});

  final DanmakuHighlightService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快速添加',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: danmakuQuickRules.map((quick) {
              return Obx(() {
                final exists = service.hasKeyword(quick.keyword);
                return ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: quick.color.value,
                    radius: 8,
                  ),
                  label: Text(quick.keyword),
                  onPressed: exists
                      ? null
                      : () async {
                          final success = await service.addQuickRule(quick);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? '已添加"${quick.keyword}"高亮规则'
                                      : '高亮规则已达 ${DanmakuHighlightService.maxRules} 条上限',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                );
              });
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RulesList extends StatelessWidget {
  const _RulesList({
    required this.service,
    required this.rules,
  });

  final DanmakuHighlightService service;
  final List<DanmakuHighlightRule> rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return Dismissible(
          key: Key(rule.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: cs.error,
            child: Icon(
              Icons.delete_outline,
              color: cs.onError,
            ),
          ),
          confirmDismiss: (_) {
            return showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除高亮规则"${rule.keyword}"吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => service.deleteRule(rule.id),
          child: _RuleCard(rule: rule, service: service),
        );
      },
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.service});

  final DanmakuHighlightRule rule;
  final DanmakuHighlightService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _showRuleEditor(context, service, rule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: rule.color.value,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rule.color.value.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.keyword,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: rule.enabled ? null : cs.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (rule.isRegex) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '正则',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onTertiaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (rule.priority != 0) ...[
                          Text(
                            '优先级: ${rule.priority}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          rule.color.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Obx(() {
                final currentRule = service.rules.firstWhere(
                  (r) => r.id == rule.id,
                  orElse: () => rule,
                );
                return Switch(
                  value: currentRule.enabled,
                  onChanged: (_) => service.toggleRule(rule.id),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showRuleEditor(
    BuildContext context,
    DanmakuHighlightService service,
    DanmakuHighlightRule? existingRule,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RuleEditorSheet(
        service: service,
        existingRule: existingRule,
      ),
    );
  }
}

class _RuleEditorSheet extends StatefulWidget {
  const _RuleEditorSheet({
    required this.service,
    this.existingRule,
  });

  final DanmakuHighlightService service;
  final DanmakuHighlightRule? existingRule;

  @override
  State<_RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends State<_RuleEditorSheet> {
  late final TextEditingController _keywordController;
  late final TextEditingController _priorityController;
  late HighlightColor _selectedColor;
  late bool _isRegex;
  late bool _enabled;

  bool get isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    _keywordController = TextEditingController(text: rule?.keyword ?? '');
    _priorityController = TextEditingController(
      text: (rule?.priority ?? 0).toString(),
    );
    _selectedColor = rule?.color ?? HighlightColor.yellow;
    _isRegex = rule?.isRegex ?? false;
    _enabled = rule?.enabled ?? true;
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? '编辑高亮规则' : '添加高亮规则',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '关键词',
                  hintText: '输入要高亮的关键词',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('使用正则表达式'),
                subtitle: const Text('开启后使用正则匹配'),
                value: _isRegex,
                onChanged: (v) => setState(() => _isRegex = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Text(
                '高亮颜色',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HighlightColor.values.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.value,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outline,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.value.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: color == HighlightColor.white
                                  ? cs.onSurface
                                  : Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priorityController,
                decoration: const InputDecoration(
                  labelText: '优先级',
                  hintText: '数字越大优先级越高',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('启用规则'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(isEditing ? '保存' : '添加'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('关键词不能为空'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.service.hasKeyword(
      keyword,
      excludingId: widget.existingRule?.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该关键词已存在'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isRegex) {
      try {
        RegExp(keyword, caseSensitive: false);
      } on FormatException {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正则表达式格式无效'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final priority = int.tryParse(_priorityController.text) ?? 0;

    final rule = DanmakuHighlightRule(
      id:
          widget.existingRule?.id ??
          'rule-${DateTime.now().microsecondsSinceEpoch}',
      keyword: keyword,
      isRegex: _isRegex,
      color: _selectedColor,
      priority: priority,
      enabled: _enabled,
      createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
    );

    final success = isEditing
        ? await widget.service.updateRule(rule)
        : await widget.service.addRule(rule);

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? '高亮规则保存失败，请重试'
                : '高亮规则已达 ${DanmakuHighlightService.maxRules} 条上限',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.highlight_off_rounded,
              size: 72,
              color: cs.outline,
            ),
            const SizedBox(height: 24),
            Text(
              '暂无高亮规则',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '点击右下角添加按钮，'
              '或使用快速添加来创建关键词高亮规则。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
