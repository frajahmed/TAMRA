import 'local_store.dart';

/// A change made while offline, waiting to be sent to the server.
class OutboxOperation {
  /// Creates an operation; [kind] is e.g. `diary.create`, [payload] the request data.
  const OutboxOperation({required this.kind, required this.payload});

  /// What to do on the server.
  final String kind;

  /// Data of the request (contains the entry id).
  final Map<String, dynamic> payload;

  /// Stored form.
  Map<String, dynamic> toJson() => {'kind': kind, 'payload': payload};

  /// Reads the stored form.
  factory OutboxOperation.fromJson(Map<String, dynamic> json) => OutboxOperation(
        kind: json['kind']?.toString() ?? '',
        payload: json['payload'] is Map<String, dynamic>
            ? json['payload'] as Map<String, dynamic>
            : const {},
      );
}

/// Ordered list of offline changes, kept in the [LocalStore] so it survives app restarts.
class Outbox {
  /// Creates the outbox on top of [store].
  Outbox(this._store);

  static const _key = 'outbox';
  final LocalStore _store;

  /// All waiting operations, oldest first.
  Future<List<OutboxOperation>> all() async {
    final items = (await _store.read(_key))?['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map<String, dynamic>) OutboxOperation.fromJson(item),
    ];
  }

  /// Adds [operation] at the end.
  Future<void> add(OutboxOperation operation) async => _save([...await all(), operation]);

  /// Removes the oldest operation (after it was sent or found invalid).
  Future<void> removeFirst() async {
    final items = await all();
    if (items.isNotEmpty) await _save(items.sublist(1));
  }

  /// Number of waiting operations.
  Future<int> get length async => (await all()).length;

  Future<void> _save(List<OutboxOperation> items) =>
      _store.write(_key, {'items': [for (final item in items) item.toJson()]});
}
