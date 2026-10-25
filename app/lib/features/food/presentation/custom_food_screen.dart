import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/app_strings.dart';
import '../data/food_repository.dart';
import '../domain/food.dart';

/// Parses "3.5" and "3,5". Returns null for empty or invalid text.
double? parseAmount(String? text) {
  final value = (text ?? '').trim().replaceAll(',', '.');
  if (value.isEmpty) return null;
  return double.tryParse(value);
}

/// Form for a food that is missing in the database. Returns the created [Food].
class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key, this.prefill = const CustomFoodPrefill()});

  final CustomFoodPrefill prefill;

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.prefill.name);
  final _brand = TextEditingController();
  late final _barcode = TextEditingController(text: widget.prefill.barcode ?? '');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _sugar = TextEditingController();
  final _fiber = TextEditingController();
  final _salt = TextEditingController();
  final _serving = TextEditingController();
  bool _busy = false;
  String? _error;

  List<TextEditingController> get _controllers => [
        _name, _brand, _barcode, _kcal, _protein, _carbs, //
        _fat, _sugar, _fiber, _salt, _serving,
      ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppStrings strings) async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final macros = [_protein, _carbs, _fat]
        .map((controller) => parseAmount(controller.text) ?? 0)
        .fold<double>(0, (sum, value) => sum + value);
    if (macros > 100) {
      setState(() => _error = strings.macrosTooHigh);
      return;
    }

    final barcode = _barcode.text.trim();
    final input = CustomFoodInput(
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      barcode: barcode.isEmpty ? null : barcode,
      kcal: parseAmount(_kcal.text)!,
      protein: parseAmount(_protein.text) ?? 0,
      carbs: parseAmount(_carbs.text) ?? 0,
      fat: parseAmount(_fat.text) ?? 0,
      sugar: parseAmount(_sugar.text) ?? 0,
      fiber: parseAmount(_fiber.text) ?? 0,
      salt: parseAmount(_salt.text) ?? 0,
      servingSizeG: parseAmount(_serving.text),
    );

    setState(() => _busy = true);
    try {
      final food = await ref.read(foodRepositoryProvider).createCustom(input);
      if (mounted) context.pop(food);
    } on ApiError catch (error) {
      if (!mounted) return;
      final messages = error.fieldMessages;
      setState(() {
        _error = error.isNetworkError || messages.isEmpty
            ? strings.genericError
            : messages.join('\n');
      });
    } catch (_) {
      if (mounted) setState(() => _error = strings.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Validator for a number between [min] and [max]; empty is ok unless [required].
  FormFieldValidator<String> _number(
    AppStrings strings, {
    required num min,
    required num max,
    bool required = false,
  }) {
    return (text) {
      if ((text ?? '').trim().isEmpty) return required ? strings.fieldRequired : null;
      final value = parseAmount(text);
      if (value == null) return strings.invalidNumber;
      if (value < min || value > max) return strings.invalidRange(min, max);
      return null;
    };
  }

  Widget _numberField(
    String key,
    TextEditingController controller,
    String label,
    FormFieldValidator<String> validator,
  ) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: TextFormField(
        key: Key(key),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    String grams(String name) => strings.gramsLabel(name);

    return Scaffold(
      appBar: AppBar(title: Text(strings.customFoodTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsetsDirectional.all(16),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: TextFormField(
                key: const Key('custom-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: strings.foodName),
                validator: (text) =>
                    (text ?? '').trim().isEmpty ? strings.fieldRequired : null,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: TextFormField(
                key: const Key('custom-brand'),
                controller: _brand,
                decoration: InputDecoration(labelText: strings.foodBrand),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: TextFormField(
                key: const Key('custom-barcode'),
                controller: _barcode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: strings.barcodeOptional),
                validator: (text) {
                  final value = (text ?? '').trim();
                  if (value.isEmpty) return null;
                  return RegExp(r'^\d{8,14}$').hasMatch(value) ? null : strings.barcodeInvalid;
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(strings.per100gHeading, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _numberField(
              'custom-kcal',
              _kcal,
              strings.kcalLabel,
              _number(strings, min: 0, max: 900, required: true),
            ),
            _numberField('custom-protein', _protein, grams(strings.protein),
                _number(strings, min: 0, max: 100)),
            _numberField(
                'custom-carbs', _carbs, grams(strings.carbs), _number(strings, min: 0, max: 100)),
            _numberField(
                'custom-sugar', _sugar, grams(strings.sugar), _number(strings, min: 0, max: 100)),
            _numberField('custom-fat', _fat, grams(strings.fat), _number(strings, min: 0, max: 100)),
            _numberField(
                'custom-fiber', _fiber, grams(strings.fiber), _number(strings, min: 0, max: 100)),
            _numberField(
                'custom-salt', _salt, grams(strings.salt), _number(strings, min: 0, max: 100)),
            _numberField('custom-serving', _serving, strings.servingSize,
                _number(strings, min: 0.1, max: 5000)),
            if (_error != null) ...[
              Text(
                _error!,
                key: const Key('custom-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const Key('custom-save'),
              onPressed: _busy ? null : () => _save(strings),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.save),
            ),
          ],
        ),
      ),
    );
  }
}
