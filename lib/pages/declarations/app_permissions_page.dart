import 'package:pili_plus/common/widgets/flutter/list_tile.dart';
import 'package:pili_plus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:pili_plus/common/widgets/view_safe_area.dart';
import 'package:pili_plus/pages/declarations/app_permissions_data.dart';
import 'package:flutter/material.dart' hide ListTile;

class AppPermissionsPage extends StatelessWidget {
  const AppPermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('应用权限')),
      body: ViewSafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                '以下为应用声明使用的系统权限及其用途。权限仅在对应功能首次使用时请求，未授权不会影响其余功能。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            ...AppPermissionsData.items.map(
              (item) => ListTile(
                leading: Icon(
                  Icons.shield_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(item.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.purpose),
                    if (item.scope != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.scope!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                ),
                isThreeLine: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
