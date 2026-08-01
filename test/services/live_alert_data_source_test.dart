import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models/member/info.dart';
import 'package:pili_plus/models_new/live/live_room_info_h5/anchor_info.dart';
import 'package:pili_plus/models_new/live/live_room_info_h5/base_info.dart';
import 'package:pili_plus/models_new/live/live_room_info_h5/data.dart';
import 'package:pili_plus/models_new/live/live_room_info_h5/room_info.dart';
import 'package:pili_plus/services/live_alert_data_source.dart';

void main() {
  group('BiliLiveAlertStatusSource', () {
    test('maps UID to room ID before fetching live room details', () async {
      int? requestedRoomId;
      final source = BiliLiveAlertStatusSource(
        memberFetcher: (mid) => Future.value(
          Success(
            MemberInfoModel(
              mid: mid,
              name: 'Member Name',
              face: 'member-face',
              liveRoom: LiveRoom(roomId: 5566, liveStatus: 0),
            ),
          ),
        ),
        roomFetcher: (roomId) {
          requestedRoomId = roomId;
          return Future.value(
            Success(
              RoomInfoH5Data(
                roomInfo: RoomInfo(
                  roomId: roomId,
                  uid: 1234,
                  liveStatus: 1,
                  title: 'Tonight Concert',
                  areaName: 'Music',
                ),
                anchorInfo: AnchorInfo(
                  baseInfo: BaseInfo(
                    uname: 'Anchor Name',
                    face: 'anchor-face',
                  ),
                ),
              ),
            ),
          );
        },
      );

      final snapshot = await source.resolveByMid(1234);

      expect(requestedRoomId, 5566);
      expect(snapshot?.roomId, 5566);
      expect(snapshot?.mid, 1234);
      expect(snapshot?.isLive, isTrue);
      expect(snapshot?.title, 'Tonight Concert');
      expect(snapshot?.areaName, 'Music');
      expect(snapshot?.upName, 'Anchor Name');
      expect(snapshot?.avatarUrl, 'anchor-face');
    });

    test('does not call room API when UID has no live room mapping', () async {
      var roomFetcherCalled = false;
      final source = BiliLiveAlertStatusSource(
        memberFetcher: (mid) =>
            Future.value(Success(MemberInfoModel(mid: mid))),
        roomFetcher: (roomId) {
          roomFetcherCalled = true;
          return Future.value(Success(RoomInfoH5Data()));
        },
      );

      expect(await source.resolveByMid(1234), isNull);
      expect(roomFetcherCalled, isFalse);
    });

    test('rejects a room detail response belonging to another UID', () async {
      final source = BiliLiveAlertStatusSource(
        memberFetcher: (mid) => Future.value(
          Success(
            MemberInfoModel(mid: mid, liveRoom: LiveRoom(roomId: 5566)),
          ),
        ),
        roomFetcher: (roomId) => Future.value(
          Success(
            RoomInfoH5Data(
              roomInfo: RoomInfo(roomId: roomId, uid: 9999),
            ),
          ),
        ),
      );

      expect(await source.resolveByMid(1234), isNull);
    });
  });
}
