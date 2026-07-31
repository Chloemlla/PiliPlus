import 'package:collection/collection.dart';

typedef WebDavWrite = Future<void> Function(String path, List<int> data);
typedef WebDavRead = Future<List<int>> Function(String path);
typedef WebDavExists = Future<bool> Function(String path);
typedef WebDavCopy =
    Future<void> Function(
      String source,
      String destination,
      bool overwrite,
    );
typedef WebDavRename = WebDavCopy;
typedef WebDavRemove = Future<void> Function(String path);

Future<void> replaceWebDavBackup({
  required String officialPath,
  required String temporaryPath,
  required String backupPath,
  required List<int> data,
  required WebDavWrite write,
  required WebDavRead read,
  required WebDavExists exists,
  required WebDavCopy copy,
  required WebDavRename rename,
  required WebDavRemove remove,
}) async {
  try {
    await write(temporaryPath, data);
    final uploaded = await read(temporaryPath);
    if (!const ListEquality<int>().equals(uploaded, data)) {
      throw const FormatException('WebDAV upload verification failed');
    }
    final hasPreviousOfficial = await exists(officialPath);
    if (hasPreviousOfficial) {
      await copy(officialPath, backupPath, true);
    }
    try {
      await rename(temporaryPath, officialPath, true);
    } catch (_) {
      if (hasPreviousOfficial) {
        await copy(backupPath, officialPath, true);
      }
      rethrow;
    }
  } catch (_) {
    try {
      await remove(temporaryPath);
    } catch (_) {}
    rethrow;
  }
}
