import 'package:pili_plus/models_new/download/bili_download_entry_info.dart';
import 'package:pili_plus/pages/common/multi_select/base.dart'
    show MultiSelectData;

class DownloadPageInfo with MultiSelectData {
  final String pageId;
  final String dirPath;
  final String title;
  String cover;
  int sortKey;
  final int? seasonType;
  final List<BiliDownloadEntryInfo> entries;

  DownloadPageInfo({
    required this.pageId,
    required this.dirPath,
    required this.title,
    required this.cover,
    required this.sortKey,
    this.seasonType,
    required this.entries,
  });
}
