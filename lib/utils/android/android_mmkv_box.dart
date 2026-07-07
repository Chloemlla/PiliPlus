import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:jni/_internal.dart' as jni$_;
import 'package:jni/jni.dart' as jni$_;

const _$jniVersionCheck = jni$_.JniVersionCheck(1, 0);

Future<Box<E>> openAndroidMmkvBackedBox<E>({
  required String name,
  required Future<Box<E>> Function() openHive,
  KeyComparator? keyComparator,
}) async {
  if (!Platform.isAndroid || !AndroidMmkvStore.isAvailable) {
    return openHive();
  }

  final migrationKey = AndroidMmkvStore.migrationKey(name);
  if (AndroidMmkvStore.getRaw(AndroidMmkvStore.metaBox, migrationKey) == '1') {
    final box = AndroidMmkvBackedBox<E>(name, keyComparator: keyComparator);
    if (box.tryLoadFromMmkv()) {
      return box;
    }
  }

  final hive = await openHive();
  final box = AndroidMmkvBackedBox<E>(hive.name, keyComparator: keyComparator);
  if (!box.replaceAllFrom(hive.toMap())) {
    return hive;
  }

  await hive.close();
  AndroidMmkvStore.putRaw(AndroidMmkvStore.metaBox, migrationKey, '1');
  return box;
}

final class AndroidMmkvBackedBox<E> implements Box<E> {
  AndroidMmkvBackedBox(this.name, {KeyComparator? keyComparator})
    : _keyComparator = keyComparator;

  @override
  final String name;

  final KeyComparator? _keyComparator;
  final Map<dynamic, E> _cache = <dynamic, E>{};
  final StreamController<BoxEvent> _events =
      StreamController<BoxEvent>.broadcast(sync: true);

  bool _open = true;
  int _nextAutoKey = 0;

  bool tryLoadFromMmkv() {
    try {
      _checkOpen();
      final json = AndroidMmkvStore.exportBox(name);
      if (json == null) return false;

      final decoded = jsonDecode(json);
      if (decoded is! Map) return false;

      final next = <dynamic, E>{};
      for (final MapEntry(:key, :value) in decoded.entries) {
        if (key is! String || value is! String) return false;
        next[_decodeKey(key)] = _decodeEntry(value) as E;
      }

      _cache
        ..clear()
        ..addAll(next);
      _resetNextAutoKey();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool replaceAllFrom(Map<dynamic, E> entries) {
    _checkOpen();
    final encoded = _encodeMap(entries);
    if (encoded == null) return false;
    if (!AndroidMmkvStore.replaceBox(name, jsonEncode(encoded))) {
      return false;
    }

    _cache
      ..clear()
      ..addAll(entries);
    _resetNextAutoKey();
    return true;
  }

  @override
  Iterable<E> get values => _sortedKeys().map((key) => _cache[key] as E);

  @override
  Iterable<E> valuesBetween({dynamic startKey, dynamic endKey}) {
    _checkOpen();
    final keys = _sortedKeys();
    final start = keys.indexOf(startKey);
    if (start == -1) return const [];

    final end = endKey == null ? -1 : keys.indexOf(endKey);
    final selected = end == -1 || end < start
        ? keys.skip(start)
        : keys.skip(start).take(end - start + 1);
    return selected.map((key) => _cache[key] as E);
  }

  @override
  E? get(dynamic key, {E? defaultValue}) {
    _checkOpen();
    return _cache.containsKey(key) ? _cache[key] : defaultValue;
  }

  @override
  E? getAt(int index) {
    _checkOpen();
    return _cache[_sortedKeys()[index]];
  }

  @override
  Map<dynamic, E> toMap() {
    _checkOpen();
    return Map<dynamic, E>.of(_cache);
  }

  @override
  String? get path => 'mmkv://$name';

  @override
  bool get isOpen => _open;

  @override
  bool get lazy => false;

  @override
  Iterable<dynamic> get keys => _sortedKeys();

  @override
  int get length {
    _checkOpen();
    return _cache.length;
  }

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => length > 0;

  @override
  dynamic keyAt(int index) {
    _checkOpen();
    return _sortedKeys()[index];
  }

  @override
  Stream<BoxEvent> watch({dynamic key}) {
    _checkOpen();
    final stream = _events.stream;
    return key == null ? stream : stream.where((event) => event.key == key);
  }

  @override
  bool containsKey(dynamic key) {
    _checkOpen();
    return _cache.containsKey(key);
  }

  @override
  Future<void> put(dynamic key, E value) {
    _checkOpen();
    final encodedValue = _encodeEntry(value);
    if (encodedValue == null) {
      return Future.error(
        UnsupportedError('Unsupported MMKV value for $name.$key: $value'),
      );
    }
    if (!AndroidMmkvStore.putRaw(name, _encodeKey(key), encodedValue)) {
      return Future.error(StateError('MMKV put failed for $name.$key'));
    }

    _cache[key] = value;
    _events.add(BoxEvent(key, value, false));
    _resetNextAutoKey();
    return Future.value();
  }

  @override
  Future<void> putAt(int index, E value) => put(keyAt(index), value);

  @override
  Future<void> putAll(Map<dynamic, E> entries) {
    _checkOpen();
    final encoded = _encodeMap(entries);
    if (encoded == null) {
      return Future.error(
        UnsupportedError('Unsupported MMKV value in $name.putAll'),
      );
    }

    for (final MapEntry(:key, :value) in encoded.entries) {
      if (!AndroidMmkvStore.putRaw(name, key, value)) {
        return Future.error(StateError('MMKV putAll failed for $name.$key'));
      }
    }

    _cache.addAll(entries);
    for (final MapEntry(:key, :value) in entries.entries) {
      _events.add(BoxEvent(key, value, false));
    }
    _resetNextAutoKey();
    return Future.value();
  }

  @override
  Future<int> add(E value) async {
    final key = _nextAutoKey++;
    await put(key, value);
    return key;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) async {
    final keys = <int>[];
    for (final value in values) {
      keys.add(await add(value));
    }
    return keys;
  }

  @override
  Future<void> delete(dynamic key) {
    _checkOpen();
    if (!AndroidMmkvStore.removeRaw(name, _encodeKey(key))) {
      return Future.error(StateError('MMKV delete failed for $name.$key'));
    }
    final hadValue = _cache.containsKey(key);
    final oldValue = _cache.remove(key);
    if (hadValue) {
      _events.add(BoxEvent(key, oldValue, true));
    }
    return Future.value();
  }

  @override
  Future<void> deleteAt(int index) => delete(keyAt(index));

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) {
    _checkOpen();
    final deleted = <MapEntry<dynamic, E?>>[];
    for (final key in keys) {
      if (!AndroidMmkvStore.removeRaw(name, _encodeKey(key))) {
        return Future.error(StateError('MMKV deleteAll failed for $name.$key'));
      }
      if (_cache.containsKey(key)) {
        deleted.add(MapEntry<dynamic, E?>(key, _cache.remove(key)));
      }
    }
    for (final MapEntry(:key, :value) in deleted) {
      _events.add(BoxEvent(key, value, true));
    }
    return Future.value();
  }

  @override
  Future<void> compact() => flush();

  @override
  Future<int> clear() {
    _checkOpen();
    if (!AndroidMmkvStore.clearBox(name)) {
      return Future.error(StateError('MMKV clear failed for $name'));
    }

    final deleted = Map<dynamic, E>.of(_cache);
    _cache.clear();
    for (final MapEntry(:key, :value) in deleted.entries) {
      _events.add(BoxEvent(key, value, true));
    }
    return Future.value(deleted.length);
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    await flush();
    _open = false;
    await _events.close();
  }

  @override
  Future<void> deleteFromDisk() async {
    if (_open) {
      await clear();
      await close();
    } else {
      AndroidMmkvStore.clearBox(name);
    }
  }

  @override
  Future<void> flush() {
    _checkOpen();
    if (!AndroidMmkvStore.sync(name)) {
      return Future.error(StateError('MMKV sync failed for $name'));
    }
    return Future.value();
  }

  List<dynamic> _sortedKeys() {
    _checkOpen();
    final keys = _cache.keys.toList();
    keys.sort(_keyComparator ?? _defaultKeyComparator);
    return keys;
  }

  void _checkOpen() {
    if (!_open) {
      throw HiveError('Box has already been closed.');
    }
  }

  void _resetNextAutoKey() {
    final intKeys = _cache.keys.whereType<int>();
    _nextAutoKey = intKeys.isEmpty
        ? 0
        : intKeys.reduce((a, b) => a > b ? a : b) + 1;
  }

  static int _defaultKeyComparator(dynamic a, dynamic b) {
    if (a is Comparable && b.runtimeType == a.runtimeType) {
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }
}

abstract final class AndroidMmkvStore {
  static const String metaBox = '__meta__';

  static bool get isAvailable {
    try {
      return _AndroidMmkvBindings.isAvailable();
    } catch (_) {
      return false;
    }
  }

  static String migrationKey(String name) => 'migrated:$name:v1';

  static String? exportBox(String name) => _AndroidMmkvBindings.exportBox(name);

  static bool replaceBox(String name, String json) =>
      _AndroidMmkvBindings.replaceBox(name, json);

  static String? getRaw(String name, String key) {
    try {
      final json = exportBox(name);
      if (json == null) return null;
      final decoded = jsonDecode(json);
      return decoded is Map ? decoded[key] as String? : null;
    } catch (_) {
      return null;
    }
  }

  static bool putRaw(String name, String key, String value) =>
      _AndroidMmkvBindings.putString(name, key, value);

  static bool removeRaw(String name, String key) =>
      _AndroidMmkvBindings.removeValue(name, key);

  static bool clearBox(String name) => _AndroidMmkvBindings.clearBox(name);

  static bool sync(String name) => _AndroidMmkvBindings.sync(name);
}

Map<String, String>? _encodeMap(Map<dynamic, dynamic> entries) {
  final encoded = <String, String>{};
  for (final MapEntry(:key, :value) in entries.entries) {
    final encodedValue = _encodeEntry(value);
    if (encodedValue == null) return null;
    encoded[_encodeKey(key)] = encodedValue;
  }
  return encoded;
}

String _encodeKey(dynamic key) => jsonEncode(_encodeJsonValue(key));

dynamic _decodeKey(String key) => _decodeJsonValue(jsonDecode(key));

String? _encodeEntry(dynamic value) {
  try {
    return jsonEncode({'value': _encodeJsonValue(value)});
  } catch (_) {
    return null;
  }
}

dynamic _decodeEntry(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map || !decoded.containsKey('value')) {
    throw const FormatException('Invalid MMKV entry');
  }
  return _decodeJsonValue(decoded['value']);
}

dynamic _encodeJsonValue(dynamic value) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is Uint8List) {
    return {'@type': 'uint8List', 'value': base64Encode(value)};
  }
  if (value is Set) {
    return {'@type': 'set', 'value': value.map(_encodeJsonValue).toList()};
  }
  if (value is List) {
    return value.map(_encodeJsonValue).toList();
  }
  if (value is Map) {
    return {
      '@type': 'map',
      'value': value.entries
          .map(
            (entry) => [
              _encodeJsonValue(entry.key),
              _encodeJsonValue(entry.value),
            ],
          )
          .toList(),
    };
  }
  throw UnsupportedError('Unsupported MMKV value: $value');
}

dynamic _decodeJsonValue(dynamic value) {
  if (value is List) {
    return value.map(_decodeJsonValue).toList();
  }
  if (value is Map) {
    return switch (value['@type']) {
      'uint8List' => base64Decode(value['value'] as String),
      'set' => (value['value'] as List).map(_decodeJsonValue).toSet(),
      'map' => Map<dynamic, dynamic>.fromEntries(
        (value['value'] as List).map((entry) {
          final pair = entry as List;
          return MapEntry(_decodeJsonValue(pair[0]), _decodeJsonValue(pair[1]));
        }),
      ),
      _ => value.map((key, value) => MapEntry(key, _decodeJsonValue(value))),
    };
  }
  return value;
}

abstract final class _AndroidMmkvBindings {
  static final _class = jni$_.JClass.forName(
    r'com/chloemlla/piliplus/AndroidMmkv',
  );

  static final _id_isAvailable = _class.staticMethodId(r'isAvailable', r'()Z');

  static final _isAvailable =
      jni$_.ProtectedJniExtensions.lookup<
            jni$_.NativeFunction<
              jni$_.JniResult Function(
                jni$_.Pointer<jni$_.Void>,
                jni$_.JMethodIDPtr,
              )
            >
          >('globalEnv_CallStaticBooleanMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
            )
          >();

  static bool isAvailable() {
    final classRef = _class.reference;
    return _isAvailable(classRef.pointer, _id_isAvailable.pointer).boolean;
  }

  static final _id_exportBox = _class.staticMethodId(
    r'exportBox',
    r'(Ljava/lang/String;)Ljava/lang/String;',
  );

  static final _exportBox =
      jni$_.ProtectedJniExtensions.lookup<
            jni$_.NativeFunction<
              jni$_.JniResult Function(
                jni$_.Pointer<jni$_.Void>,
                jni$_.JMethodIDPtr,
                jni$_.VarArgs<(jni$_.Pointer<jni$_.Void>,)>,
              )
            >
          >('globalEnv_CallStaticObjectMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
              jni$_.Pointer<jni$_.Void>,
            )
          >();

  static String? exportBox(String name) {
    final jName = name.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      return _exportBox(
        classRef.pointer,
        _id_exportBox.pointer,
        nameRef.pointer,
      ).object<jni$_.JString?>()?.toDartString(releaseOriginal: true);
    } finally {
      jName.release();
    }
  }

  static final _id_replaceBox = _class.staticMethodId(
    r'replaceBox',
    r'(Ljava/lang/String;Ljava/lang/String;)Z',
  );

  static final _replaceBox =
      jni$_.ProtectedJniExtensions.lookup<
            jni$_.NativeFunction<
              jni$_.JniResult Function(
                jni$_.Pointer<jni$_.Void>,
                jni$_.JMethodIDPtr,
                jni$_.VarArgs<
                  (jni$_.Pointer<jni$_.Void>, jni$_.Pointer<jni$_.Void>)
                >,
              )
            >
          >('globalEnv_CallStaticBooleanMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
              jni$_.Pointer<jni$_.Void>,
              jni$_.Pointer<jni$_.Void>,
            )
          >();

  static bool replaceBox(String name, String json) {
    final jName = name.toJString();
    final jJson = json.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      final jsonRef = jJson.reference;
      return _replaceBox(
        classRef.pointer,
        _id_replaceBox.pointer,
        nameRef.pointer,
        jsonRef.pointer,
      ).boolean;
    } finally {
      jName.release();
      jJson.release();
    }
  }

  static final _id_putString = _class.staticMethodId(
    r'putString',
    r'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Z',
  );

  static final _putString =
      jni$_.ProtectedJniExtensions.lookup<
            jni$_.NativeFunction<
              jni$_.JniResult Function(
                jni$_.Pointer<jni$_.Void>,
                jni$_.JMethodIDPtr,
                jni$_.VarArgs<
                  (
                    jni$_.Pointer<jni$_.Void>,
                    jni$_.Pointer<jni$_.Void>,
                    jni$_.Pointer<jni$_.Void>,
                  )
                >,
              )
            >
          >('globalEnv_CallStaticBooleanMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
              jni$_.Pointer<jni$_.Void>,
              jni$_.Pointer<jni$_.Void>,
              jni$_.Pointer<jni$_.Void>,
            )
          >();

  static bool putString(String name, String key, String value) {
    final jName = name.toJString();
    final jKey = key.toJString();
    final jValue = value.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      final keyRef = jKey.reference;
      final valueRef = jValue.reference;
      return _putString(
        classRef.pointer,
        _id_putString.pointer,
        nameRef.pointer,
        keyRef.pointer,
        valueRef.pointer,
      ).boolean;
    } finally {
      jName.release();
      jKey.release();
      jValue.release();
    }
  }

  static final _id_removeValue = _class.staticMethodId(
    r'removeValue',
    r'(Ljava/lang/String;Ljava/lang/String;)Z',
  );

  static final _removeValue =
      jni$_.ProtectedJniExtensions.lookup<
            jni$_.NativeFunction<
              jni$_.JniResult Function(
                jni$_.Pointer<jni$_.Void>,
                jni$_.JMethodIDPtr,
                jni$_.VarArgs<
                  (jni$_.Pointer<jni$_.Void>, jni$_.Pointer<jni$_.Void>)
                >,
              )
            >
          >('globalEnv_CallStaticBooleanMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
              jni$_.Pointer<jni$_.Void>,
              jni$_.Pointer<jni$_.Void>,
            )
          >();

  static bool removeValue(String name, String key) {
    final jName = name.toJString();
    final jKey = key.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      final keyRef = jKey.reference;
      return _removeValue(
        classRef.pointer,
        _id_removeValue.pointer,
        nameRef.pointer,
        keyRef.pointer,
      ).boolean;
    } finally {
      jName.release();
      jKey.release();
    }
  }

  static final _id_clearBox = _class.staticMethodId(
    r'clearBox',
    r'(Ljava/lang/String;)Z',
  );

  static final _clearBox =
      jni$_.ProtectedJniExtensions.lookup<
            jni$_.NativeFunction<
              jni$_.JniResult Function(
                jni$_.Pointer<jni$_.Void>,
                jni$_.JMethodIDPtr,
                jni$_.VarArgs<(jni$_.Pointer<jni$_.Void>,)>,
              )
            >
          >('globalEnv_CallStaticBooleanMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
              jni$_.Pointer<jni$_.Void>,
            )
          >();

  static bool clearBox(String name) {
    final jName = name.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      return _clearBox(
        classRef.pointer,
        _id_clearBox.pointer,
        nameRef.pointer,
      ).boolean;
    } finally {
      jName.release();
    }
  }

  static final _id_sync = _class.staticMethodId(
    r'sync',
    r'(Ljava/lang/String;)Z',
  );

  static final _sync =
      jni$_.ProtectedJniExtensions.lookup<
            jni$_.NativeFunction<
              jni$_.JniResult Function(
                jni$_.Pointer<jni$_.Void>,
                jni$_.JMethodIDPtr,
                jni$_.VarArgs<(jni$_.Pointer<jni$_.Void>,)>,
              )
            >
          >('globalEnv_CallStaticBooleanMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
              jni$_.Pointer<jni$_.Void>,
            )
          >();

  static bool sync(String name) {
    final jName = name.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      return _sync(classRef.pointer, _id_sync.pointer, nameRef.pointer).boolean;
    } finally {
      jName.release();
    }
  }
}
