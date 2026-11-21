import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/account_secret_store.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:hive_ce/hive.dart';

class LoginAccountAdapter extends TypeAdapter<LoginAccount> {
  @override
  final int typeId = 9;

  @override
  LoginAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final type = (fields[3] as List?)?.cast<AccountType>().toSet();
    // Legacy records held 2 fields and kept the secret-store key in slot 4;
    // current records store `buvid` in slot 4 and the secret key in slot 5.
    final bool legacy = numOfFields <= 2;
    final String? buvid = legacy ? null : fields[4] as String?;
    final String? secretKey = legacy
        ? fields[4] as String?
        : fields[5] as String?;
    if (secretKey != null) {
      final secret = AccountSecretStore.read(secretKey);
      return LoginAccount(
        BiliCookieJar.fromJson(secret?.cookies ?? const {}),
        secret?.accessKey,
        secret?.refresh,
        type,
        buvid,
      );
    }

    final account = LoginAccount(
      fields[0] as DefaultCookieJar? ?? DefaultCookieJar(),
      fields[1] as String?,
      fields[2] as String?,
      type,
      buvid,
    );
    if (account.shouldKeep) {
      account.persistSecret();
    }
    return account;
  }

  @override
  void write(BinaryWriter writer, LoginAccount obj) {
    writer
      ..writeByte(3)
      ..writeByte(3)
      ..write(obj.type.toList())
      ..writeByte(4)
      ..write(obj.buvid)
      ..writeByte(5)
      ..write(obj.secretKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
