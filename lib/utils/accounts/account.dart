import 'package:pili_plus/common/constants.dart';
import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account_secret_store.dart';
import 'package:pili_plus/utils/accounts/grpc_headers.dart';
import 'package:pili_plus/utils/buvid_store.dart';
import 'package:pili_plus/utils/id_utils.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:hive_ce/hive.dart';

sealed class Account {
  Map<String, dynamic>? toJson() => null;

  Future<void>? onChange() => null;

  Set<AccountType> get type => const {};

  bool get activated => false;

  set activated(bool value) => throw UnimplementedError();

  String? get accessKey => throw UnimplementedError();

  DefaultCookieJar get cookieJar => throw UnimplementedError();

  String get csrf => throw UnimplementedError();

  Future<void> delete() => throw UnimplementedError();

  Map<String, String> get headers => throw UnimplementedError();

  Map<String, String> get grpcHeaders => throw UnimplementedError();

  bool get isLogin => throw UnimplementedError();

  int get mid => throw UnimplementedError();

  String? get refresh => throw UnimplementedError();

  set buvid(String value) => throw UnimplementedError();
  String get buvid => throw UnimplementedError();

  const Account();
}

@HiveType(typeId: 9)
class LoginAccount extends Account {
  @override
  bool get isLogin => hasRequiredCookies;
  @override
  @HiveField(0)
  final DefaultCookieJar cookieJar;
  @override
  @HiveField(1)
  final String? accessKey;
  @override
  @HiveField(2)
  final String? refresh;
  @override
  @HiveField(3)
  final Set<AccountType> type;

  late String _buvid = AnonymousAccount()._buvid;
  @override
  @HiveField(4)
  String get buvid => _buvid;
  @override
  set buvid(String value) {
    if (_buvid == value) return;
    _buvid = value;
    grpcHeaders.addAll(GrpcHeaders.newHeaders(this));
    onChange();
  }

  @override
  bool activated = false;

  @override
  late final int mid = int.tryParse(_midStr) ?? 0;

  @override
  late final Map<String, String> headers = {
    ...Constants.baseHeaders,
    'x-bili-mid': _midStr,
    if (mid != 0) 'x-bili-aurora-eid': IdUtils.genAuroraEid(mid),
  };

  @override
  late final Map<String, String> grpcHeaders = GrpcHeaders.newHeaders(this);

  @override
  late final String csrf = _cookieValue('bili_jct') ?? '';

  bool get hasRequiredCookies =>
      _midStr.isNotEmpty && csrf.isNotEmpty && mid != 0;

  String get secretKey => _midStr;

  bool _hasDelete = false;

  @override
  Future<void> delete() {
    _hasDelete = true;
    AccountSecretStore.delete(secretKey);
    return Future.wait([cookieJar.deleteAll(), _box.delete(_midStr)]);
  }

  @override
  Future<void>? onChange() {
    if (_hasDelete) return null;
    persistSecret();
    return _box.put(secretKey, this);
  }

  void persistSecret() {
    AccountSecretStore.write(
      secretKey,
      AccountSecret(
        cookies: cookieJar.toJson(),
        accessKey: accessKey,
        refresh: refresh,
      ),
    );
  }

  @override
  Map<String, dynamic>? toJson() => {
    'cookies': cookieJar.toJson(),
    'accessKey': accessKey,
    'refresh': refresh,
    'buvid': buvid,
    'type': type.map((i) => i.index).toList(),
  };

  late final String _midStr = _cookieValue('DedeUserID') ?? '';

  late final Box<LoginAccount> _box = Accounts.account;

  LoginAccount(
    this.cookieJar,
    this.accessKey,
    this.refresh, [
    Set<AccountType>? type,
    String? buvid,
  ]) : type = type ?? {} {
    if (buvid != null) _buvid = buvid;
    cookieJar.setBuvid3();
  }

  String? _cookieValue(String name) {
    final value =
        cookieJar.domainCookies['bilibili.com']?['/']?[name]?.cookie.value;
    return value == null || value.isEmpty ? null : value;
  }

  factory LoginAccount.fromJson(Map json) => LoginAccount(
    BiliCookieJar.fromJson(json['cookies']),
    json['accessKey'],
    json['refresh'],
    (json['type'] as Iterable?)?.map((i) => AccountType.values[i]).toSet(),
    json['buvid'],
  );

  @override
  int get hashCode => mid.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LoginAccount && mid == other.mid);
}

class AnonymousAccount extends Account {
  @override
  final bool isLogin = false;
  @override
  final DefaultCookieJar cookieJar = DefaultCookieJar();
  @override
  final String? accessKey = null;
  @override
  final String? refresh = null;
  @override
  final Set<AccountType> type = {};
  @override
  final int mid = 0;
  @override
  final String csrf = '';
  @override
  final Map<String, String> headers = Constants.baseHeaders;

  @override
  late final Map<String, String> grpcHeaders = GrpcHeaders.newHeaders(this);

  @override
  bool activated = true;

  late String _buvid = BuvidStore.buvid;
  @override
  String get buvid => _buvid;
  @override
  set buvid(String value) {
    if (_buvid == value) return;
    _buvid = value;
    grpcHeaders.addAll(GrpcHeaders.newHeaders(this));
    GStorage.setting.put(SettingBoxKey.buvid, value);
  }

  @override
  Future<void> delete() {
    grpcHeaders['x-bili-fawkes-req-bin'] = GrpcHeaders.fawkes;
    return cookieJar.deleteAll().whenComplete(refreshBuvidCookies);
  }

  static final _instance = AnonymousAccount._();

  AnonymousAccount._();

  /// Installed by `LoginUtils.initializeSession`.
  ///
  /// `utils/accounts/` must not import `http/`, otherwise storage
  /// initialization would transitively depend on `storage_pref.dart`;
  /// the fingerprint request lives in `anonymous_buvid.dart` instead.
  static Future<void> Function(DefaultCookieJar cookieJar)?
  buvidCookieRefresher;

  /// Refreshes the anonymous device fingerprints, falling back to a local
  /// buvid3 when no refresher is installed yet.
  Future<void> refreshBuvidCookies() async {
    final refresher = buvidCookieRefresher;
    if (refresher != null) {
      await refresher(cookieJar);
    } else {
      cookieJar.setBuvid3();
    }
  }

  factory AnonymousAccount() => _instance;

  @override
  int get hashCode => cookieJar.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnonymousAccount && cookieJar == other.cookieJar);
}

extension BiliCookie on Cookie {
  void setBiliDomain([String domain = '.bilibili.com']) {
    this.domain = domain;
    httpOnly = false;
    path = '/';
  }
}

extension BiliCookieJar on DefaultCookieJar {
  Map<String, String> toJson() {
    final cookies = domainCookies['bilibili.com']?['/'] ?? const {};
    return {for (final i in cookies.values) i.cookie.name: i.cookie.value};
  }

  List<Cookie> toList() =>
      domainCookies['bilibili.com']?['/']?.entries
          .map((i) => i.value.cookie)
          .toList() ??
      [];

  void setBuvid3() {
    (domainCookies['bilibili.com'] ??= {
      '/': {},
    })['/']!['buvid3'] ??= SerializableCookie(
      Cookie('buvid3', IdUtils.genBuvid3())..setBiliDomain(),
    );
  }

  static DefaultCookieJar fromJson(Map json) =>
      DefaultCookieJar(ignoreExpires: true)
        ..domainCookies['bilibili.com'] = {
          '/': {
            for (final i in json.entries)
              if (i.value != null)
                i.key.toString(): SerializableCookie(
                  Cookie(i.key.toString(), i.value.toString())..setBiliDomain(),
                ),
          },
        };

  static DefaultCookieJar fromList(List cookies) =>
      DefaultCookieJar(ignoreExpires: true)
        ..domainCookies['bilibili.com'] = {
          '/': {
            for (final i in cookies)
              if (i is Map && i['name'] is String && i['value'] != null)
                i['name'] as String: SerializableCookie(
                  Cookie(i['name'] as String, i['value'].toString())
                    ..setBiliDomain(),
                ),
          },
        };
}

extension LoginAccountValidation on LoginAccount {
  bool get shouldKeep => hasRequiredCookies;
}

/*
  Keep the no-op account class in this file so callers can depend on the sealed
  Account hierarchy without importing additional implementation details.
 */
final class NoAccount extends Account {
  const NoAccount();
}
