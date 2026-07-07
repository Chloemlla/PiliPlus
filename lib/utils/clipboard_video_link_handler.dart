import 'package:pili_plus/utils/app_scheme.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class ClipboardVideoLinkHandler {
  static final _videoUrlRegExp = RegExp(
    r'((?:https?://)?(?:(?:www|m)\.)?bilibili\.com/video/(?:av\d+|BV1[0-9A-Za-z]{9})(?:[/?#][^\s]*)?)',
    caseSensitive: false,
  );
  static const _trailingPunctuation = '.,，。;；!！?？)）]】>》\'"';
  static const _sameLinkThrottle = Duration(seconds: 3);

  static bool _isHandling = false;
  static String? _lastHandledLink;
  static DateTime? _lastHandledAt;

  static Future<void> checkAndOpen() async {
    if (!Pref.autoOpenClipboardVideoLink || _isHandling) return;

    _isHandling = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;

      final link = _extractVideoLink(text);
      if (link == null) return;

      final now = DateTime.now();
      if (_lastHandledLink == link &&
          _lastHandledAt != null &&
          now.difference(_lastHandledAt!) < _sameLinkThrottle) {
        return;
      }

      final handled = await PiliScheme.routePushFromUrl(
        link,
        selfHandle: true,
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

  static String? _extractVideoLink(String text) {
    final link = _videoUrlRegExp.firstMatch(text)?.group(1);
    return link == null ? null : _trimLink(link);
  }

  static String _trimLink(String link) {
    while (link.isNotEmpty &&
        _trailingPunctuation.contains(link[link.length - 1])) {
      link = link.substring(0, link.length - 1);
    }
    return link;
  }
}
