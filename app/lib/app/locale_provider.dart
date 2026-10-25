import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The language chosen by the user. `null` means: follow the device language.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  /// Switches the app language (null = device language).
  void setLocale(Locale? locale) => state = locale;
}

/// The chosen app language; null means "use the device language".
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
