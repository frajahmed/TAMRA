import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/core/auth/auth_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('valid input logs in and opens the app', (tester) async {
    final controller = FakeAuthController(const AuthState.loggedOut());
    await tester.pumpWidget(testApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login-email')), 'user@example.com');
    await tester.enterText(
        find.byKey(const Key('login-password')), 'secret-123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(controller.calls, ['login:user@example.com']);
    expect(find.byKey(const Key('home-title')), findsOneWidget);
  });

  testWidgets('invalid email is rejected before calling the API',
      (tester) async {
    final controller = FakeAuthController(const AuthState.loggedOut());
    await tester.pumpWidget(testApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login-email')), 'no-email');
    await tester.enterText(
        find.byKey(const Key('login-password')), 'secret-123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(controller.calls, isEmpty);
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('server error is shown under the form', (tester) async {
    final controller = FakeAuthController(
      const AuthState.loggedOut(),
      loginError: const ApiError(
        code: 'no_active_account',
        message: 'No active account found with the given credentials',
        statusCode: 401,
      ),
    );
    await tester.pumpWidget(testApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login-email')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('No active account found with the given credentials'),
        findsOneWidget);
  });

  testWidgets('register needs 10 characters and then leads to consent',
      (tester) async {
    final controller = FakeAuthController(const AuthState.loggedOut());
    await tester.pumpWidget(testApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-switch')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('register-email')), 'neu@example.com');
    await tester.enterText(find.byKey(const Key('register-password')), 'short');
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();
    expect(find.text('The password needs at least 10 characters.'),
        findsOneWidget);
    expect(controller.calls, isEmpty);

    await tester.enterText(
        find.byKey(const Key('register-password')), 'long-enough-1');
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(controller.calls, ['register:neu@example.com']);
    expect(find.byKey(const Key('consent-checkbox')), findsOneWidget);
  });
}
