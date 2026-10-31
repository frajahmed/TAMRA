import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the chosen app language is kept between app starts.
abstract class LanguageStorage {
  /// The saved language code, or null for "device language".
  Future<String?> read();

  /// Saves [code]; null means "device language".
  Future<void> write(String? code);
}

/// Language stored with the phone's secure storage (no extra package needed).
class SecureLanguageStorage implements LanguageStorage {
  /// Creates the storage; [storage] can be replaced in tests.
  SecureLanguageStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'tamra_language';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? code) => code == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: code);
}

/// Language kept in memory (tests).
class MemoryLanguageStorage implements LanguageStorage {
  /// Creates the storage with an optional saved [code].
  MemoryLanguageStorage([this.code]);

  /// The saved language code.
  String? code;

  @override
  Future<String?> read() async => code;

  @override
  Future<void> write(String? code) async => this.code = code;
}

/// Where the language is saved (replaced by [MemoryLanguageStorage] in tests).
final languageStorageProvider =
    Provider<LanguageStorage>((ref) => SecureLanguageStorage());

/// The language chosen by the user. `null` means: follow the device language.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    unawaited(Future<void>.microtask(_load));
    return null;
  }

  Future<void> _load() async {
    final code = await ref.read(languageStorageProvider).read();
    if (code != null && state == null) state = Locale(code);
  }

  /// Switches the app language (null = device language) and remembers it.
  void setLocale(Locale? locale) {
    state = locale;
    unawaited(ref.read(languageStorageProvider).write(locale?.languageCode));
  }
}

/// The chosen app language; null means "use the device language".
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
