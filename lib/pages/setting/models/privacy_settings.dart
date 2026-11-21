import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:pili_plus/common/widgets/custom_icon.dart';
import 'package:pili_plus/common/widgets/stateful_builder.dart';
import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/pages/setting/models/model.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/api_type.dart';
import 'package:pili_plus/utils/android/credential_auth.dart';
import 'package:pili_plus/utils/login_utils.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/utils.dart';

List<SettingsModel> get privacySettings => [
  const SwitchModel(
    title: '自动打开剪贴板视频',
    subtitle: '进入应用或返回前台时，自动读取剪贴板中的B站视频链接',
    leading: Icon(Icons.content_paste_outlined),
    setKey: SettingBoxKey.autoOpenClipboardVideoLink,
    defaultVal: false,
  ),
  if (Platform.isAndroid)
    const NormalModel(
      onTap: _copyLoginCookie,
      title: '复制登录 Cookie',
      subtitle: '需通过系统锁屏或PIN验证',
      leading: Icon(Icons.cookie_outlined),
    ),
  NormalModel(
    onTap: (context, setState) => Get.toNamed('/blackListPage'),
    title: '黑名单管理',
    subtitle: '已拉黑用户',
    leading: const Icon(Icons.block),
  ),
  const NormalModel(
    title: 'buvid设置',
    leading: Icon(CustomIcons.identifier_circle),
    onTap: _showBuvidDialog,
  ),
  NormalModel(
    onTap: (context, setState) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('账号模式详情'),
          content: SelectionArea(
            child: SingleChildScrollView(
              child: _getAccountDetail(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text('确认'),
            ),
          ],
        ),
      );
    },
    leading: const Icon(Icons.flag_outlined),
    title: '了解账号模式',
    subtitle: '查看各个账号模式作用的API列表',
  ),
];

Future<void> _copyLoginCookie(BuildContext _, VoidCallback _) async {
  if (!Accounts.main.isLogin) {
    SmartDialog.showToast('登录后复制');
    return;
  }

  bool verified = false;
  try {
    verified = await AndroidCredentialAuth.confirm(
      title: '验证身份',
      description: '验证通过后复制当前登录账号 Cookie',
    );
  } on PlatformException catch (e) {
    SmartDialog.showToast(e.message ?? '系统验证不可用');
    return;
  } catch (_) {
    SmartDialog.showToast('系统验证不可用');
    return;
  }

  if (!verified) {
    SmartDialog.showToast('验证未通过');
    return;
  }

  final account = Accounts.main;
  if (!account.isLogin) {
    SmartDialog.showToast('登录状态已失效');
    return;
  }

  final cookie = account.cookieJar.toJson().entries
      .map((e) => '${e.key}=${e.value}')
      .join('; ');
  if (cookie.isEmpty) {
    SmartDialog.showToast('Cookie为空');
    return;
  }

  await Utils.copyText(cookie, toastText: '已复制登录 Cookie');
}

Widget _getAccountDetail(BuildContext context) {
  final children = <Widget>[];
  final theme = TextTheme.of(context);
  for (final i in AccountType.values) {
    final url = ApiType.apiTypeSet[i];
    if (url == null) continue;

    children
      ..add(Center(child: Text(i.title, style: theme.titleMedium)))
      ..add(Text(url.join('\n')));
  }
  return Column(
    spacing: 8,
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    children: children,
  );
}

void _showBuvidDialog(BuildContext context, VoidCallback setState) {
  final filter = [
    FilteringTextInputFormatter.allow(
      RegExp(r"[a-z\d\-_]+", caseSensitive: false),
    ),
  ];
  final controllers = [
    (
      AnonymousAccount(),
      TextEditingController(text: AnonymousAccount().buvid),
    ),
    ...Accounts.account.values.map(
      (i) => (i, TextEditingController(text: i.buvid)),
    ),
  ];
  showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        onDispose: () {
          for (var (_, ctr) in controllers) {
            ctr.dispose();
          }
          controllers.clear();
        },
        builder: (context, _) => AlertDialog(
          title: const Text('buvid'),
          content: SingleChildScrollView(
            child: Column(
              spacing: 8,
              mainAxisSize: .min,
              children: controllers
                  .map(
                    (i) => TextField(
                      controller: i.$2,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'mid: ${i.$1.mid}',
                        labelStyle: theme.textTheme.titleMedium,
                        suffixIcon: IconButton(
                          onPressed: () =>
                              i.$2.text = LoginUtils.generateBuvid(),
                          iconSize: 24,
                          tooltip: '随机',
                          icon: const Icon(Icons.casino_outlined),
                        ),
                      ),
                      inputFormatters: filter,
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                for (var (account, ctr) in controllers) {
                  if (ctr.text case final text when text.isNotEmpty) {
                    account.buvid = text;
                  }
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    },
  );
}
