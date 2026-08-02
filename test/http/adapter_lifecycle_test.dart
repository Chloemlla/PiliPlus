import 'dart:typed_data';

import 'package:pili_plus/http/adapter_lifecycle.dart';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http2/http2.dart';

void main() {
  test('HTTP/2 replacements are installed before old pools drain', () {
    final events = <String>[];
    final oldManager = _RecordingConnectionManager('oldManager', events);
    final newManager = _RecordingConnectionManager('newManager', events);
    final oldFallback = _RecordingAdapter('oldFallback', events);
    final newFallback = _RecordingAdapter('newFallback', events);
    final adapter = Http2Adapter(
      oldManager,
      fallbackAdapter: oldFallback,
    );

    replaceHttp2AdapterPool(
      adapter: adapter,
      connectionManager: newManager,
      fallbackAdapter: newFallback,
      installHttp11Adapter: (installed) {
        expect(adapter.connectionManager, same(newManager));
        expect(adapter.fallbackAdapter, same(newFallback));
        expect(installed, same(newFallback));
        events.add('installed');
      },
    );

    expect(events, [
      'installed',
      'oldManager.close:false',
      'oldFallback.close:false',
    ]);
    expect(oldManager.force, isFalse);
    expect(oldFallback.force, isFalse);
  });

  test('HTTP/1.1 replacement is installed before graceful close', () {
    final events = <String>[];
    late final Dio dio;
    final replacement = _RecordingAdapter('new', events);
    final previous = _RecordingAdapter(
      'old',
      events,
      onClose: () {
        expect(dio.httpClientAdapter, same(replacement));
      },
    );
    dio = Dio()..httpClientAdapter = previous;

    replaceHttpClientAdapter(dio: dio, adapter: replacement);

    expect(events, ['old.close:false']);
    expect(previous.force, isFalse);
  });
}

final class _RecordingConnectionManager implements ConnectionManager {
  _RecordingConnectionManager(this.name, this.events);

  final String name;
  final List<String> events;
  bool? force;

  @override
  int get cachedConnectionsCount => 0;

  @override
  void close({bool force = false}) {
    this.force = force;
    events.add('$name.close:$force');
  }

  @override
  Future<ClientTransportConnection> getConnection(
    RequestOptions options,
    List<RedirectRecord> redirects,
  ) => throw UnimplementedError();

  @override
  void removeConnection(ClientTransportConnection transport) {}
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.name, this.events, {this.onClose});

  final String name;
  final List<String> events;
  final void Function()? onClose;
  bool? force;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw UnimplementedError();

  @override
  void close({bool force = false}) {
    this.force = force;
    onClose?.call();
    events.add('$name.close:$force');
  }
}
