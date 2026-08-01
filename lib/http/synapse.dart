import 'package:dio/dio.dart';
import 'package:pili_plus/models/synapse_sync.dart';

/// Synapse transport is intentionally separate from [Request].
/// It must never pass through the Bilibili AccountManager cookie interceptor.
final class SynapseHttp {
  SynapseHttp({required String baseUrl, required String sessionToken})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Authorization': 'Bearer ${sessionToken.trim()}'},
          ),
        );

  final Dio _dio;

  Future<SynapseBindResult> bindBilibili({
    required int mid,
    required String sessionProof,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'uid',
      data: {'uid': mid.toString(), 'cookie': sessionProof},
      options: Options(extra: {'synapseSensitive': true}),
    );
    final data = _responseData(response);
    final result = SynapseBindResult.fromJson(data);
    if (!result.bound || result.uid != mid.toString()) {
      throw StateError('Synapse 返回的绑定账号与当前 B 站 UID 不一致');
    }
    return result;
  }

  Future<bool> isBound({required int mid}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'uid',
    );
    final body = response.data?['data'];
    return body is Map && body['bound'] == true && body['uid']?.toString() == mid.toString();
  }

  Future<SynapseRemoteSnapshot?> discoverSnapshot() async {
    final search = await _dio.get<Map<String, dynamic>>('search-records/changes', queryParameters: {
      'since': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(),
    });
    final settings = await _dio.get<Map<String, dynamic>>('settings');
    if (search.data == null || settings.data == null) return null;
    final searchBody = search.data!['data'] as Map?;
    final settingsBody = settings.data!['data'] as Map?;
    return SynapseRemoteSnapshot.fromJson({
      'records': searchBody?['records'] ?? const [],
      'settings': settingsBody?['settings'] ?? const <String, Object?>{},
    });
  }

  Future<void> pushSnapshot({
    required List<SynapseSearchRecord> search,
    required Map<String, Object?> settings,
  }) async {
    await _dio.post<void>('search-records/batch', data: {
      'records': [
        for (final item in search)
          {...item.toJson(), 'isDeleted': item.deleted, 'deletedAt': item.deleted ? item.updatedAt.toUtc().toIso8601String() : null},
      ],
    });
    await _dio.put<void>('settings', data: {
      'settings': settings,
      'baseVersion': 0,
    });
  }

  Map<String, dynamic> _responseData(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null || body['success'] != true || body['data'] is! Map) {
      throw StateError(body?['error']?.toString() ?? body?['message']?.toString() ?? 'Synapse 请求失败');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}

final class SynapseBindResult {
  const SynapseBindResult({required this.bound, required this.uid, this.boundAt});

  final bool bound;
  final String uid;
  final String? boundAt;

  factory SynapseBindResult.fromJson(Map<String, dynamic> json) => SynapseBindResult(
        bound: json['bound'] == true,
        uid: json['uid']?.toString() ?? '',
        boundAt: json['boundAt']?.toString(),
      );
}

