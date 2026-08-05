import 'dart:async';

import 'package:pili_plus/http/init.dart';
import 'package:dio/dio.dart';

/// Injectable seam for measuring throughput against the current video CDN.
abstract interface class NetworkSpeedProbe {
  Future<double?> measure(
    Uri uri, {
    required Duration maxDuration,
  });
}

/// Measures real response throughput with a bounded byte-range request.
///
/// The stream is stopped after [maxBytes] or [maxDuration], whichever comes
/// first. A server that ignores the Range header is still bounded because the
/// response subscription is cancelled once the limit is reached.
final class BiliCdnNetworkSpeedProbe implements NetworkSpeedProbe {
  BiliCdnNetworkSpeedProbe({
    Dio Function()? dioProvider,
    this.maxBytes = 3 * 1024 * 1024,
    this.minimumBytes = 32 * 1024,
  }) : _dioProvider = dioProvider ?? (() => Request.http11Dio);

  final Dio Function() _dioProvider;
  final int maxBytes;
  final int minimumBytes;

  @override
  Future<double?> measure(
    Uri uri, {
    required Duration maxDuration,
  }) async {
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final cancelToken = CancelToken();
    final stopwatch = Stopwatch()..start();
    StreamSubscription<List<int>>? subscription;
    Timer? deadline;
    Completer<void>? streamCompleted;
    var receivedBytes = 0;

    try {
      deadline = Timer(maxDuration, () {
        final completed = streamCompleted;
        if (completed == null) {
          if (!cancelToken.isCancelled) {
            cancelToken.cancel('quality speed probe timed out');
          }
        } else if (!completed.isCompleted) {
          completed.complete();
        }
      });
      final response = await _dioProvider().get<ResponseBody>(
        uri.toString(),
        options: Options(
          headers: {
            'range': 'bytes=0-${maxBytes - 1}',
            'accept-encoding': 'identity',
            'referer': 'https://www.bilibili.com/',
          },
          responseType: ResponseType.stream,
          receiveTimeout: maxDuration,
          validateStatus: (status) => status == 200 || status == 206,
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) return null;

      final completed = Completer<void>();
      streamCompleted = completed;
      void finish() {
        if (!completed.isCompleted) completed.complete();
      }

      subscription = body.stream.listen(
        (chunk) {
          receivedBytes += chunk.length;
          if (receivedBytes >= maxBytes) finish();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completed.isCompleted) {
            completed.completeError(error, stackTrace);
          }
        },
        onDone: finish,
        cancelOnError: true,
      );
      await completed.future;
    } catch (_) {
      return null;
    } finally {
      stopwatch.stop();
      deadline?.cancel();
      await subscription?.cancel();
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('quality speed probe finished');
      }
    }

    if (receivedBytes < minimumBytes || stopwatch.elapsedMicroseconds <= 0) {
      return null;
    }

    // One bit per microsecond equals one megabit per second.
    return receivedBytes * 8 / stopwatch.elapsedMicroseconds;
  }
}
