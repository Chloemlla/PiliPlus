import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

void replaceHttp2AdapterPool({
  required Http2Adapter adapter,
  required ConnectionManager connectionManager,
  required HttpClientAdapter fallbackAdapter,
  required void Function(HttpClientAdapter adapter) installHttp11Adapter,
}) {
  final previousConnectionManager = adapter.connectionManager;
  final previousFallbackAdapter = adapter.fallbackAdapter;

  adapter
    ..connectionManager = connectionManager
    ..fallbackAdapter = fallbackAdapter;
  installHttp11Adapter(fallbackAdapter);

  if (!identical(previousConnectionManager, connectionManager)) {
    previousConnectionManager.close(force: false);
  }
  if (!identical(previousFallbackAdapter, fallbackAdapter)) {
    previousFallbackAdapter.close(force: false);
  }
}

void replaceHttpClientAdapter({
  required Dio dio,
  required HttpClientAdapter adapter,
}) {
  final previousAdapter = dio.httpClientAdapter;
  dio.httpClientAdapter = adapter;
  if (!identical(previousAdapter, adapter)) {
    previousAdapter.close(force: false);
  }
}
