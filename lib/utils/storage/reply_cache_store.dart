import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/bounded_uint8_list_store.dart';
import 'package:pili_plus/utils/storage_key.dart';

final class ReplyCacheStore extends BoundedUint8ListStore {
  ReplyCacheStore(
    Box<Uint8List>? box, {
    required Box<dynamic> orderStore,
    int maxEntries = defaultMaxEntries,
  }) : super(
         box,
         orderStore: orderStore,
         orderKey: LocalCacheKey.replyWriteOrder,
         maxEntries: maxEntries,
       );

  static const int defaultMaxEntries = 500;
}
