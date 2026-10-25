import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/features/food/domain/food.dart';

import 'food_fakes.dart';

const _code = '4000417025005';

/// Opens search → scan and returns the fake camera.
Future<FakeBarcodeSource> _openScanner(
  WidgetTester tester,
  FakeFoodRepository repository,
  List<Food?> picked,
) async {
  final camera = FakeBarcodeSource();
  await tester.pumpWidget(foodTestApp(repository, picked, barcodeSource: camera));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('food-scan')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('fake-camera')), findsOneWidget);
  return camera;
}

void main() {
  testWidgets('a found code returns the food; the same code twice is looked up once',
      (tester) async {
    final repository = FakeFoodRepository();
    final picked = <Food?>[];
    final camera = await _openScanner(tester, repository, picked);

    camera
      ..emit(_code)
      ..emit(_code);
    await tester.pumpAndSettle();

    expect(repository.barcodes, [_code]);
    expect(picked, [apple]);
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('codes that are not food barcodes are ignored', (tester) async {
    final repository = FakeFoodRepository();
    final camera = await _openScanner(tester, repository, []);

    camera
      ..emit('https://example.com')
      ..emit('123');
    await tester.pumpAndSettle();

    expect(repository.barcodes, isEmpty);
  });

  testWidgets('unknown code shows a dialog; "scan again" allows the next code', (tester) async {
    final repository = FakeFoodRepository()..barcodeFood = null;
    final camera = await _openScanner(tester, repository, []);

    camera.emit(_code);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan-not-found')), findsOneWidget);
    expect(find.textContaining(_code), findsOneWidget);

    await tester.tap(find.byKey(const Key('scan-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-not-found')), findsNothing);

    camera.emit('40084015');
    await tester.pumpAndSettle();
    expect(repository.barcodes, [_code, '40084015']);
  });

  testWidgets('unknown code → create own food with the barcode filled in', (tester) async {
    useTallScreen(tester);
    final repository = FakeFoodRepository()..barcodeFood = null;
    final picked = <Food?>[];
    final camera = await _openScanner(tester, repository, picked);

    camera.emit(_code);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-create')));
    await tester.pumpAndSettle();

    final barcodeField = tester.widget<TextFormField>(find.byKey(const Key('custom-barcode')));
    expect(barcodeField.controller?.text, _code);

    await tester.enterText(find.byKey(const Key('custom-name')), 'Hafermilch');
    await tester.enterText(find.byKey(const Key('custom-kcal')), '46');
    await tester.tap(find.byKey(const Key('custom-save')));
    await tester.pumpAndSettle();

    expect(repository.created?.barcode, _code);
    expect(picked.single?.name, 'Hafermilch');
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('camera denied shows an explanation and opens the settings', (tester) async {
    final repository = FakeFoodRepository();
    final camera = await _openScanner(tester, repository, []);

    camera.deny();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan-denied')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-open-settings')));
    await tester.pump();
    expect(camera.settingsOpened, 1);
  });
}
