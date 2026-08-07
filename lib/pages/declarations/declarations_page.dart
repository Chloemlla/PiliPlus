import 'package:pili_plus/common/widgets/flutter/list_tile.dart';
import 'package:pili_plus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:pili_plus/common/widgets/view_safe_area.dart';
import 'package:pili_plus/services/first_launch_oss_notice_service.dart';
import 'package:flutter/material.dart' hide ListTile;
import 'package:get/get.dart';

class DeclarationsPage extends StatelessWidget {
  const DeclarationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final subTitleStyle = TextStyle(fontSize: 13, color: outline);
    final arrow = Icon(Icons.arrow_forward, size: 16, color: outline);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('应用声明')),
      body: ViewSafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              onTap: () => Get.toNamed('/legalInfo'),
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('法律信息'),
              subtitle: Text(
                '用户协议、隐私政策、会员服务协议、个人信息收集清单、撤回同意',
                style: subTitleStyle,
              ),
              trailing: arrow,
            ),
            ListTile(
              onTap: FirstLaunchOssNoticeService.openManual,
              leading: const Icon(Icons.balance_outlined),
              title: const Text('开源许可声明'),
              subtitle: Text(
                '源码地址、永久免费提示、协议与依赖鸣谢',
                style: subTitleStyle,
              ),
              trailing: arrow,
            ),
            ListTile(
              onTap: () => Get.toNamed('/appPermissions'),
              leading: const Icon(Icons.shield_outlined),
              title: const Text('应用权限'),
              subtitle: Text(
                '应用声明的系统权限及用途说明',
                style: subTitleStyle,
              ),
              trailing: arrow,
            ),
          ],
        ),
      ),
    );
  }
}
