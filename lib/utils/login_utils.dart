import 'dart:async';
import 'dart:io' show Platform;

import 'package:pili_plus/http/init.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/user.dart';
import 'package:pili_plus/main.dart';
import 'package:pili_plus/services/account_service.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/bilibili_device_identity.dart';
import 'package:pili_plus/utils/global_data.dart';
import 'package:pili_plus/utils/request_utils.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:pili_plus/utils/utils.dart';
import 'package:pili_plus/utils/web_cookie_sync.dart';
import 'package:pili_plus/services/synapse_sync_service.dart';
import 'package:collection/collection.dart';
import 'package:pili_plus/utils/linux_cookie_manager.dart';
import 'package:crypto/crypto.dart' show Digest;
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as web;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

abstract final class LoginUtils {
  static Future<void> initializeSession() async {
    Request.installAccountManager();
    Accounts.configureSessionHandlers(
      activateAccount: Request.buvidActive,
      onMainLogin: onLoginMain,
      onMainLogout: onLogoutMain,
    );
    await Accounts.refresh();
    await setWebCookie();

    if (Accounts.main.isLogin) {
      final coin = Pref.userInfoCache?.money;
      if (coin == null) {
        await syncCoin();
      } else {
        GlobalData().coins = coin;
      }
      await SynapseSyncService.maybeShowStartupPrompt();
    }

    // 会话/鉴权对齐：让 AccountService.isLogin / userInfoCache 反映实际 main
    // 账号，消除"显示已登录但请求按匿名/错误账号鉴权"的分歧。refresh() 只重建
    // accountMode，不驱动 main 登录回调；这里在存在分歧时才补一次，避免重复网络调用。
    if (Get.isRegistered<AccountService>()) {
      final session = Get.find<AccountService>();
      if (Accounts.main.isLogin) {
        if (!session.isLogin.value) {
          await onLoginMain();
        }
      } else if (session.isLogin.value) {
        await onLogoutMain();
      }
    }
  }

  static Future<void> syncCoin() async {
    final res = await UserHttp.getCoin();
    if (res case Success(:final response)) {
      GlobalData().coins = response;
    }
  }

  static Future<void> setWebCookie([Account? account]) async {
    if (Platform.isLinux) {
      return;
    }
    final cookies = (account ?? Accounts.main).cookieJar.toList();
    final webManager = web.CookieManager.instance(
      webViewEnvironment: webViewEnvironment,
    );
    await WebCookieSync.writeAll(
      cookies,
      write: (origin, cookie) async {
        await webManager.setCookie(
          url: web.WebUri(origin.toString()),
          name: cookie.name,
          value: cookie.value,
          path: cookie.path ?? '/',
          domain: cookie.domain,
          isSecure: cookie.secure,
          isHttpOnly: cookie.httpOnly,
        );
      },
    );
  }

  static Future<void> onLoginMain() async {
    final account = Accounts.main;
    final res = await UserHttp.userInfo();
    if (account != Accounts.main) {
      // A rapid A→B main-account switch replaced the main slot while
      // userInfo() was in flight; this response belongs to the previous
      // account, so ignore it entirely.
      return;
    }
    if (res case Success(:final response)) {
      await setWebCookie(account);
      RequestUtils.syncHistoryStatus();
      if (response.isLogin == true) {
        final accountService = Get.find<AccountService>()
          ..face.value = response.face!;

        if (accountService.isLogin.value) {
          accountService.isLogin.refresh();
        } else {
          accountService.isLogin.value = true;
        }

        SmartDialog.showToast('main登录成功');
        if (response != Pref.userInfoCache) {
          await GStorage.userInfo.put('userInfoCache', response);
        }
        await SynapseSyncService.maybeShowStartupPrompt();
        unawaited(SynapseSyncService.syncAllBilibiliAccounts());
      }
    } else {
      // 获取用户信息失败
      final errMsg = res.toString();
      if (errMsg == '账号未登录') {
        await Accounts.deleteAll({account});
        SmartDialog.showNotify(
          msg: '登录失败，请检查cookie是否正确，$errMsg',
          notifyType: .warning,
        );
      } else {
        // 非“账号未登录”的失败：Accounts.main 已是新账号，但会话状态
        // (isLogin / userInfoCache) 仍可能指向旧账号或匿名状态，导致 UI
        // 显示“已登录却按错误账号鉴权”。这里把会话对齐到实际的 main 账号。
        SmartDialog.showToast(errMsg);
        final accountService = Get.find<AccountService>();
        if (accountService.isLogin.value) {
          accountService.isLogin.refresh();
        } else {
          accountService.isLogin.value = true;
        }
        final cached = Pref.userInfoCache;
        if (cached?.mid != Accounts.main.mid) {
          accountService.face.value = '';
          await GStorage.userInfo.delete('userInfoCache');
        } else {
          accountService.face.value = cached?.face ?? '';
        }
      }
    }
  }

  static Future<void> onLogoutMain() {
    Get.find<AccountService>()
      ..face.value = ''
      ..isLogin.value = false;

    return Future.wait([
      SynapseSyncService.disableForLogout(),
      if (Platform.isLinux)
        LinuxCookieManager.deleteAllCookies()
      else
        web.CookieManager.instance(
          webViewEnvironment: webViewEnvironment,
        ).deleteAllCookies(),
      GStorage.userInfo.delete('userInfoCache'),
    ]);
  }

  static String generateBuvid() {
    final md5Str = Digest(
      List.generate(16, (_) => Utils.random.nextInt(256)),
    ).toString();
    final buvid = 'XY${md5Str[2]}${md5Str[12]}${md5Str[22]}$md5Str';
    BilibiliDeviceIdentity.buvid = buvid;
    return buvid;
  }

  static String get buvid => Pref.buvid;

  // static String getUUID() {
  //   return const Uuid().v4().replaceAll('-', '');
  // }

  // static String generateBuvid() {
  //   String uuid = getUUID() + getUUID();
  //   return 'XY${uuid.substring(0, 35).toUpperCase()}';
  // }

  static String genDeviceId() {
    // https://github.com/bilive/bilive_client/blob/2873de0532c54832f5464a4c57325ad9af8b8698/bilive/lib/app_client.ts#L62
    final time = DateTime.now();

    final List<int> bytes = [
      ...Iterable.generate(16, (_) => Utils.random.nextInt(256)),
      _dec2bcd(time.year ~/ 100),
      _dec2bcd(time.year % 100),
      _dec2bcd(time.month),
      _dec2bcd(time.day),
      _dec2bcd(time.hour),
      _dec2bcd(time.minute),
      _dec2bcd(time.second),
      ...Iterable.generate(8, (_) => Utils.random.nextInt(256)),
    ];
    final check = (bytes.sum & 0xFF).toRadixString(16).padLeft(2, '0');

    return Digest(bytes).toString() + check;
  }

  static int _dec2bcd(int dec) {
    assert(0 <= dec && dec < 100);
    return ((dec ~/ 10) << 4) | (dec % 10);
  }
}
