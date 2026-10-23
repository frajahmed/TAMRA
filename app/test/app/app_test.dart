import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/app/app.dart';
import 'package:tamra_app/app/locale_provider.dart';
import 'package:tamra_app/features/debug/presentation/debug_screen.dart';

class _FixedLocale extends LocaleNotifier {
  _FixedLocale(this.locale);

  final Locale locale;

  @override
  Locale? build() => locale;
}

Widget _app(Locale locale, {bool serverOk = true}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith(() => _FixedLocale(locale)),
      healthProvider.overrideWith((ref) async => serverOk),
    ],
    child: const TamraApp(),
  );
}

void main() {
  testWidgets('home screen shows German texts, left-to-right', (tester) async {
    await tester.pumpWidget(_app(const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Willkommen bei TAMRA'), findsOneWidget);
    final direction = Directionality.of(tester.element(find.byKey(const Key('home-title'))));
    expect(direction, TextDirection.ltr);
  });

  testWidgets('Arabic switches the layout to right-to-left', (tester) async {
    await tester.pumpWidget(_app(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بك في تمرة'), findsOneWidget);
    final direction = Directionality.of(tester.element(find.byKey(const Key('home-title'))));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('debug screen shows the server status', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-debug')));
    await tester.pumpAndSettle();

    expect(find.text('Server reachable'), findsOneWidget);
  });

  testWidgets('debug screen shows an error when the server is down', (tester) async {
    await tester.pumpWidget(_app(const Locale('en'), serverOk: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-debug')));
    await tester.pumpAndSettle();

    expect(find.text('Server not reachable'), findsOneWidget);
  });
}
