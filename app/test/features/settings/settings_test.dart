import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/app/locale_provider.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/features/onboarding/domain/profile.dart';

import '../../helpers/fakes.dart';

const _profile = Profile(kcalTarget: 1742, isComplete: true);

Future<void> _openProfile(
  WidgetTester tester, {
  FakeProfileRepository? profile,
  FakeAuthController? controller,
  FakeFileSharer? sharer,
  MemoryLanguageStorage? languageStorage,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      profile: profile ?? FakeProfileRepository(result: _profile),
      controller: controller,
      sharer: sharer,
      languageStorage: languageStorage,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav-profile')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the daily target', (tester) async {
    await _openProfile(tester);
    expect(find.text('1742 kcal'), findsOneWidget);
  });

  testWidgets('changing units saves them in the profile', (tester) async {
    final profile = FakeProfileRepository(result: _profile);
    await _openProfile(tester, profile: profile);

    await tester.tap(find.text('lb'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kJ'));
    await tester.pumpAndSettle();

    expect(profile.settingsChanges, [
      {'weight_unit': 'lb'},
      {'energy_unit': 'kj'},
    ]);
    expect(find.text('7289 kJ'), findsOneWidget); // target shown in the new unit
  });

  testWidgets('choosing a language switches the app and remembers it', (tester) async {
    final storage = MemoryLanguageStorage();
    final profile = FakeProfileRepository(result: _profile);
    await _openProfile(tester, profile: profile, languageStorage: storage);

    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsWidgets);
    expect(storage.code, 'de');
    expect(profile.settingsChanges.last, {'language': 'de'});
  });

  testWidgets('export hands the JSON file to the share menu', (tester) async {
    final sharer = FakeFileSharer();
    await _openProfile(tester, sharer: sharer);

    await tester.tap(find.byKey(const Key('export-data')));
    await tester.pumpAndSettle();

    expect(sharer.sharedNames, ['tamra-export-${dateKey(DateTime.now())}.json']);
    expect(sharer.sharedContents.single, contains('a@example.com'));
  });

  testWidgets('withdrawing the consent brings back the consent screen', (tester) async {
    final profile = FakeProfileRepository(result: _profile);
    await _openProfile(tester, profile: profile);

    await tester.tap(find.byKey(const Key('withdraw-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(profile.withdrawCalls, 1);
    expect(find.byKey(const Key('consent-checkbox')), findsOneWidget);
  });

  testWidgets('delete account needs the right password, then logs out', (tester) async {
    final profile = FakeProfileRepository(result: _profile);
    final controller = FakeAuthController(loggedInComplete);
    await _openProfile(tester, profile: profile, controller: controller);

    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('delete-password')), 'wrong');
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('The password is not correct.'), findsOneWidget);
    expect(controller.calls, isEmpty);

    await tester.enterText(find.byKey(const Key('delete-password')), 'secret-pass-1');
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();

    expect(profile.deletedWithPassword, ['secret-pass-1']);
    expect(controller.calls, ['accountDeleted']);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  test('memory language storage keeps the code', () async {
    final storage = MemoryLanguageStorage('fr');
    expect(await storage.read(), 'fr');
    await storage.write(null);
    expect(await storage.read(), isNull);
  });
}
