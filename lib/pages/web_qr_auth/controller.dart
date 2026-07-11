import 'dart:async';

import 'package:pili_plus/http/web_qr_auth.dart';
import 'package:pili_plus/models_new/web_qr_auth/code.dart';
import 'package:pili_plus/models_new/web_qr_auth/scene.dart';
import 'package:pili_plus/pages/login/geetest/geetest_webview_dialog.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/android/qr_scanner.dart';
import 'package:pili_plus/utils/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

enum WebQrAuthStage { idle, loading, ready, confirming, success, error }

final class WebQrAuthController extends GetxController {
  final stage = WebQrAuthStage.idle.obs;
  final scene = Rxn<WebQrAuthScene>();
  final message = ''.obs;
  final selectedEnvironment = RxnString();
  final transientLogin = false.obs;
  final maskedPhone = RxnString();
  final smsSending = false.obs;
  final smsVerifying = false.obs;
  final scanning = false.obs;
  final phoneVerified = false.obs;
  final smsCooldown = 0.obs;
  final smsCodeController = TextEditingController();

  WebQrLoginCode? _loginCode;
  Account? _account;
  String? _verifyKey;
  String? _verifyCode;
  Timer? _smsTimer;
  int _generation = 0;

  int get accountMid => (_account ?? Accounts.main).mid;
  bool get canStartInput =>
      stage.value != .loading &&
      stage.value != .confirming &&
      !smsSending.value &&
      !smsVerifying.value &&
      !scanning.value;

  Future<void> scanCamera() => _runScanner(AndroidQrScanner.scanCamera);

  Future<void> scanImage() => _runScanner(AndroidQrScanner.scanImage);

  Future<void> submitManualUrl(String value) => acceptRawValue(value);

  Future<void> _runScanner(Future<String?> Function() scanner) async {
    if (!_ensureLoggedIn()) return;
    if (!canStartInput) {
      SmartDialog.showToast('当前授权请求正在处理中');
      return;
    }
    scanning.value = true;
    try {
      final value = await scanner();
      if (isClosed) return;
      scanning.value = false;
      if (value != null) {
        await acceptRawValue(value);
      }
    } on AndroidQrScannerException catch (error) {
      if (isClosed) return;
      if (error.canOpenSettings) {
        await _showPermissionDialog(error.message);
      } else {
        SmartDialog.showToast(error.message);
      }
    } catch (_) {
      if (isClosed) return;
      SmartDialog.showToast('二维码识别失败，请重试');
    } finally {
      if (!isClosed) scanning.value = false;
    }
  }

  Future<void> acceptRawValue(String value) async {
    if (!_ensureLoggedIn()) return;
    if (!canStartInput) {
      SmartDialog.showToast('当前授权请求正在处理中');
      return;
    }
    final WebQrLoginCode loginCode;
    try {
      loginCode = WebQrLoginCode.parse(value);
    } on FormatException catch (error) {
      SmartDialog.showToast(error.message.toString());
      return;
    }

    _resetAuthorization();
    final generation = _generation;
    _loginCode = loginCode;
    stage.value = .loading;
    message.value = '正在读取网页登录信息';
    final account = Accounts.main;
    _account = account;
    try {
      await WebQrAuthHttp.check(account, loginCode.key);
      if (!_isCurrent(generation)) return;
      final response = await WebQrAuthHttp.scene(account, loginCode.key);
      if (!_isCurrent(generation)) return;
      if (response.requiresEnvironment && response.environments.length == 1) {
        selectedEnvironment.value = response.environments.single.key;
      }
      scene.value = response;
      stage.value = .ready;
      message.value = '';
      if (response.requiresPhoneVerification) {
        unawaited(_loadMaskedPhone(generation, account));
      }
    } on WebQrAuthException catch (error) {
      if (!_isCurrent(generation)) return;
      _setError(error.isExpired ? '二维码已过期，请重新扫描' : error.message);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _setError('无法读取网页登录信息，请稍后重试');
    }
  }

  Future<void> confirm() async {
    final loginCode = _loginCode;
    final account = _account;
    final generation = _generation;
    final currentScene = scene.value;
    if (loginCode == null ||
        account == null ||
        currentScene == null ||
        stage.value != .ready) {
      return;
    }
    if (currentScene.requiresEnvironment && selectedEnvironment.value == null) {
      SmartDialog.showToast('请选择本次登录环境');
      return;
    }
    if (currentScene.requiresPhoneVerification && !phoneVerified.value) {
      SmartDialog.showToast('请先完成手机号验证');
      return;
    }
    if (smsSending.value || smsVerifying.value) {
      SmartDialog.showToast('手机号验证正在处理中');
      return;
    }
    if (currentScene.locationDiffers &&
        !await _confirmLocationRisk(currentScene.location)) {
      return;
    }
    if (!_isCurrent(generation)) return;

    stage.value = .confirming;
    message.value = '正在确认网页登录';
    try {
      await WebQrAuthHttp.confirm(
        account: account,
        qrcodeKey: loginCode.key,
        transient: transientLogin.value,
        environmentKey: selectedEnvironment.value,
        verifyKey: _verifyKey,
        verifyCode: _verifyCode,
      );
      if (!_isCurrent(generation)) return;
      stage.value = .success;
      message.value = '网页端登录授权成功';
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (_isCurrent(generation) && Get.currentRoute == '/webQrAuth') {
        Get.back();
      }
    } on WebQrAuthException catch (error) {
      if (!_isCurrent(generation)) return;
      stage.value = .ready;
      message.value = '';
      SmartDialog.showToast(
        error.isExpired ? '二维码已过期，请重新扫描' : error.message,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      stage.value = .ready;
      message.value = '';
      SmartDialog.showToast('确认授权失败，请稍后重试');
    }
  }

  Future<void> sendSms() async {
    if (smsSending.value || smsCooldown.value > 0) return;
    final generation = _generation;
    final account = _account;
    if (account == null) return;
    _verifyCode = null;
    phoneVerified.value = false;
    smsSending.value = true;
    try {
      final captcha = await WebQrAuthHttp.prepareCaptcha(account);
      if (!_isCurrent(generation)) return;
      final result = await GeetestWebviewDialog.geetest(
        captcha.gt,
        captcha.challenge,
      );
      if (!_isCurrent(generation)) return;
      if (result is! Map) return;
      final challenge =
          _mapString(result, 'geetest_challenge') ?? captcha.challenge;
      final validate = _mapString(result, 'geetest_validate');
      final seccode = _mapString(result, 'geetest_seccode');
      if (validate == null || seccode == null) {
        SmartDialog.showToast('人机验证结果不完整，请重试');
        return;
      }
      final verifyKey = await WebQrAuthHttp.sendSms(
        account: account,
        captcha: captcha,
        geetestChallenge: challenge,
        geetestValidate: validate,
        geetestSeccode: seccode,
      );
      if (!_isCurrent(generation)) return;
      _verifyKey = verifyKey;
      _verifyCode = null;
      phoneVerified.value = false;
      _startSmsCooldown();
      SmartDialog.showToast('短信验证码已发送');
    } on WebQrAuthException catch (error) {
      if (!_isCurrent(generation)) return;
      SmartDialog.showToast(error.message);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      SmartDialog.showToast('短信验证码发送失败，请重试');
    } finally {
      if (_isCurrent(generation)) smsSending.value = false;
    }
  }

  Future<void> verifySms() async {
    if (smsVerifying.value) return;
    final generation = _generation;
    final account = _account;
    if (account == null) return;
    final captchaKey = _verifyKey;
    final code = smsCodeController.text.trim();
    if (captchaKey == null) {
      SmartDialog.showToast('请先发送短信验证码');
      return;
    }
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      SmartDialog.showToast('请输入有效的短信验证码');
      return;
    }
    smsVerifying.value = true;
    try {
      await WebQrAuthHttp.verifySms(
        account: account,
        captchaKey: captchaKey,
        code: code,
      );
      if (!_isCurrent(generation)) return;
      _verifyCode = code;
      phoneVerified.value = true;
      SmartDialog.showToast('手机号验证成功');
    } on WebQrAuthException catch (error) {
      if (!_isCurrent(generation)) return;
      SmartDialog.showToast(error.message);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      SmartDialog.showToast('短信验证码校验失败，请重试');
    } finally {
      if (_isCurrent(generation)) smsVerifying.value = false;
    }
  }

  void retry() {
    _resetAuthorization();
    stage.value = .idle;
    message.value = '';
  }

  Future<void> _loadMaskedPhone(int generation, Account account) async {
    try {
      final value = await WebQrAuthHttp.getMaskedPhone(account);
      if (_isCurrent(generation)) maskedPhone.value = value;
    } catch (_) {
      if (_isCurrent(generation)) maskedPhone.value = null;
    }
  }

  bool _ensureLoggedIn() {
    if (Accounts.main.isLogin) return true;
    SmartDialog.showToast('请先登录并设置主账号');
    return false;
  }

  Future<void> _showPermissionDialog(String text) async {
    final context = Get.context;
    if (context == null) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要相机权限'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('打开设置'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await openAppSettings();
    }
  }

  Future<bool> _confirmLocationRisk(String? location) async {
    final context = Get.context;
    if (context == null) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('确认异地网页登录'),
            content: Text(
              location == null
                  ? '检测到登录位置不同。请确认二维码所在的设备在你身边。'
                  : '登录位置：$location\n\n请确认二维码所在的设备在你身边，继续操作将允许该设备登录。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消授权'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认继续'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _startSmsCooldown() {
    _smsTimer?.cancel();
    smsCooldown.value = 60;
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (smsCooldown.value <= 1) {
        smsCooldown.value = 0;
        timer.cancel();
      } else {
        smsCooldown.value--;
      }
    });
  }

  void _setError(String value) {
    scene.value = null;
    stage.value = .error;
    message.value = value;
  }

  void _resetAuthorization() {
    _generation++;
    _loginCode = null;
    _account = null;
    scene.value = null;
    selectedEnvironment.value = null;
    transientLogin.value = false;
    maskedPhone.value = null;
    smsSending.value = false;
    smsVerifying.value = false;
    phoneVerified.value = false;
    smsCodeController.clear();
    _verifyKey = null;
    _verifyCode = null;
    _smsTimer?.cancel();
    smsCooldown.value = 0;
  }

  bool _isCurrent(int generation) => !isClosed && generation == _generation;

  static String? _mapString(Map map, String key) {
    final value = map[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  void onClose() {
    _generation++;
    _smsTimer?.cancel();
    smsCodeController.dispose();
    super.onClose();
  }
}
