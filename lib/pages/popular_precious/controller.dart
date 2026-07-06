import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/video.dart';
import 'package:pili_plus/models/model_hot_video_item.dart';
import 'package:pili_plus/models_new/popular/popular_precious/data.dart';
import 'package:pili_plus/pages/common/common_list_controller.dart';

class PopularPreciousController
    extends CommonListController<PopularPreciousData, HotVideoItemModel> {
  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  int? mediaId;

  @override
  List<HotVideoItemModel>? getDataList(PopularPreciousData response) {
    mediaId = response.mediaId;
    return response.list;
  }

  @override
  Future<LoadingState<PopularPreciousData>> customGetData() =>
      VideoHttp.popularPrecious(page: page);
}
