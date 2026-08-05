import 'package:pili_plus/utils/storage/bounded_uint8_list_store.dart';
import 'package:pili_plus/utils/storage_key.dart';

final class ReplyCacheStore extends BoundedUint8ListStore {
  ReplyCacheStore(
    super.box, {
    required super.orderStore,
    super.maxEntries = defaultMaxEntries,
  }) : super(
         orderKey: LocalCacheKey.replyWriteOrder,
       );

  static const int defaultMaxEntries = 500;
}
