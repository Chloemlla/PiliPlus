import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pili_plus/http/adapter_lifecycle.dart';
import 'package:pili_plus/http/api.dart';
import 'package:pili_plus/http/constants.dart';
import 'package:pili_plus/http/network_security_policy.dart';
import 'package:pili_plus/http/retry_interceptor.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/account_manager/account_mgr.dart';
import 'package:pili_plus/utils/log_redactor.dart';
import 'package:pili_plus/utils/clash_compat.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:pili_plus/utils/utils.dart';
import 'package:archive/archive.dart';
import 'package:brotli/brotli.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, listEquals;

class Request {
  static const _gzipDecoder = GZipDecoder();
  static const _brotliDecoder = BrotliDecoder();

  static final Request _instance = Request._internal();
  static late AccountManager accountManager;
  static bool _accountManagerInstalled = false;
  static final _enableHttp2 = Pref.enableHttp2;
  static late final Dio dio;
  static Dio? _http11Dio;
  static Dio get http11Dio =>
      _http11Dio ??= _enableHttp2 ? _cloneHttp11Dio() : dio;
  factory Request() => _instance;

  static void installAccountManager() {
    if (_accountManagerInstalled) return;
    accountManager = AccountManager();
    dio.interceptors.add(accountManager);
    _accountManagerInstalled = true;
  }

  static Future<void> buvidActive(Account account) async {
    // 这样线程不安全, 但仍按预期进行
    if (account.activated) return;
    account.activated = true;
    try {
      // final html = await Request().get(Api.dynamicSpmPrefix,
      //     options: Options(extra: {'account': account}));
      // final String spmPrefix = _spmPrefixExp.firstMatch(html.data)!.group(1)!;
      final String randPngEnd = base64.encode([
        ...Iterable<int>.generate(32, (_) => Utils.random.nextInt(256)),
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        ...Iterable<int>.generate(4, (_) => Utils.random.nextInt(256)),
      ]);

      final jsonData = json.encode({
        '3064': 1,
        '39c8': '333.1387.fp.risk',
        '3c43': {
          'adca': 'Linux',
          'bfe9': randPngEnd.substring(randPngEnd.length - 50),
        },
      });

      await Request().post(
        Api.activateBuvidApi,
        data: {'payload': jsonData},
        options: Options(
          extra: {'account': account},
          contentType: Headers.jsonContentType,
        ),
      );
    } catch (_) {}
  }

  static Dio _cloneHttp11Dio() {
    final h11 = dio.clone(
      httpClientAdapter:
          (dio.httpClientAdapter as Http2Adapter).fallbackAdapter,
    );
    final interceptors = h11.interceptors;
    for (var i = 0; i < interceptors.length; i++) {
      final elem = interceptors[i];
      if (elem is RetryInterceptor) {
        interceptors[i] = elem.copyWith(client: h11);
        break;
      }
    }
    return h11;
  }

  static Timer? _networkChangeDebounce;

  static void _onConnectivityChanged(List<ConnectivityResult> result) {
    if (listEquals(result, const [ConnectivityResult.none])) {
      return;
    }
    _networkChangeDebounce?.cancel();
    _networkChangeDebounce = Timer(
      const Duration(milliseconds: 500),
      _resetAdaptersForNetworkChange,
    );
  }

  static void _watchConnectivity() {
    Connectivity().onConnectivityChanged.skip(1).listen(_onConnectivityChanged);
  }

  static (IOHttpClientAdapter, ConnectionManager?) _createPool() {
    final bool enableSystemProxy;
    late final String systemProxyHost;
    late final int? systemProxyPort;
    // Clash VPN auto-adapt: traffic already goes through TUN — do not stack HTTP proxy.
    final skipManualProxy =
        Pref.clashAutoAdapt &&
        Platform.isAndroid &&
        ClashCompat.isClashVpnRouting;
    if (Pref.enableSystemProxy && !skipManualProxy) {
      systemProxyHost = Pref.systemProxyHost;
      systemProxyPort = int.tryParse(Pref.systemProxyPort);
      enableSystemProxy = systemProxyPort != null && systemProxyHost.isNotEmpty;
    } else {
      enableSystemProxy = false;
    }

    HttpClient createHttpClient() {
      final client = HttpClient()
        ..idleTimeout = const Duration(seconds: 15)
        ..autoUncompress = false; // Http2Adapter没有自动解压, 统一行为
      if (enableSystemProxy) {
        client.findProxy = (_) => 'PROXY $systemProxyHost:$systemProxyPort';
      }
      if (NetworkSecurityPolicy.shouldBypassCertificateValidation(
        explicitBadCertificateBypass: Pref.badCertificateCallback,
      )) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
      return client;
    }

    final http11Adapter = IOHttpClientAdapter(
      createHttpClient: createHttpClient,
    );

    final connectionManager = _enableHttp2
        ? ConnectionManager(
            idleTimeout: const Duration(seconds: 15),
            onClientCreate: enableSystemProxy || Pref.badCertificateCallback
                ? (_, config) {
                    if (enableSystemProxy) {
                      config.proxy = Uri(
                        scheme: 'http',
                        host: systemProxyHost,
                        port: systemProxyPort,
                      );
                    }
                    if (NetworkSecurityPolicy.shouldBypassCertificateValidation(
                      explicitBadCertificateBypass: Pref.badCertificateCallback,
                    )) {
                      config.onBadCertificate = (_) => true;
                    }
                  }
                : null,
          )
        : null;
    return (http11Adapter, connectionManager);
  }

  @pragma('vm:notify-debugger-on-exception')
  /// Public entry for settings toggle / VPN adapt refresh.
  static void resetAdaptersForClashAdapt() {
    if (Platform.isAndroid) {
      unawaited(() async {
        await ClashCompat.setAutoAdaptEnabled(Pref.clashAutoAdapt);
        await ClashCompat.refresh();
        _lastClashVpnRouting = ClashCompat.isClashVpnRouting;
        _lastClashAutoAdaptPref = Pref.clashAutoAdapt;
        _resetAdaptersForNetworkChange();
      }());
      return;
    }
    _resetAdaptersForNetworkChange();
  }

  static void _resetAdaptersForNetworkChange() {
    try {
      final (h11, connectionManager) = _createPool();
      if (connectionManager != null) {
        replaceHttp2AdapterPool(
          adapter: dio.httpClientAdapter as Http2Adapter,
          connectionManager: connectionManager,
          fallbackAdapter: h11,
          installHttp11Adapter: (adapter) {
            _http11Dio?.httpClientAdapter = adapter;
          },
        );
      } else {
        replaceHttpClientAdapter(dio: dio, adapter: h11);
      }
    } catch (_) {}
  }

  /*
   * config it and create
   */
  Request._internal() {
    //BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    BaseOptions options = BaseOptions(
      //请求基地址,可以包含子路径
      baseUrl: HttpString.apiBaseUrl,
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: const Duration(milliseconds: 10000),
      //响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: const Duration(milliseconds: 10000),
      //Http请求头.
      headers: {
        'user-agent': 'Dart/3.6 (dart:io)', // Http2Adapter不会自动添加标头
        if (!_enableHttp2) 'connection': 'keep-alive',
        'accept-encoding': 'br,gzip',
      },
      responseDecoder: _responseDecoder, // Http2Adapter没有自动解压
      persistentConnection: true,
    );

    final (h11, connectionManager) = _createPool();

    dio = Dio(options)
      ..httpClientAdapter = _enableHttp2
          ? Http2Adapter(connectionManager, fallbackAdapter: h11)
          : h11;

    // 先于其他Interceptor
    if (Pref.retryCount != 0) {
      dio.interceptors.add(
        RetryInterceptor(dio, Pref.retryCount, Pref.retryDelay),
      );
    }

    // 日志拦截器 输出请求、响应内容
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          responseHeader: false,
          logPrint: (value) => debugPrint(
            LogRedactor.redactText(value.toString()),
          ),
        ),
      );
    }

    dio
      ..transformer = BackgroundTransformer()
      ..options.validateStatus = (int? status) {
        return status != null && status >= 200 && status < 300;
      };

    if (Platform.isIOS) {
      _watchConnectivity();
    } else if (Platform.isAndroid) {
      _startClashAutoAdapt();
    }
  }

  // ignore: cancel_subscriptions
  static StreamSubscription<void>? _clashStatusSub;
  static bool? _lastClashVpnRouting;
  static bool? _lastClashAutoAdaptPref;

  static void _startClashAutoAdapt() {
    if (!Platform.isAndroid) return;
    unawaited(
      ClashCompat.ensureStarted().then((_) async {
        // Keep native process-binding flag in sync with Pref.
        await ClashCompat.setAutoAdaptEnabled(Pref.clashAutoAdapt);
        _lastClashVpnRouting = ClashCompat.isClashVpnRouting;
        _lastClashAutoAdaptPref = Pref.clashAutoAdapt;
        if (Pref.clashAutoAdapt) {
          _resetAdaptersForNetworkChange();
        }
      }),
    );
    if (_clashStatusSub != null) return;
    _clashStatusSub = ClashCompat.onStatusChanged.listen((_) {
      final prefEnabled = Pref.clashAutoAdapt;
      // Pref can change outside the status stream; push to native when needed.
      if (_lastClashAutoAdaptPref != prefEnabled) {
        _lastClashAutoAdaptPref = prefEnabled;
        unawaited(ClashCompat.setAutoAdaptEnabled(prefEnabled));
      }
      if (!prefEnabled) {
        // Ensure adapters leave the "skip proxy" path when adapt is off.
        if (_lastClashVpnRouting != false) {
          _lastClashVpnRouting = false;
          _resetAdaptersForNetworkChange();
        }
        return;
      }
      final routing = ClashCompat.isClashVpnRouting;
      if (_lastClashVpnRouting == routing) return;
      _lastClashVpnRouting = routing;
      _resetAdaptersForNetworkChange();
    });
  }

  /*
   * get请求
   */
  Future<Response> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.get<T>(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      return Response(
        data: {
          'message': await AccountManager.dioError(e),
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: e.response?.statusCode ?? -1,
        requestOptions: e.requestOptions,
      );
    }
  }

  /*
   * post请求
   */
  Future<Response> post<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    // if (kDebugMode) debugPrint('post-data: $data');
    try {
      return await dio.post<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      AccountManager.toast(e);
      return Response(
        data: {
          'message': await AccountManager.dioError(e),
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: e.response?.statusCode ?? -1,
        requestOptions: e.requestOptions,
      );
    }
  }

  /*
   * 下载文件
   */
  Future<Response> downloadFile(
    String urlPath,
    String savePath, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.download(
        urlPath,
        savePath,
        cancelToken: cancelToken,
        // onReceiveProgress: (int count, int total) {
        // 进度
        // if (kDebugMode) debugPrint("$count $total");
        // },
      );
      // if (kDebugMode) debugPrint('downloadFile success: ${response.data}');
    } on DioException catch (e) {
      // if (kDebugMode) debugPrint('downloadFile error: $e');
      return Response(
        data: {'message': await AccountManager.dioError(e)},
        statusCode: e.response?.statusCode ?? -1,
        requestOptions: e.requestOptions,
      );
    }
  }

  static List<int> responseBytesDecoder(
    List<int> responseBytes,
    Map<String, List<String>> headers,
  ) => switch (headers['content-encoding']?.firstOrNull) {
    'gzip' => _gzipDecoder.decodeBytes(responseBytes),
    'br' => _brotliDecoder.convert(responseBytes),
    _ => responseBytes,
  };

  static String _responseDecoder(
    List<int> responseBytes,
    RequestOptions options,
    ResponseBody responseBody,
  ) => utf8.decode(
    responseBytesDecoder(responseBytes, responseBody.headers),
    allowMalformed: true,
  );
}
