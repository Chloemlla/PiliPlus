import 'package:pili_plus/utils/app_scheme.dart';
import 'package:pili_plus/utils/mobile_observer.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

abstract final class ClipboardVideoLinkHandler {
  static final _supportedUrlRegExp = RegExp(
    r'((?:https?://)?(?:(?:(?:www|m)\.)?bilibili\.com/video/(?:av\d+|BV1[0-9A-Za-z]{9})|(?:share\.)?b23\.tv/[^\s/]+)(?:[/?#][^\s]*)?)',
    caseSensitive: false,
  );
  static const _trailingPunctuation = '.,，。;；!！?？)）]】>》\'"';
  static const _sameLinkThrottle = Duration(seconds: 3);

  static bool _isHandling = false;
  static bool _observerInitialized = false;
  static final _observer = _ClipboardVideoLinkObserver();
  static String? _lastHandledLink;
  static DateTime? _lastHandledAt;

  static void init() {
    if (_observerInitialized) return;
    _observerInitialized = true;
    addObserverMobile(_observer);
  }

  static void dispose() {
    if (!_observerInitialized) return;
    _observerInitialized = false;
    removeObserverMobile(_observer);
  }

  static Future<void> checkAndOpen() async {
    if (!Pref.autoOpenClipboardVideoLink || _isHandling) return;

    _isHandling = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;

      final link = extractVideoLink(text);
      if (link == null) return;

      final now = DateTime.now();
      if (_lastHandledLink == link &&
          _lastHandledAt != null &&
          now.difference(_lastHandledAt!) < _sameLinkThrottle) {
        return;
      }

      final shouldAskBeforeOpen = Get.currentRoute == '/videoV';
      if (shouldAskBeforeOpen && !await _confirmOpen(link)) {
        _lastHandledLink = link;
        _lastHandledAt = now;
        return;
      }

      final handled = await PiliScheme.routePushFromUrl(
        link,
        selfHandle: true,
        off: shouldAskBeforeOpen,
      );
      if (handled) {
        _lastHandledLink = link;
        _lastHandledAt = now;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('check clipboard video link failed: $e');
    } finally {
      _isHandling = false;
    }
  }

  static String? extractVideoLink(String text) {
    final link = _supportedUrlRegExp.firstMatch(text)?.group(1);
    return link == null ? null : _trimLink(link);
  }

  static String _trimLink(String link) {
    while (link.isNotEmpty &&
        _trailingPunctuation.contains(link[link.length - 1])) {
      link = link.substring(0, link.length - 1);
    }
    return link;
  }

  static Future<bool> _confirmOpen(String link) async {
    final context = Get.context;
    if (context == null) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('打开剪贴板视频？'),
            content: Text(
              link,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('打开'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _ClipboardVideoLinkObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ClipboardVideoLinkHandler.checkAndOpen();
    }
  }
}
