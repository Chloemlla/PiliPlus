import 'dart:async';
import 'dart:io';

import 'package:pili_plus/utils/web_cookie_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a valid HTTPS origin and waits for every cookie write', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    final origins = <Uri>[];
    final writtenNames = <String>[];
    var completed = false;

    final sync =
        WebCookieSync.writeAll(
          [Cookie('SESSDATA', 'session'), Cookie('bili_jct', 'csrf')],
          write: (origin, cookie) {
            origins.add(origin);
            writtenNames.add(cookie.name);
            return cookie.name == 'SESSDATA' ? first.future : second.future;
          },
        ).then<void>((_) {
          completed = true;
        });
    await Future<void>.delayed(Duration.zero);

    expect(writtenNames, ['SESSDATA', 'bili_jct']);
    expect(
      origins,
      everyElement(
        predicate<Uri>(
          (origin) =>
              origin.scheme == 'https' &&
              origin.host == 'www.bilibili.com' &&
              !origin.toString().contains(' '),
        ),
      ),
    );
    expect(completed, isFalse);

    first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    second.complete();
    await sync;
    expect(completed, isTrue);
  });

  test('reports the cookie name when a platform write fails', () async {
    const secretValue = 'session-secret-value';
    await expectLater(
      WebCookieSync.writeAll(
        [Cookie('SESSDATA', secretValue)],
        write: (_, _) async => throw StateError(
          'platform rejected cookie value=$secretValue',
        ),
      ),
      throwsA(
        isA<StateError>()
            .having(
              (error) => error.message,
              'message',
              contains('SESSDATA'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains(secretValue)),
            ),
      ),
    );
  });
}
