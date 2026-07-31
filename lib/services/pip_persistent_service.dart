import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// Manages PiP (Picture-in-Picture) state persistence across navigation.
/// Stores current video info when entering PiP so playback can be restored.
class PipPersistentService {
  PipPersistentService._();

  static final PipPersistentService instance = PipPersistentService._();

  /// Store video state when entering PiP
  Future<void> savePipState({
    required String bvid,
    required int cid,
    required int positionMs,
    String? title,
    String? cover,
  }) async {
    await GStorage.localCache.put(LocalCacheKey.pipVideoBvid, bvid);
    await GStorage.localCache.put(LocalCacheKey.pipVideoCid, cid);
    await GStorage.localCache.put(LocalCacheKey.pipVideoPosition, positionMs);
    await GStorage.localCache.put(LocalCacheKey.pipVideoTitle, title);
    await GStorage.localCache.put(LocalCacheKey.pipVideoCover, cover);
  }

  /// Get stored video bvid for PiP restoration
  String? get pipVideoBvid =>
      GStorage.localCache.get(LocalCacheKey.pipVideoBvid);

  /// Get stored video cid for PiP restoration
  int? get pipVideoCid => GStorage.localCache.get(LocalCacheKey.pipVideoCid);

  /// Get stored video position for PiP restoration
  int? get pipVideoPosition =>
      GStorage.localCache.get(LocalCacheKey.pipVideoPosition);

  /// Get stored video title for PiP restoration
  String? get pipVideoTitle =>
      GStorage.localCache.get(LocalCacheKey.pipVideoTitle);

  /// Get stored video cover for PiP restoration
  String? get pipVideoCover =>
      GStorage.localCache.get(LocalCacheKey.pipVideoCover);

  /// Check if there's a stored PiP state
  bool get hasPipState => pipVideoBvid != null && pipVideoCid != null;

  /// Clear PiP state
  Future<void> clearPipState() async {
    await GStorage.localCache.delete(LocalCacheKey.pipVideoBvid);
    await GStorage.localCache.delete(LocalCacheKey.pipVideoCid);
    await GStorage.localCache.delete(LocalCacheKey.pipVideoPosition);
    await GStorage.localCache.delete(LocalCacheKey.pipVideoTitle);
    await GStorage.localCache.delete(LocalCacheKey.pipVideoCover);
  }
}
