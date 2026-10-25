import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Where barcodes come from. The real app uses the camera ([MobileBarcodeSource]);
/// widget tests inject fake codes.
abstract interface class BarcodeSource {
  /// The camera preview. Calls [onCode] for every detected code and
  /// [onPermissionDenied] when the user did not allow the camera.
  Widget buildPreview(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required VoidCallback onPermissionDenied,
  });

  /// Opens the system settings of the app (to allow the camera).
  Future<void> openSettings();
}

/// Camera scanner based on `mobile_scanner`, limited to food barcodes.
class MobileBarcodeSource implements BarcodeSource {
  const MobileBarcodeSource();

  @override
  Widget buildPreview(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required VoidCallback onPermissionDenied,
  }) =>
      _CameraPreview(onCode: onCode, onPermissionDenied: onPermissionDenied);

  @override
  Future<void> openSettings() => AppSettings.openAppSettings();
}

class _CameraPreview extends StatefulWidget {
  const _CameraPreview({required this.onCode, required this.onPermissionDenied});

  final ValueChanged<String> onCode;
  final VoidCallback onPermissionDenied;

  @override
  State<_CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<_CameraPreview> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _deniedReported = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        widget.onCode(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) {
        if (error.errorCode == MobileScannerErrorCode.permissionDenied && !_deniedReported) {
          _deniedReported = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPermissionDenied());
        }
        return const ColoredBox(color: Colors.black);
      },
    );
  }
}

/// The camera scanner; widget tests override it with a fake.
final barcodeSourceProvider = Provider<BarcodeSource>((ref) => const MobileBarcodeSource());
