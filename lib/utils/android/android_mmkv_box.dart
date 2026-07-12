// ignore_for_file: cascade_invocations, invalid_use_of_internal_member
// ignore_for_file: library_prefixes, non_constant_identifier_names
// ignore_for_file: prefer_initializing_formals, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:jni/_internal.dart' as jni$_;
import 'package:jni/jni.dart' as jni$_;

const _$jniVersionCheck = jni$_.JniVersionCheck(1, 0);

typedef AndroidMmkvValueEncoder<E> = Object? Function(E value);
typedef AndroidMmkvValueDecoder<E> = E Function(Object? value);

enum AndroidMmkvLoadMode {
  /// Decode all entries into memory on open (default).
  eager,

  /// Load keys only; decode values on first access. Best for large boxes.
  lazy,
}

Future<Box<E>> openAndroidMmkvBackedBox<E>({
  required String name,
  required Future<Box<E>> Function() openHive,
  KeyComparator? keyComparator,
  AndroidMmkvValueEncoder<E>? valueEncoder,
  AndroidMmkvValueDecoder<E>? valueDecoder,
  AndroidMmkvStoreBackend store = const AndroidMmkvStore(),
  bool? isAndroid,
  AndroidMmkvLoadMode loadMode = AndroidMmkvLoadMode.eager,
}) async {
  if (!(isAndroid ?? Platform.isAndroid) || !store.isAvailable) {
    return openHive();
  }

  final migrationKey = AndroidMmkvStore.migrationKey(name);
  if (store.getRaw(AndroidMmkvStore.metaBox, migrationKey) == '1') {
    final box = AndroidMmkvBackedBox<E>(
      name,
      keyComparator: keyComparator,
      valueEncoder: valueEncoder,
      valueDecoder: valueDecoder,
      store: store,
      loadMode: loadMode,
    );
    if (box.tryLoadFromMmkv()) {
      return box;
    }
    throw StateError(
      'MMKV box $name is marked as migrated but cannot be decoded; '
      'legacy Hive data was left untouched to avoid restoring stale data.',
    );
  }

  final hive = await openHive();
  final box = AndroidMmkvBackedBox<E>(
    hive.name,
    keyComparator: keyComparator,
    valueEncoder: valueEncoder,
    valueDecoder: valueDecoder,
    store: store,
    loadMode: loadMode,
  );
  if (!box.replaceAllFrom(hive.toMap())) {
    return hive;
  }

  if (!store.putRaw(AndroidMmkvStore.metaBox, migrationKey, '1') ||
      !store.sync(AndroidMmkvStore.metaBox)) {
    return hive;
  }

  await hive.close();
  return box;
}

final class AndroidMmkvBackedBox<E> implements Box<E> {
  AndroidMmkvBackedBox(
    this.name, {
    KeyComparator? keyComparator,
    AndroidMmkvValueEncoder<E>? valueEncoder,
    AndroidMmkvValueDecoder<E>? valueDecoder,
    AndroidMmkvStoreBackend store = const AndroidMmkvStore(),
    AndroidMmkvLoadMode loadMode = AndroidMmkvLoadMode.eager,
  }) : _keyComparator = keyComparator,
       _valueEncoder = valueEncoder,
       _valueDecoder = valueDecoder,
       _store = store,
       _loadMode = loadMode;

  @override
  final String name;

  final KeyComparator? _keyComparator;
  final AndroidMmkvValueEncoder<E>? _valueEncoder;
  final AndroidMmkvValueDecoder<E>? _valueDecoder;
  final AndroidMmkvStoreBackend _store;
  final AndroidMmkvLoadMode _loadMode;
  final Map<dynamic, E> _cache = <dynamic, E>{};
  /// Encoded keys present on disk but not yet decoded into [_cache] (lazy mode).
  final Set<String> _pendingEncodedKeys = <String>{};
  final StreamController<BoxEvent> _events =
      StreamController<BoxEvent>.broadcast(sync: true);

  bool _open = true;
  int _nextAutoKey = 0;
  bool get _isLazy => _loadMode == AndroidMmkvLoadMode.lazy;

  bool tryLoadFromMmkv() {
    try {
      _checkOpen();
      if (_isLazy) {
        final keysJson = _store.exportKeys(name);
        if (keysJson == null) return false;
        final decoded = jsonDecode(keysJson);
        if (decoded is! List) return false;
        _cache.clear();
        _pendingEncodedKeys
          ..clear()
          ..addAll(decoded.whereType<String>());
        _resetNextAutoKey();
        return true;
      }

      final json = _store.exportBox(name);
      if (json == null) return false;

      final decoded = jsonDecode(json);
      if (decoded is! Map) return false;

      final next = <dynamic, E>{};
      for (final MapEntry(:key, :value) in decoded.entries) {
        if (key is! String || value is! String) return false;
        next[_decodeKey(key)] = _decodeEntry(value, _valueDecoder);
      }

      _cache
        ..clear()
        ..addAll(next);
      _pendingEncodedKeys.clear();
      _resetNextAutoKey();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool replaceAllFrom(Map<dynamic, E> entries) {
    _checkOpen();
    final encoded = _encodeMap(entries, _valueEncoder);
    if (encoded == null) return false;
    if (!_store.replaceBox(name, jsonEncode(encoded))) {
      return false;
    }

    _cache
      ..clear()
      ..addAll(entries);
    _pendingEncodedKeys.clear();
    _resetNextAutoKey();
    return true;
  }

  @override
  Iterable<E> get values {
    _materializeAll();
    return _sortedKeys().map((key) => _cache[key] as E);
  }

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
    if (_cache.containsKey(key)) return _cache[key];
    if (_materializeKey(key)) return _cache[key];
    return defaultValue;
  }

  @override
  E? getAt(int index) {
    _checkOpen();
    final key = keyAt(index);
    return get(key);
  }

  @override
  Map<dynamic, E> toMap() {
    _checkOpen();
    _materializeAll();
    return Map<dynamic, E>.of(_cache);
  }

  @override
  String? get path => 'mmkv://$name';

  @override
  bool get isOpen => _open;

  @override
  bool get lazy => _isLazy;

  @override
  Iterable<dynamic> get keys => _sortedKeys();

  @override
  int get length {
    _checkOpen();
    if (!_isLazy || _pendingEncodedKeys.isEmpty) return _cache.length;
    // Count unique logical keys: cache + pending not already cached.
    return _cache.length + _pendingEncodedKeys.length;
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
    if (_cache.containsKey(key)) return true;
    if (!_isLazy) return false;
    final encoded = _encodeKey(key);
    if (_pendingEncodedKeys.contains(encoded)) return true;
    return _store.containsKey(name, encoded);
  }

  @override
  Future<void> put(dynamic key, E value) {
    _checkOpen();
    final encodedKey = _encodeKey(key);
    final encodedValue = _encodeEntry(value, _valueEncoder);
    if (encodedValue == null) {
      return Future.error(
        UnsupportedError('Unsupported MMKV value for $name.$key: $value'),
      );
    }
    if (!_store.putRaw(name, encodedKey, encodedValue)) {
      return Future.error(StateError('MMKV put failed for $name.$key'));
    }

    _pendingEncodedKeys.remove(encodedKey);
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
    if (entries.isEmpty) return Future.value();

    final encoded = _encodeMap(entries, _valueEncoder);
    if (encoded == null) {
      return Future.error(
        UnsupportedError('Unsupported MMKV value in $name.putAll'),
      );
    }

    if (!_store.putAllRaw(name, encoded)) {
      return Future.error(StateError('MMKV putAll failed for $name'));
    }

    for (final key in encoded.keys) {
      _pendingEncodedKeys.remove(key);
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
    final encodedKey = _encodeKey(key);
    if (!_store.removeRaw(name, encodedKey)) {
      return Future.error(StateError('MMKV delete failed for $name.$key'));
    }
    final hadPending = _pendingEncodedKeys.remove(encodedKey);
    final hadValue = _cache.containsKey(key);
    final oldValue = _cache.remove(key);
    if (hadValue || hadPending) {
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
    final encodedKeys = <String>[];
    for (final key in keys) {
      final encodedKey = _encodeKey(key);
      final inCache = _cache.containsKey(key);
      final inPending = _pendingEncodedKeys.contains(encodedKey);
      if (!inCache && !inPending) continue;
      deleted.add(MapEntry<dynamic, E?>(key, inCache ? _cache[key] : null));
      encodedKeys.add(encodedKey);
    }
    if (encodedKeys.isEmpty) return Future.value();

    if (!_store.removeAllRaw(name, encodedKeys)) {
      return Future.error(StateError('MMKV deleteAll failed for $name'));
    }

    for (final MapEntry(:key, :value) in deleted) {
      _cache.remove(key);
      _pendingEncodedKeys.remove(_encodeKey(key));
      _events.add(BoxEvent(key, value, true));
    }
    return Future.value();
  }

  @override
  Future<void> compact() {
    _checkOpen();
    // MMKV manages its own file layout; avoid expensive process-wide sync here.
    return Future.value();
  }

  @override
  Future<int> clear() {
    _checkOpen();
    if (!_store.clearBox(name)) {
      return Future.error(StateError('MMKV clear failed for $name'));
    }

    final count = length;
    final deleted = Map<dynamic, E>.of(_cache);
    _cache.clear();
    _pendingEncodedKeys.clear();
    for (final MapEntry(:key, :value) in deleted.entries) {
      _events.add(BoxEvent(key, value, true));
    }
    return Future.value(count);
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    // MMKV mmap writes are durable without forced sync; skip flush on close
    // to avoid exit jank. Callers that need fsync can still await flush().
    _open = false;
    _cache.clear();
    _pendingEncodedKeys.clear();
    await _events.close();
  }

  @override
  Future<void> deleteFromDisk() async {
    if (_open) {
      await clear();
      await close();
    } else {
      if (!_store.clearBox(name)) {
        throw StateError('MMKV clear failed for $name');
      }
    }
  }

  @override
  Future<void> flush() {
    _checkOpen();
    if (!_store.sync(name)) {
      return Future.error(StateError('MMKV sync failed for $name'));
    }
    return Future.value();
  }

  List<dynamic> _sortedKeys() {
    _checkOpen();
    if (_isLazy && _pendingEncodedKeys.isNotEmpty) {
      final keys = <dynamic>{
        ..._cache.keys,
        for (final encoded in _pendingEncodedKeys) _decodeKey(encoded),
      }.toList();
      keys.sort(_keyComparator ?? _defaultKeyComparator);
      return keys;
    }
    final keys = _cache.keys.toList();
    keys.sort(_keyComparator ?? _defaultKeyComparator);
    return keys;
  }

  bool _materializeKey(dynamic key) {
    if (!_isLazy) return false;
    final encodedKey = _encodeKey(key);
    if (!_pendingEncodedKeys.contains(encodedKey) &&
        !_store.containsKey(name, encodedKey)) {
      return false;
    }
    final raw = _store.getRaw(name, encodedKey);
    if (raw == null) {
      _pendingEncodedKeys.remove(encodedKey);
      return false;
    }
    try {
      final value = _decodeEntry(raw, _valueDecoder);
      _cache[key] = value;
      _pendingEncodedKeys.remove(encodedKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _materializeAll() {
    if (!_isLazy || _pendingEncodedKeys.isEmpty) return;
    // Prefer one export for bulk materialization when many keys remain.
    if (_pendingEncodedKeys.length > 8) {
      final json = _store.exportBox(name);
      if (json != null) {
        try {
          final decoded = jsonDecode(json);
          if (decoded is Map) {
            for (final MapEntry(:key, :value) in decoded.entries) {
              if (key is! String || value is! String) continue;
              final logical = _decodeKey(key);
              if (_cache.containsKey(logical)) continue;
              _cache[logical] = _decodeEntry(value, _valueDecoder);
            }
            _pendingEncodedKeys.clear();
            return;
          }
        } catch (_) {
          // Fall through to per-key materialization.
        }
      }
    }
    for (final encoded in _pendingEncodedKeys.toList(growable: false)) {
      final logical = _decodeKey(encoded);
      if (_cache.containsKey(logical)) {
        _pendingEncodedKeys.remove(encoded);
        continue;
      }
      _materializeKey(logical);
    }
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

abstract interface class AndroidMmkvStoreBackend {
  bool get isAvailable;

  String? exportBox(String name);

  String? exportKeys(String name);

  bool replaceBox(String name, String json);

  String? getRaw(String name, String key);

  bool containsKey(String name, String key);

  bool putRaw(String name, String key, String value);

  bool putAllRaw(String name, Map<String, String> entries);

  bool removeRaw(String name, String key);

  bool removeAllRaw(String name, Iterable<String> keys);

  bool clearBox(String name);

  bool sync(String name);
}

final class AndroidMmkvStore implements AndroidMmkvStoreBackend {
  const AndroidMmkvStore();

  static const String metaBox = '__meta__';

  @override
  bool get isAvailable {
    try {
      return _AndroidMmkvBindings.isAvailable();
    } catch (_) {
      return false;
    }
  }

  static String migrationKey(String name) => 'migrated:$name:v1';

  @override
  String? exportBox(String name) => _AndroidMmkvBindings.exportBox(name);

  @override
  String? exportKeys(String name) => _AndroidMmkvBindings.exportKeys(name);

  @override
  bool replaceBox(String name, String json) =>
      _AndroidMmkvBindings.replaceBox(name, json);

  @override
  String? getRaw(String name, String key) =>
      _AndroidMmkvBindings.getString(name, key);

  @override
  bool containsKey(String name, String key) =>
      _AndroidMmkvBindings.containsKey(name, key);

  @override
  bool putRaw(String name, String key, String value) =>
      _AndroidMmkvBindings.putString(name, key, value);

  @override
  bool putAllRaw(String name, Map<String, String> entries) {
    if (entries.isEmpty) return true;
    return _AndroidMmkvBindings.putAllStrings(name, jsonEncode(entries));
  }

  @override
  bool removeRaw(String name, String key) =>
      _AndroidMmkvBindings.removeValue(name, key);

  @override
  bool removeAllRaw(String name, Iterable<String> keys) {
    final list = keys.toList(growable: false);
    if (list.isEmpty) return true;
    return _AndroidMmkvBindings.removeValues(name, jsonEncode(list));
  }

  @override
  bool clearBox(String name) => _AndroidMmkvBindings.clearBox(name);

  @override
  bool sync(String name) => _AndroidMmkvBindings.sync(name);
}

Map<String, String>? _encodeMap<E>(
  Map<dynamic, E> entries,
  AndroidMmkvValueEncoder<E>? valueEncoder,
) {
  final encoded = <String, String>{};
  for (final MapEntry(:key, :value) in entries.entries) {
    final encodedValue = _encodeEntry(value, valueEncoder);
    if (encodedValue == null) return null;
    encoded[_encodeKey(key)] = encodedValue;
  }
  return encoded;
}

String _encodeKey(dynamic key) => jsonEncode(_encodeJsonValue(key));

dynamic _decodeKey(String key) => _decodeJsonValue(jsonDecode(key));

String? _encodeEntry<E>(
  E value,
  AndroidMmkvValueEncoder<E>? valueEncoder,
) {
  try {
    return jsonEncode({
      'value': _encodeJsonValue(_encodeValue(value, valueEncoder)),
    });
  } catch (_) {
    return null;
  }
}

E _decodeEntry<E>(
  String value,
  AndroidMmkvValueDecoder<E>? valueDecoder,
) {
  final decoded = jsonDecode(value);
  if (decoded is! Map || !decoded.containsKey('value')) {
    throw const FormatException('Invalid MMKV entry');
  }
  final decodedValue = _decodeJsonValue(decoded['value']);
  return valueDecoder == null ? decodedValue as E : valueDecoder(decodedValue);
}

Object? _encodeValue<E>(
  E value,
  AndroidMmkvValueEncoder<E>? valueEncoder,
) => valueEncoder == null ? value : valueEncoder(value);

dynamic _encodeJsonValue(dynamic value) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is Uint8List) {
    return {'@type': 'uint8List', 'value': base64Encode(value)};
  }
  if (value is Set) {
    return {
      '@type': 'set',
      'elementType': _setElementType(value),
      'value': value.map(_encodeJsonValue).toList(),
    };
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
      'set' => _decodeSet(value),
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

String _setElementType(Set<dynamic> value) {
  if (value is Set<int>) {
    return 'int';
  }
  if (value is Set<double>) {
    return 'double';
  }
  if (value is Set<num>) {
    return 'num';
  }
  if (value is Set<String>) {
    return 'string';
  }
  if (value is Set<bool>) {
    return 'bool';
  }
  if (value.isEmpty) return 'dynamic';
  if (value.every((item) => item is int)) return 'int';
  if (value.every((item) => item is double)) return 'double';
  if (value.every((item) => item is num)) return 'num';
  if (value.every((item) => item is String)) return 'string';
  if (value.every((item) => item is bool)) return 'bool';
  return 'dynamic';
}

Set<dynamic> _decodeSet(Map<dynamic, dynamic> value) {
  final decoded = (value['value'] as List).map(_decodeJsonValue).toList();
  switch (value['elementType']) {
    case 'int':
      return decoded.cast<int>().toSet();
    case 'double':
      return decoded.cast<double>().toSet();
    case 'num':
      return decoded.cast<num>().toSet();
    case 'string':
      return decoded.cast<String>().toSet();
    case 'bool':
      return decoded.cast<bool>().toSet();
  }
  if (decoded.every((item) => item is int)) {
    return decoded.cast<int>().toSet();
  }
  if (decoded.every((item) => item is double)) {
    return decoded.cast<double>().toSet();
  }
  if (decoded.every((item) => item is num)) {
    return decoded.cast<num>().toSet();
  }
  if (decoded.every((item) => item is String)) {
    return decoded.cast<String>().toSet();
  }
  if (decoded.every((item) => item is bool)) {
    return decoded.cast<bool>().toSet();
  }
  return decoded.toSet();
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


  static final _id_exportKeys = _class.staticMethodId(
    r'exportKeys',
    r'(Ljava/lang/String;)Ljava/lang/String;',
  );

  static final _exportKeys =
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

  static String? exportKeys(String name) {
    final jName = name.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      return _exportKeys(
        classRef.pointer,
        _id_exportKeys.pointer,
        nameRef.pointer,
      ).object<jni$_.JString?>()?.toDartString(releaseOriginal: true);
    } finally {
      jName.release();
    }
  }

  static final _id_containsKey = _class.staticMethodId(
    r'containsKey',
    r'(Ljava/lang/String;Ljava/lang/String;)Z',
  );

  static final _containsKey =
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

  static bool containsKey(String name, String key) {
    final jName = name.toJString();
    final jKey = key.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      final keyRef = jKey.reference;
      return _containsKey(
        classRef.pointer,
        _id_containsKey.pointer,
        nameRef.pointer,
        keyRef.pointer,
      ).boolean;
    } finally {
      jName.release();
      jKey.release();
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


  static final _id_getString = _class.staticMethodId(
    r'getString',
    r'(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;',
  );

  static final _getString =
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
          >('globalEnv_CallStaticObjectMethod')
          .asFunction<
            jni$_.JniResult Function(
              jni$_.Pointer<jni$_.Void>,
              jni$_.JMethodIDPtr,
              jni$_.Pointer<jni$_.Void>,
              jni$_.Pointer<jni$_.Void>,
            )
          >();

  static String? getString(String name, String key) {
    final jName = name.toJString();
    final jKey = key.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      final keyRef = jKey.reference;
      return _getString(
        classRef.pointer,
        _id_getString.pointer,
        nameRef.pointer,
        keyRef.pointer,
      ).object<jni$_.JString?>()?.toDartString(releaseOriginal: true);
    } finally {
      jName.release();
      jKey.release();
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


  static final _id_putAllStrings = _class.staticMethodId(
    r'putAllStrings',
    r'(Ljava/lang/String;Ljava/lang/String;)Z',
  );

  static final _putAllStrings =
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

  static bool putAllStrings(String name, String json) {
    final jName = name.toJString();
    final jJson = json.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      final jsonRef = jJson.reference;
      return _putAllStrings(
        classRef.pointer,
        _id_putAllStrings.pointer,
        nameRef.pointer,
        jsonRef.pointer,
      ).boolean;
    } finally {
      jName.release();
      jJson.release();
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


  static final _id_removeValues = _class.staticMethodId(
    r'removeValues',
    r'(Ljava/lang/String;Ljava/lang/String;)Z',
  );

  static final _removeValues =
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

  static bool removeValues(String name, String keysJson) {
    final jName = name.toJString();
    final jKeys = keysJson.toJString();
    try {
      final classRef = _class.reference;
      final nameRef = jName.reference;
      final keysRef = jKeys.reference;
      return _removeValues(
        classRef.pointer,
        _id_removeValues.pointer,
        nameRef.pointer,
        keysRef.pointer,
      ).boolean;
    } finally {
      jName.release();
      jKeys.release();
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

