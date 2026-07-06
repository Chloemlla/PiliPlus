import 'package:pili_plus/grpc/bilibili/app/im/v1.pb.dart'
    show GetImSettingsReply, IMSettingType, Setting;
import 'package:pili_plus/grpc/im.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/pages/common/common_data_controller.dart';
import 'package:get/get.dart';
import 'package:protobuf/protobuf.dart' show PbMap;

class WhisperSettingsController
    extends CommonDataController<GetImSettingsReply, PbMap<int, Setting>> {
  WhisperSettingsController({
    required this.imSettingType,
  });

  final IMSettingType imSettingType;

  final RxString title = ''.obs;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  bool customHandleResponse(
    bool isRefresh,
    Success<GetImSettingsReply> response,
  ) {
    title.value = response.response.pageTitle;
    loadingState.value = Success(response.response.settings);
    return true;
  }

  @override
  Future<LoadingState<GetImSettingsReply>> customGetData() =>
      ImGrpc.getImSettings(type: imSettingType);

  Future<bool> onSet(Map<int, Setting> settings) async {
    final res = await ImGrpc.setImSettings(settings: settings);
    if (!res.isSuccess) {
      res.toast();
      return false;
    }
    return true;
  }
}
