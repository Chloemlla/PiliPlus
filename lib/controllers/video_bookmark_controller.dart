import 'package:get/get.dart';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';

class VideoBookmarkController extends GetxController {
  final RxList<VideoBookmark> bookmarks = <VideoBookmark>[].obs;
  final RxList<VideoBookmark> allBookmarks = <VideoBookmark>[].obs;
  final RxString currentBvid = ''.obs;
  final RxString searchQuery = ''.obs;
  final Rx<SortType> sortType = SortType.mostRecent.obs;
  final Rx<BookmarkFilterType> filterType = BookmarkFilterType.all.obs;
  final RxnString bvidFilter = RxnString();
  final RxnInt authorMidFilter = RxnInt();

  void loadBookmarksForVideo(String bvid) {
    currentBvid.value = bvid;
    bookmarks.value = VideoBookmarkService.getBookmarksForVideo(bvid);
  }

  void loadAllBookmarks() {
    _refreshAllBookmarks();
  }

  void _refreshAllBookmarks() {
    allBookmarks.value = VideoBookmarkService.getBookmarksSorted(
      sortType: sortType.value,
      bvidFilter: bvidFilter.value,
      authorMidFilter: authorMidFilter.value,
      searchQuery: searchQuery.value,
    );
  }

  Future<VideoBookmark?> addBookmark({
    required String bvid,
    required String videoTitle,
    int? authorMid,
    required int timestampSeconds,
    String? name,
    String? note,
  }) async {
    final bookmark = await VideoBookmarkService.addBookmark(
      bvid: bvid,
      videoTitle: videoTitle,
      authorMid: authorMid,
      timestampSeconds: timestampSeconds,
      name: name,
      note: note,
    );

    if (bookmark != null) {
      if (currentBvid.value == bvid) {
        loadBookmarksForVideo(bvid);
      }
      loadAllBookmarks();
    }

    return bookmark;
  }

  Future<void> updateBookmark(VideoBookmark bookmark) async {
    await VideoBookmarkService.updateBookmark(bookmark);
    if (currentBvid.value == bookmark.bvid) {
      loadBookmarksForVideo(bookmark.bvid);
    }
    loadAllBookmarks();
  }

  Future<void> deleteBookmark(VideoBookmark bookmark) async {
    await VideoBookmarkService.deleteBookmark(bookmark.id);
    if (currentBvid.value == bookmark.bvid) {
      loadBookmarksForVideo(bookmark.bvid);
    }
    loadAllBookmarks();
  }

  void search(String query) {
    searchQuery.value = query;
    _refreshAllBookmarks();
  }

  void setSortType(SortType type) {
    sortType.value = type;
    _refreshAllBookmarks();
  }

  void clearFilter() {
    filterType.value = BookmarkFilterType.all;
    bvidFilter.value = null;
    authorMidFilter.value = null;
    _refreshAllBookmarks();
  }

  void filterByCurrentVideo(String bvid) {
    filterType.value = BookmarkFilterType.currentVideo;
    bvidFilter.value = bvid;
    authorMidFilter.value = null;
    _refreshAllBookmarks();
  }

  void filterByCreator(int authorMid) {
    filterType.value = BookmarkFilterType.creator;
    bvidFilter.value = null;
    authorMidFilter.value = authorMid;
    _refreshAllBookmarks();
  }

  bool canAddBookmark(String bvid) {
    return VideoBookmarkService.canAddBookmark(bvid);
  }

  int getBookmarkCount(String bvid) {
    return VideoBookmarkService.getBookmarkCountForVideo(bvid);
  }

  List<int> get availableAuthorMids => VideoBookmarkService.getAuthorMids();

  String exportAllBookmarks() {
    return VideoBookmarkService.exportAllBookmarks();
  }

  Future<int> importBookmarks(String jsonString) async {
    final count = await VideoBookmarkService.importBookmarks(jsonString);
    if (currentBvid.value.isNotEmpty) {
      loadBookmarksForVideo(currentBvid.value);
    }
    _refreshAllBookmarks();
    return count;
  }

  Future<void> clearAllBookmarks() async {
    await VideoBookmarkService.clearAllBookmarks();
    bookmarks.clear();
    allBookmarks.clear();
  }
}

enum BookmarkFilterType {
  all,
  currentVideo,
  creator,
}
