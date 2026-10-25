import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/features/food/domain/food.dart';

import 'food_fakes.dart';

Future<void> _openForm(WidgetTester tester, FakeFoodRepository repository, List<Food?> picked) async {
  useTallScreen(tester);
  await tester.pumpWidget(foodTestApp(repository, picked));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('food-add-custom')));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('custom-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('name and kcal are required', (tester) async {
    final repository = FakeFoodRepository();
    await _openForm(tester, repository, []);

    await _save(tester);

    expect(find.text('This field is required.'), findsNWidgets(2));
    expect(repository.created, isNull);
  });

  testWidgets('kcal above 900 and an invalid barcode are rejected', (tester) async {
    final repository = FakeFoodRepository();
    await _openForm(tester, repository, []);

    await tester.enterText(find.byKey(const Key('custom-name')), 'Brot');
    await tester.enterText(find.byKey(const Key('custom-kcal')), '950');
    await tester.enterText(find.byKey(const Key('custom-barcode')), '123');
    await _save(tester);

    expect(find.text('Please enter a value between 0 and 900.'), findsOneWidget);
    expect(find.text('A barcode has 8 to 14 digits.'), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('protein, carbs and fat together must stay at or below 100 g', (tester) async {
    final repository = FakeFoodRepository();
    await _openForm(tester, repository, []);

    await tester.enterText(find.byKey(const Key('custom-name')), 'Brot');
    await tester.enterText(find.byKey(const Key('custom-kcal')), '250');
    await tester.enterText(find.byKey(const Key('custom-protein')), '60');
    await tester.enterText(find.byKey(const Key('custom-carbs')), '50');
    await _save(tester);

    expect(find.byKey(const Key('custom-error')), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('valid form saves with decimal commas and returns the food', (tester) async {
    final repository = FakeFoodRepository();
    final picked = <Food?>[];
    await _openForm(tester, repository, picked);

    await tester.enterText(find.byKey(const Key('custom-name')), ' Vollkornbrot ');
    await tester.enterText(find.byKey(const Key('custom-kcal')), '230,5');
    await tester.enterText(find.byKey(const Key('custom-protein')), '8,4');
    await tester.enterText(find.byKey(const Key('custom-carbs')), '40');
    await tester.enterText(find.byKey(const Key('custom-barcode')), '4000417025005');
    await _save(tester);

    final created = repository.created!;
    expect(created.name, 'Vollkornbrot');
    expect(created.kcal, 230.5);
    expect(created.protein, 8.4);
    expect(created.carbs, 40);
    expect(created.fat, 0);
    expect(created.barcode, '4000417025005');
    expect(created.servingSizeG, isNull);
    expect(picked.single?.name, 'Vollkornbrot');
  });

  testWidgets('server field errors are shown', (tester) async {
    final repository = FakeFoodRepository()
      ..createError = const ApiError(
        code: 'validation_error',
        message: 'Invalid input.',
        fields: {
          'barcode': ['This barcode already exists.'],
        },
        statusCode: 400,
      );
    await _openForm(tester, repository, []);

    await tester.enterText(find.byKey(const Key('custom-name')), 'Brot');
    await tester.enterText(find.byKey(const Key('custom-kcal')), '250');
    await _save(tester);

    expect(find.text('This barcode already exists.'), findsOneWidget);
  });
}
