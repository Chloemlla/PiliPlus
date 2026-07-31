// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_keyword_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LiveKeywordRuleAdapter extends TypeAdapter<LiveKeywordRule> {
  @override
  final int typeId = 101;

  @override
  LiveKeywordRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LiveKeywordRule(
      id: fields[0] as String,
      mid: fields[1] as int,
      upName: fields[2] as String,
      keyword: fields[3] as String,
      matchTargetIndex: fields[4] as int,
      enabled: fields[5] as bool,
      createdAt: fields[6] as int,
      lastNotifiedAt: fields[7] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, LiveKeywordRule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mid)
      ..writeByte(2)
      ..write(obj.upName)
      ..writeByte(3)
      ..write(obj.keyword)
      ..writeByte(4)
      ..write(obj.matchTargetIndex)
      ..writeByte(5)
      ..write(obj.enabled)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastNotifiedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveKeywordRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
