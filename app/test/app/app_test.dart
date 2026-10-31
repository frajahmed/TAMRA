import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/auth/auth_controller.dart';
import 'package:tamra_app/features/debug/presentation/debug_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('diary start screen shows German texts, left-to-right',
      (tester) async {
    useTallView(tester);
    await tester.pumpWidget(testApp(locale: const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Frühstück'), findsOneWidget);
    final direction =
        Directionality.of(tester.element(find.byKey(const Key('home-title'))));
    expect(direction, TextDirection.ltr);
  });

  testWidgets('Arabic switches the layout to right-to-left', (tester) async {
    useTallView(tester);
    await tester.pumpWidget(testApp(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('الفطور'), findsOneWidget);
    final direction =
        Directionality.of(tester.element(find.byKey(const Key('home-title'))));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('logged out users see the login screen', (tester) async {
    await tester.pumpWidget(testApp(auth: const AuthState.loggedOut()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('new users must give consent first', (tester) async {
    await tester.pumpWidget(
      testApp(
        auth: const AuthState(
            status: AuthStatus.loggedIn,
            needsConsent: true,
            needsProfile: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-checkbox')), findsOneWidget);
  });

  testWidgets('logout returns to the login screen', (tester) async {
    useTallView(tester);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('debug screen shows the server status', (tester) async {
    await tester.pumpWidget(
      testApp(overrides: [healthProvider.overrideWith((ref) async => true)]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-debug')));
    await tester.pumpAndSettle();

    expect(find.text('Server reachable'), findsOneWidget);
  });

  testWidgets('debug screen shows an error when the server is down',
      (tester) async {
    await tester.pumpWidget(
      testApp(overrides: [healthProvider.overrideWith((ref) async => false)]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-debug')));
    await tester.pumpAndSettle();

    expect(find.text('Server not reachable'), findsOneWidget);
  });
}
