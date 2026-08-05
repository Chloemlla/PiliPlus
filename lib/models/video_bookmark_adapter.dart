part of 'video_bookmark.dart';

class VideoBookmarkAdapter extends TypeAdapter<VideoBookmark> {
  @override
  final int typeId = 100;

  @override
  VideoBookmark read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VideoBookmark(
      id: fields[0] as String,
      bvid: fields[1] as String,
      videoTitle: fields[2] as String,
      authorMid: fields[3] as int?,
      timestampSeconds: fields[4] as int,
      name: fields[5] as String,
      note: fields[6] as String?,
      createdAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VideoBookmark obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bvid)
      ..writeByte(2)
      ..write(obj.videoTitle)
      ..writeByte(3)
      ..write(obj.authorMid)
      ..writeByte(4)
      ..write(obj.timestampSeconds)
      ..writeByte(5)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoBookmarkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
