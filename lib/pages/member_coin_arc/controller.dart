import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/member.dart';
import 'package:pili_plus/models_new/member/coin_like_arc/data.dart';
import 'package:pili_plus/models_new/member/coin_like_arc/item.dart';
import 'package:pili_plus/pages/common/common_list_controller.dart';

class MemberCoinArcController
    extends CommonListController<CoinLikeArcData, CoinLikeArcItem> {
  final dynamic mid;
  MemberCoinArcController({this.mid});

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  List<CoinLikeArcItem>? getDataList(CoinLikeArcData response) {
    return response.item;
  }

  @override
  Future<LoadingState<CoinLikeArcData>> customGetData() =>
      MemberHttp.coinArc(mid: mid, page: page);
}
