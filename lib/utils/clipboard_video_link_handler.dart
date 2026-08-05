import 'package:pili_plus/utils/app_scheme.dart';
import 'package:pili_plus/utils/id_utils.dart';
import 'package:pili_plus/utils/mobile_observer.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:pili_plus/utils/url_utils.dart';
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
  static final _urlPrefixRegExp = RegExp(r'^\S+://');

  static bool _isHandling = false;
  static bool _observerInitialized = false;
  static final _observer = _ClipboardVideoLinkObserver();
  static final _handledLinks = <String>{};
  static final _handledVideoKeys = <String>{};
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

      final resolvedLink = await _resolveVideoLink(link);
      final now = DateTime.now();
      if (_isHandledInSession(resolvedLink) ||
          _lastHandledLink == resolvedLink.link &&
          _lastHandledAt != null &&
          now.difference(_lastHandledAt!) < _sameLinkThrottle) {
        return;
      }

      final shouldAskBeforeOpen = Get.currentRoute == '/videoV';
      if (shouldAskBeforeOpen && !await _confirmOpen(resolvedLink.link)) {
        _markHandled(resolvedLink, now);
        return;
      }

      final handled = await PiliScheme.routePushFromUrl(
        resolvedLink.link,
        selfHandle: true,
        off: shouldAskBeforeOpen,
      );
      if (handled) {
        _markHandled(resolvedLink, now);
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

  static Future<_ResolvedVideoLink> _resolveVideoLink(String link) async {
    var resolved = _ensureUrlScheme(link);
    var uri = Uri.tryParse(resolved);

    if (uri != null && _isB23Host(uri)) {
      final redirectUrl = await UrlUtils.parseRedirectUrl(resolved);
      if (redirectUrl != null) {
        resolved = redirectUrl;
        uri = Uri.tryParse(resolved);
      }
    }

    return _ResolvedVideoLink(
      link: resolved,
      videoKey: _videoKeyFromUri(uri) ?? _videoKeyFromText(resolved),
    );
  }

  static String _ensureUrlScheme(String link) {
    if (link.startsWith('//')) return 'https:$link';
    if (_urlPrefixRegExp.hasMatch(link)) return link;
    return 'https://$link';
  }

  static bool _isB23Host(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'b23.tv' || host.endsWith('.b23.tv');
  }

  static String? _videoKeyFromUri(Uri? uri) {
    if (uri == null) return null;
    return _videoKeyFromText(uri.path);
  }

  static String? _videoKeyFromText(String text) {
    final res = IdUtils.matchAvorBv(input: text);
    if (res.av != null) return 'aid:${res.av}';
    if (res.bv == null) return null;

    final bvid = 'BV${res.bv!.substring(2)}';
    try {
      return 'aid:${IdUtils.bv2av(bvid)}';
    } catch (_) {
      return 'bvid:$bvid';
    }
  }

  static bool _isHandledInSession(_ResolvedVideoLink link) {
    return _handledLinks.contains(link.link) ||
        (link.videoKey != null && _handledVideoKeys.contains(link.videoKey));
  }

  static void _markHandled(_ResolvedVideoLink link, DateTime now) {
    _handledLinks.add(link.link);
    if (link.videoKey != null) {
      _handledVideoKeys.add(link.videoKey!);
    }
    _lastHandledLink = link.link;
    _lastHandledAt = now;
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

class _ResolvedVideoLink {
  const _ResolvedVideoLink({
    required this.link,
    required this.videoKey,
  });

  final String link;
  final String? videoKey;
}

class _ClipboardVideoLinkObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ClipboardVideoLinkHandler.checkAndOpen();
    }
  }
}
