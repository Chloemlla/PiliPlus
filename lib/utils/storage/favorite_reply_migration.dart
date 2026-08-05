import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/favorite_reply_store.dart';

typedef FavoriteReplyMigrationErrorHandler =
    void Function(Object error, StackTrace stackTrace);

typedef FavoriteReplyStartupErrorHandler =
    void Function(
      Object error,
      StackTrace stackTrace, {
      required String operation,
      required String reason,
    });

/// Opens the old combined reply box only when recording or migration needs it.
///
/// A migration/open failure leaves the marker unset, closes an opened source,
/// and returns null so startup can continue with automatic recording disabled
/// for that session. Once migration is complete, recording-open failures keep
/// their original fatal behavior because no retry source is at risk.
Future<Box<Uint8List>?> prepareLegacyReplyStorage({
  required bool shouldSaveReply,
  required bool shouldMigrateFavorites,
  required Future<Box<Uint8List>> Function() openLegacyBox,
  required FavoriteReplyStore destination,
  required Box<dynamic> markerStore,
  required FavoriteReplyStartupErrorHandler onError,
}) async {
  if (!shouldSaveReply && !shouldMigrateFavorites) return null;

  final Box<Uint8List> legacyBox;
  try {
    legacyBox = await openLegacyBox();
  } catch (error, stackTrace) {
    if (!shouldMigrateFavorites) rethrow;
    _notifyStartupError(
      onError,
      error,
      stackTrace,
      operation: 'favoriteReply.legacyOpen',
      reason: 'favorite_reply_legacy_open_failed',
    );
    return null;
  }

  if (!shouldMigrateFavorites) return legacyBox;

  final migrationSucceeded = await tryMigrateLegacyReplyFavorites(
    destination: destination,
    legacyBox: legacyBox,
    markerStore: markerStore,
    onError: (error, stackTrace) {
      _notifyStartupError(
        onError,
        error,
        stackTrace,
        operation: 'favoriteReply.legacyMigration',
        reason: 'favorite_reply_legacy_migration_failed',
      );
    },
  );
  if (shouldSaveReply && migrationSucceeded) return legacyBox;

  await legacyBox.close();
  return null;
}

/// Runs the legacy copy as a best-effort startup migration.
///
/// Returning false leaves the marker unset and lets startup continue. Callers
/// should avoid mutating the legacy box for the remainder of that session so a
/// later launch can retry from the intact source.
Future<bool> tryMigrateLegacyReplyFavorites({
  required FavoriteReplyStore destination,
  required Box<Uint8List> legacyBox,
  required Box<dynamic> markerStore,
  required FavoriteReplyMigrationErrorHandler onError,
}) async {
  try {
    await destination.migrateLegacy(
      legacyBox: legacyBox,
      markerStore: markerStore,
    );
    return true;
  } catch (error, stackTrace) {
    try {
      onError(error, stackTrace);
    } catch (_) {
      // Diagnostics must not turn a retryable migration into a startup failure.
    }
    return false;
  }
}

void _notifyStartupError(
  FavoriteReplyStartupErrorHandler onError,
  Object error,
  StackTrace stackTrace, {
  required String operation,
  required String reason,
}) {
  try {
    onError(
      error,
      stackTrace,
      operation: operation,
      reason: reason,
    );
  } catch (_) {
    // Diagnostics must never turn a retryable startup migration into a crash.
  }
}
