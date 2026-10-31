import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/features/food/data/food_repository.dart';
import 'package:tamra_app/features/food/domain/food.dart';
import 'package:tamra_app/features/food/presentation/food_search_screen.dart';

import '../../helpers/fakes.dart';
import 'food_fakes.dart';

final _field = find.byKey(const Key('food-search-field'));

Future<void> _openSearch(WidgetTester tester, FakeFoodRepository repository,
    List<Food?> picked) async {
  await tester.pumpWidget(foodTestApp(repository, picked));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

/// Lets the debounce timer fire and the fake search answer.
Future<void> _waitForSearch(WidgetTester tester) async {
  await tester.pump(searchDebounce);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing fast sends only one request after the debounce',
      (tester) async {
    final repository = FakeFoodRepository()..results = [apple];
    final picked = <Food?>[];
    await _openSearch(tester, repository, picked);

    for (final text in ['ap', 'apf', 'apfe', 'apfel']) {
      await tester.enterText(_field, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(repository.queries, isEmpty);

    await _waitForSearch(tester);
    expect(repository.queries, ['apfel']);
  });

  testWidgets('less than 2 letters never calls the API', (tester) async {
    final repository = FakeFoodRepository();
    await _openSearch(tester, repository, []);

    await tester.enterText(_field, 'a');
    await tester.pump(const Duration(seconds: 1));

    expect(repository.queries, isEmpty);
    expect(find.byKey(const Key('food-search-idle')), findsOneWidget);
    expect(find.text('Type at least 2 letters.'), findsOneWidget);
  });

  testWidgets('results show name, brand and kcal; tap returns the food',
      (tester) async {
    final repository = FakeFoodRepository()..results = [apple];
    final picked = <Food?>[];
    await _openSearch(tester, repository, picked);

    await tester.enterText(_field, 'apfel');
    await _waitForSearch(tester);

    expect(find.text('Apfel'), findsOneWidget);
    expect(find.text('Bio'), findsOneWidget);
    expect(find.text('52 kcal / 100 g'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-result-f1')));
    await tester.pumpAndSettle();

    expect(picked, [apple]);
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    final repository = FakeFoodRepository()
      ..searchError = const ApiError(code: 'network_error', message: 'offline');
    await _openSearch(tester, repository, []);

    await tester.enterText(_field, 'apfel');
    await _waitForSearch(tester);
    expect(find.byKey(const Key('food-search-error')), findsOneWidget);

    repository
      ..searchError = null
      ..results = [apple];
    await tester.tap(find.byKey(const Key('food-retry')));
    await tester.pumpAndSettle();

    expect(repository.queries, ['apfel', 'apfel']);
    expect(find.byKey(const Key('food-result-f1')), findsOneWidget);
  });

  testWidgets(
      'empty result leads to the own-food form and returns the new food',
      (tester) async {
    useTallScreen(tester);
    final repository = FakeFoodRepository();
    final picked = <Food?>[];
    await _openSearch(tester, repository, picked);

    await tester.enterText(_field, 'Omas Kuchen');
    await _waitForSearch(tester);
    expect(find.text('No food found for "Omas Kuchen".'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-create-custom')));
    await tester.pumpAndSettle();

    final nameField =
        tester.widget<TextFormField>(find.byKey(const Key('custom-name')));
    expect(nameField.controller?.text, 'Omas Kuchen');

    await tester.enterText(find.byKey(const Key('custom-kcal')), '380');
    await tester.tap(find.byKey(const Key('custom-save')));
    await tester.pumpAndSettle();

    expect(repository.created?.name, 'Omas Kuchen');
    expect(picked.single?.id, 'new');
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('the + of a meal in the diary opens the food search',
      (tester) async {
    useTallView(tester);
    await tester.pumpWidget(
      testApp(overrides: [
        foodRepositoryProvider.overrideWithValue(FakeFoodRepository())
      ]),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('add-breakfast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-breakfast')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-search-field')), findsOneWidget);
  });
}
