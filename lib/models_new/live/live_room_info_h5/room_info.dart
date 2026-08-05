import 'package:pili_plus/utils/parse_int.dart';

class RoomInfo {
  int? roomId;
  int? uid;
  int? liveStatus;
  String? title;
  String? areaName;
  String? parentAreaName;
  String? cover;
  String? appBackground;

  RoomInfo({
    this.roomId,
    this.uid,
    this.liveStatus,
    this.title,
    this.areaName,
    this.parentAreaName,
    this.cover,
    this.appBackground,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
    roomId: safeToInt(json['room_id']),
    uid: safeToInt(json['uid']),
    liveStatus: safeToInt(json['live_status']),
    title: json['title'] as String?,
    areaName: json['area_name'] as String?,
    parentAreaName: json['parent_area_name'] as String?,
    cover: json['cover'] as String?,
    appBackground: json['app_background'] as String?,
  );
}
