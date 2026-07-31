// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_stats_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchStatsSessionAdapter extends TypeAdapter<WatchStatsSession> {
  @override
  final int typeId = 100;

  @override
  WatchStatsSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchStatsSession(
      bvid: fields[0] as String,
      title: fields[1] as String,
      authorName: fields[2] as String,
      authorMid: fields[3] as int,
      watchedSeconds: fields[4] as int,
      timestamp: fields[5] as int,
      date: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WatchStatsSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.bvid)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.authorName)
      ..writeByte(3)
      ..write(obj.authorMid)
      ..writeByte(4)
      ..write(obj.watchedSeconds)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchStatsSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
