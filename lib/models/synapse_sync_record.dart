import 'dart:convert';

final class SynapseSyncRecord {
  const SynapseSyncRecord({
    required this.id,
    required this.category,
    required this.updatedAt,
    required this.deleted,
    required this.crypto,
    this.metadata,
    this.revision = 0,
  });

  final String id;
  final String category;
  final DateTime updatedAt;
  final bool deleted;
  final Map<String, Object?> crypto;
  final Object? metadata;
  final int revision;

  factory SynapseSyncRecord.fromJson(Object? value) {
    if (value is! Map || value['crypto'] is! Map) {
      throw const FormatException('Invalid Synapse sync record');
    }
    final updatedAt = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
    final id = value['id']?.toString() ?? '';
    final category = value['category']?.toString() ?? '';
    if (id.isEmpty || category.isEmpty || updatedAt == null) {
      throw const FormatException('Invalid Synapse sync record fields');
    }
    return SynapseSyncRecord(
      id: id,
      category: category,
      updatedAt: updatedAt.toUtc(),
      deleted: value['deleted'] == true,
      revision: (value['revision'] as num?)?.toInt() ?? 0,
      crypto: Map<String, Object?>.from(value['crypto'] as Map),
      metadata: value['metadata'],
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'category': category,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deleted': deleted,
    'crypto': crypto,
    if (metadata != null) 'metadata': metadata,
  };

  String encode() => jsonEncode(toJson());
}

