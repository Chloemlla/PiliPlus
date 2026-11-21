import 'package:pili_plus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply;
import 'package:pili_plus/grpc/reply.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/pages/common/reply/fold/reply_fold_mixin.dart';
import 'package:pili_plus/pages/common/reply/reply_controller.dart';
import 'package:get/get.dart';

class MainReplyController extends ReplyController<MainListReply>
    with BaseReplyFoldMixin<MainListReply>, ReplyFoldMixin {
  @override
  late final int oid;
  @override
  late final int replyType;

  @override
  int get sourceId => oid;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    oid = args['oid'];
    replyType = args['replyType'];

    queryData();
  }

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    type: replyType,
    oid: oid,
    mode: mode,
    offset: nextOffset,
  );
}
