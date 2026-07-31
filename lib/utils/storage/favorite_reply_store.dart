import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/bounded_uint8_list_store.dart';
import 'package:pili_plus/utils/storage_key.dart';

final class FavoriteReplyStore extends BoundedUint8ListStore {
  FavoriteReplyStore(
    Box<Uint8List> super.box, {
    required Box<dynamic> super.orderStore,
    this.maxFavoriteEntries = defaultMaxEntries,
  }) : super(
         orderKey: LocalCacheKey.favoriteReplyWriteOrder,
         maxEntries: maxFavoriteEntries,
       );

  static const int defaultMaxEntries = 500;

  final int maxFavoriteEntries;

  /// Copies the old combined reply cache without deleting it.
  ///
  /// The completion marker is written only after every destination write
  /// succeeds. A failed copy therefore remains retryable on the next launch.
  Future<void> migrateLegacy({
    required Box<Uint8List> legacyBox,
    required Box<dynamic> markerStore,
  }) async {
    if (markerStore.get(LocalCacheKey.favoriteReplyMigrationV1) == true) {
      return;
    }

    final legacyValues = <String, Uint8List>{
      for (final entry in legacyBox.toMap().entries)
        entry.key.toString(): entry.value,
    };
    final rawOrder = markerStore.get(LocalCacheKey.replyWriteOrder);
    final orderedKeys = <String>[];
    final seen = <String>{};
    if (rawOrder is List) {
      for (final item in rawOrder) {
        final key = item.toString();
        if (legacyValues.containsKey(key) && seen.add(key)) {
          orderedKeys.add(key);
        }
      }
    }
    final remainingKeys = legacyValues.keys.where(seen.add).toList()
      ..sort(_compareNumericStringKeys);
    orderedKeys.addAll(remainingKeys);

    // A retry may run after the user has created new explicit favorites in a
    // session where the previous migration failed. Fill only unused capacity
    // so legacy recovery never evicts those already-visible favorites.
    final availableSlots = maxFavoriteEntries - length;
    if (availableSlots > 0) {
      final missingKeys = orderedKeys
          .where((key) => !containsKey(key))
          .toList();
      final keysToCopy = missingKeys.length <= availableSlots
          ? missingKeys
          : missingKeys.skip(missingKeys.length - availableSlots);
      await putAll({
        for (final key in keysToCopy) key: legacyValues[key]!,
      });
    }
    await markerStore.put(LocalCacheKey.favoriteReplyMigrationV1, true);
  }

  static int _compareNumericStringKeys(String a, String b) {
    final aNumber = BigInt.tryParse(a);
    final bNumber = BigInt.tryParse(b);
    if (aNumber != null && bNumber != null) {
      return aNumber.compareTo(bNumber);
    }
    return a.compareTo(b);
  }
}
