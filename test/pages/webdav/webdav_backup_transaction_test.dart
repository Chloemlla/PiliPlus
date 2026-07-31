import 'dart:convert';

import 'package:pili_plus/pages/webdav/webdav_backup_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const official = '/settings.json';
  const temporary = '/settings.json.tmp';
  const backup = '/settings.json.bak';
  final oldData = utf8.encode('old');
  final newData = utf8.encode('new');

  test('upload failure leaves the official backup untouched', () async {
    final remote = _FakeWebDav({official: oldData})..failWrite = true;

    await expectLater(
      replaceWebDavBackup(
        officialPath: official,
        temporaryPath: temporary,
        backupPath: backup,
        data: newData,
        write: remote.write,
        read: remote.read,
        exists: remote.exists,
        copy: remote.copy,
        rename: remote.rename,
        remove: remote.remove,
      ),
      throwsStateError,
    );

    expect(remote.files[official], oldData);
    expect(remote.files, isNot(contains(temporary)));
  });

  test('upload verification failure aborts replacement', () async {
    final remote = _FakeWebDav({official: oldData})..corruptRead = true;

    await expectLater(
      replaceWebDavBackup(
        officialPath: official,
        temporaryPath: temporary,
        backupPath: backup,
        data: newData,
        write: remote.write,
        read: remote.read,
        exists: remote.exists,
        copy: remote.copy,
        rename: remote.rename,
        remove: remote.remove,
      ),
      throwsFormatException,
    );

    expect(remote.files[official], oldData);
    expect(remote.files, isNot(contains(temporary)));
    expect(remote.copyCalls, 0);
    expect(remote.renameCalls, 0);
  });

  test(
    'replacement failure keeps official data and cleans temporary data',
    () async {
      final remote = _FakeWebDav({official: oldData})..failRename = true;

      await expectLater(
        replaceWebDavBackup(
          officialPath: official,
          temporaryPath: temporary,
          backupPath: backup,
          data: newData,
          write: remote.write,
          read: remote.read,
          exists: remote.exists,
          copy: remote.copy,
          rename: remote.rename,
          remove: remote.remove,
        ),
        throwsStateError,
      );

      expect(remote.files[official], oldData);
      expect(remote.files[backup], oldData);
      expect(remote.files, isNot(contains(temporary)));
      expect(remote.copyCalls, 2);
      expect(remote.renameCalls, 1);
    },
  );

  test('copy failure aborts replacement when official data exists', () async {
    final remote = _FakeWebDav({official: oldData})..failCopy = true;

    await expectLater(
      replaceWebDavBackup(
        officialPath: official,
        temporaryPath: temporary,
        backupPath: backup,
        data: newData,
        write: remote.write,
        read: remote.read,
        exists: remote.exists,
        copy: remote.copy,
        rename: remote.rename,
        remove: remote.remove,
      ),
      throwsStateError,
    );

    expect(remote.files[official], oldData);
    expect(remote.files, isNot(contains(temporary)));
    expect(remote.copyCalls, 1);
    expect(remote.renameCalls, 0);
  });

  test('existence probe failure aborts replacement', () async {
    final remote = _FakeWebDav({official: oldData})..failExists = true;

    await expectLater(
      replaceWebDavBackup(
        officialPath: official,
        temporaryPath: temporary,
        backupPath: backup,
        data: newData,
        write: remote.write,
        read: remote.read,
        exists: remote.exists,
        copy: remote.copy,
        rename: remote.rename,
        remove: remote.remove,
      ),
      throwsStateError,
    );

    expect(remote.files[official], oldData);
    expect(remote.files, isNot(contains(temporary)));
    expect(remote.copyCalls, 0);
    expect(remote.renameCalls, 0);
  });

  test(
    'first upload skips the previous copy when official is missing',
    () async {
      final remote = _FakeWebDav({})..failCopy = true;

      await replaceWebDavBackup(
        officialPath: official,
        temporaryPath: temporary,
        backupPath: backup,
        data: newData,
        write: remote.write,
        read: remote.read,
        exists: remote.exists,
        copy: remote.copy,
        rename: remote.rename,
        remove: remote.remove,
      );

      expect(remote.files[official], newData);
      expect(remote.files, isNot(contains(temporary)));
      expect(remote.copyCalls, 0);
      expect(remote.renameCalls, 1);
    },
  );
}

final class _FakeWebDav {
  _FakeWebDav(Map<String, List<int>> initial)
    : files = initial.map(
        (path, data) => MapEntry(path, List<int>.of(data)),
      );

  final Map<String, List<int>> files;
  bool failWrite = false;
  bool corruptRead = false;
  bool failExists = false;
  bool failCopy = false;
  bool failRename = false;
  int copyCalls = 0;
  int renameCalls = 0;

  Future<void> write(String path, List<int> data) async {
    if (failWrite) throw StateError('upload failed');
    files[path] = List<int>.of(data);
  }

  Future<List<int>> read(String path) async {
    final data = List<int>.of(files[path]!);
    if (corruptRead && data.isNotEmpty) data[0] ^= 0xff;
    return data;
  }

  Future<bool> exists(String path) async {
    if (failExists) throw StateError('existence probe failed');
    return files.containsKey(path);
  }

  Future<void> copy(String source, String destination, bool overwrite) async {
    copyCalls++;
    if (failCopy) throw StateError('copy failed');
    final data = files[source];
    if (data == null) throw StateError('source missing');
    if (!overwrite && files.containsKey(destination)) {
      throw StateError('destination exists');
    }
    files[destination] = List<int>.of(data);
  }

  Future<void> rename(
    String source,
    String destination,
    bool overwrite,
  ) async {
    renameCalls++;
    if (failRename) {
      files.remove(destination);
      throw StateError('replacement failed after removing destination');
    }
    final data = files.remove(source);
    if (data == null) throw StateError('source missing');
    if (!overwrite && files.containsKey(destination)) {
      throw StateError('destination exists');
    }
    files[destination] = data;
  }

  Future<void> remove(String path) async {
    files.remove(path);
  }
}
