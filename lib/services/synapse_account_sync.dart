import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

/// Tracks which per-account cookie was last uploaded to the Synapse vault so
/// an unchanged cookie is not re-sent on every sync tick.
final class SynapseSyncedAccountState {
  const SynapseSyncedAccountState({required this.cookieHash, required this.at});

  final String cookieHash;
  final String at;

  @override
  bool operator ==(Object other) =>
      other is SynapseSyncedAccountState &&
      cookieHash == other.cookieHash &&
      at == other.at;

  @override
  int get hashCode => Object.hash(cookieHash, at);

  Map<String, dynamic> toJson() => {'cookieHash': cookieHash, 'at': at};

  static SynapseSyncedAccountState? fromJson(Object? value) {
    if (value is! Map) return null;
    final cookieHash = value['cookieHash']?.toString() ?? '';
    final at = value['at']?.toString() ?? '';
    if (cookieHash.isEmpty) return null;
    return SynapseSyncedAccountState(cookieHash: cookieHash, at: at);
  }
}

String synapseCookieHash(String cookie) =>
    sha256.convert(utf8.encode(cookie)).toString();

Map<String, SynapseSyncedAccountState> decodeSyncedAccounts(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final result = <String, SynapseSyncedAccountState>{};
    for (final entry in decoded.entries) {
      final state = SynapseSyncedAccountState.fromJson(entry.value);
      if (entry.key is String && state != null) {
        result[entry.key as String] = state;
      }
    }
    return result;
  } catch (_) {
    return {};
  }
}

String encodeSyncedAccounts(Map<String, SynapseSyncedAccountState> accounts) =>
    jsonEncode({
      for (final entry in accounts.entries) entry.key: entry.value.toJson(),
    });

/// Returns the uids whose cookie differs from the last synced state, plus any
/// uid that has never been synced. [uidToCookie] is the current local snapshot.
List<String> findChangedAccountUids(
  Map<String, SynapseSyncedAccountState> previous,
  Map<String, String> uidToCookie,
) {
  final changed = <String>[];
  for (final entry in uidToCookie.entries) {
    if (previous[entry.key]?.cookieHash != synapseCookieHash(entry.value)) {
      changed.add(entry.key);
    }
  }
  return changed;
}
