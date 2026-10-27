import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Small JSON documents kept on the phone (cached days, the offline outbox).
abstract class LocalStore {
  /// The document saved under [key], or null.
  Future<Map<String, dynamic>?> read(String key);

  /// Saves [value] under [key] (replaces the old document).
  Future<void> write(String key, Map<String, dynamic> value);

  /// Removes the document under [key].
  Future<void> delete(String key);

  /// Removes everything (logout, account deleted): no health data stays on the phone.
  Future<void> clear();
}

/// One JSON file per key in the app's private documents folder.
///
/// Health data stays inside the app sandbox (not in backups shared with other apps) and is
/// deleted with the app or on logout / account deletion.
class FileLocalStore implements LocalStore {
  /// Creates the store; [directory] can be given in tests.
  FileLocalStore([Directory? directory]) : _directory = directory;

  Directory? _directory;

  Future<File> _file(String key) async {
    final base = _directory ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}/tamra_offline',
    );
    await base.create(recursive: true);
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${base.path}/$safe.json');
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null; // a broken file is treated as "no cache"
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final file = await _file(key);
    // Write to a temp file first so a crash never leaves half a document.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clear() async {
    final folder = (await _file('x')).parent;
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

/// Documents kept in memory (tests).
class MemoryLocalStore implements LocalStore {
  /// The stored documents, by key.
  final Map<String, Map<String, dynamic>> documents = {};

  @override
  Future<Map<String, dynamic>?> read(String key) async => documents[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async =>
      documents[key] = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  Future<void> delete(String key) async => documents.remove(key);

  @override
  Future<void> clear() async => documents.clear();
}

/// The store of the app (memory in tests).
final localStoreProvider = Provider<LocalStore>((ref) => FileLocalStore());
