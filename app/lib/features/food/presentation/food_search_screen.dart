import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../data/food_repository.dart';
import '../domain/food.dart';

/// Wait this long after the last keystroke before searching.
const searchDebounce = Duration(milliseconds: 400);

/// Minimum number of characters before the API is called.
const searchMinChars = 2;

enum _SearchStatus { idle, loading, results, empty, error }

/// Search foods by name or brand. Tapping a result returns it to the caller
/// (`context.push<Food>(AppRoutes.foodSearch)`).
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  _SearchStatus _status = _SearchStatus.idle;
  List<Food> _results = const [];
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < searchMinChars) {
      _requestId++; // ignore answers that are still on the way
      setState(() {
        _status = _SearchStatus.idle;
        _results = const [];
        _query = query;
      });
      return;
    }
    _debounce = Timer(searchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _status = _SearchStatus.loading;
      _query = query;
    });
    try {
      final results = await ref.read(foodRepositoryProvider).search(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _status = results.isEmpty ? _SearchStatus.empty : _SearchStatus.results;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _status = _SearchStatus.error);
    }
  }

  Future<void> _createCustom() async {
    final food = await context.push<Food>(
      AppRoutes.foodCustom,
      extra: CustomFoodPrefill(name: _query),
    );
    if (food != null && mounted) context.pop(food);
  }

  Future<void> _scan() async {
    final food = await context.push<Food>(AppRoutes.foodScan);
    if (food != null && mounted) context.pop(food);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.foodSearchTitle),
        actions: [
          IconButton(
            key: const Key('food-scan'),
            tooltip: strings.scanTitle,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
          IconButton(
            key: const Key('food-add-custom'),
            tooltip: strings.foodCreateCustom,
            icon: const Icon(Icons.add),
            onPressed: _createCustom,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            child: TextField(
              key: const Key('food-search-field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: strings.foodSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _onChanged,
              onSubmitted: (text) {
                final query = text.trim();
                if (query.length < searchMinChars) return;
                _debounce?.cancel();
                _search(query);
              },
            ),
          ),
          Expanded(child: _body(strings)),
        ],
      ),
    );
  }

  Widget _body(AppStrings strings) {
    switch (_status) {
      case _SearchStatus.idle:
        return _Message(
            key: const Key('food-search-idle'),
            text: strings.foodSearchMinChars);
      case _SearchStatus.loading:
        return const Center(
            child: CircularProgressIndicator(key: Key('food-search-loading')));
      case _SearchStatus.error:
        return _Message(
          key: const Key('food-search-error'),
          text: strings.genericError,
          action: OutlinedButton(
            key: const Key('food-retry'),
            onPressed: () => _search(_query),
            child: Text(strings.retry),
          ),
        );
      case _SearchStatus.empty:
        return _Message(
          key: const Key('food-search-empty'),
          text: strings.foodNoResults(_query),
          action: FilledButton(
            key: const Key('food-create-custom'),
            onPressed: _createCustom,
            child: Text(strings.foodCreateCustom),
          ),
        );
      case _SearchStatus.results:
        return ListView.separated(
          key: const Key('food-results'),
          itemCount: _results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final food = _results[index];
            return ListTile(
              key: Key('food-result-${food.id}'),
              title: Text(food.name),
              subtitle: food.brand.isEmpty ? null : Text(food.brand),
              trailing: Text(strings.kcalPer100g(food.per100g.kcal.round())),
              onTap: () => context.pop(food),
            );
          },
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
