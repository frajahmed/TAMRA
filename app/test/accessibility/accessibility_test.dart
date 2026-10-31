import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/features/diary/domain/diary.dart';
import 'package:tamra_app/features/onboarding/domain/profile.dart';

import '../helpers/fakes.dart';

final _today = dateOnly(DateTime.now());

FakeDiaryRepository _diary() => FakeDiaryRepository(
      entries: [
        diaryEntry(
          id: 'e1',
          date: _today,
          meal: Meal.breakfast,
          name: 'Vollkorn-Haferflocken mit Joghurt und Beeren',
          grams: 250,
          kcal: 420,
        ),
      ],
    );

/// Pumps the app on a small phone (360 × 740) with the given language and text size.
Future<void> _pump(WidgetTester tester, {required Locale locale, double textScale = 1}) async {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    testApp(
      locale: locale,
      diary: _diary(),
      profile: FakeProfileRepository(result: const Profile(kcalTarget: 1850, weightKg: 70)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _visitTabs(WidgetTester tester) async {
  for (final tab in ['nav-stats', 'nav-activity', 'nav-profile', 'nav-diary']) {
    await tester.tap(find.byKey(Key(tab)));
    await tester.pumpAndSettle();
  }
}

void main() {
  // An overflow ("RenderFlex overflowed") fails these tests automatically.
  for (final locale in const [Locale('de'), Locale('ar'), Locale('fr')]) {
    testWidgets('all tabs fit on a small phone with 200 % text (${locale.languageCode})',
        (tester) async {
      await _pump(tester, locale: locale, textScale: 2);
      await _visitTabs(tester);
    });
  }

  testWidgets('tap targets are big enough and labelled (diary)', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, locale: const Locale('en'));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('tap targets are big enough and labelled (profile)', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('days in the week strip are read with the full date', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, locale: const Locale('en'));

    final label = MaterialLocalizations.of(tester.element(find.byKey(const Key('home-title'))))
        .formatFullDate(_today);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    handle.dispose();
  });
}
