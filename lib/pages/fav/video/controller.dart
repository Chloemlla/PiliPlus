import 'package:pili_plus/http/fav.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models_new/fav/fav_folder/data.dart';
import 'package:pili_plus/models_new/fav/fav_folder/list.dart';
import 'package:pili_plus/pages/common/common_list_controller.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/storage.dart';

class FavController extends CommonListController<FavFolderData, FavFolderInfo> {
  /// Local pin + sort overlay scope for the favorite folder list.
  static const String scope = 'favFolder';

  late final account = Accounts.main;

  /// Stable identity for a folder (folder id, falling back to media list id).
  static String folderId(FavFolderInfo folder) =>
      (folder.fid ?? folder.id).toString();

  /// Currently loaded folders in display order (pinned first).
  List<FavFolderInfo> get orderedFolders {
    final data = loadingState.value.dataOrNull;
    if (data == null || data.isEmpty) return data ?? const <FavFolderInfo>[];
    final ordered = GStorage.favoriteOrderStore.displayOrder(
      scope,
      data.map(folderId),
    );
    final byId = {for (final folder in data) folderId(folder): folder};
    return [for (final id in ordered) byId[id]!];
  }

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<void> queryData([bool isRefresh = true]) {
    if (!account.isLogin) {
      loadingState.value = const Error('账号未登录');
      return Future.syncValue(null);
    }
    return super.queryData(isRefresh);
  }

  @override
  List<FavFolderInfo>? getDataList(FavFolderData response) {
    if (response.hasMore == false) {
      isEnd = true;
    }
    return response.list;
  }

  @override
  Future<LoadingState<FavFolderData>> customGetData() => FavHttp.userfavFolder(
    pn: page,
    ps: 20,
    mid: account.mid,
  );
}
