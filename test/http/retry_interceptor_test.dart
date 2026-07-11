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
}

final class _FailingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const FormatException('simulated transport failure'),
    );
  }

  @override
  void close({bool force = false}) {}
}
