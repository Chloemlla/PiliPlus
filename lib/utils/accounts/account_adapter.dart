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
    if (fields[4] case final String secretKey) {
      final secret = AccountSecretStore.read(secretKey);
      return LoginAccount(
        BiliCookieJar.fromJson(secret?.cookies ?? const {}),
        secret?.accessKey,
        secret?.refresh,
        type,
      );
    }

    final account = LoginAccount(
      fields[0] as DefaultCookieJar,
      fields[1] as String?,
      fields[2] as String?,
      type,
    );
    if (account.shouldKeep) {
      account.persistSecret();
    }
    return account;
  }

  @override
  void write(BinaryWriter writer, LoginAccount obj) {
    writer
      ..writeByte(2)
      ..writeByte(4)
      ..write(obj.secretKey)
      ..writeByte(3)
      ..write(obj.type.toList());
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
