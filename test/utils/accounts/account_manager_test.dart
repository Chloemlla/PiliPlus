import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/account_manager/account_mgr.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cookie-load failure rejects the request once', () async {
    final adapter = _ResponseAdapter(statusCode: 200);
    final dio = _createDio(
      adapter,
      LoginAccount(
        _ThrowingCookieJar(failLoad: true),
        null,
        null,
      ),
    );

    final zoneErrors = await _captureZoneErrors(() async {
      await expectLater(
        dio.post<void>('https://example.com/request'),
        throwsA(isA<DioException>()),
      );
    });

    expect(adapter.calls, 0);
    expect(zoneErrors, isEmpty);
    dio.close(force: true);
  });

  test('cookie-save failure still forwards a valid response once', () async {
    final adapter = _ResponseAdapter(statusCode: 200, includeCookie: true);
    final dio = _createDio(
      adapter,
      LoginAccount(
        _ThrowingCookieJar(failSave: true),
        null,
        null,
      ),
    );

    final zoneErrors = await _captureZoneErrors(() async {
      final response = await dio.post<void>('https://example.com/response');
      expect(response.statusCode, 200);
    });

    expect(adapter.calls, 1);
    expect(zoneErrors, isEmpty);
    dio.close(force: true);
  });

  test('error-response cookie failure forwards one wrapped error', () async {
    final adapter = _ResponseAdapter(statusCode: 500, includeCookie: true);
    final dio = _createDio(
      adapter,
      LoginAccount(
        _ThrowingCookieJar(failSave: true),
        null,
        null,
      ),
    );

    final zoneErrors = await _captureZoneErrors(() async {
      await expectLater(
        dio.post<void>('https://example.com/error'),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'error',
            isA<StateError>(),
          ),
        ),
      );
    });

    expect(adapter.calls, 1);
    expect(zoneErrors, isEmpty);
    dio.close(force: true);
  });
}

Dio _createDio(_ResponseAdapter adapter, LoginAccount account) {
  final dio = Dio(
    BaseOptions(
      extra: {'account': account},
    ),
  );
  return dio
    ..httpClientAdapter = adapter
    ..interceptors.add(AccountManager(blockServer: 'https://block.invalid'));
}

Future<List<Object>> _captureZoneErrors(Future<void> Function() body) async {
  final errors = <Object>[];
  await runZonedGuarded<Future<void>>(
    body,
    (error, stackTrace) => errors.add(error),
  );
  await Future<void>.delayed(Duration.zero);
  return errors;
}

final class _ThrowingCookieJar extends DefaultCookieJar {
  _ThrowingCookieJar({this.failLoad = false, this.failSave = false});

  final bool failLoad;
  final bool failSave;

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) {
    if (failLoad) {
      return Future<List<Cookie>>.error(
        StateError('cookie load failed'),
      );
    }
    return super.loadForRequest(uri);
  }

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) {
    if (failSave) {
      return Future<void>.error(StateError('cookie save failed'));
    }
    return super.saveFromResponse(uri, cookies);
  }
}

final class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter({required this.statusCode, this.includeCookie = false});

  final int statusCode;
  final bool includeCookie;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return Future<ResponseBody>.value(
      ResponseBody.fromString(
        '',
        statusCode,
        headers: {
          if (includeCookie) HttpHeaders.setCookieHeader: ['sid=value; Path=/'],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}
