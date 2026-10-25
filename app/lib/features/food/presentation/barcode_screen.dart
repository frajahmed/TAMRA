import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/app_strings.dart';
import '../data/food_repository.dart';
import '../domain/food.dart';
import 'barcode_source.dart';

final _foodBarcode = RegExp(r'^\d{8,14}$');

/// Scans a food barcode and returns the [Food] (`context.push<Food>(AppRoutes.foodScan)`).
class BarcodeScreen extends ConsumerStatefulWidget {
  const BarcodeScreen({super.key});

  @override
  ConsumerState<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends ConsumerState<BarcodeScreen> {
  /// True while a code is being looked up; further codes are ignored.
  bool _handling = false;
  bool _loading = false;
  bool _denied = false;
  String? _error;

  Future<void> _onCode(String code) async {
    if (_handling || !_foodBarcode.hasMatch(code)) return;
    _handling = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final food = await ref.read(foodRepositoryProvider).byBarcode(code);
      if (mounted) context.pop(food);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (error.statusCode == 404) {
        await _notFound(code);
      } else {
        setState(() => _error = AppStrings.of(context).genericError);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppStrings.of(context).genericError;
      });
    }
  }

  Future<void> _notFound(String code) async {
    final strings = AppStrings.of(context);
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('scan-not-found'),
        title: Text(strings.scanNotFoundTitle),
        content: Text(strings.scanNotFoundText(code)),
        actions: [
          TextButton(
            key: const Key('scan-again'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.scanAgain),
          ),
          FilledButton(
            key: const Key('scan-create'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.foodCreateCustom),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (create == true) {
      final food = await context.push<Food>(
        AppRoutes.foodCustom,
        extra: CustomFoodPrefill(barcode: code),
      );
      if (!mounted) return;
      if (food != null) {
        context.pop(food);
        return;
      }
    }
    _scanAgain();
  }

  void _scanAgain() {
    setState(() {
      _handling = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final source = ref.watch(barcodeSourceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.scanTitle)),
      body: _denied
          ? Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.cameraDeniedText,
                      key: const Key('scan-denied'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('scan-open-settings'),
                      onPressed: source.openSettings,
                      child: Text(strings.openSettings),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                source.buildPreview(
                  context,
                  onCode: _onCode,
                  onPermissionDenied: () => setState(() => _denied = true),
                ),
                const IgnorePointer(child: Center(child: _ScanFrame())),
                PositionedDirectional(
                  start: 24,
                  end: 24,
                  bottom: 48,
                  child: _error == null
                      ? Text(
                          strings.scanHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              key: const Key('scan-error'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const Key('scan-retry'),
                              onPressed: _scanAgain,
                              child: Text(strings.scanAgain),
                            ),
                          ],
                        ),
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator(key: Key('scan-loading'))),
              ],
            ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 170,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
