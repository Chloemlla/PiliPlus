import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/utils/seal_download_title.dart';

void main() {
  group('resolveSealMediaTitle', () {
    test('falls back to bvid when no title sources are set', () {
      expect(
        resolveSealMediaTitle(bvid: 'BV1xx411c7mD'),
        'BV1xx411c7mD',
      );
    });

    test('uses empty watchLaterTitle safely (no LateError)', () {
      expect(
        resolveSealMediaTitle(
          args: const <String, dynamic>{},
          watchLaterTitle: '',
          bvid: 'BV1fallback',
        ),
        'BV1fallback',
      );
    });

    test('prefers route title over favTitle and watchLaterTitle', () {
      expect(
        resolveSealMediaTitle(
          args: <String, dynamic>{
            'title': '  Video Title  ',
            'favTitle': 'Playlist',
          },
          watchLaterTitle: 'Later',
          bvid: 'BV1xx',
        ),
        'Video Title',
      );
    });

    test('uses favTitle when title missing', () {
      expect(
        resolveSealMediaTitle(
          args: <String, dynamic>{'favTitle': '  稍后再看  '},
          watchLaterTitle: 'Later Panel',
          bvid: 'BV1xx',
        ),
        '稍后再看',
      );
    });

    test('uses watchLaterTitle when args have no titles', () {
      expect(
        resolveSealMediaTitle(
          args: <String, dynamic>{'bvid': 'BV1xx'},
          watchLaterTitle: '  收藏夹 · 测试  ',
          bvid: 'BV1xx',
        ),
        '收藏夹 · 测试',
      );
    });

    test('ignores blank title and blank favTitle', () {
      expect(
        resolveSealMediaTitle(
          args: <String, dynamic>{'title': '   ', 'favTitle': ''},
          watchLaterTitle: 'Panel',
          bvid: 'BV1xx',
        ),
        'Panel',
      );
    });
  });
}
