import 'package:pili_plus/plugin/pl_player/utils/stream_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlPlayerStreamError', () {
    test('classifies premature HTTP stream endings as recoverable', () {
      expect(
        PlPlayerStreamError.isInterruptedNetworkStream(
          'https: Stream ends prematurely at 43579125, should be 66466136',
        ),
        isTrue,
      );
      expect(
        PlPlayerStreamError.isInterruptedNetworkStream(
          'http: Stream ends prematurely at 1, should be 2',
        ),
        isTrue,
      );
    });

    test('keeps unrelated player errors reportable', () {
      expect(
        PlPlayerStreamError.isInterruptedNetworkStream('Could not open codec'),
        isFalse,
      );
      expect(
        PlPlayerStreamError.isNetworkOpenError('Could not open codec'),
        isFalse,
      );
    });

    test('keeps existing network open errors recoverable', () {
      expect(
        PlPlayerStreamError.isNetworkOpenError(
          'Failed to open https://example.invalid/video.m4s',
        ),
        isTrue,
      );
      expect(
        PlPlayerStreamError.isNetworkOpenError(
          'Can not open external file https://example.invalid/audio.m4s',
        ),
        isTrue,
      );
      expect(
        PlPlayerStreamError.isNetworkOpenError(
          'tcp: ffurl_read returned 0xffffff99',
        ),
        isTrue,
      );
    });
  });
}
