import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tamra_app/app/router.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/features/food/data/food_repository.dart';
import 'package:tamra_app/features/food/domain/food.dart';
import 'package:tamra_app/features/food/presentation/barcode_source.dart';
import 'package:tamra_app/l10n/app_strings.dart';

const apple = Food(
  id: 'f1',
  name: 'Apfel',
  brand: 'Bio',
  per100g: NutritionPer100g(kcal: 52.4, protein: 0.3, carbs: 14, fat: 0.2),
);

/// Food repository with canned answers; records every call.
class FakeFoodRepository implements FoodRepository {
  List<Food> results = const [];
  Object? searchError;
  Object? createError;
  final List<String> queries = [];
  final List<String> barcodes = [];
  CustomFoodInput? created;

  /// Answer for [byBarcode]; null means "not found" (404).
  Food? barcodeFood = apple;

  @override
  Future<List<Food>> search(String query, {String? country}) async {
    queries.add(query);
    if (searchError != null) throw searchError!;
    return results;
  }

  @override
  Future<Food> byBarcode(String barcode) async {
    barcodes.add(barcode);
    final food = barcodeFood;
    if (food == null) {
      throw const ApiError(
          code: 'not_found', message: 'Not found.', statusCode: 404);
    }
    return food;
  }

  @override
  Future<Food> byId(String id) async => apple;

  @override
  Future<Food> createCustom(CustomFoodInput input) async {
    if (createError != null) throw createError!;
    created = input;
    return Food(
      id: 'new',
      name: input.name,
      isCustom: true,
      per100g: NutritionPer100g(
        kcal: input.kcal,
        protein: input.protein,
        carbs: input.carbs,
        fat: input.fat,
      ),
    );
  }
}

/// Camera replacement: the test calls [emit] or [deny].
class FakeBarcodeSource implements BarcodeSource {
  ValueChanged<String>? _onCode;
  VoidCallback? _onDenied;
  int settingsOpened = 0;

  void emit(String code) => _onCode!(code);

  void deny() => _onDenied!();

  @override
  Widget buildPreview(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required VoidCallback onPermissionDenied,
  }) {
    _onCode = onCode;
    _onDenied = onPermissionDenied;
    return const ColoredBox(key: Key('fake-camera'), color: Colors.black);
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}

/// A start page with an "open" button that pushes the food search and
/// collects what the search returns into [picked].
Widget foodTestApp(
  FakeFoodRepository repository,
  List<Food?> picked, {
  FakeBarcodeSource? barcodeSource,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                picked.add(await context.push<Food>(AppRoutes.foodSearch));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      ...foodRoutes(),
    ],
  );
  return ProviderScope(
    overrides: [
      foodRepositoryProvider.overrideWithValue(repository),
      barcodeSourceProvider
          .overrideWithValue(barcodeSource ?? FakeBarcodeSource()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

/// Room for the whole "own food" form without scrolling.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
