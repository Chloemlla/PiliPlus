import 'package:pili_plus/http/dynamics.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models_new/dynamic/dyn_topic_top/topic_item.dart';
import 'package:pili_plus/pages/common/common_list_controller.dart';

class DynTopicRcmdController
    extends CommonListController<List<TopicItem>?, TopicItem> {
  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<LoadingState<List<TopicItem>?>> customGetData() =>
      DynamicsHttp.dynTopicRcmd();
}
