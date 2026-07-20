import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/pages/setting/models/model.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/api_type.dart';
import 'package:pili_plus/utils/android/credential_auth.dart';
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
    onTap: (context, setState) {
      if (!Accounts.main.isLogin) {
        SmartDialog.showToast('登录后查看');
        return;
      }
      Get.toNamed('/blackListPage');
    },
    title: '黑名单管理',
    subtitle: '已拉黑用户',
    leading: const Icon(Icons.block),
  ),
  NormalModel(
    onTap: (context, setState) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('账号模式详情'),
          content: SingleChildScrollView(child: _getAccountDetail(context)),
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
  return SelectionArea(
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 8,
      children: children,
    ),
  );
}
