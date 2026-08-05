import 'dart:async';
import 'dart:typed_data';

import 'package:pili_plus/http/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled requests are not replayed after transport failures', () async {
    final dio = Dio();
    final adapter = _FailingAdapter();
    dio
      ..httpClientAdapter = adapter
      ..interceptors.add(RetryInterceptor(dio, 2, 0));

    await expectLater(
      dio.get<void>(
        'https://example.com/security-sensitive-operation',
        options: Options(
          extra: {RetryInterceptor.disableRetryKey: true},
        ),
      ),
      throwsA(isA<DioException>()),
    );

    expect(adapter.calls, 1);
    dio.close(force: true);
  });

  test('transport failure is resolved once after a successful retry', () async {
    final dio = Dio();
    final adapter = _FailThenSucceedAdapter();
    dio
      ..httpClientAdapter = adapter
      ..interceptors.add(RetryInterceptor(dio, 1, 0));

    final zoneErrors = await _captureZoneErrors(() async {
      final response = await dio.get<String>('https://example.com/video');
      expect(response.data, 'ok');
    });

    expect(adapter.calls, 2);
    expect(zoneErrors, isEmpty);
    dio.close(force: true);
  });

  test(
    'exhausted retry rejects once without an uncaught handler error',
    () async {
      final dio = Dio();
      final adapter = _FailingAdapter();
      dio
        ..httpClientAdapter = adapter
        ..interceptors.add(RetryInterceptor(dio, 1, 0));

      final zoneErrors = await _captureZoneErrors(() async {
        await expectLater(
          dio.get<void>('https://example.com/video'),
          throwsA(isA<DioException>()),
        );
      });

      expect(adapter.calls, 2);
      expect(zoneErrors, isEmpty);
      dio.close(force: true);
    },
  );

  test('redirect replay failure rejects once', () async {
    final dio = Dio();
    final adapter = _RedirectThenFailAdapter();
    dio
      ..httpClientAdapter = adapter
      ..interceptors.add(RetryInterceptor(dio, 0, 0));

    final zoneErrors = await _captureZoneErrors(() async {
      await expectLater(
        dio.get<void>('https://example.com/redirect'),
        throwsA(isA<DioException>()),
      );
    });

    expect(adapter.calls, 2);
    expect(zoneErrors, isEmpty);
    dio.close(force: true);
  });
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

final class _FailingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return Future<ResponseBody>.error(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const FormatException('simulated transport failure'),
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _FailThenSucceedAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    if (calls == 1) {
      return Future<ResponseBody>.error(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const FormatException('simulated transport failure'),
        ),
      );
    }
    return Future<ResponseBody>.value(ResponseBody.fromString('ok', 200));
  }

  @override
  void close({bool force = false}) {}
}

final class _RedirectThenFailAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    if (calls == 1) {
      return Future<ResponseBody>.value(
        ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['/next'],
          },
        ),
      );
    }
    return Future<ResponseBody>.error(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const FormatException('redirect replay failed'),
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}
