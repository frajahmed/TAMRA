import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/features/onboarding/domain/profile.dart';
import 'package:tamra_app/features/tracking/domain/tracking.dart';
import 'package:tamra_app/l10n/app_strings.dart';

import '../../helpers/fakes.dart';

final _today = dateKey(DateTime.now());

Future<void> _pumpApp(
  WidgetTester tester, {
  FakeTrackingRepository? tracking,
  FakeProfileRepository? profile,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(tracking: tracking, profile: profile));
  await tester.pumpAndSettle();
}

Future<void> _openWeight(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-profile')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('profile-weight')));
  await tester.pumpAndSettle();
}

Future<void> _addWeight(WidgetTester tester, String value) async {
  await tester.tap(find.byKey(const Key('weight-add')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('weight-input')), value);
  await tester.tap(find.byKey(const Key('weight-save')));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  group('water', () {
    testWidgets('plus adds a glass, minus removes the newest one', (tester) async {
      final tracking = FakeTrackingRepository();
      await _pumpApp(tester, tracking: tracking);
      expect(_text(tester, 'water-total'), '0 / 2000 ml');

      await tester.tap(find.byKey(const Key('water-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('water-add')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'water-total'), '500 / 2000 ml');

      await tester.tap(find.byKey(const Key('water-remove')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'water-total'), '250 / 2000 ml');
      expect(tracking.calls, ['water+250', 'water+250', 'water-water1']);
    });

    test('glasses never go beyond the goal', () {
      final day = WaterDay(
        date: DateTime(2026),
        entries: [for (var i = 0; i < 12; i++) WaterLog(id: '$i', amountMl: 250)],
      );
      expect(day.totalMl, 3000);
      expect(day.glasses, 8);
    });
  });

  group('weight', () {
    testWidgets('empty history explains when to weigh', (tester) async {
      await _pumpApp(tester);
      await _openWeight(tester);
      expect(find.byKey(const Key('weight-empty')), findsOneWidget);
    });

    testWidgets('adding a weight in kg shows it in the list and chart', (tester) async {
      final tracking = FakeTrackingRepository();
      await _pumpApp(tester, tracking: tracking);
      await _openWeight(tester);

      await _addWeight(tester, '75,5');

      expect(tracking.calls, ['weight:$_today:75.5']);
      expect(find.text('75.5 kg'), findsOneWidget);
      expect(find.byKey(const Key('weight-chart')), findsOneWidget);
    });

    testWidgets('lb input is stored in kg', (tester) async {
      final tracking = FakeTrackingRepository();
      await _pumpApp(
        tester,
        tracking: tracking,
        profile: FakeProfileRepository(result: const Profile(weightUnit: WeightUnit.lb)),
      );
      await _openWeight(tester);

      await _addWeight(tester, '166');

      expect(tracking.calls, ['weight:$_today:75.3']);
      expect(find.text('166 lb'), findsOneWidget);
    });

    testWidgets('a weight outside 30–300 kg is refused', (tester) async {
      final tracking = FakeTrackingRepository();
      await _pumpApp(tester, tracking: tracking);
      await _openWeight(tester);

      await _addWeight(tester, '20');

      expect(find.text('Please enter a value between 30 and 300.'), findsOneWidget);
      expect(tracking.calls, isEmpty);
    });

    testWidgets('delete removes the entry', (tester) async {
      final tracking = FakeTrackingRepository();
      await tracking.saveWeight(DateTime.now(), 80);
      await _pumpApp(tester, tracking: tracking);
      await _openWeight(tester);
      expect(find.text('80 kg'), findsOneWidget);

      await tester.tap(find.byKey(const Key('weight-delete-w0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weight-empty')), findsOneWidget);
    });

    test('weight text in kg and lb, with sign for changes', () {
      final strings = AppStrings(const Locale('en'));
      expect(strings.weight(75.5, WeightUnit.kg), '75.5 kg');
      expect(strings.weight(80, WeightUnit.lb), '176.4 lb');
      expect(strings.weight(-0.6, WeightUnit.kg, signed: true), '-0.6 kg');
      expect(strings.weight(1.2, WeightUnit.kg, signed: true), '+1.2 kg');
      expect(WeightUnit.lb.toKg(WeightUnit.lb.fromKg(70)), closeTo(70, 1e-9));
    });
  });
}
