import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:pili_plus/main.dart';
import 'package:pili_plus/plugin/linux_webview.dart';
import 'package:pili_plus/services/synapse_ip_verification.dart';

/// Synapse 首访闸门的人机验证模块。
///
/// 与网页端 `FirstVisitVerification` / Synapse-Client `TurnstileVerificationView` 等价：
/// 在 WebView 里渲染 Turnstile（优先）或 hCaptcha，把验证码 token 交回调用方去换
/// `/api/ip-verification/complete` 的访问令牌。这里只负责「拿到 captchaToken」，
/// 令牌签发与 40 分钟有效期全由 [SynapseIpVerification] 管。
class SynapseVerificationDialog extends StatefulWidget {
  const SynapseVerificationDialog({
    required this.config,
    required this.pageBaseUrl,
    super.key,
  });

  final SynapseIpVerificationConfig config;
  final String pageBaseUrl;

  /// 返回验证码 token；用户取消或组件失败时返回 null。
  static Future<String?> show({
    required SynapseIpVerificationConfig config,
    required String pageBaseUrl,
  }) {
    final context = Get.context;
    if (context == null) return Future<String?>.value();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SynapseVerificationDialog(
        config: config,
        pageBaseUrl: pageBaseUrl,
      ),
    );
  }

  @override
  State<SynapseVerificationDialog> createState() => _SynapseVerificationDialogState();
}

class _SynapseVerificationDialogState extends State<SynapseVerificationDialog> {
  static const _turnstileScript =
      'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
  static const _hcaptchaScript = 'https://js.hcaptcha.com/1/api.js?render=explicit';

  int _widgetKey = 0;
  String? _error;
  bool _submitting = false;

  String get _siteKey => widget.config.siteKey;

  String _buildHtml() {
    final isTurnstile = widget.config.type == SynapseCaptchaType.turnstile;
    final siteKey = jsonEncode(_siteKey);
    final script = isTurnstile ? _turnstileScript : _hcaptchaScript;
    // Linux 上没有 flutter_inappwebview 的 JS handler，走既有的 webkit 消息桥。
    final report = Platform.isLinux
        ? 'R=(n,o)=>window.webkit.messageHandlers.msgToNative.postMessage(n+":"+JSON.stringify(o))'
        : 'R=(n,o)=>window.flutter_inappwebview?.callHandler(n,o)';
    final render = isTurnstile
        ? '''
        window.turnstile.render('#captcha', {
          sitekey: $siteKey,
          theme: 'light',
          size: 'normal',
          callback: function (token) { R('verify', token || ''); },
          'expired-callback': function () { R('expire', ''); },
          'error-callback': function () { R('error', ''); }
        });'''
        : '''
        window.hcaptcha.render('captcha', {
          sitekey: $siteKey,
          callback: function (token) { R('verify', token || ''); },
          'expired-callback': function () { R('expire', ''); },
          'error-callback': function () { R('error', ''); }
        });''';

    return '<!DOCTYPE html><html><head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
        '<style>'
        'html,body{margin:0;padding:0;background:#ffffff;overflow:hidden;}'
        '#captcha{min-height:78px;display:flex;align-items:center;justify-content:center;}'
        '#E{font:13px sans-serif;color:#c62828;padding:12px;text-align:center;}'
        '</style></head><body>'
        '<div id="captcha"></div><div id="E"></div>'
        '<script>'
        '$report;'
        'var rendered=false;'
        'function fail(){document.getElementById("E").textContent="验证组件加载失败，请重试";R("error","")}'
        'function start(){'
        'if(rendered)return;'
        'if(!(window.turnstile||window.hcaptcha)){window.setTimeout(start,100);return;}'
        'rendered=true;'
        'try{$render}catch(e){fail()}'
        '}'
        'window.addEventListener("load",start);start();'
        '</script>'
        '<script src="$script" async defer></script>'
        '</body></html>';
  }

  void _complete(String token) {
    if (!mounted || _submitting) return;
    if (token.trim().isEmpty) {
      setState(() => _error = '验证未通过，请重新验证。');
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(token);
  }

  void _handleError() {
    if (!mounted) return;
    setState(() => _error = '验证组件加载失败，请重试。');
  }

  @override
  Widget build(BuildContext context) {
    final html = _buildHtml();
    return AlertDialog(
      title: const Text('人机验证'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请完成验证以继续访问 Synapse。'),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: Platform.isLinux
                  ? LinuxWebview(
                      key: ValueKey('linux-$_widgetKey'),
                      initialHtml: html,
                      incognito: true,
                      onWebMessageReceived: _onLinuxMessage,
                    )
                  : InAppWebView(
                      key: ValueKey('webview-$_widgetKey'),
                      webViewEnvironment: webViewEnvironment,
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: false,
                        cacheEnabled: false,
                        allowFileAccess: false,
                        allowContentAccess: false,
                        useShouldOverrideUrlLoading: false,
                        useHybridComposition: true,
                        horizontalScrollBarEnabled: false,
                        verticalScrollBarEnabled: false,
                        overScrollMode: OverScrollMode.NEVER,
                      ),
                      initialData: InAppWebViewInitialData(data: html),
                      onWebViewCreated: (controller) {
                        controller.addJavaScriptHandler(
                          handlerName: 'verify',
                          callback: (args) => _complete(args.isEmpty ? '' : args.first.toString()),
                        );
                        controller.addJavaScriptHandler(
                          handlerName: 'expire',
                          callback: (_) {
                            if (mounted) {
                              setState(() => _error = '验证已过期，请重新验证。');
                            }
                          },
                        );
                        controller.addJavaScriptHandler(
                          handlerName: 'error',
                          callback: (_) => _handleError(),
                        );
                      },
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _error = null;
            _widgetKey += 1;
          }),
          child: const Text('重新验证'),
        ),
      ],
    );
  }

  void _onLinuxMessage(Object? message) {
    final text = message?.toString() ?? '';
    if (text.startsWith('verify:')) {
      final payload = text.substring('verify:'.length);
      String token = payload;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is String) token = decoded;
      } catch (_) {
        // 桥接端偶发非 JSON 载荷时按原文本收下，交由服务端判定有效性。
      }
      _complete(token);
    } else if (text.startsWith('expire:')) {
      if (mounted) setState(() => _error = '验证已过期，请重新验证。');
    } else if (text.startsWith('error:')) {
      _handleError();
    }
  }
}
