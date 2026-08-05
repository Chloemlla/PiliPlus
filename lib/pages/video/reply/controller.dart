import 'package:pili_plus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyInfo;
import 'package:pili_plus/grpc/reply.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models/common/video/video_type.dart';
import 'package:pili_plus/pages/common/reply_controller.dart';
import 'package:pili_plus/pages/video/controller.dart';
import 'package:pili_plus/pages/video/reply/vote/reply_vote_mixin.dart';
import 'package:pili_plus/utils/id_utils.dart';
import 'package:get/get.dart';

class VideoReplyController extends ReplyController<MainListReply>
    with ReplyVoteMixin {
  VideoReplyController({
    required this.aid,
    required this.videoType,
    required this.heroTag,
  });
  int aid;
  final VideoType videoType;
  late final isPugv = videoType == VideoType.pugv;

  final String heroTag;
  late final videoCtr = Get.find<VideoDetailController>(tag: heroTag);

  @override
  dynamic get sourceId => IdUtils.av2bv(aid);

  @override
  List<ReplyInfo>? getDataList(MainListReply response) {
    return response.replies;
  }

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    oid: isPugv ? videoCtr.epId! : aid,
    type: videoType.replyType,
    mode: mode,
    cursorNext: cursorNext,
    offset: paginationReply?.nextOffset,
  );
}
