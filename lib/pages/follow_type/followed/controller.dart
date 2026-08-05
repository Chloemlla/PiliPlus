import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/user.dart';
import 'package:pili_plus/models_new/follow/data.dart';
import 'package:pili_plus/pages/follow_type/controller.dart';

class FollowedController extends FollowTypeController {
  @override
  Future<LoadingState<FollowData>> customGetData() =>
      UserHttp.followedUp(mid: mid, pn: page);
}
