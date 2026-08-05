import 'package:pili_plus/http/live.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/member.dart';
import 'package:pili_plus/models/member/info.dart';
import 'package:pili_plus/models_new/live/live_room_info_h5/data.dart';

typedef LiveAlertMemberFetcher =
    Future<LoadingState<MemberInfoModel>> Function(int mid);
typedef LiveAlertRoomFetcher =
    Future<LoadingState<RoomInfoH5Data>> Function(int roomId);

class LiveAlertRoomSnapshot {
  const LiveAlertRoomSnapshot({
    required this.mid,
    required this.roomId,
    required this.upName,
    required this.avatarUrl,
    required this.liveStatus,
    required this.title,
    required this.areaName,
  });

  final int mid;
  final int roomId;
  final String upName;
  final String avatarUrl;
  final int liveStatus;
  final String title;
  final String areaName;

  bool get isLive => liveStatus == 1;
}

abstract interface class LiveAlertStatusSource {
  Future<LiveAlertRoomSnapshot?> resolveByMid(int mid);
}

class BiliLiveAlertStatusSource implements LiveAlertStatusSource {
  BiliLiveAlertStatusSource({
    LiveAlertMemberFetcher? memberFetcher,
    LiveAlertRoomFetcher? roomFetcher,
  }) : _memberFetcher = memberFetcher ?? _fetchMember,
       _roomFetcher = roomFetcher ?? _fetchRoom;

  final LiveAlertMemberFetcher _memberFetcher;
  final LiveAlertRoomFetcher _roomFetcher;

  @override
  Future<LiveAlertRoomSnapshot?> resolveByMid(int mid) async {
    if (mid <= 0) return null;

    try {
      final memberResult = await _memberFetcher(mid);
      final MemberInfoModel memberInfo;
      if (memberResult case Success(:final response)) {
        memberInfo = response;
      } else {
        return null;
      }

      final mappedRoomId = memberInfo.liveRoom?.roomId;
      if (mappedRoomId == null || mappedRoomId <= 0) return null;

      final roomResult = await _roomFetcher(mappedRoomId);
      final RoomInfoH5Data roomData;
      if (roomResult case Success(:final response)) {
        roomData = response;
      } else {
        return null;
      }

      final roomInfo = roomData.roomInfo;
      final resolvedUid = roomInfo?.uid;
      if (resolvedUid != null && resolvedUid > 0 && resolvedUid != mid) {
        return null;
      }

      final upName = _firstNotEmpty([
        roomData.anchorInfo?.baseInfo?.uname,
        memberInfo.name,
      ]);
      final avatarUrl = _firstNotEmpty([
        roomData.anchorInfo?.baseInfo?.face,
        memberInfo.face,
      ]);

      return LiveAlertRoomSnapshot(
        mid: mid,
        roomId: roomInfo?.roomId ?? mappedRoomId,
        upName: upName,
        avatarUrl: avatarUrl,
        liveStatus:
            roomInfo?.liveStatus ?? memberInfo.liveRoom?.liveStatus ?? 0,
        title: roomInfo?.title?.trim() ?? '',
        areaName: _firstNotEmpty([
          roomInfo?.areaName,
          roomInfo?.parentAreaName,
        ]),
      );
    } on Exception {
      return null;
    }
  }

  static String _firstNotEmpty(Iterable<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  static Future<LoadingState<MemberInfoModel>> _fetchMember(int mid) =>
      MemberHttp.memberInfo(mid: mid);

  static Future<LoadingState<RoomInfoH5Data>> _fetchRoom(int roomId) =>
      LiveHttp.liveRoomInfoH5(roomId: roomId);
}
